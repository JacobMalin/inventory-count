import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:provider/provider.dart';

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
                      content: Consumer<CountModel>(
                        builder: (context, countModel, child) {
                          return TextField(
                            controller: controller,
                            autofocus: true,
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                areaModel.editItem(
                                  selectedOrder,
                                  newName: value,
                                  countModel: countModel,
                                );
                              }
                            },
                            onSubmitted: (_) => Navigator.pop(context),
                          );
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
                        Consumer<CountModel>(
                          builder: (context, countModel, child) {
                            return TextButton(
                              onPressed: () {
                                areaModel.removeItem(selectedOrder, countModel);
                                Navigator.pop(context);
                                deselect();
                              },
                              child: const Text('Delete'),
                            );
                          },
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
                deselect();
              }
            },
            child: ItemSettings(item: item, selectedOrder: selectedOrder),
          ),
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
  late CountPhase countPhase;
  late CountPhase? personalCountPhase;
  final TextEditingController strategyIntController = TextEditingController();
  final TextEditingController strategyInt2Controller = TextEditingController();
  final TextEditingController countNameController = TextEditingController();
  final TextEditingController defaultCountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    countStrategy = widget.item.strategy;
    countPhase = widget.item.countPhase;
    personalCountPhase = widget.item.personalCountPhase;
    countNameController.text = widget.item.countName ?? '';
    if (widget.item.strategyInt != null) {
      strategyIntController.text = widget.item.strategyInt.toString();
    }
    if (widget.item.strategyInt2 != null) {
      strategyInt2Controller.text = widget.item.strategyInt2.toString();
    }
    if (widget.item.defaultCount != null) {
      defaultCountController.text = widget.item.defaultCount.toString();
    }
  }

  @override
  void dispose() {
    strategyIntController.dispose();
    strategyInt2Controller.dispose();
    countNameController.dispose();
    defaultCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Consumer2<AreaModel, CountModel>(
        builder: (context, areaModel, countModel, child) {
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
                  areaModel.editItem(
                    widget.selectedOrder,
                    newCountName: value,
                    countModel: countModel,
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
                child: SegmentedButton<CountStrategy>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment<CountStrategy>(
                      value: CountStrategy.singular,
                      label: Text('Singular'),
                    ),
                    ButtonSegment<CountStrategy>(
                      value: CountStrategy.stacks,
                      label: Text('Stacks'),
                    ),
                    ButtonSegment<CountStrategy>(
                      value: CountStrategy.boxesAndStacks,
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
                      countModel: countModel,
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              if (countStrategy == CountStrategy.stacks)
                TextField(
                  controller: strategyIntController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Items per stack',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      areaModel.editItem(
                        widget.selectedOrder,
                        clearStrategyInt: true,
                        countModel: countModel,
                      );
                    } else {
                      final intValue = int.tryParse(value);
                      areaModel.editItem(
                        widget.selectedOrder,
                        newStrategyInt: intValue,
                        countModel: countModel,
                      );
                    }
                  },
                ),
              if (countStrategy == CountStrategy.boxesAndStacks)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: strategyIntController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stacks per box',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          if (value.isEmpty) {
                            areaModel.editItem(
                              widget.selectedOrder,
                              clearStrategyInt: true,
                              countModel: countModel,
                            );
                          } else {
                            final intValue = int.tryParse(value);
                            areaModel.editItem(
                              widget.selectedOrder,
                              newStrategyInt: intValue,
                              countModel: countModel,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: strategyInt2Controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Items per stack',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          if (value.isEmpty) {
                            areaModel.editItem(
                              widget.selectedOrder,
                              clearStrategyInt2: true,
                              countModel: countModel,
                            );
                          } else {
                            final intValue = int.tryParse(value);
                            areaModel.editItem(
                              widget.selectedOrder,
                              newStrategyInt2: intValue,
                              countModel: countModel,
                            );
                          }
                        },
                      ),
                    ),
                  ],
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
                    if (value.isEmpty) {
                      areaModel.editItem(
                        widget.selectedOrder,
                        clearStrategyInt: true,
                        countModel: countModel,
                      );
                    } else {
                      final intValue = int.tryParse(value);
                      areaModel.editItem(
                        widget.selectedOrder,
                        newStrategyInt: intValue,
                        countModel: countModel,
                      );
                    }
                  },
                ),
              const SizedBox(height: 24),
              Text(
                'Default Count',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: defaultCountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '0',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  if (value.isEmpty) {
                    areaModel.editItem(
                      widget.selectedOrder,
                      clearDefaultCount: true,
                    );
                    return;
                  }

                  final intValue = int.tryParse(value);
                  areaModel.editItem(
                    widget.selectedOrder,
                    newDefaultCount: intValue,
                  );
                },
              ),
              const SizedBox(height: 24),
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
                  selected: {countPhase},
                  onSelectionChanged: (Set<CountPhase> newSelection) {
                    setState(() {
                      countPhase = newSelection.first;
                    });
                    areaModel.editItem(
                      widget.selectedOrder,
                      newCountPhase: countPhase,
                      countModel: countModel,
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
                  selected: personalCountPhase != null
                      ? {personalCountPhase!}
                      : {},
                  onSelectionChanged: (Set<CountPhase> newSelection) {
                    setState(() {
                      personalCountPhase = newSelection.firstOrNull;
                    });
                    areaModel.editItem(
                      widget.selectedOrder,
                      newPersonalCountPhase: personalCountPhase,
                      clearPersonalCountPhase: personalCountPhase == null,
                      countModel: countModel,
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
