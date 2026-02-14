import 'package:flutter/material.dart';
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
                            onSubmitted: (value) async {
                              if (value.isNotEmpty) {
                                areaModel.addShelfToArea(
                                  widget._selectedOrder.last,
                                  Shelf(value),
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
                            onSubmitted: (value) async {
                              if (value.isNotEmpty) {
                                areaModel.addItemToArea(
                                  widget._selectedOrder.last,
                                  Item(value),
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
                            index < (area.shelvesAndItems.length);
                            index += 1
                          )
                            area.shelvesAndItems[index] is Shelf
                                ? ShelfTile(
                                    key: Key('$index'),
                                    index: index,
                                    selectedOrder: widget._selectedOrder,
                                    select: widget._select,
                                  )
                                : ItemTile(
                                    key: Key('$index'),
                                    index: index,
                                    selectedOrder: widget._selectedOrder,
                                    select: widget._select,
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
