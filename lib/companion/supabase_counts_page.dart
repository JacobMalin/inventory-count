import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main/models/data/inventory_models.dart';
import 'window_model.dart';

class SupabaseCountsPage extends StatelessWidget {
  const SupabaseCountsPage({super.key});

  Future<bool> printJson(BuildContext context, String json) async {
    final windowModel = WindowModel();

    // Prompt user to locate Excel if not configured
    if (windowModel.countExcelPath == null ||
        !File(windowModel.countExcelPath!).existsSync()) {
      if (!context.mounted) return false;
      final bool? locate = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Locate Conc Inventory Count Sheet'),
          content: const Text(
            'Inventory Sheet path is not configured. '
            'Would you like to locate the Excel sheet?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Locate'),
            ),
          ],
        ),
      );

      if (locate != true) return false;

      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Excel sheet',
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'xlsm'],
      );
      final String? path = result?.files.single.path;
      if (path == null) return false;
      windowModel.countExcelPath = path;
    }

    if (!context.mounted) return false;

    final String printCountVbs = await DefaultAssetBundle.of(
      context,
    ).loadString('assets/PrintCount.vbs');

    if (!context.mounted) return false;

    final String vbsJsonVbs = await DefaultAssetBundle.of(
      context,
    ).loadString('assets/VbsJson.vbs');

    // Create temporary VBS script and JSON file
    final Directory tempDir = Directory.systemTemp;
    final File scriptFile = await File(
      '${tempDir.path}\\print_count_${DateTime.now().millisecondsSinceEpoch}.vbs',
    ).create();
    await scriptFile.writeAsString(printCountVbs);

    final File vbsJsonFile = await File(
      '${tempDir.path}\\vbs_json_${DateTime.now().millisecondsSinceEpoch}.vbs',
    ).create();
    await vbsJsonFile.writeAsString(vbsJsonVbs);

    final File jsonFile = await File(
      '${tempDir.path}\\count_${DateTime.now().millisecondsSinceEpoch}.json',
    ).create();
    await jsonFile.writeAsString(json);

    try {
      if (!Platform.isWindows) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Printing is only supported on Windows.'),
            ),
          );
        }
        return false;
      }

      final Process proc = await Process.start('cscript', [
        '//Nologo',
        scriptFile.path,
        vbsJsonFile.path,
        windowModel.countExcelPath!,
        jsonFile.path,
      ]);

      final Future<String> stdoutData = proc.stdout
          .transform(utf8.decoder)
          .join();
      final Future<String> stderrData = proc.stderr
          .transform(utf8.decoder)
          .join();

      final int exitCode = await proc.exitCode;
      final String out = await stdoutData;
      final String err = await stderrData;

      if (exitCode != 0) {
        throw Exception(
          'cscript failed (exit $exitCode): ${err.isNotEmpty ? err : out}',
        );
      }

      return true;
    } finally {
      try {
        if (scriptFile.existsSync()) await scriptFile.delete();
      } on Exception {
        // On fail, do nothing
      }
      try {
        if (vbsJsonFile.existsSync()) await vbsJsonFile.delete();
      } on Exception {
        // On fail, do nothing
      }
      try {
        if (jsonFile.existsSync()) await jsonFile.delete();
      } on Exception {
        // On fail, do nothing
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final SupabaseQueryBuilder storage = Supabase.instance.client.from(
      'counts',
    );

    return SafeArea(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: storage
            .stream(primaryKey: ['name', 'profile'])
            .order('updated_at'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final List<Map<String, dynamic>> counts = snapshot.data ?? [];
          if (counts.isEmpty) {
            return const Center(child: Text('No counts found.'));
          }

          return ListView.builder(
            itemCount: counts.length,
            itemBuilder: (context, index) {
              final Map<String, dynamic> count = counts[index];

              final String profile = count['profile'] ?? 'Default';

              var time = '';
              if (count['updated_at'] != null) {
                final DateTime? dt = DateTime.tryParse(
                  count['updated_at'].toString(),
                )?.toLocal();

                if (dt != null) {
                  time = DateFormat.yMMMd().add_jm().format(dt);
                } else {
                  time = count['updated_at'].toString();
                }
              }

              return ListTile(
                title: Text(
                  profile,
                  style: TextStyle(color: Profile(profile).color),
                ),
                leading: Icon(
                  Profile(profile).icon,
                  color: Profile(profile).color,
                ),
                subtitle: Text('Last updated: $time'),
                onTap: () async {
                  try {
                    if (!context.mounted) return;
                    final hostContext = context;
                    await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Print this count?'),
                        content: Text(
                          'Would you like to print the count '
                          'updated on $time?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop();

                              try {
                                final bool success = await printJson(
                                  hostContext,
                                  count['json'] is String
                                      ? count['json'] as String
                                      : jsonEncode(count['json']),
                                );

                                if (hostContext.mounted) {
                                  ScaffoldMessenger.of(
                                    hostContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: success
                                          ? const Text(
                                              'Print completed. Exiting...',
                                            )
                                          : const Text('Print canceled.'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }

                                if (success) {
                                  await Future.delayed(
                                    const Duration(seconds: 2),
                                  );
                                  exit(0);
                                }
                              } on Exception catch (e) {
                                if (hostContext.mounted) {
                                  ScaffoldMessenger.of(
                                    hostContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text('Print failed: $e'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text('Print'),
                          ),
                        ],
                      ),
                    );
                  } on Exception catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Download failed: $e')),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
