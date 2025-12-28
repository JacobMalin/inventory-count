import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_count/area.dart';

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
        Area area = Hive.box('areas').get('areas')[selectedOrder.first];
        dynamic shelfOrItem = area.shelvesAndItems[selectedOrder[1]];
        for (int i = 2; i < selectedOrder.length; i++) {
          shelfOrItem = shelfOrItem.shelvesAndItems[selectedOrder[i]];
        }

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
    return ValueListenableBuilder(
      valueListenable: Hive.box('areas').listenable(),
      builder: (context, box, child) {
        return Scrollable(
          viewportBuilder: (context, position) => Viewport(
            axisDirection: AxisDirection.down,
            offset: position,
            slivers: [
              SliverList(
                delegate: SliverChildListDelegate([
                  ReorderableListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      for (
                        int index = 0;
                        index < (box.get('areas')?.length ?? 0);
                        index += 1
                      )
                        ListTile(
                          key: Key('$index'),
                          textColor: box.get('areas')[index].color,
                          tileColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          title: Text(box.get('areas')[index].name),
                          trailing: const Icon(Icons.drag_handle),
                          onTap: () => select(index),
                        ),
                    ],
                    onReorder: (int oldIndex, int newIndex) {
                      final List items = box.get('areas', defaultValue: []);

                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }

                      items.insert(newIndex, items.removeAt(oldIndex));
                      box.put('areas', items);
                    },
                  ),
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
                                final List areas = box.get(
                                  'areas',
                                  defaultValue: [],
                                );
                                box.put('areas', [...areas, Area(value)]);
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
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

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
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder(
          valueListenable: Hive.box('areas').listenable(),
          builder: (context, box, widget) {
            return Text(
              box.get('areas')[selectedOrder.last].name,
              style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                color: box.get('areas')[selectedOrder.last].color,
              ),
            );
          },
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: deselect,
        ),
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: ShelfList(select: select, selectedOrder: selectedOrder),
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
    return ValueListenableBuilder(
      valueListenable: Hive.box('areas').listenable(),
      builder: (context, box, child) {
        Area area = box.get('areas')[selectedOrder.last];

        return Column(
          children: [
            ReorderableListView(
              shrinkWrap: true,
              children: <Widget>[
                for (
                  int index = 0;
                  index < (area.shelvesAndItems.length);
                  index += 1
                )
                  ListTile(
                    key: Key('$index'),
                    tileColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    title: Text(area.shelvesAndItems[index].name),
                    trailing: const Icon(Icons.drag_handle),
                    onTap: () => select(index),
                  ),
              ],
              onReorder: (int oldIndex, int newIndex) {
                final List items = area.shelvesAndItems;

                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }

                items.insert(newIndex, items.removeAt(oldIndex));
                List areas = box.get('areas');
                areas[selectedOrder.last].shelves_and_items = items;
                box.put('areas', areas);
              },
            ),
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
                                area.shelvesAndItems.add(Shelf(value));

                                List areas = box.get('areas');
                                areas[selectedOrder.last] = area;
                                box.put('areas', areas);

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
                                area.shelvesAndItems.add(Item(value));

                                List areas = box.get('areas');
                                areas[selectedOrder.last] = area;
                                box.put('areas', areas);

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
          ],
        );
      },
    );
  }
}

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
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder(
          valueListenable: Hive.box('shelves').listenable(),
          builder: (context, box, widget) {
            return Text(
              shelf.name,
              style: Theme.of(context).textTheme.headlineLarge,
            );
          },
        ),
        centerTitle: true,
        toolbarHeight: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: deselect,
        ),
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: const Center(child: Text('Shelf Page')),
    );
  }
}

class ItemPage extends StatelessWidget {
  const ItemPage({
    super.key,
    required this.deselect,
    required this.item,
    required this.selectedOrder,
  });

  final Function() deselect;
  final Item item;
  final List<int> selectedOrder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          item.name,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        centerTitle: true,
        toolbarHeight: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: deselect,
        ),
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: const Center(child: Text('Item Detail Page')),
    );
  }
}
