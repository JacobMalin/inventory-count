import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/setup/export_setup_page.dart';
import 'package:inventory_count/setup/shelf_setup_page.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            body: const TabBarView(
              children: [ShelfSetupPage(), ExportSetupPage()],
            ),
            bottomNavigationBar: Row(
              children: [
                const Expanded(
                  child: TabBar(
                    tabs: [
                      Tab(text: 'Areas'),
                      Tab(text: 'Export Order'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: BackupButton(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BackupButton extends StatelessWidget {
  const BackupButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.import_export),
      onPressed: () {
        showBackupAndRestore(context);
      },
    );
  }

  Future<dynamic> showBackupAndRestore(BuildContext hostContext) {
    return showDialog(
      context: hostContext,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Backup & Restore'),
        content: const Text(
          'Choose an option to backup or restore your inventory data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          Consumer<AreaModel>(
            builder: (context, areaModel, child) {
              return TextButton(
                onPressed: () async {
                  final messengerHost = ScaffoldMessenger.of(hostContext);
                  Navigator.of(dialogCtx).pop();

                  try {
                    final jsonString = areaModel.exportAllToJson();

                    final now = DateTime.now();
                    final timestamp =
                        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                    final defaultFileName = timestamp;

                    final nameController = TextEditingController(
                      text: defaultFileName,
                    );
                    final String? chosenName = await showDialog<String>(
                      context: hostContext,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Export file name'),
                        content: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'File name',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(ctx, nameController.text.trim()),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );

                    if (chosenName == null || chosenName.isEmpty) {
                      // user cancelled - do nothing
                      return;
                    }

                    final storage = Supabase.instance.client.from('setups');

                    bool exists = false;
                    try {
                      exists =
                          (await storage
                                  .select()
                                  .eq('name', chosenName)
                                  .count())
                              .count >
                          0;
                    } catch (_) {
                      // ignore exists check errors, proceed to upload which may fail
                    }

                    if (exists) {
                      if (!hostContext.mounted) return;
                      final overwrite = await showDialog<bool>(
                        context: hostContext,
                        builder: (ctx) => AlertDialog(
                          title: const Text('File exists'),
                          content: Text(
                            'A backup named "$chosenName" already exists. Overwrite?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Overwrite'),
                            ),
                          ],
                        ),
                      );

                      if (overwrite != true) {
                        messengerHost.showSnackBar(
                          const SnackBar(
                            content: Text('Upload cancelled.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      await storage
                          .update({
                            'json': jsonString,
                            'updated_at': DateTime.now()
                                .toUtc()
                                .toIso8601String(),
                          })
                          .eq('name', chosenName);
                    } else {
                      await storage.insert({
                        'name': chosenName,
                        'json': jsonString,
                      });
                    }

                    messengerHost.showSnackBar(
                      SnackBar(
                        content: GestureDetector(
                          onTap: () => messengerHost.hideCurrentSnackBar(),
                          child: const Text('Data exported successfully!'),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    messengerHost.showSnackBar(
                      SnackBar(
                        content: GestureDetector(
                          onTap: () => messengerHost.hideCurrentSnackBar(),
                          child: Text('Export failed: $e'),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text('Backup'),
              );
            },
          ),
          RestoreButton(hostContext: hostContext),
        ],
      ),
    );
  }
}

class RestoreButton extends StatelessWidget {
  final BuildContext hostContext;
  const RestoreButton({super.key, required this.hostContext});

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            final messengerHost = ScaffoldMessenger.of(hostContext);

            // Show confirmation dialog
            final confirm = await showDialog<bool>(
              context: hostContext,
              builder: (confirmCtx) => AlertDialog(
                title: const Text('Restore Data'),
                content: const Text(
                  'This will replace all current areas, items, and export order. Are you sure?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(confirmCtx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final storage = Supabase.instance.client.from('setups');

                      // close the confirmation dialog
                      Navigator.of(confirmCtx).pop();

                      // Show dialog that lists files using FutureBuilder
                      final choice = await showDialog<String?>(
                        context: hostContext,
                        builder: (dialogCtx) {
                          return AlertDialog(
                            title: const Text('Select backup to restore'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: StreamBuilder(
                                stream: storage
                                    .stream(primaryKey: ['name'])
                                    .order('updated_at', ascending: false),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox(
                                      height: 80,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  if (snapshot.hasError ||
                                      snapshot.data == null) {
                                    return const Text(
                                      'Failed to list backups.',
                                    );
                                  }

                                  final backups = snapshot.data!;
                                  if (backups.isEmpty) {
                                    return const Text('No backups found.');
                                  }

                                  return ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: backups.length,
                                    itemBuilder: (context, index) {
                                      final backup = backups[index];
                                      final name = backup['name'] as String;
                                      String updated = '';
                                      if (backup['updated_at'] != null) {
                                        DateTime? dt;
                                        if (backup['updated_at'] is DateTime) {
                                          dt = backup['updated_at'] as DateTime;
                                        } else {
                                          dt = DateTime.tryParse(
                                            backup['updated_at'].toString(),
                                          )?.toLocal();
                                        }
                                        if (dt != null) {
                                          updated = DateFormat.yMMMd()
                                              .add_jm()
                                              .format(dt);
                                        } else {
                                          updated = backup['updated_at']
                                              .toString();
                                        }
                                      }
                                      return ListTile(
                                        title: Text(name),
                                        subtitle: Text(updated),
                                        onTap: () => Navigator.pop(
                                          dialogCtx,
                                          backup['json'],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      );

                      if (choice == null) return;

                      try {
                        areaModel.importAllFromJson(choice);

                        if (!hostContext.mounted) return;
                        ScaffoldMessenger.of(hostContext).showSnackBar(
                          const SnackBar(
                            content: Text('Backup restored.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } catch (e) {
                        if (!hostContext.mounted) return;
                        ScaffoldMessenger.of(hostContext).showSnackBar(
                          SnackBar(
                            content: Text('Restore failed: $e'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text('Restore'),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['json'],
                );

                if (result != null && result.files.single.path != null) {
                  final file = File(result.files.single.path!);
                  final jsonString = await file.readAsString();

                  areaModel.importAllFromJson(jsonString);

                  messengerHost.showSnackBar(
                    SnackBar(
                      content: GestureDetector(
                        onTap: () => messengerHost.hideCurrentSnackBar(),
                        child: const Text('Data imported successfully!'),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                messengerHost.showSnackBar(
                  SnackBar(
                    content: GestureDetector(
                      onTap: () => messengerHost.hideCurrentSnackBar(),
                      child: Text('Import failed: $e'),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          child: const Text('Restore'),
        );
      },
    );
  }
}
