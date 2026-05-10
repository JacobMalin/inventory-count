import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/area_model.dart';
import '../../models/data/count_strategy.dart';
import '../../models/data/export_entry.dart';
import '../../models/data/inventory_models.dart';
import '../../models/export_model.dart';
import 'setup_helpers.dart';

class ItemPage extends StatelessWidget {
  const ItemPage({
    required Item item,
    required void Function({StorageObject? object}) select,
    super.key,
  }) : _item = item,
       _select = select;

  final Item _item;
  final void Function({StorageObject? object}) _select;

  Future<void> _moveItem(BuildContext context, AreaModel areaModel) async {
    final List<int> sourceOrder;
    final StorageObject parent = _item.parent;
    if (parent is Area) {
      final int areaIndex = areaModel.getAreas().indexOf(parent);
      final int itemIndex = parent.indexOf(_item);
      if (areaIndex == -1 || itemIndex == -1) {
        return;
      }
      sourceOrder = [areaIndex, itemIndex];
    } else if (parent is Shelf) {
      final int areaIndex = areaModel.getAreas().indexOf(parent.parent);
      final int shelfIndex = parent.parent.indexOf(parent);
      var itemIndex = -1;
      for (var i = 0; i < parent.numItems; i++) {
        if (identical(parent[i], _item)) {
          itemIndex = i;
          break;
        }
      }
      if (areaIndex == -1 || shelfIndex == -1 || itemIndex == -1) {
        return;
      }
      sourceOrder = [areaIndex, shelfIndex, itemIndex];
    } else {
      return;
    }

    int selectedAreaIndex = sourceOrder[0];
    int? selectedShelfIndex = sourceOrder.length == 3 ? sourceOrder[1] : null;

    final bool? shouldMove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final Area selectedArea = areaModel.getArea(selectedAreaIndex);
            final List<MapEntry<int, Shelf>> shelves = getShelfEntriesForArea(
              selectedArea,
            );

            if (selectedShelfIndex != null &&
                !shelves.any((entry) => entry.key == selectedShelfIndex)) {
              selectedShelfIndex = null;
            }

            return AlertDialog(
              title: const Text('Move Item'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedAreaIndex,
                    decoration: const InputDecoration(labelText: 'Area'),
                    items: [
                      for (var i = 0; i < areaModel.numAreas; i++)
                        DropdownMenuItem<int>(
                          value: i,
                          child: Text(areaModel.getArea(i).name),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedAreaIndex = value;
                        selectedShelfIndex = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedShelfIndex,
                    isDense: false,
                    decoration: const InputDecoration(
                      labelText: 'Shelf',
                      contentPadding: EdgeInsets.symmetric(vertical: 2),
                    ),
                    items: [
                      buildBottomOfAreaOption(context),
                      for (final shelfEntry in shelves)
                        DropdownMenuItem<int?>(
                          value: shelfEntry.key,
                          child: Text(shelfEntry.value.name),
                        ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedShelfIndex = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Move'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldMove != true) {
      return;
    }

    areaModel.moveItemToDestination(
      sourceOrder: sourceOrder,
      targetAreaIndex: selectedAreaIndex,
      targetShelfIndex: selectedShelfIndex,
    );

    _select();

    final String destinationArea = areaModel.getArea(selectedAreaIndex).name;
    final String destination;
    if (selectedShelfIndex == null) {
      destination = destinationArea;
    } else {
      final destinationShelf =
          areaModel.getArea(selectedAreaIndex)[selectedShelfIndex!] as Shelf;
      destination = '$destinationArea > ${destinationShelf.name}';
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Moved "${_item.name}" to $destination.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _item.name,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            centerTitle: true,
            toolbarHeight: 40,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: _select,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final String originalName = _item.name;
                  final controller = TextEditingController(text: _item.name);
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );

                  await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Rename Item'),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            areaModel.editItem(_item, newName: value);
                          }
                        },
                        onSubmitted: (_) => Navigator.pop(context),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            areaModel.editItem(_item, newName: originalName);
                            Navigator.pop(context);
                          },
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.drive_file_move),
                onPressed: () async {
                  await _moveItem(context, areaModel);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  await showDialog(
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
                            areaModel.removeItem(_item);
                            Navigator.pop(context);
                            _select();
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
          body: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 300) {
                _select();
              }
            },
            child: ItemSettings(item: _item),
          ),
        );
      },
    );
  }
}

class ItemSettings extends StatefulWidget {
  const ItemSettings({required Item item, super.key}) : _item = item;

  final Item _item;

  @override
  State<ItemSettings> createState() => _ItemSettingsState();
}

