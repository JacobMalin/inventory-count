import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:inventory_count/setup/setup_tiles.dart';
import 'package:provider/provider.dart';

class ShelfPage extends StatelessWidget {
  const ShelfPage({
    super.key,
    required this.select,
    required this.deselect,
    required this.shelf,
    required this.selectedOrder,
  });

  final void Function(int) select;
  final void Function() deselect;
  final Shelf shelf;
  final List<int> selectedOrder;

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              shelf.name,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: deselect,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  final controller = TextEditingController(text: shelf.name);
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );

                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Rename Shelf'),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            areaModel.renameShelfInArea(
                              selectedOrder[0],
                              selectedOrder[1],
                              value,
                            );
                            Navigator.pop(context);
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
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  showDialog(
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
                        Consumer<CountModel>(
                          builder: (context, countModel, child) {
                            return TextButton(
                              onPressed: () {
                                areaModel.removeShelfOrItemFromArea(
                                  selectedOrder[0],
                                  selectedOrder[1],
                                  countModel,
                                );
                                Navigator.pop(context);
                                deselect();
                              },
                              child: const Text('Delete'),
                            );
                          },
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
          body: ItemList(select: select, selectedOrder: selectedOrder),
        );
      },
    );
  }
}

class ItemList extends StatefulWidget {
  const ItemList({
    super.key,
    required this.select,
    required this.selectedOrder,
  });

  final void Function(int) select;
  final List<int> selectedOrder;

  @override
  State<ItemList> createState() => _ItemListState();
}

class _ItemListState extends State<ItemList> {
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
              title: const Text('Add Item'),
              tileColor: Theme.of(context).colorScheme.surface,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Enter Item Name'),
                    content: TextField(
                      autofocus: true,
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          areaModel.addItemToShelf(
                            widget.selectedOrder[0],
                            widget.selectedOrder[1],
                            Item(value),
                          );

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
                        children: <Widget>[
                          for (
                            int index = 0;
                            index <
                                (areaModel.getShelfOrItem(widget.selectedOrder)
                                        as Shelf)
                                    .items
                                    .length;
                            index += 1
                          )
                            ItemTile(
                              key: Key('$index'),
                              index: index,
                              selectedOrder: widget.selectedOrder,
                              select: widget.select,
                            ),
                        ],
                        onReorder: (int oldIndex, int newIndex) {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }

                          areaModel.moveItemInShelf(
                            widget.selectedOrder[0],
                            widget.selectedOrder[1],
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
