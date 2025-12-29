import 'package:flutter/material.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/setup/area_page.dart';
import 'package:inventory_count/setup/item_page.dart';
import 'package:inventory_count/setup/setup_tiles.dart';
import 'package:inventory_count/setup/shelf_page.dart';
import 'package:provider/provider.dart';

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: const TabBarView(children: [ShelfSetupPage(), ExportSetupPage()]),
        bottomNavigationBar: const TabBar(
          tabs: [
            Tab(text: 'Areas'),
            Tab(text: 'Export Order'),
          ],
        ),
      ),
    );
  }
}

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
        dynamic shelfOrItem = Provider.of<AreaModel>(
          context,
        ).getShelfOrItem(selectedOrder);

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
  }
}

class AreasPage extends StatelessWidget {
  const AreasPage({super.key, required this.select});

  final void Function(int) select;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Areas', style: Theme.of(context).textTheme.headlineLarge),
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: AreaList(select: select),
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

class ExportSetupPage extends StatefulWidget {
  const ExportSetupPage({super.key});

  @override
  State<ExportSetupPage> createState() => _ExportSetupPageState();
}

class _ExportSetupPageState extends State<ExportSetupPage> {
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
                            Row(
                              children: [
                                Expanded(
                                  child: ListTile(
                                    leading: const Icon(Icons.add),
                                    title: const Text('Add Title'),
                                    tileColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
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
                                    tileColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
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
                            Expanded(
                              child: ReorderableListView(
                                scrollController: _scrollController,
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
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            areaModel.editExportListEntry(index, name: value);
                            Navigator.pop(context);
                          }
                        },
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
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            areaModel.editExportListEntry(index, name: value);
                            Navigator.pop(context);
                          }
                        },
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
