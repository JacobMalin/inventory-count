import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../models/area_model.dart';
import '../models/data/inventory_models.dart';
import 'setup_helpers.dart';
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

  Future<void> _moveShelf(
    AreaModel areaModel,
    int areaIndex,
    int shelfIndex,
  ) async {
    final List<int> targetAreaIndices = [
      for (var i = 0; i < areaModel.numAreas; i++)
        if (i != areaIndex) i,
    ];

    if (targetAreaIndices.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add another area to move this shelf.')),
      );
      return;
    }

    final shelf = areaModel.getShelfOrItem([areaIndex, shelfIndex]) as Shelf;
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
      sourceAreaIndex: areaIndex,
      shelfIndex: shelfIndex,
      targetAreaIndex: targetAreaIndex,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Moved "${shelf.name}" to '
          '${areaModel.getArea(targetAreaIndex).name}.',
        ),
      ),
    );
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
                                            await _moveShelf(
                                              areaModel,
                                              widget._selectedOrder.last,
                                              index,
                                            );
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
                                            await _moveItem(areaModel, [
                                              widget._selectedOrder.last,
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
