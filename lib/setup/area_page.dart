import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
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
            actionsPadding: EdgeInsets.all(10),
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
                        TextButton(
                          onPressed: () {
                            areaModel.removeArea(selectedOrder.last);
                            Navigator.pop(context);
                            deselect();
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
          body: ShelfList(select: select, selectedOrder: selectedOrder),
        );
      },
    );
  }
}

class ShelfList extends StatelessWidget {
  const ShelfList({
    super.key,
    required this.select,
    required this.selectedOrder,
  });

  final void Function(int) select;
  final List<int> selectedOrder;

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        Area area = areaModel.getArea(selectedOrder.last);

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Add Shelf'),
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
                                  selectedOrder.last,
                                  Shelf(value),
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
                ),
                Expanded(
                  child: ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Add Item'),
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
                                  selectedOrder.last,
                                  Item(value),
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
                ),
              ],
            ),
            Expanded(
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => ReorderableListView(
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
                                  selectedOrder: selectedOrder,
                                  select: select,
                                )
                              : ItemTile(
                                  key: Key('$index'),
                                  index: index,
                                  selectedOrder: selectedOrder,
                                  select: select,
                                ),
                      ],
                      onReorder: (int oldIndex, int newIndex) {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }

                        areaModel.moveShelfOrItemInArea(
                          selectedOrder.last,
                          oldIndex,
                          newIndex,
                        );
                      },
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
