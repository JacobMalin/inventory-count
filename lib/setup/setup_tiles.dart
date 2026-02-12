import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/area_model.dart';
import '../models/export_model.dart';
import '../models/hive.dart';

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
  final List<CountPhase> sortedPhases = phases.toList()
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
  const AreaTile({
    required int index,
    required void Function(int) select,
    super.key,
  }) : _select = select,
       _index = index;

  final int _index;
  final void Function(int) _select;

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        final Area area = areaModel.getArea(_index);
        final int numShelves = area.shelvesAndItems.whereType<Shelf>().length;
        final int numItems = area.shelvesAndItems.whereType<Item>().length;

        // Collect all phases from items in area
        final phases = <CountPhase>{};
        for (final StorageObject element in area.shelvesAndItems) {
          if (element is Item) {
            phases.add(element.personalCountPhase ?? element.countPhase);
          } else if (element is Shelf) {
            for (final Item item in element.items) {
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
              '$numShelves ${numShelves == 1 ? 'shelf' : 'shelves'}, '
              '$numItems item${numItems == 1 ? '' : 's'}';
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
          onTap: () => _select(_index),
        );
      },
    );
  }
}

class ShelfTile extends StatelessWidget {
  const ShelfTile({
    required int index,
    required List<int> selectedOrder,
    required void Function(int) select,
    super.key,
  }) : _select = select,
       _ = selectedOrder,
       _index = index;

  final int _index;
  final List<int> _;
  final void Function(int) _select;

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        final shelf = areaModel.getShelfOrItem([..._, _index]) as Shelf;

        // Collect all phases from items in shelf
        final phases = <CountPhase>{};
        for (final Item item in shelf.items) {
          phases.add(item.personalCountPhase ?? item.countPhase);
        }

        return ListTile(
          key: Key('$_index'),
          leading: const Icon(Icons.shelves, color: Colors.amber),
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
          onTap: () => _select(_index),
        );
      },
    );
  }
}

class ItemTile extends StatelessWidget {
  const ItemTile({
    required int index,
    required List<int> selectedOrder,
    required void Function(int) select,
    super.key,
  }) : _select = select,
       _selectedOrder = selectedOrder,
       _index = index;

  final int _index;
  final List<int> _selectedOrder;
  final void Function(int) _select;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AreaModel, ExportModel>(
      builder: (context, areaModel, exportModel, child) {
        final item =
            areaModel.getShelfOrItem([..._selectedOrder, _index]) as Item;
        final bool isValid = item.getIsValid(exportModel);

        return ListTile(
          key: Key('$_index'),
          leading: const Icon(Icons.inventory, color: Colors.blue),
          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          title: Text(item.name),
          subtitle: Text(
            item.defaultCount != null
                ? '${item.strategy.strategyText} • '
                      'Default: ${item.defaultCount!.count}'
                : item.strategy.strategyText,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isValid) ...[
                Icon(
                  Icons.visibility_off,
                  size: 20,
                  color: Colors.red.withAlpha(160),
                ),
                const SizedBox(width: 8),
              ],
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
          onTap: () => _select(_index),
        );
      },
    );
  }
}
