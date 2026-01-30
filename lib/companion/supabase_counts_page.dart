import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'window_model.dart';

class SupabaseCountsPage extends StatelessWidget {
  const SupabaseCountsPage({super.key});

  Future<bool> printJson(BuildContext context, String json) async {
    // Prompt user to locate Excel if not configured
    if (WindowModel.countExcelPath == null ||
        !await File(WindowModel.countExcelPath!).exists()) {
      if (!context.mounted) return false;
      final locate = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Locate Conc Inventory Count Sheet'),
          content: const Text(
            'Inventory Sheet path is not configured. Would you like to locate the Excel sheet?',
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

      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Excel sheet',
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'xlsm'],
      );
      final path = result?.files.single.path;
      if (path == null) return false;
      WindowModel.countExcelPath = path;
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
    final tempDir = Directory.systemTemp;
    final scriptFile = await File(
      '${tempDir.path}\\print_count_${DateTime.now().millisecondsSinceEpoch}.vbs',
    ).create();
    await scriptFile.writeAsString(printCountVbs);

    final vbsJsonFile = await File(
      '${tempDir.path}\\vbs_json_${DateTime.now().millisecondsSinceEpoch}.vbs',
    ).create();
    await vbsJsonFile.writeAsString(vbsJsonVbs);

    final jsonFile = await File(
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

      final proc = await Process.start('cscript', [
        '//Nologo',
        scriptFile.path,
        vbsJsonFile.path,
        WindowModel.countExcelPath!,
        jsonFile.path,
      ]);

      final stdoutData = proc.stdout.transform(utf8.decoder).join();
      final stderrData = proc.stderr.transform(utf8.decoder).join();

      final exitCode = await proc.exitCode;
      final out = await stdoutData;
      final err = await stderrData;

      if (exitCode != 0) {
        throw Exception(
          'cscript failed (exit $exitCode): ${err.isNotEmpty ? err : out}',
        );
      }

      return true;
    } finally {
      try {
        if (await scriptFile.exists()) await scriptFile.delete();
      } catch (_) {}
      try {
        if (await vbsJsonFile.exists()) await vbsJsonFile.delete();
      } catch (_) {}
      try {
        if (await jsonFile.exists()) await jsonFile.delete();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = Supabase.instance.client.from('counts');

    return SafeArea(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: storage
            .stream(primaryKey: ['created_at'])
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final counts = snapshot.data ?? [];
          if (counts.isEmpty) {
            return const Center(child: Text('No counts found.'));
          }

          return ListView.builder(
            itemCount: counts.length,
            itemBuilder: (context, index) {
              final count = counts[index];

              var title = '';
              if (count['created_at'] != null) {
                DateTime? dt;
                if (count['created_at'] is DateTime) {
                  dt = count['created_at'] as DateTime;
                } else {
                  dt = DateTime.tryParse(
                    count['created_at'].toString(),
                  )?.toLocal();
                }
                if (dt != null) {
                  title = DateFormat.yMMMd().add_jm().format(dt);
                } else {
                  title = count['created_at'].toString();
                }
              }

              return ListTile(
                title: Text(title),
                leading: const Icon(Icons.insert_drive_file),
                onTap: () async {
                  try {
                    if (!context.mounted) return;
                    final hostContext = context;
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Print this count?'),
                        content: Text(
                          'Would you like to print the count uploaded on $title?',
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
                                bool success = await printJson(
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
                                          ? Text('Print completed. Exiting...')
                                          : Text('Print canceled.'),
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
                              } catch (e) {
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
                  } catch (e) {
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
