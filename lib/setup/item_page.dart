import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
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
  late CountPhase countPhase;
  late CountPhase? personalCountPhase;
  final TextEditingController strategyIntController = TextEditingController();
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
    if (widget.item.defaultCount != null) {
      defaultCountController.text = widget.item.defaultCount.toString();
    }
  }

  @override
  void dispose() {
    strategyIntController.dispose();
    countNameController.dispose();
    defaultCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                      value: CountStrategy.stacks,
                      label: Text('Stacks'),
                    ),
                    ButtonSegment<CountStrategy>(
                      value: CountStrategy.singularAndStacks,
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
              if (countStrategy == CountStrategy.stacks ||
                  countStrategy == CountStrategy.singularAndStacks)
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
                  final intValue = int.tryParse(value) ?? 0;
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
