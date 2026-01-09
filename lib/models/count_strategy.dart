import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:inventory_count/models/hive.dart';

part 'count_strategy.g.dart';

void registerCountStrategyAdapters() {
  Hive.registerAdapter<SingularCountStrategy>(SingularCountStrategyAdapter());
  Hive.registerAdapter<NegativeCountStrategy>(NegativeCountStrategyAdapter());
  Hive.registerAdapter<StacksCountStrategy>(StacksCountStrategyAdapter());
  Hive.registerAdapter<BoxesAndStacksCountStrategy>(
    BoxesAndStacksCountStrategyAdapter(),
  );
  Hive.registerAdapter<ItemCount>(ItemCountAdapter());
  Hive.registerAdapter<ItemNotCounted>(ItemNotCountedAdapter());
}

enum CountStrategyType {
  singular,
  stacks,
  boxesAndStacks,
  negative;

  String get name => switch (this) {
    CountStrategyType.singular => 'Singular',
    CountStrategyType.negative => 'Negative',
    CountStrategyType.stacks => 'Stacks',
    CountStrategyType.boxesAndStacks => 'Both',
  };
}

abstract class CountStrategy {
  CountStrategyType get index => switch (this) {
    SingularCountStrategy() => CountStrategyType.singular,
    NegativeCountStrategy() => CountStrategyType.negative,
    StacksCountStrategy() => CountStrategyType.stacks,
    BoxesAndStacksCountStrategy() => CountStrategyType.boxesAndStacks,
    _ => throw Exception('Unknown CountStrategy type'),
  };

  Map<String, dynamic> toJson();

  int? calculateCount(int? field1, int? field2);

  bool isEmpty(int? field1, int? field2);

  String get strategyText;

  void populateControllers(
    TextEditingController controller1,
    TextEditingController controller2,
  ) {}

  List<Widget> buildConfigFields({
    required TextEditingController controller1,
    required TextEditingController controller2,
    required List<int> selectedOrder,
    required AreaModel areaModel,
    required CountModel countModel,
  }) => [];

  Widget buildCountFields({
    required TextEditingController controller1,
    required TextEditingController controller2,
    required FocusNode focusNode,
    required CountModel countModel,
    required Item item,
    required void Function(String) onSubmitted,
  });

  const CountStrategy();

  factory CountStrategy.fromIndex(
    CountStrategyType index, {
    int? modifier1,
    int? modifier2,
  }) {
    switch (index) {
      case CountStrategyType.singular:
        return SingularCountStrategy();
      case CountStrategyType.negative:
        return NegativeCountStrategy(modifier1 ?? 0);
      case CountStrategyType.stacks:
        return StacksCountStrategy(modifier1 ?? 1);
      case CountStrategyType.boxesAndStacks:
        return BoxesAndStacksCountStrategy(modifier1 ?? 1, modifier2 ?? 1);
    }
  }

  static final Map<String, CountStrategy Function(Map<String, dynamic>)>
  _registry = {
    'SingularCountStrategy': SingularCountStrategy.fromJson,
    'StacksCountStrategy': StacksCountStrategy.fromJson,
    'BoxesAndStacksCountStrategy': BoxesAndStacksCountStrategy.fromJson,
    'NegativeCountStrategy': NegativeCountStrategy.fromJson,
  };

  factory CountStrategy.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final constructor = _registry[type];

    if (constructor == null) {
      throw Exception('Unknown CountStrategy type: $type');
    }

    return constructor(json);
  }
}

@HiveType(typeId: 12)
class SingularCountStrategy extends CountStrategy {
  // Hive requires at least one field for subtypes
  @HiveField(0)
  bool? placeholder = true;

  @override
  Map<String, dynamic> toJson() => {'type': 'SingularCountStrategy'};

  @override
  int? calculateCount(int? field1, int? field2) => field1;

  @override
  bool isEmpty(int? field1, int? field2) => field1 == null;

  @override
  get strategyText => 'Singular';

  @override
  Widget buildCountFields({
    required TextEditingController controller1,
    required TextEditingController controller2,
    required FocusNode focusNode,
    required CountModel countModel,
    required Item item,
    required void Function(String) onSubmitted,
  }) {
    return TextField(
      controller: controller1,
      focusNode: focusNode,
      autofocus: true,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Count',
        border: OutlineInputBorder(),
      ),
      onChanged: (value) {
        final intValue = int.tryParse(value);
        countModel.setField1(item, intValue);
      },
      onSubmitted: onSubmitted,
    );
  }

  SingularCountStrategy({this.placeholder});

  SingularCountStrategy.fromJson(Map<String, dynamic> json);
}

