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

  Future<dynamic> showBackupAndRestore(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup & Restore'),
        content: const Text(
          'Choose an option to backup or restore your inventory data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          Consumer<AreaModel>(
            builder: (context, areaModel, child) {
              return TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  navigator.pop();

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
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Export file name'),
                        content: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'File name',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(
                              context,
                              nameController.text.trim(),
                            ),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );

                    if (chosenName == null || chosenName.isEmpty) {
                      // user cancelled - do nothing
                      return;
                    }

                    var fileName = chosenName;
                    if (!fileName.toLowerCase().endsWith('.json')) {
                      fileName = '$fileName.json';
                    }

                    final tempDir = Directory.systemTemp;
                    final file = File('${tempDir.path}/$fileName');
                    await file.writeAsString(jsonString);

                    final storage = Supabase.instance.client.storage.from(
                      'Setups',
                    );

                    bool exists = false;
                    try {
                      exists = await storage.exists(fileName);
                    } catch (_) {
                      // ignore exists check errors, proceed to upload which may fail
                    }

                    if (exists) {
                      if (!context.mounted) return;
                      final overwrite = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('File exists'),
                          content: Text(
                            'A backup named "$fileName" already exists. Overwrite?',
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
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Upload cancelled.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                    }

                    await storage.upload(fileName, file);

                    file.delete();

                    messenger.showSnackBar(
                      SnackBar(
                        content: GestureDetector(
                          onTap: () => messenger.hideCurrentSnackBar(),
                          child: const Text('Data exported successfully!'),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: GestureDetector(
                          onTap: () => messenger.hideCurrentSnackBar(),
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
          RestoreButton(),
        ],
      ),
    );
  }
}

class RestoreButton extends StatelessWidget {
  const RestoreButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return TextButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(context);
            navigator.pop();

            // Show confirmation dialog
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Restore Data'),
                content: const Text(
                  'This will replace all current areas, items, and export order. Are you sure?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final dialogMessenger = ScaffoldMessenger.of(context);
                      final dialogNavigator = Navigator.of(context);
                      final storage = Supabase.instance.client.storage.from(
                        'Setups',
                      );
                      dialogNavigator.pop();

                      // Show dialog that lists files using FutureBuilder
                      final choice = await showDialog<String?>(
                        context: context,
                        builder: (dialogCtx) {
                          return AlertDialog(
                            title: const Text('Select backup to restore'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: FutureBuilder<List<FileObject>>(
                                future: storage.list(),
                                builder: (ctx, snap) {
                                  if (snap.connectionState !=
                                      ConnectionState.done) {
                                    return const SizedBox(
                                      height: 80,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  if (snap.hasError || snap.data == null) {
                                    return const Text(
                                      'Failed to list backups.',
                                    );
                                  }

                                  final files = snap.data!;
                                  if (files.isEmpty) {
                                    return const Text('No backups found.');
                                  }

                                  return ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: files.length,
                                    itemBuilder: (context, index) {
                                      final f = files[index];
                                      final name = f.name;
                                      final displayName =
                                          name.toLowerCase().endsWith('.json')
                                          ? name.substring(0, name.length - 5)
                                          : name;
                                      String updated = '';
                                      if (f.updatedAt != null) {
                                        DateTime? dt;
                                        if (f.updatedAt is DateTime) {
                                          dt = f.updatedAt as DateTime;
                                        } else {
                                          dt = DateTime.tryParse(
                                            f.updatedAt.toString(),
                                          );
                                        }
                                        if (dt != null) {
                                          updated = DateFormat.yMMMd()
                                              .add_jm()
                                              .format(dt);
                                        } else {
                                          updated = f.updatedAt.toString();
                                        }
                                      }
                                      return ListTile(
                                        title: Text(displayName),
                                        subtitle: Text(updated),
                                        onTap: () =>
                                            Navigator.pop(dialogCtx, name),
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
                        final res = await storage.download(choice);

                        String jsonString = utf8.decode(res as List<int>);

                        areaModel.importAllFromJson(jsonString);

                        dialogMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Backup restored.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } catch (e) {
                        dialogMessenger.showSnackBar(
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

                  messenger.showSnackBar(
                    SnackBar(
                      content: GestureDetector(
                        onTap: () => messenger.hideCurrentSnackBar(),
                        child: const Text('Data imported successfully!'),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: GestureDetector(
                      onTap: () => messenger.hideCurrentSnackBar(),
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
