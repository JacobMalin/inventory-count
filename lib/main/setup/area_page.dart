import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../models/area_model.dart';
import '../models/data/inventory_models.dart';
import 'setup_tiles.dart';

class AreaPage extends StatelessWidget {
  const AreaPage({
    required void Function(int) select,
    required void Function() deselect,
    required List<int> selectedOrder,
    super.key,
  }) : _selectedOrder = selectedOrder,
       _deselect = deselect,
       _select = select;

  final void Function(int) _select;
  final void Function() _deselect;
  final List<int> _selectedOrder;

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              areaModel.getArea(_selectedOrder.last).name,
              style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                color: areaModel.getArea(_selectedOrder.last).color,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: _deselect,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final controller = TextEditingController(
                    text: areaModel.getArea(_selectedOrder.last).name,
                  );
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );

                  await showDialog(
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
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ).then((_) {
                    if (controller.text.isNotEmpty) {
                      areaModel.renameArea(
                        _selectedOrder.last,
                        controller.text,
                      );
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Area'),
                      content: const Text(
                        'Are you sure you want to delete this area?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            areaModel.removeArea(_selectedOrder.last);
                            Navigator.pop(context);
                            _deselect();
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            scrolledUnderElevation: 0,
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
          body: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 300) {
                _deselect();
              }
            },
            child: ShelfList(select: _select, selectedOrder: _selectedOrder),
          ),
        );
      },
    );
  }
}

class ShelfList extends StatefulWidget {
  const ShelfList({
    required void Function(int) select,
    required List<int> selectedOrder,
    super.key,
  }) : _selectedOrder = selectedOrder,
       _select = select;

  final void Function(int) _select;
  final List<int> _selectedOrder;

  @override
  State<ShelfList> createState() => _ShelfListState();
}

class _ShelfListState extends State<ShelfList> {
  final ScrollController _scrollController = ScrollController();

  Future<bool> _confirmDelete({
    required String type,
    required String name,
  }) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $type'),
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

  Future<void> _renameShelf(
    AreaModel areaModel,
    int areaIndex,
    int shelfIndex,
  ) async {
    final shelf = areaModel.getShelfOrItem([areaIndex, shelfIndex]) as Shelf;
    final controller = TextEditingController(text: shelf.name);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Shelf'),
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
      areaModel.renameShelfInArea(areaIndex, shelfIndex, name);
    }
  }

  Future<void> _renameItem(AreaModel areaModel, List<int> selectedOrder) async {
    final item = areaModel.getShelfOrItem(selectedOrder) as Item;
    final controller = TextEditingController(text: item.name);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Item'),
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
      areaModel.editItem(selectedOrder, newName: name);
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
        final Area area = areaModel.getArea(widget._selectedOrder.last);

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Add Shelf'),
                    tileColor: Theme.of(context).colorScheme.surface,
                    onTap: () async {
                      await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Enter Shelf Name'),
                          content: TextField(
                            autofocus: true,
                            onSubmitted: (name) async {
                              if (name.isNotEmpty) {
                                areaModel.addShelfToArea(
                                  widget._selectedOrder.last,
                                  name,
                                );

                                Navigator.pop(context);
                                await _scrollToBottom();
                              }
                            },
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Add Item'),
                    tileColor: Theme.of(context).colorScheme.surface,
                    onTap: () async {
                      await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Enter Item Name'),
                          content: TextField(
                            autofocus: true,
                            onSubmitted: (name) async {
                              if (name.isNotEmpty) {
                                areaModel.addItemToArea(
                                  widget._selectedOrder.last,
                                  name,
                                );

                                Navigator.pop(context);
                                await _scrollToBottom();
                              }
                            },
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            Expanded(
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => Material(
                      child: ReorderableListView(
                        scrollController: _scrollController,
                        key: const PageStorageKey('areaContentListView'),
                        children: <Widget>[
                          for (
                            int index = 0;
                            index < (area.numItemsAndShelves);
                            index += 1
                          )
                            area[index] is Shelf
                                ? Slidable(
                                    key: ValueKey(
                                      'area_${widget._selectedOrder.last}_'
                                      'shelf_$index',
                                    ),
                                    endActionPane: ActionPane(
                                      motion: const DrawerMotion(),
                                      children: [
                                        SlidableAction(
                                          onPressed: (_) async {
                                            await _renameShelf(
                                              areaModel,
                                              widget._selectedOrder.last,
                                              index,
                                            );
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
                                            final shelf =
                                                areaModel.getShelfOrItem([
                                                      widget
                                                          ._selectedOrder
                                                          .last,
                                                      index,
                                                    ])
                                                    as Shelf;
                                            final bool shouldDelete =
                                                await _confirmDelete(
                                                  type: 'Shelf',
                                                  name: shelf.name,
                                                );
                                            if (shouldDelete) {
                                              areaModel
                                                  .removeShelfOrItemFromArea(
                                                    widget._selectedOrder.last,
                                                    index,
                                                  );
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
                                    child: ShelfTile(
                                      key: Key('$index'),
                                      index: index,
                                      selectedOrder: widget._selectedOrder,
                                      select: widget._select,
                                    ),
                                  )
                                : Slidable(
                                    key: ValueKey(
                                      'area_${widget._selectedOrder.last}_'
                                      'item_$index',
                                    ),
                                    endActionPane: ActionPane(
                                      motion: const DrawerMotion(),
                                      children: [
                                        SlidableAction(
                                          onPressed: (_) async {
                                            await _renameItem(areaModel, [
                                              widget._selectedOrder.last,
                                              index,
                                            ]);
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
                                            final item =
                                                areaModel.getShelfOrItem([
                                                      widget
                                                          ._selectedOrder
                                                          .last,
                                                      index,
                                                    ])
                                                    as Item;
                                            final bool shouldDelete =
                                                await _confirmDelete(
                                                  type: 'Item',
                                                  name: item.name,
                                                );
                                            if (shouldDelete) {
                                              areaModel.removeItem([
                                                widget._selectedOrder.last,
                                                index,
                                              ]);
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
                                    child: ItemTile(
                                      key: Key('$index'),
                                      index: index,
                                      selectedOrder: widget._selectedOrder,
                                      select: widget._select,
                                    ),
                                  ),
                        ],
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }

                          areaModel.moveShelfOrItemInArea(
                            widget._selectedOrder.last,
                            oldIndex,
                            newIndex,
                          );
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
