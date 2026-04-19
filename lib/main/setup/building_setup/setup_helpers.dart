import 'package:flutter/material.dart';

import '../../models/data/inventory_models.dart';

/// Helper function to extract shelf entries from an area
List<MapEntry<int, Shelf>> getShelfEntriesForArea(Area area) {
  final shelves = <MapEntry<int, Shelf>>[];
  for (var i = 0; i < area.numItemsAndShelves; i++) {
    final StorageObject object = area[i];
    if (object is Shelf) {
      shelves.add(MapEntry(i, object));
    }
  }
  return shelves;
}

/// Creates a styled "Bottom of Area" dropdown option
DropdownMenuItem<int?> buildBottomOfAreaOption(BuildContext context) {
  return DropdownMenuItem<int?>(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(
            Icons.south_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Bottom of Area',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}