class _ItemSettingsState extends State<ItemSettings> {
  late CountStrategy _countStrategy;
  late CountPhase _countPhase;
  late CountPhase? _personalCountPhase;
  final TextEditingController _strategyIntController = TextEditingController();
  final TextEditingController _strategyInt2Controller = TextEditingController();
  final TextEditingController _defaultCountController = TextEditingController();
  final TextEditingController _defaultStacksController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _countStrategy = widget._item.strategy;
    _countPhase = widget._item.countPhase;
    _personalCountPhase = widget._item.personalCountPhase;
    _countStrategy.populateControllers(
      _strategyIntController,
      _strategyInt2Controller,
    );
    if (widget._item.defaultCount != null) {
      _defaultCountController.text =
          widget._item.defaultCount!.field1?.toString() ?? '';
      _defaultStacksController.text =
          widget._item.defaultCount!.field2?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _strategyIntController.dispose();
    _strategyInt2Controller.dispose();
    _defaultCountController.dispose();
    _defaultStacksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Consumer<AreaModel>(
        builder: (context, areaModel, child) {
          void updateDefaultCount() {
            int? defaultCountField1;
            int? defaultCountField2;

            if (_defaultCountController.text.isNotEmpty) {
              defaultCountField1 = int.tryParse(_defaultCountController.text);
            }

            if (_defaultStacksController.text.isNotEmpty) {
              defaultCountField2 = int.tryParse(_defaultStacksController.text);
            }

            if (defaultCountField1 != null || defaultCountField2 != null) {
              areaModel.editItem(
                widget._item,
                newDefaultCount: ItemCount(
                  _countStrategy,
                  field1: defaultCountField1,
                  field2: defaultCountField2,
                ),
              );
            } else {
              areaModel.editItem(widget._item, clearDefaultCount: true);
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Consumer<ExportModel>(
                builder: (context, exportModel, child) {
                  final bool isValid = widget._item.getIsValid(exportModel);
                  final String? countName = widget._item.countName;
                  final String exportName = countName ?? widget._item.name;

                  return Row(
                    children: [
                      Text(
                        'Count Name'
                        '${isValid ? ' ($exportName)' : ''}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (!isValid) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.visibility_off,
                          size: 20,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          countName == null
                              ? 'No export selected'
                              : 'Export "$countName" is hidden',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Consumer<ExportModel>(
                builder: (context, exportModel, child) {
                  final List<String> exportItemNames = exportModel.exportList
                      .whereType<ExportItem>()
                      .map((entry) => entry.name)
                      .toList();
                  final String? currentCountName = widget._item.countName;
                  final dropdownValue = currentCountName;

                  return DropdownSearch<String>(
                    selectedItem: dropdownValue,
                    items: (f, cs) => exportItemNames,
                    popupProps: PopupProps.autocomplete(
                      autoCompleteProps: AutocompleteProps(
                        groupId: UniqueKey(),
                      ),
                    ),

                    onSelected: (value) {
                      if (value == null) {
                        areaModel.editItem(widget._item, newCountName: '');
                      } else {
                        areaModel.editItem(widget._item, newCountName: value);
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Count Strategy',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Center(
                child: SegmentedButton<CountStrategyType>(
                  showSelectedIcon: false,
                  segments: [
                    for (int i = 0; i < CountStrategyType.values.length; i++)
                      ButtonSegment<CountStrategyType>(
                        value: CountStrategyType.values[i],
                        label: Text(CountStrategyType.values[i].name),
                      ),
                  ],
                  selected: {_countStrategy.index},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _countStrategy = CountStrategy.fromIndex(
                        newSelection.first,
                        modifier1: int.tryParse(_strategyIntController.text),
                        modifier2: int.tryParse(_strategyInt2Controller.text),
                      );
                    });
                    areaModel.editItem(
                      widget._item,
                      newStrategy: _countStrategy,
                    );
                    updateDefaultCount();
                  },
                ),
              ),
              ..._countStrategy.buildConfigFields(
                controller1: _strategyIntController,
                controller2: _strategyInt2Controller,
                item: widget._item,
                areaModel: areaModel,
              ),
              const SizedBox(height: 24),
              if (_countStrategy is! NegativeCountStrategy) ...[
                Text(
                  widget._item.defaultCount != null
                      ? 'Default Count: ${widget._item.defaultCount!.count}'
                      : 'Default Count',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (_countStrategy is SingularCountStrategy ||
                    _countStrategy is StacksCountStrategy)
                  TextField(
                    controller: _defaultCountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0',
                      labelText: _countStrategy is StacksCountStrategy
                          ? 'Default stacks'
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      updateDefaultCount();
                    },
                  )
                else if (_countStrategy is BoxesAndStacksCountStrategy)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _defaultStacksController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '0',
                            labelText: 'Default stacks',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            updateDefaultCount();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _defaultCountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '0',
                            labelText: 'Default boxes',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            updateDefaultCount();
                          },
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
              ],
              Text(
                'Count Phase',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Store Phase',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Center(
                child: SegmentedButton<CountPhase>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment<CountPhase>(
                      value: CountPhase.back,
                      label: Text('Back'),
                    ),
                    ButtonSegment<CountPhase>(
                      value: CountPhase.cabinet,
                      label: Text('Cabinet'),
                    ),
                    ButtonSegment<CountPhase>(
                      value: CountPhase.out,
                      label: Text('Out'),
                    ),
                  ],
                  selected: {_countPhase},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _countPhase = newSelection.first;
                    });
                    areaModel.editItem(
                      widget._item,
                      newCountPhase: _countPhase,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Personal Phase (Optional)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Center(
                child: SegmentedButton<CountPhase>(
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment<CountPhase>(
                      value: CountPhase.back,
                      label: Text('Back'),
                    ),
                    ButtonSegment<CountPhase>(
                      value: CountPhase.cabinet,
                      label: Text('Cabinet'),
                    ),
                    ButtonSegment<CountPhase>(
                      value: CountPhase.out,
                      label: Text('Out'),
                    ),
                  ],
                  selected: _personalCountPhase != null
                      ? {_personalCountPhase!}
                      : {},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _personalCountPhase = newSelection.firstOrNull;
                    });
                    areaModel.editItem(
                      widget._item,
                      newPersonalCountPhase: _personalCountPhase,
                      clearPersonalCountPhase: _personalCountPhase == null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
