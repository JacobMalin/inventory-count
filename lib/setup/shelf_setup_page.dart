import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:inventory_count/setup/area_page.dart';
import 'package:inventory_count/setup/item_page.dart';
import 'package:inventory_count/setup/setup_tiles.dart';
import 'package:inventory_count/setup/shelf_page.dart';
import 'package:provider/provider.dart';

class ShelfSetupPage extends StatefulWidget {
  const ShelfSetupPage({super.key});

  @override
  State<ShelfSetupPage> createState() => _ShelfSetupPageState();
}

class _ShelfSetupPageState extends State<ShelfSetupPage> {
  var selectedOrder = <int>[];

  void select(int index) {
    setState(() {
      selectedOrder.add(index);
    });
  }

  void deselect() {
    setState(() {
      selectedOrder.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        switch (selectedOrder.length) {
          case 0:
            return AreasPage(select: select);
          case 1:
            return AreaPage(
              select: select,
              deselect: deselect,
              selectedOrder: selectedOrder,
            );
          default:
            dynamic shelfOrItem = areaModel.getShelfOrItem(selectedOrder);

            if (shelfOrItem is Shelf) {
              return ShelfPage(
                select: select,
                deselect: deselect,
                shelf: shelfOrItem,
                selectedOrder: selectedOrder,
              );
            } else {
              return ItemPage(
                deselect: deselect,
                item: shelfOrItem,
                selectedOrder: selectedOrder,
              );
            }
        }
      },
    );
  }
}

class AreasPage extends StatelessWidget {
  const AreasPage({super.key, required this.select});

  final void Function(int) select;

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Areas',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            centerTitle: true,
            scrolledUnderElevation: 0,
            backgroundColor: Theme.of(context).colorScheme.surface,
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () async {
                  // Export functionality
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Export Areas'),
                      content: const Text(
                        'This will create a backup file of all your areas.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);

                            try {
                              final jsonString = areaModel.exportAreasToJson();

                              final String? outputPath = await FilePicker
                                  .platform
                                  .saveFile(
                                    dialogTitle: 'Save areas backup',
                                    fileName: 'areas_backup.json',
                                    type: FileType.custom,
                                    allowedExtensions: ['json'],
                                  );

                              if (outputPath != null) {
                                final file = File(outputPath);
                                await file.writeAsString(jsonString);

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Export successful!'),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Export failed: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('Export'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.upload_file),
                onPressed: () async {
                  // Import functionality
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Import Areas'),
                      content: const Text(
                        'This will replace all current areas. Are you sure?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);

                            try {
                              final result = await FilePicker.platform
                                  .pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['json'],
                                  );

                              if (result != null &&
                                  result.files.single.path != null) {
                                final file = File(result.files.single.path!);
                                final jsonString = await file.readAsString();

                                areaModel.importAreasFromJson(jsonString);

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Import successful!'),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Import failed: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('Import'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          body: AreaList(select: select),
        );
      },
    );
  }
}

class AreaList extends StatefulWidget {
  const AreaList({super.key, required this.select});

  final void Function(int) select;

  @override
  State<AreaList> createState() => _AreaListState();
}

class _AreaListState extends State<AreaList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return Column(
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add Area'),
              tileColor: Theme.of(context).colorScheme.surface,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Enter Area Name'),
                    content: TextField(
                      autofocus: true,
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          areaModel.addArea(Area(value));
                          Navigator.pop(context);
                          _scrollToBottom();
                        }
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => Material(
                      child: ReorderableListView(
                        scrollController: _scrollController,
                        children: <AreaTile>[
                          for (
                            int index = 0;
                            index < areaModel.numAreas;
                            index += 1
                          )
                            AreaTile(
                              key: Key('$index'),
                              index: index,
                              select: widget.select,
                            ),
                        ],
                        onReorder: (int oldIndex, int newIndex) {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }

                          areaModel.moveArea(oldIndex, newIndex);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
