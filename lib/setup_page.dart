import 'package:flutter/material.dart';
import 'package:inventory_count/area.dart';
import 'package:inventory_count/area_model.dart';
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
            ReorderableListView(
              shrinkWrap: true,
              children: <Widget>[
                for (int index = 0; index < areaModel.numAreas; index += 1)
                  AreaTile(key: Key('$index'), index: index, select: select),
              ],
              onReorder: (int oldIndex, int newIndex) {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }

                areaModel.moveArea(oldIndex, newIndex);
              },
            ),
          ],
        );
      },
    );
  }
}

class AreaTile extends StatelessWidget {
  const AreaTile({super.key, required this.index, required this.select});

  final int index;
  final void Function(int) select;

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        final area = areaModel.getArea(index);
        final numShelves = area.shelvesAndItems.whereType<Shelf>().length;
        final numItems = area.shelvesAndItems.whereType<Item>().length;

        String subtitleText;
        if (numShelves == 0 && numItems == 0) {
          subtitleText = 'Empty';
        } else if (numShelves == 0) {
          subtitleText = '$numItems item${numItems == 1 ? '' : 's'}';
        } else if (numItems == 0) {
          subtitleText = '$numShelves ${numShelves == 1 ? 'shelf' : 'shelves'}';
        } else {
          subtitleText =
              '$numShelves ${numShelves == 1 ? 'shelf' : 'shelves'}, $numItems item${numItems == 1 ? '' : 's'}';
        }

        return ListTile(
          key: Key('$index'),
          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          title: Text(area.name, style: TextStyle(color: area.color)),
          subtitle: Text(subtitleText),
          trailing: const Icon(Icons.drag_handle),
          onTap: () => select(index),
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
            ReorderableListView(
              shrinkWrap: true,
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
                        TextButton(
                          onPressed: () {
                            areaModel.removeShelfOrItemFromArea(
                              selectedOrder[0],
                              selectedOrder[1],
                            );
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
          body: ItemList(select: select, selectedOrder: selectedOrder),
        );
      },
    );
  }
}

class ItemList extends StatelessWidget {
  const ItemList({
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
        return Column(
          children: [
            ListTile(
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
                          areaModel.addItemToShelf(
                            selectedOrder[0],
                            selectedOrder[1],
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
            ReorderableListView(
              shrinkWrap: true,
              children: <Widget>[
                for (
                  int index = 0;
                  index <
                      (areaModel.getShelfOrItem(selectedOrder) as Shelf)
                          .items
                          .length;
                  index += 1
                )
                  ItemTile(
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

                areaModel.moveItemInShelf(
                  selectedOrder[0],
                  selectedOrder[1],
                  oldIndex,
                  newIndex,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class ShelfTile extends StatelessWidget {
  const ShelfTile({
    super.key,
    required this.index,
    required this.selectedOrder,
    required this.select,
  });

  final int index;
  final List<int> selectedOrder;
  final void Function(int) select;

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        final shelf =
            areaModel.getShelfOrItem([...selectedOrder, index]) as Shelf;
        return ListTile(
          key: Key('$index'),
          leading: Icon(Icons.shelves, color: Colors.amber),
          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          title: Text(shelf.name),
          subtitle: Text('${shelf.items.length} items'),
          trailing: const Icon(Icons.drag_handle),
          onTap: () => select(index),
        );
      },
    );
  }
}

class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.index,
    required this.selectedOrder,
    required this.select,
  });

  final int index;
  final List<int> selectedOrder;
  final void Function(int) select;

  String _getStrategyText(CountStrategy strategy, int? strategyInt) {
    switch (strategy) {
      case CountStrategy.singular:
        return 'Singular';
      case CountStrategy.boxes:
        return strategyInt != null
            ? 'Stacks ($strategyInt per stack)'
            : 'Stacks';
      case CountStrategy.singularAndBoxes:
        return strategyInt != null ? 'Both ($strategyInt per stack)' : 'Both';
      case CountStrategy.negative:
        return strategyInt != null
            ? 'Negative (from $strategyInt)'
            : 'Negative';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        final item =
            areaModel.getShelfOrItem([...selectedOrder, index]) as Item;
        return ListTile(
          key: Key('$index'),
          leading: Icon(Icons.inventory, color: Colors.blue),
          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          title: Text(item.name),
          subtitle: Text(_getStrategyText(item.strategy, item.strategyInt)),
          trailing: const Icon(Icons.drag_handle),
          onTap: () => select(index),
        );
      },
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
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
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
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  final controller = TextEditingController(text: item.name);
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );

                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Rename Item'),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            areaModel.editItem(selectedOrder, newName: value);
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
                      title: const Text('Delete Item'),
                      content: const Text(
                        'Are you sure you want to delete this item?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            areaModel.removeItem(selectedOrder);
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
          body: ItemSettings(item: item, selectedOrder: selectedOrder),
        );
      },
    );
  }
}

class ItemSettings extends StatefulWidget {
  const ItemSettings({
    super.key,
    required this.item,
    required this.selectedOrder,
  });

  final Item item;
  final List<int> selectedOrder;

  @override
  State<ItemSettings> createState() => _ItemSettingsState();
}

class _ItemSettingsState extends State<ItemSettings> {
  late CountStrategy countStrategy;
  final TextEditingController strategyIntController = TextEditingController();
  final TextEditingController countNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    countStrategy = widget.item.strategy;
    countNameController.text = widget.item.countName ?? '';
    if (widget.item.strategyInt != null) {
      strategyIntController.text = widget.item.strategyInt.toString();
    }
  }

  @override
  void dispose() {
    strategyIntController.dispose();
    countNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Consumer<AreaModel>(
        builder: (context, areaModel, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Count Name', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: countNameController,
                decoration: InputDecoration(
                  hintText: widget.item.name,
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  areaModel.editItem(widget.selectedOrder, newCountName: value);
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Count Strategy',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Center(
                child: SegmentedButton<CountStrategy>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment<CountStrategy>(
                      value: CountStrategy.singular,
                      label: Text('Singular'),
                    ),
                    ButtonSegment<CountStrategy>(
                      value: CountStrategy.boxes,
                      label: Text('Stacks'),
                    ),
                    ButtonSegment<CountStrategy>(
                      value: CountStrategy.singularAndBoxes,
                      label: Text('Both'),
                    ),
                    ButtonSegment<CountStrategy>(
                      value: CountStrategy.negative,
                      label: Text('Negative'),
                    ),
                  ],
                  selected: {countStrategy},
                  onSelectionChanged: (Set<CountStrategy> newSelection) {
                    setState(() {
                      countStrategy = newSelection.first;
                    });
                    areaModel.editItem(
                      widget.selectedOrder,
                      newStrategy: countStrategy,
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              if (countStrategy == CountStrategy.boxes ||
                  countStrategy == CountStrategy.singularAndBoxes)
                TextField(
                  controller: strategyIntController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Items per stack',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    final intValue = int.tryParse(value);
                    areaModel.editItem(
                      widget.selectedOrder,
                      newStrategyInt: intValue,
                    );
                  },
                ),
              if (countStrategy == CountStrategy.negative)
                TextField(
                  controller: strategyIntController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Starting total',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    final intValue = int.tryParse(value);
                    areaModel.editItem(
                      widget.selectedOrder,
                      newStrategyInt: intValue,
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
