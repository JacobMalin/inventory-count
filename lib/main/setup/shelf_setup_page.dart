import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../models/area_model.dart';
import '../models/data/inventory_models.dart';
import 'area_page.dart';
import 'item_page.dart';
import 'setup_tiles.dart';
import 'shelf_page.dart';

class ShelfSetupPage extends StatefulWidget {
  const ShelfSetupPage({super.key});

  @override
  State<ShelfSetupPage> createState() => _ShelfSetupPageState();
}

class _ShelfSetupPageState extends State<ShelfSetupPage> {
  final _selectedOrder = <int>[];

  void reset() {
    setState(_selectedOrder.clear);
  }

  void select(int index) {
    setState(() {
      _selectedOrder.add(index);
    });
  }

  void deselect() {
    setState(_selectedOrder.removeLast);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        switch (_selectedOrder.length) {
          case 0:
            return AreasPage(select: select);
          case 1:
            return AreaPage(
              select: select,
              deselect: deselect,
              selectedOrder: _selectedOrder,
            );
          default:
            final dynamic shelfOrItem = areaModel.getShelfOrItem(
              _selectedOrder,
            );

            if (shelfOrItem is Shelf) {
              return ShelfPage(
                select: select,
                deselect: deselect,
                shelf: shelfOrItem,
                selectedOrder: _selectedOrder,
              );
            } else {
              return ItemPage(
                deselect: deselect,
                item: shelfOrItem,
                selectedOrder: _selectedOrder,
              );
            }
        }
      },
    );
  }
}

class AreasPage extends StatelessWidget {
  const AreasPage({required void Function(int) select, super.key})
    : _select = select;

  final void Function(int) _select;

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
          ),
          body: AreaList(select: _select),
        );
      },
    );
  }
}

class AreaList extends StatefulWidget {
  const AreaList({required void Function(int) select, super.key})
    : _select = select;

  final void Function(int) _select;

  @override
  State<AreaList> createState() => _AreaListState();
}

class _AreaListState extends State<AreaList> {
  final ScrollController _scrollController = ScrollController();

  Future<bool> _confirmDelete(String name) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Area'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return shouldDelete ?? false;
  }

  Future<void> _renameArea(AreaModel areaModel, int index) async {
    final controller = TextEditingController(
      text: areaModel.getArea(index).name,
    );
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Area'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (_) => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final String name = controller.text.trim();
    if (name.isNotEmpty) {
      areaModel.renameArea(index, name);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToBottom() async {
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
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Enter Area Name'),
                    content: TextField(
                      autofocus: true,
                      onSubmitted: (value) async {
                        if (value.isNotEmpty) {
                          areaModel.addArea(Area(value));
                          Navigator.pop(context);
                          await _scrollToBottom();
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
                        key: const PageStorageKey('areaListView'),
                        children: <Widget>[
                          for (
                            int index = 0;
                            index < areaModel.numAreas;
                            index += 1
                          )
                            Slidable(
                              key: ValueKey('area_$index'),
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                children: [
                                  SlidableAction(
                                    onPressed: (_) async {
                                      await _renameArea(areaModel, index);
                                    },
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    icon: Icons.edit,
                                    label: 'Edit',
                                  ),
                                  SlidableAction(
                                    onPressed: (_) async {
                                      final String name = areaModel
                                          .getArea(index)
                                          .name;
                                      final bool shouldDelete =
                                          await _confirmDelete(name);
                                      if (shouldDelete) {
                                        areaModel.removeArea(index);
                                      }
                                    },
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.errorContainer,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
                                    icon: Icons.delete,
                                    label: 'Delete',
                                  ),
                                ],
                              ),
                              child: AreaTile(
                                key: Key('$index'),
                                index: index,
                                select: widget._select,
                              ),
                            ),
                        ],
                        onReorder: (oldIndex, newIndex) {
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
