import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:inventory_count/setup/setup_tiles.dart';
import 'package:provider/provider.dart';

class AreaPage extends StatelessWidget {
  const AreaPage({
    super.key,
    required this.select,
    required this.deselect,
    required this.selectedOrder,
  });

  final void Function(int) select;
  final void Function() deselect;
  final List<int> selectedOrder;

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              areaModel.getArea(selectedOrder.last).name,
              style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                color: areaModel.getArea(selectedOrder.last).color,
              ),
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
                  final controller = TextEditingController(
                    text: areaModel.getArea(selectedOrder.last).name,
                  );
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );

                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Rename Area'),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            areaModel.renameArea(selectedOrder.last, value);
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
                      title: const Text('Delete Area'),
                      content: const Text(
                        'Are you sure you want to delete this area?',
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
                                areaModel.removeArea(
                                  selectedOrder.last,
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
          body: ShelfList(select: select, selectedOrder: selectedOrder),
        );
      },
    );
  }
}

class ShelfList extends StatefulWidget {
  const ShelfList({
    super.key,
    required this.select,
    required this.selectedOrder,
  });

  final void Function(int) select;
  final List<int> selectedOrder;

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
        Area area = areaModel.getArea(widget.selectedOrder.last);

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Add Shelf'),
                    tileColor: Theme.of(context).colorScheme.surface,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Enter Shelf Name'),
                          content: TextField(
                            autofocus: true,
                            onSubmitted: (value) {
                              if (value.isNotEmpty) {
                                areaModel.addShelfToArea(
                                  widget.selectedOrder.last,
                                  Shelf(value),
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
                ),
                Expanded(
                  child: ListTile(
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
                                areaModel.addItemToArea(
                                  widget.selectedOrder.last,
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
                                    selectedOrder: widget.selectedOrder,
                                    select: widget.select,
                                  )
                                : ItemTile(
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

                          areaModel.moveShelfOrItemInArea(
                            widget.selectedOrder.last,
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
