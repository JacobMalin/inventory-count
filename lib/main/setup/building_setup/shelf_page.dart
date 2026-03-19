import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../models/area_model.dart';
import '../../models/data/inventory_models.dart';
import 'setup_helpers.dart';
import 'setup_tiles.dart';

class ShelfPage extends StatelessWidget {
  const ShelfPage({
    required Shelf shelf,
    required Future<void> Function({StorageObject? object}) select,
    super.key,
  }) : _shelf = shelf,
       _select = select;

  final Shelf _shelf;
  final Future<void> Function({StorageObject? object}) _select;

  Future<void> _moveShelf(BuildContext context, AreaModel areaModel) async {
    final int sourceAreaIndex = _selectedOrder[0];
    final int shelfIndex = _selectedOrder[1];
    final List<int> targetAreaIndices = [
      for (var i = 0; i < areaModel.numAreas; i++)
        if (i != sourceAreaIndex) i,
    ];

    if (targetAreaIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add another area to move this shelf.')),
      );
      return;
    }

    final int? targetAreaIndex = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Move Shelf To Area'),
        children: [
          for (final int index in targetAreaIndices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, index),
              child: Text(areaModel.getArea(index).name),
            ),
        ],
      ),
    );

    if (targetAreaIndex == null) {
      return;
    }

    areaModel.moveShelfToArea(
      sourceAreaIndex: sourceAreaIndex,
      shelfIndex: shelfIndex,
      targetAreaIndex: targetAreaIndex,
    );
    _deselect();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Moved "${_shelf.name}" to '
          '${areaModel.getArea(targetAreaIndex).name}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _shelf.name,
              style: Theme.of(context).textTheme.headlineLarge,
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
                  final controller = TextEditingController(text: _shelf.name);
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );

                  await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Rename Shelf'),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        onChanged: (value) {
                          areaModel.renameShelfInArea(
                            _selectedOrder[0],
                            _selectedOrder[1],
                            value,
                          );
                        },
                        onSubmitted: (_) => Navigator.pop(context),
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
              IconButton(
                icon: const Icon(Icons.drive_file_move),
                onPressed: () async {
                  await _moveShelf(context, areaModel);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Shelf'),
                      content: const Text(
                        'Are you sure you want to delete this shelf?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            areaModel.removeShelfOrItemFromArea(
                              _selectedOrder[0],
                              _selectedOrder[1],
                            );
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
            child: ItemList(select: _select, selectedOrder: _selectedOrder),
          ),
        );
      },
    );
  }
}

class ItemList extends StatefulWidget {
  const ItemList({
    required void Function(int) select,
    required List<int> selectedOrder,
    super.key,
  }) : _select = select,
       _selectedOrder = selectedOrder;

  final void Function(int) _select;
  final List<int> _selectedOrder;

  @override
  State<ItemList> createState() => _ItemListState();
}

class _ItemListState extends State<ItemList> {
  final ScrollController _scrollController = ScrollController();

  Future<bool> _confirmDelete(String name) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
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

  Future<void> _moveItem(AreaModel areaModel, List<int> sourceOrder) async {
    final item = areaModel.getShelfOrItem(sourceOrder) as Item;

    int selectedAreaIndex = sourceOrder[0];
    int? selectedShelfIndex = sourceOrder.length == 3 ? sourceOrder[1] : null;

    final bool? shouldMove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final Area selectedArea = areaModel.getArea(selectedAreaIndex);
            final List<MapEntry<int, Shelf>> shelves = getShelfEntriesForArea(
              selectedArea,
            );

            if (selectedShelfIndex != null &&
                !shelves.any((entry) => entry.key == selectedShelfIndex)) {
              selectedShelfIndex = null;
            }

            return AlertDialog(
              title: const Text('Move Item'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedAreaIndex,
                    decoration: const InputDecoration(labelText: 'Area'),
                    items: [
                      for (var i = 0; i < areaModel.numAreas; i++)
                        DropdownMenuItem<int>(
                          value: i,
                          child: Text(areaModel.getArea(i).name),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedAreaIndex = value;
                        selectedShelfIndex = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedShelfIndex,
                    isDense: false,
                    decoration: const InputDecoration(
                      labelText: 'Shelf',
                      contentPadding: EdgeInsets.symmetric(vertical: 2),
                    ),
                    items: [
                      buildBottomOfAreaOption(context),
                      for (final shelfEntry in shelves)
                        DropdownMenuItem<int?>(
                          value: shelfEntry.key,
                          child: Text(shelfEntry.value.name),
                        ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedShelfIndex = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Move'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldMove != true) {
      return;
    }

    areaModel.moveItemToDestination(
      sourceOrder: sourceOrder,
      targetAreaIndex: selectedAreaIndex,
      targetShelfIndex: selectedShelfIndex,
    );

    if (!mounted) return;
    final String destinationArea = areaModel.getArea(selectedAreaIndex).name;
    final String destination;
    if (selectedShelfIndex == null) {
      destination = destinationArea;
    } else {
      final destinationShelf =
          areaModel.getArea(selectedAreaIndex)[selectedShelfIndex!] as Shelf;
      destination = '$destinationArea > ${destinationShelf.name}';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Moved "${item.name}" to $destination.')),
    );
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
                          areaModel.addItemToShelf(
                            widget._selectedOrder[0],
                            widget._selectedOrder[1],
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
                        key: const PageStorageKey('shelfItemsListView'),
                        children: <Widget>[
                          for (
                            int index = 0;
                            index <
                                (areaModel.getShelfOrItem(widget._selectedOrder)
                                        as Shelf)
                                    .numItems;
                            index += 1
                          )
                            Slidable(
                              key: ValueKey(
                                'shelf_${widget._selectedOrder[0]}_'
                                '${widget._selectedOrder[1]}_item_$index',
                              ),
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                children: [
                                  SlidableAction(
                                    onPressed: (_) async {
                                      await _renameItem(areaModel, [
                                        widget._selectedOrder[0],
                                        widget._selectedOrder[1],
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
                                      await _moveItem(areaModel, [
                                        widget._selectedOrder[0],
                                        widget._selectedOrder[1],
                                        index,
                                      ]);
                                    },
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.secondaryContainer,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                                    icon: Icons.drive_file_move,
                                    label: 'Move',
                                  ),
                                  SlidableAction(
                                    onPressed: (_) async {
                                      final item =
                                          areaModel.getShelfOrItem([
                                                widget._selectedOrder[0],
                                                widget._selectedOrder[1],
                                                index,
                                              ])
                                              as Item;
                                      final bool shouldDelete =
                                          await _confirmDelete(item.name);
                                      if (shouldDelete) {
                                        areaModel.removeItem([
                                          widget._selectedOrder[0],
                                          widget._selectedOrder[1],
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

                          areaModel.moveItemInShelf(
                            widget._selectedOrder[0],
                            widget._selectedOrder[1],
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