@HiveType(typeId: 13)
class NegativeCountStrategy extends CountStrategy {
  @HiveField(0)
  int from;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'NegativeCountStrategy',
    'from': from,
  };

  @override
  int? calculateCount(int? field1, int? field2) {
    if (field1 == null) return null;
    return from - field1;
  }

  @override
  bool isEmpty(int? field1, int? field2) => field1 == null;

  @override
  get strategyText => 'Negative (from $from)';

  @override
  void populateControllers(
    TextEditingController controller1,
    TextEditingController controller2,
  ) {
    controller1.text = from == 0 ? '' : from.toString();
  }

  @override
  List<Widget> buildConfigFields({
    required TextEditingController controller1,
    required TextEditingController controller2,
    required List<int> selectedOrder,
    required AreaModel areaModel,
    required CountModel countModel,
  }) {
    return [
      const SizedBox(height: 24),
      TextField(
        controller: controller1,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Starting total',
          border: OutlineInputBorder(),
        ),
        onChanged: (value) {
          final intValue = value.isEmpty ? 0 : (int.tryParse(value) ?? 0);
          from = intValue;
          areaModel.editItem(
            selectedOrder,
            newStrategy: this,
            countModel: countModel,
          );
        },
      ),
    ];
  }

  @override
  Widget buildCountFields({
    required TextEditingController controller1,
    required TextEditingController controller2,
    required FocusNode focusNode,
    required CountModel countModel,
    required Item item,
    required void Function(String) onSubmitted,
  }) {
    return TextField(
      controller: controller1,
      focusNode: focusNode,
      autofocus: true,
      keyboardType: TextInputType.text,
      decoration: InputDecoration(
        labelText: 'Count (negative from $from)',
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        final intValue = int.tryParse(value);
        countModel.setField1(item, intValue);
      },
      onSubmitted: onSubmitted,
    );
  }

  NegativeCountStrategy(this.from);

  NegativeCountStrategy.fromJson(Map<String, dynamic> json)
    : from = json['from'] as int? ?? 0;
}

@HiveType(typeId: 14)
class StacksCountStrategy extends CountStrategy {
  @HiveField(0)
  int perStack;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'StacksCountStrategy',
    'perStack': perStack,
  };

  @override
  int? calculateCount(int? field1, int? field2) {
    if (field1 == null) return null;
    return field1 * perStack;
  }

  @override
  bool isEmpty(int? field1, int? field2) => field1 == null;

  @override
  get strategyText => 'Stacks ($perStack per stack)';

  @override
  void populateControllers(
    TextEditingController controller1,
    TextEditingController controller2,
  ) {
    controller1.text = perStack == 1 ? '' : perStack.toString();
  }

  @override
  List<Widget> buildConfigFields({
    required TextEditingController controller1,
    required TextEditingController controller2,
    required List<int> selectedOrder,
    required AreaModel areaModel,
    required CountModel countModel,
  }) {
    return [
      const SizedBox(height: 24),
      TextField(
        controller: controller1,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Items per stack',
          border: OutlineInputBorder(),
        ),
        onChanged: (value) {
          if (value.isEmpty) {
            perStack = 1;
            areaModel.editItem(
              selectedOrder,
              newStrategy: this,
              countModel: countModel,
            );
          } else {
            final intValue = int.tryParse(value);
            perStack = intValue ?? 1;
            areaModel.editItem(
              selectedOrder,
              newStrategy: this,
              countModel: countModel,
            );
          }
        },
      ),
    ];
  }

  @override
  Widget buildCountFields({
    required TextEditingController controller1,
    required TextEditingController controller2,
    required FocusNode focusNode,
    required CountModel countModel,
    required Item item,
    required void Function(String) onSubmitted,
  }) {
    return TextField(
      controller: controller1,
      focusNode: focusNode,
      autofocus: true,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Stacks ($perStack per stack)',
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        final intValue = int.tryParse(value);
        countModel.setField1(item, intValue);
      },
      onSubmitted: onSubmitted,
    );
  }

  StacksCountStrategy(this.perStack);

  StacksCountStrategy.fromJson(Map<String, dynamic> json)
    : perStack = json['perStack'] as int? ?? 1;
}

@HiveType(typeId: 15)
class BoxesAndStacksCountStrategy extends CountStrategy {
  @HiveField(0)
  int perBox;

