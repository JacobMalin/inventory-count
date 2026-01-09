import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:provider/provider.dart';

String _getPhaseText(CountPhase phase) {
  switch (phase) {
    case CountPhase.back:
      return 'B';
    case CountPhase.cabinet:
      return 'C';
    case CountPhase.out:
      return 'O';
  }
}

Color _getPhaseColor(CountPhase phase) {
  switch (phase) {
    case CountPhase.back:
      return const Color.fromRGBO(244, 67, 54, 0.6); // Red
    case CountPhase.cabinet:
      return const Color.fromRGBO(255, 235, 59, 0.6); // Yellow
    case CountPhase.out:
      return const Color.fromRGBO(76, 175, 80, 0.6); // Green
  }
}

Widget _buildPhaseIndicators(Set<CountPhase> phases) {
  final sortedPhases = phases.toList()
    ..sort((a, b) => a.index.compareTo(b.index));

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < sortedPhases.length; i++) ...[
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: _getPhaseColor(sortedPhases[i]),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              _getPhaseText(sortedPhases[i]),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (i < sortedPhases.length - 1) const SizedBox(width: 4),
      ],
    ],
  );
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

        // Collect all phases from items in area
        final phases = <CountPhase>{};
        for (var element in area.shelvesAndItems) {
          if (element is Item) {
            phases.add(element.personalCountPhase ?? element.countPhase);
          } else if (element is Shelf) {
            for (var item in element.items) {
              phases.add(item.personalCountPhase ?? item.countPhase);
            }
          }
        }

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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (phases.isNotEmpty) ...[
                _buildPhaseIndicators(phases),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.drag_handle),
            ],
          ),
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

        // Collect all phases from items in shelf
        final phases = <CountPhase>{};
        for (var item in shelf.items) {
          phases.add(item.personalCountPhase ?? item.countPhase);
        }

        return ListTile(
          key: Key('$index'),
          leading: Icon(Icons.shelves, color: Colors.amber),
          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          title: Text(shelf.name),
          subtitle: Text('${shelf.items.length} items'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (phases.isNotEmpty) ...[
                _buildPhaseIndicators(phases),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.drag_handle),
            ],
          ),
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
            item.defaultCount != null
                ? '${item.strategy.strategyText} • Default: ${item.defaultCount!.count}'
                : item.strategy.strategyText,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _getPhaseColor(item.countPhase),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        _getPhaseText(item.countPhase),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (item.personalCountPhase != null) ...[
                    const SizedBox(height: 2),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _getPhaseColor(item.personalCountPhase!),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color.fromRGBO(255, 255, 255, 0.5),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _getPhaseText(item.personalCountPhase!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.drag_handle),
            ],
          ),
          onTap: () => select(index),
        );
      },
    );
  }
}
