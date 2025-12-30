import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:provider/provider.dart';

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

  String _getStrategyText(
    CountStrategy strategy,
    int? strategyInt,
    int? strategyInt2,
  ) {
    switch (strategy) {
      case CountStrategy.singular:
        return 'Singular';
      case CountStrategy.stacks:
        return strategyInt != null
            ? 'Stacks ($strategyInt per stack)'
            : 'Stacks';
      case CountStrategy.boxesAndStacks:
        if (strategyInt != null && strategyInt2 != null) {
          return 'Both ($strategyInt per box, $strategyInt2 per stack)';
        } else if (strategyInt != null) {
          return 'Both ($strategyInt per box)';
        } else {
          return 'Both';
        }
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
          subtitle: Text(
            _getStrategyText(
              item.strategy,
              item.strategyInt,
              item.strategyInt2,
            ),
          ),
          trailing: const Icon(Icons.drag_handle),
          onTap: () => select(index),
        );
      },
    );
  }
}
