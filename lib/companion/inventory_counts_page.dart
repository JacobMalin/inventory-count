import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main/models/data/inventory_models.dart';
import 'omniterm_interaction.dart';
import 'window_model.dart';

class InventoryCountsPage extends StatelessWidget {
  const InventoryCountsPage({super.key});

  String _formatCountName(String rawName) {
    final DateTime? isoParsed = DateTime.tryParse(rawName);
    if (isoParsed != null) {
      return DateFormat.yMMMMd().format(isoParsed);
    }

    return rawName;
  }

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

          return ListView.separated(
            itemCount: counts.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 36, endIndent: 36),
            itemBuilder: (context, index) {
              final Map<String, dynamic> count = counts[index];

              final String profile = count['profile'] ?? 'Default';
              final countName = (count['name'] ?? '').toString();
              final String countId = _formatCountName(countName);

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

              final String jsonString = count['json'] is String
                  ? count['json'] as String
                  : jsonEncode(count['json']);

              return ListTile(
                title: Text(
                  countId.isNotEmpty ? countId : 'Count',
                  overflow: TextOverflow.ellipsis,
                ),
                leading: Icon(
                  Profile(profile).icon,
                  color: Profile(profile).color,
                ),
                subtitle: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: profile,
                        style: TextStyle(color: Profile(profile).color),
                      ),
                      TextSpan(
                        text: ' • Last updated: $time',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                onTap: () async {
                  try {
                    if (!context.mounted) return;
                    final hostContext = context;
                    await showItemDialogue(
                      context,
                      countId,
                      time,
                      profile,
                      jsonString,
                      hostContext,
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

  Future<dynamic> showItemDialogue(
    BuildContext context,
    String countName,
    String time,
    String profile,
    String jsonString,
    BuildContext hostContext,
  ) {
    var isFillingOut = false;
    var isPrinting = false;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(countName.isNotEmpty ? countName : time),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Profile(profile).icon,
                    size: 16,
                    color: Profile(profile).color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    profile,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Profile(profile).color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          content: isFillingOut
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Flexible(child: Text('Filling out Omniterm...')),
                  ],
                )
              : isPrinting
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Flexible(child: Text('Printing count...')),
                  ],
                )
              : Text(
                  'Would you like to print the count or fill '
                  'out Omniterm with the count '
                  'updated on $time?',
                ),
          actions: [
            TextButton(
              onPressed: isFillingOut || isPrinting
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isFillingOut || isPrinting
                  ? null
                  : () async {
                      setDialogState(() {
                        isFillingOut = true;
                      });

                      try {
                        final bool success =
                            await OmnitermInteraction.fillOutCount(jsonString);

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }

                        if (hostContext.mounted) {
                          ScaffoldMessenger.of(hostContext).showSnackBar(
                            SnackBar(
                              content: success
                                  ? const Text('Omniterm autofill completed.')
                                  : const Text('Omniterm autofill canceled.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } on Exception catch (e) {
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }

                        if (hostContext.mounted) {
                          ScaffoldMessenger.of(hostContext).showSnackBar(
                            SnackBar(
                              content: Text('Omniterm autofill failed:\n$e'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            isFillingOut = false;
                          });
                        }
                      }
                    },
              child: const Text('Fill Out Omniterm'),
            ),
            TextButton(
              onPressed: isFillingOut || isPrinting
                  ? null
                  : () async {
                      setDialogState(() {
                        isPrinting = true;
                      });

                      try {
                        final bool success = await printJson(
                          hostContext,
                          jsonString,
                        );

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }

                        if (hostContext.mounted) {
                          ScaffoldMessenger.of(hostContext).showSnackBar(
                            SnackBar(
                              content: success
                                  ? const Text('Print completed. Exiting...')
                                  : const Text('Print canceled.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }

                        if (success) {
                          await Future.delayed(const Duration(seconds: 2));
                          exit(0);
                        }
                      } on Exception catch (e) {
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }

                        if (hostContext.mounted) {
                          ScaffoldMessenger.of(hostContext).showSnackBar(
                            SnackBar(
                              content: Text('Print failed: $e'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            isPrinting = false;
                          });
                        }
                      }
                    },
              child: const Text('Print'),
            ),
          ],
        ),
      ),
    );
  }
}
