import 'package:flutter/material.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/setup/area_page.dart';
import 'package:inventory_count/setup/item_page.dart';
import 'package:inventory_count/setup/setup_tiles.dart';
import 'package:inventory_count/setup/shelf_page.dart';
import 'package:provider/provider.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
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

class AreaList extends StatelessWidget {
  const AreaList({super.key, required this.select});

  final void Function(int) select;

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return Column(
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add Area'),
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
                    builder: (context) => ReorderableListView(
                      children: <AreaTile>[
                        for (
                          int index = 0;
                          index < areaModel.numAreas;
                          index += 1
                        )
                          AreaTile(
                            key: Key('$index'),
                            index: index,
                            select: select,
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
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
