import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/setup/export_setup_page.dart';
import 'package:inventory_count/setup/shelf_setup_page.dart';
import 'package:provider/provider.dart';

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
                  child: IconButton(
                    icon: const Icon(Icons.import_export),
                    onPressed: () {
                      showDialog(
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
                            TextButton(
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                Navigator.pop(context);

                                try {
                                  final jsonString = areaModel
                                      .exportAllToJson();
                                  final bytes = Uint8List.fromList(
                                    jsonString.codeUnits,
                                  );

                                  final now = DateTime.now();
                                  final timestamp =
                                      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                                  final fileName =
                                      'inventory_backup_$timestamp.json';

                                  final String? outputPath = await FilePicker
                                      .platform
                                      .saveFile(
                                        dialogTitle: 'Save inventory backup',
                                        fileName: fileName,
                                        type: FileType.custom,
                                        bytes: bytes,
                                        allowedExtensions: ['json'],
                                      );

                                  if (outputPath != null) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: GestureDetector(
                                          onTap: () =>
                                              messenger.hideCurrentSnackBar(),
                                          child: const Text(
                                            'Data exported successfully!',
                                          ),
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: GestureDetector(
                                        onTap: () =>
                                            messenger.hideCurrentSnackBar(),
                                        child: Text('Export failed: $e'),
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Backup'),
                            ),
                            TextButton(
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                Navigator.pop(context);

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
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Restore'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  try {
                                    final result = await FilePicker.platform
                                        .pickFiles(
                                          type: FileType.custom,
                                          allowedExtensions: ['json'],
                                        );

                                    if (result != null &&
                                        result.files.single.path != null) {
                                      final file = File(
                                        result.files.single.path!,
                                      );
                                      final jsonString = await file
                                          .readAsString();

                                      areaModel.importAllFromJson(jsonString);

                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: GestureDetector(
                                            onTap: () =>
                                                messenger.hideCurrentSnackBar(),
                                            child: const Text(
                                              'Data imported successfully!',
                                            ),
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: GestureDetector(
                                          onTap: () =>
                                              messenger.hideCurrentSnackBar(),
                                          child: Text('Import failed: $e'),
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('Restore'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