  @HiveField(1)
  int perStack;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'BoxesAndStacksCountStrategy',
    'perBox': perBox,
    'perStack': perStack,
  };

  @override
  int? calculateCount(int? field1, int? field2) {
    if (field1 == null && field2 == null) return null;
    return ((field1 ?? 0) * perBox + (field2 ?? 0)) * perStack;
  }

  @override
  bool isEmpty(int? field1, int? field2) => field1 == null && field2 == null;

  @override
  get strategyText => 'Both ($perBox per box, $perStack per stack)';

  @override
  void populateControllers(
    TextEditingController controller1,
    TextEditingController controller2,
  ) {
    controller1.text = perBox == 1 ? '' : perBox.toString();
    controller2.text = perStack == 1 ? '' : perStack.toString();
  }

  @override
  List<Widget> buildConfigFields({
    required TextEditingController controller1,
    required TextEditingController controller2,
    required List<int> selectedOrder,
    required AreaModel areaModel,
    required CountModel countModel,
  }) {
    return [
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller1,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stacks per box',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                if (value.isEmpty) {
                  perBox = 1;
                  areaModel.editItem(
                    selectedOrder,
                    newStrategy: this,
                    countModel: countModel,
                  );
                } else {
                  final intValue = int.tryParse(value);
                  perBox = intValue ?? 1;
                  areaModel.editItem(
                    selectedOrder,
                    newStrategy: this,
                    countModel: countModel,
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller2,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Items per stack',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                if (value.isEmpty) {
                  perStack = 1;
                  areaModel.editItem(
                    selectedOrder,
                    newStrategy: this,
                    countModel: countModel,
                  );
                } else {
                  final intValue = int.tryParse(value);
                  perStack = intValue ?? 1;
                  areaModel.editItem(
                    selectedOrder,
                    newStrategy: this,
                    countModel: countModel,
                  );
                }
              },
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget buildCountFields({
    required TextEditingController controller1,
    required TextEditingController controller2,
    required FocusNode focusNode,
    required CountModel countModel,
    required Item item,
    required void Function(String) onSubmitted,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller1,
            focusNode: focusNode,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Boxes ($perBox stacks)',
              labelStyle: const TextStyle(fontSize: 12),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              final intValue = int.tryParse(value);
              countModel.setField1(item, intValue);
            },
            onSubmitted: onSubmitted,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller2,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Stacks ($perStack per)',
              labelStyle: const TextStyle(fontSize: 12),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              final intValue = int.tryParse(value);
              countModel.setField2(item, intValue);
            },
            onSubmitted: onSubmitted,
          ),
        ),
      ],
    );
  }

  BoxesAndStacksCountStrategy(this.perBox, this.perStack);

  BoxesAndStacksCountStrategy.fromJson(Map<String, dynamic> json)
    : perBox = json['perBox'] as int? ?? 1,
      perStack = json['perStack'] as int? ?? 1;
}

@HiveType(typeId: 10)
class ItemCount extends ItemCountType {
  @HiveField(0)
  int? field1;

  @HiveField(1)
  int? field2;

  @HiveField(2)
  CountStrategy strategy;

  int? get count => strategy.calculateCount(field1, field2);

  bool isCounted() => count != null;
  bool isEmpty() => strategy.isEmpty(field1, field2);

  ItemCount(this.strategy, {this.field1, this.field2});

  Map<String, dynamic> toJson() => {
    'field1': field1,
    'field2': field2,
    'strategy': strategy.toJson(),
  };

  static ItemCount fromJson(Map<String, dynamic> json) {
    try {
      CountStrategy strategy;
      if (json['strategy'] != null &&
          json['strategy'] is Map<String, dynamic>) {
        try {
          strategy = CountStrategy.fromJson(
            json['strategy'] as Map<String, dynamic>,
          );
        } catch (e) {
          // If strategy parsing fails, use default
          strategy = SingularCountStrategy();
        }
      } else {
        strategy = SingularCountStrategy();
      }

      return ItemCount(
        strategy,
        field1: json['field1'] as int?,
        field2: json['field2'] as int?,
      );
    } catch (e) {
      // If anything fails, return a basic ItemCount
      return ItemCount(SingularCountStrategy());
    }
  }
}

@HiveType(typeId: 11)
class ItemNotCounted extends ItemCountType {
  // Hive requires at least one field for subtypes
  @HiveField(0)
  bool? placeholder = true;

  ItemNotCounted({this.placeholder});
}

abstract class ItemCountType {}
