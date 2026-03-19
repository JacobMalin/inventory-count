import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/area_model.dart';
import '../../models/data/inventory_models.dart';
import '../../models/export_model.dart';

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
            color: sortedPhases[i].color,
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
    required Area area,
    required Future<void> Function({StorageObject? object}) select,
    super.key,
  }) : _area = area,
       _select = select;

  final Area _area;
  final Future<void> Function({StorageObject? object}) _select;

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        final int numShelves = _area.numShelves;
        final int numItems = _area.numItems;

        // Collect all phases from items in area
        final phases = <CountPhase>{};
        _area.forEachItem((element) {
          phases.add(element.personalCountPhase ?? element.countPhase);
        });

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
          title: Text(_area.name, style: TextStyle(color: _area.color)),
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
          onTap: () => _select(object: _area),
        );
      },
    );
  }
}

class ShelfTile extends StatelessWidget {
  const ShelfTile({
    required Shelf shelf,
    required Future<void> Function({StorageObject? object}) select,
    super.key,
  }) : _shelf = shelf,
       _select = select;

  final Shelf _shelf;
  final Future<void> Function({StorageObject? object}) _select;

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        // Collect all phases from items in shelf
        final phases = <CountPhase>{};
        _shelf.forEach((item) {
          phases.add(item.personalCountPhase ?? item.countPhase);
        });

        return ListTile(
          key: Key(_shelf.path),
          leading: const Icon(Icons.shelves, color: Colors.amber),
          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          title: Text(_shelf.name),
          subtitle: Text('${_shelf.numItems} items'),
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
          onTap: () => _select(object: _shelf),
        );
      },
    );
  }
}

class ItemTile extends StatelessWidget {
  const ItemTile({
    required Item item,
    required Future<void> Function({StorageObject? object}) select,
    super.key,
  }) : _item = item,
       _select = select;

  final Item _item;
  final Future<void> Function({StorageObject? object}) _select;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AreaModel, ExportModel>(
      builder: (context, areaModel, exportModel, child) {
        final bool isValid = _item.getIsValid(exportModel);

        return ListTile(
          key: Key(_item.path),
          leading: const Icon(Icons.inventory, color: Colors.blue),
          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          title: Text(_item.name),
          subtitle: Text(
            _item.defaultCount != null
                ? '${_item.strategy.strategyText} • '
                      'Default: ${_item.defaultCount!.count}'
                : _item.strategy.strategyText,
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
                      color: _item.countPhase.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        _getPhaseText(_item.countPhase),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (_item.personalCountPhase != null) ...[
                    const SizedBox(height: 2),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _item.personalCountPhase!.color,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color.fromRGBO(255, 255, 255, 0.5),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _getPhaseText(_item.personalCountPhase!),
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
          onTap: () => _select(object: _item),
        );
      },
    );
  }
}
