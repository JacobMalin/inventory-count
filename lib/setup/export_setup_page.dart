import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:provider/provider.dart';

class ExportSetupPage extends StatefulWidget {
  const ExportSetupPage({super.key});

  @override
  State<ExportSetupPage> createState() => _ExportSetupPageState();
}

class _ExportSetupPageState extends State<ExportSetupPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final isAtBottom =
          _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50;
      if (isAtBottom != _isAtBottom) {
        setState(() {
          _isAtBottom = isAtBottom;
        });
      }
    }
  }

  void _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      // Scroll again in case the extent changed during animation
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  void _scrollToTop() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) {
            return Consumer<AreaModel>(
              builder: (context, areaModel, child) {
                final exportList = List<ExportEntry>.from(areaModel.exportList);

                return Scaffold(
                  appBar: AppBar(
                    title: Text(
                      'Export Order',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    centerTitle: true,
                    scrolledUnderElevation: 0,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                  body: exportList.isEmpty
                      ? const Center(child: Text('No items to export'))
                      : Column(
                          children: [
                            Container(
                              color: Theme.of(context).colorScheme.surface,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ListTile(
                                      leading: const Icon(Icons.add),
                                      title: const Text('Add Title'),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            final controller =
                                                TextEditingController();
                                            return AlertDialog(
                                              title: const Text('Enter Title'),
                                              content: TextField(
                                                controller: controller,
                                                autofocus: true,
                                                onSubmitted: (value) {
                                                  if (value.isNotEmpty) {
                                                    areaModel.addToExportList(
                                                      ExportTitle(value),
                                                    );
                                                    Navigator.pop(context);
                                                    _scrollToBottom();
                                                  }
                                                },
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    if (controller
                                                        .text
                                                        .isNotEmpty) {
                                                      areaModel.addToExportList(
                                                        ExportTitle(
                                                          controller.text,
                                                        ),
                                                      );
                                                      Navigator.pop(context);
                                                      _scrollToBottom();
                                                    }
                                                  },
                                                  child: const Text('Add'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: ListTile(
                                      leading: const Icon(Icons.add),
                                      title: const Text('Add Fake Item'),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            final controller =
                                                TextEditingController();
                                            return AlertDialog(
                                              title: const Text(
                                                'Enter Placeholder',
                                              ),
                                              content: TextField(
                                                controller: controller,
                                                autofocus: true,
                                                onSubmitted: (value) {
                                                  if (value.isNotEmpty) {
                                                    areaModel.addToExportList(
                                                      ExportPlaceholder(value),
                                                    );
                                                    Navigator.pop(context);
                                                    _scrollToBottom();
                                                  }
                                                },
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    if (controller
                                                        .text
                                                        .isNotEmpty) {
                                                      areaModel.addToExportList(
                                                        ExportPlaceholder(
                                                          controller.text,
                                                        ),
                                                      );
                                                      Navigator.pop(context);
                                                      _scrollToBottom();
                                                    }
                                                  },
                                                  child: const Text('Add'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ReorderableListView(
                                scrollController: _scrollController,
                                key: const PageStorageKey('exportListView'),
                                onReorder: (int oldIndex, int newIndex) {
                                  if (newIndex > oldIndex) {
                                    newIndex -= 1;
                                  }
                                  areaModel.reorderExportList(
                                    oldIndex,
                                    newIndex,
                                  );
                                },
                                children: [
                                  for (
                                    int index = 0;
                                    index < exportList.length;
                                    index++
                                  )
                                    () {
                                      final exportEntry = exportList[index];
                                      return switch (exportEntry) {
                                        ExportTitle() => ExportTitleTile(
                                          key: Key('$index'),
                                          exportTitle: exportEntry,
                                          exportList: exportList,
                                          index: index,
                                        ),
                                        ExportPlaceholder() =>
                                          ExportPlaceholderTile(
                                            key: Key('$index'),
                                            exportPlaceholder: exportEntry,
                                            exportList: exportList,
                                            index: index,
                                          ),
                                        ExportItem() => ExportItemTile(
                                          key: Key('$index'),
                                          exportItem: exportEntry,
                                        ),
                                        _ => throw UnimplementedError(),
                                      };
                                    }(),
                                ],
                              ),
                            ),
                          ],
                        ),
                  floatingActionButton: exportList.isEmpty
                      ? null
                      : FloatingActionButton.small(
                          onPressed: _isAtBottom
                              ? _scrollToTop
                              : _scrollToBottom,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant,
                          elevation: 2,
                          child: AnimatedRotation(
                            duration: const Duration(milliseconds: 200),
                            turns: _isAtBottom ? -0.5 : 0,
                            child: const Icon(Icons.arrow_downward),
                          ),
                        ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class ExportItemTile extends StatelessWidget {
  const ExportItemTile({super.key, required this.exportItem});

  final ExportItem exportItem;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      trailing: const Icon(Icons.drag_handle),
      onTap: () {},
      title: Text(exportItem.name),
      subtitle: exportItem.paths.isNotEmpty
          ? Text(exportItem.paths.join('\n'))
          : null,
    );
  }
}

class ExportPlaceholderTile extends StatelessWidget {
  const ExportPlaceholderTile({
    super.key,
    required this.exportPlaceholder,
    required this.exportList,
    required this.index,
  });

  final ExportPlaceholder exportPlaceholder;
  final List<ExportEntry> exportList;
  final int index;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
      tileColor: Colors.yellow.withValues(alpha: 0.3),
      trailing: Consumer<AreaModel>(
        builder: (context, areaModel, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  final controller = TextEditingController(
                    text: exportPlaceholder.name,
                  );
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Rename Placeholder'),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        onChanged: (value) {
                          areaModel.editExportListEntry(index, name: value);
                        },
                        onSubmitted: (_) => Navigator.pop(context),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            if (controller.text.isNotEmpty) {
                              areaModel.editExportListEntry(
                                index,
                                name: controller.text,
                              );
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Placeholder'),
                      content: Text(
                        'Are you sure you want to delete "${exportPlaceholder.name}"?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            areaModel.removeFromExportList(index);
                            Navigator.pop(context);
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Icon(Icons.drag_handle),
            ],
          );
        },
      ),
      onTap: () {},
      title: Text(exportPlaceholder.name),
    );
  }
}

class ExportTitleTile extends StatelessWidget {
  const ExportTitleTile({
    super.key,
    required this.exportTitle,
    required this.exportList,
    required this.index,
  });

  final ExportTitle exportTitle;
  final List<ExportEntry> exportList;
  final int index;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
      trailing: Consumer<AreaModel>(
        builder: (context, areaModel, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  final controller = TextEditingController(
                    text: exportTitle.name,
                  );
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Rename Title'),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        onChanged: (value) {
                          areaModel.editExportListEntry(index, name: value);
                        },
                        onSubmitted: (_) => Navigator.pop(context),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            if (controller.text.isNotEmpty) {
                              areaModel.editExportListEntry(
                                index,
                                name: controller.text,
                              );
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Title'),
                      content: Text(
                        'Are you sure you want to delete "${exportTitle.name}"?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            areaModel.removeFromExportList(index);
                            Navigator.pop(context);
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Icon(Icons.drag_handle),
            ],
          );
        },
      ),
      onTap: () {},
      title: Text(exportTitle.name),
    );
  }
}
