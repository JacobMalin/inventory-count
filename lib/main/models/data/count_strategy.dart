import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/types/json.dart';
import '../area_model.dart';
import '../count_model.dart';
import 'inventory_models.dart';

part 'count_strategy.g.dart';

void registerCountStrategyAdapters() {
  Hive
    ..registerAdapter<SingularCountStrategy>(SingularCountStrategyAdapter())
    ..registerAdapter<NegativeCountStrategy>(NegativeCountStrategyAdapter())
    ..registerAdapter<StacksCountStrategy>(StacksCountStrategyAdapter())
    ..registerAdapter<BoxesAndStacksCountStrategy>(
      BoxesAndStacksCountStrategyAdapter(),
    )
    ..registerAdapter<ItemCount>(ItemCountAdapter())
    ..registerAdapter<ItemNotCounted>(ItemNotCountedAdapter());
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
  const CountStrategy();

  factory CountStrategy.fromJson(Json json) {
    final type = json['type'] as String?;
    final CountStrategy Function(Json)? constructor = _registry[type];

    if (constructor == null) {
      throw Exception('Unknown CountStrategy type: $type');
    }

    return constructor(json);
  }

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

  CountStrategyType get index => switch (this) {
    SingularCountStrategy() => CountStrategyType.singular,
    NegativeCountStrategy() => CountStrategyType.negative,
    StacksCountStrategy() => CountStrategyType.stacks,
    BoxesAndStacksCountStrategy() => CountStrategyType.boxesAndStacks,
    _ => throw Exception('Unknown CountStrategy type'),
  };

  Json toJson();
  int? calculateCount(int? field1, int? field2);

  bool isEmpty(int? field1, int? field2);

  String get strategyText;

  String? getLastDisplay(int? field1, int? field2);

  void populateControllers(
    TextEditingController controller1,
    TextEditingController controller2,
  ) {}

  List<Widget> buildConfigFields({
    required TextEditingController controller1,
    required TextEditingController controller2,
    required List<int> selectedOrder,
    required AreaModel areaModel,
  }) => [];

  Widget buildCountFields({
    required TextEditingController controller1,
    required TextEditingController controller2,
    required FocusNode focusNode,
    required CountModel countModel,
    required Item item,
    required void Function(String) onSubmitted,
  });

  Widget buildBumpDisplay(BuildContext context, Item item);

  void setZeroCount(CountModel countModel, Item item) {
    countModel.setField1(item, 0);
  }

  static final Map<String, CountStrategy Function(Json)> _registry = {
    'SingularCountStrategy': SingularCountStrategy.fromJson,
    'StacksCountStrategy': StacksCountStrategy.fromJson,
    'BoxesAndStacksCountStrategy': BoxesAndStacksCountStrategy.fromJson,
    'NegativeCountStrategy': NegativeCountStrategy.fromJson,
  };
}

@HiveType(typeId: 12)
class SingularCountStrategy extends CountStrategy {
  SingularCountStrategy({this.placeholder});

  // Must match pattern
  // ignore: avoid_unused_constructor_parameters
  SingularCountStrategy.fromJson(Json json);

  // Hive requires at least one field for subtypes
  @HiveField(0)
  bool? placeholder = true;

  @override
  Json toJson() => {'type': 'SingularCountStrategy'};

  @override
  int? calculateCount(int? field1, int? field2) => field1;

  @override
  bool isEmpty(int? field1, int? field2) => field1 == null;

  @override
  String? getLastDisplay(int? field1, int? field2) {
    return calculateCount(field1, field2)?.toString();
  }

  @override
  String get strategyText => 'Singular';

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
        final int? intValue = int.tryParse(value);
        countModel.setField1(item, intValue);
      },
      onSubmitted: onSubmitted,
    );
  }

  @override
  Widget buildBumpDisplay(BuildContext context, Item item) {
    return _SingularBumpDisplay(item: item);
  }
}

class _SingularBumpDisplay extends StatefulWidget {
  const _SingularBumpDisplay({required Item item}) : _item = item;

  final Item _item;

  @override
  State<_SingularBumpDisplay> createState() => _SingularBumpDisplayState();
}

class _SingularBumpDisplayState extends State<_SingularBumpDisplay> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CountModel>(
      builder: (context, countModel, child) {
        final ItemCountType? itemCountType = countModel.getCount(widget._item);
        final isNotCounted = itemCountType is ItemNotCounted;
        final ItemCount? itemCount = itemCountType is ItemCount
            ? itemCountType
            : null;
        final Object? count = isNotCounted ? '-' : itemCount?.count;
        final int? currentValue = itemCount?.field1;
        final String expectedText = isNotCounted
            ? '-'
            : (currentValue?.toString() ?? '');

        if (_controller.text != expectedText &&
            !_controller.selection.isValid) {
          _controller.text = expectedText;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: isNotCounted
                  ? null
                  : () {
                      final int value = currentValue ?? 0;
                      if (value <= 0) {
                        countModel.setNotCounted(widget._item);
                        _controller.text = '-';
                      } else {
                        final int newValue = value - 1;
                        countModel.setField1(widget._item, newValue);
                        _controller.text = newValue.toString();
                      }
                    },
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(40, 40),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 80),
              child: IntrinsicWidth(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onTap: () {
                    _controller.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _controller.text.length,
                    );
                  },
                  onChanged: (value) {
                    final int? intValue = int.tryParse(value);
                    countModel.setField1(widget._item, intValue);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                if (currentValue == null) {
                  countModel.setField1(widget._item, 0);
                  _controller.text = '0';
                } else {
                  final int newValue = currentValue + 1;
                  countModel.setField1(widget._item, newValue);
                  _controller.text = newValue.toString();
                }
              },
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(40, 40),
              ),
            ),
            Text(
              ' =  $count',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        );
      },
    );
  }
}

@HiveType(typeId: 13)
class NegativeCountStrategy extends CountStrategy {
  NegativeCountStrategy(this.from);

  NegativeCountStrategy.fromJson(Json json) : from = json['from'] as int? ?? 0;
  @HiveField(0)
  int from;

  @override
  Json toJson() => {'type': 'NegativeCountStrategy', 'from': from};

  @override
  int? calculateCount(int? field1, int? field2) {
    if (field1 == null) return null;
    final int result = from - field1;
    return result < 0 ? 0 : result;
  }

  @override
  bool isEmpty(int? field1, int? field2) => field1 == null;

  @override
  String? getLastDisplay(int? field1, int? field2) {
    if (field1 == null) return null;
    return '${calculateCount(field1, field2)} ($from-$field1)';
  }

  @override
  String get strategyText => 'Negative (from $from)';

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
          final int intValue = value.isEmpty ? 0 : (int.tryParse(value) ?? 0);
          from = intValue;
          areaModel.editItem(selectedOrder, newStrategy: this);
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
    return _NegativeEntryField(
      controller: controller1,
      focusNode: focusNode,
      countModel: countModel,
      item: item,
      onSubmitted: onSubmitted,
      from: from,
    );
  }

  @override
  Widget buildBumpDisplay(BuildContext context, Item item) {
    return _NegativeBumpDisplay(item: item, from: from);
  }

  @override
  void setZeroCount(CountModel countModel, Item item) {
    countModel.setField1(item, from);
  }
}

class _NegativeBumpDisplay extends StatefulWidget {
  const _NegativeBumpDisplay({required Item item, required int from})
    : _from = from,
      _item = item;

  final Item _item;
  final int _from;

  @override
  State<_NegativeBumpDisplay> createState() => _NegativeBumpDisplayState();
}

class _NegativeBumpDisplayState extends State<_NegativeBumpDisplay> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CountModel>(
      builder: (context, countModel, child) {
        final ItemCountType? itemCountType = countModel.getCount(widget._item);
        final isNotCounted = itemCountType is ItemNotCounted;
        final ItemCount? itemCount = itemCountType is ItemCount
            ? itemCountType
            : null;
        final Object? count = isNotCounted ? '-' : itemCount?.count;
        final int? field1 = itemCount?.field1;
        final String expectedText = isNotCounted
            ? '-'
            : (field1?.toString() ?? '');

        if (_controller.text != expectedText &&
            !_controller.selection.isValid) {
          _controller.text = expectedText;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget._from} - ',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: isNotCounted
                      ? null
                      : () {
                          final int currentValue = field1 ?? 0;
                          if (currentValue <= 0) {
                            countModel.setNotCounted(widget._item);
                            _controller.text = '-';
                          } else {
                            final int newValue = currentValue - 1;
                            countModel.setField1(widget._item, newValue);
                            _controller.text = newValue.toString();
                          }
                        },
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(40, 40),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 50),
                  child: IntrinsicWidth(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onTap: () {
                        _controller.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _controller.text.length,
                        );
                      },
                      onChanged: (value) {
                        final int? intValue = int.tryParse(value);
                        countModel.setField1(widget._item, intValue);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed:
                      (!isNotCounted &&
                          field1 != null &&
                          field1 >= widget._from)
                      ? null
                      : () {
                          final currentValue = field1;
                          if (currentValue == null) {
                            countModel.setField1(widget._item, 0);
                            _controller.text = '0';
                          } else {
                            final int newValue = currentValue + 1;
                            countModel.setField1(widget._item, newValue);
                            _controller.text = newValue.toString();
                          }
                        },
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(40, 40),
                  ),
                ),
                Text(
                  ' =  $count',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _NegativeEntryField extends StatefulWidget {
  const _NegativeEntryField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required CountModel countModel,
    required Item item,
    required void Function(String) onSubmitted,
    required int from,
  }) : _from = from,
       _onSubmitted = onSubmitted,
       _item = item,
       _countModel = countModel,
       _focusNode = focusNode,
       _controller = controller;

  final TextEditingController _controller;
  final FocusNode _focusNode;
  final CountModel _countModel;
  final Item _item;
  final void Function(String) _onSubmitted;
  final int _from;

  @override
  State<_NegativeEntryField> createState() => _NegativeEntryFieldState();
}

class _NegativeEntryFieldState extends State<_NegativeEntryField> {
  bool _usePositiveInput = false;

  void _toggleInputMode() {
    final bool nextUsePositiveInput = !_usePositiveInput;
    setState(() {
      _usePositiveInput = nextUsePositiveInput;
    });

    FocusScope.of(context).requestFocus(widget._focusNode);

    final int? intValue = int.tryParse(widget._controller.text);
    if (intValue == null) {
      widget._controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget._controller.text.length,
      );
      return;
    }

    // Negative mode value is the deducted amount (field1).
    // Positive mode value is the resulting count (from - field1).
    final int convertedValue = widget._from - intValue;
    widget._controller.text = convertedValue.toString();
    widget._controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget._controller.text.length,
    );

    final int storedValue = nextUsePositiveInput
        ? widget._from - convertedValue
        : convertedValue;
    widget._countModel.setField1(widget._item, storedValue);

    widget._controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget._controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: _toggleInputMode,
          icon: Icon(_usePositiveInput ? Icons.add : Icons.remove, size: 26),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          splashRadius: 16,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: TextField(
            controller: widget._controller,
            focusNode: widget._focusNode,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _usePositiveInput
                  ? 'Count'
                  : 'Count (negative from ${widget._from})',
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              final int? intValue = int.tryParse(value);
              final int? storedValue = _usePositiveInput && intValue != null
                  ? widget._from - intValue
                  : intValue;
              widget._countModel.setField1(widget._item, storedValue);
            },
            onSubmitted: widget._onSubmitted,
          ),
        ),
      ],
    );
  }
}

@HiveType(typeId: 14)
class StacksCountStrategy extends CountStrategy {
  StacksCountStrategy(this.perStack);

  StacksCountStrategy.fromJson(Json json)
    : perStack = json['perStack'] as int? ?? 1;
  @HiveField(0)
  int perStack;

  @override
  Json toJson() => {'type': 'StacksCountStrategy', 'perStack': perStack};

  @override
  int? calculateCount(int? field1, int? field2) {
    if (field1 == null) return null;
    return field1 * perStack;
  }

  @override
  bool isEmpty(int? field1, int? field2) => field1 == null;

  @override
  String? getLastDisplay(int? field1, int? field2) {
    if (field1 == null) return null;
    return '${calculateCount(field1, field2)} (${field1}stk)';
  }

  @override
  String get strategyText => 'Stacks ($perStack per stack)';

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
            areaModel.editItem(selectedOrder, newStrategy: this);
          } else {
            final int? intValue = int.tryParse(value);
            perStack = intValue ?? 1;
            areaModel.editItem(selectedOrder, newStrategy: this);
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
        final int? intValue = int.tryParse(value);
        countModel.setField1(item, intValue);
      },
      onSubmitted: onSubmitted,
    );
  }

  @override
  Widget buildBumpDisplay(BuildContext context, Item item) {
    return _StacksBumpDisplay(item: item, perStack: perStack);
  }
}

class _StacksBumpDisplay extends StatefulWidget {
  const _StacksBumpDisplay({required Item item, required int perStack})
    : _perStack = perStack,
      _item = item;

  final Item _item;
  final int _perStack;

  @override
  State<_StacksBumpDisplay> createState() => _StacksBumpDisplayState();
}

class _StacksBumpDisplayState extends State<_StacksBumpDisplay> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CountModel>(
      builder: (context, countModel, child) {
        final ItemCountType? itemCountType = countModel.getCount(widget._item);
        final isNotCounted = itemCountType is ItemNotCounted;
        final ItemCount? itemCount = itemCountType is ItemCount
            ? itemCountType
            : null;
        final Object? count = isNotCounted ? '-' : itemCount?.count;
        final int? stacks = itemCount?.field1;
        final String expectedText = isNotCounted
            ? '-'
            : (stacks?.toString() ?? '');

        if (_controller.text != expectedText &&
            !_controller.selection.isValid) {
          _controller.text = expectedText;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: isNotCounted
                  ? null
                  : () {
                      final int currentValue = stacks ?? 0;
                      if (currentValue <= 0) {
                        countModel.setNotCounted(widget._item);
                        _controller.text = '-';
                      } else {
                        final int newValue = currentValue - 1;
                        countModel.setField1(widget._item, newValue);
                        _controller.text = newValue.toString();
                      }
                    },
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(40, 40),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 60),
              child: IntrinsicWidth(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                  decoration: InputDecoration(
                    labelText: 'x${widget._perStack}',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onTap: () {
                    _controller.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _controller.text.length,
                    );
                  },
                  onChanged: (value) {
                    final int? intValue = int.tryParse(value);
                    countModel.setField1(widget._item, intValue);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                final currentValue = stacks;
                if (currentValue == null) {
                  countModel.setField1(widget._item, 0);
                  _controller.text = '0';
                } else {
                  final int newValue = currentValue + 1;
                  countModel.setField1(widget._item, newValue);
                  _controller.text = newValue.toString();
                }
              },
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(40, 40),
              ),
            ),
            Text(
              ' =  $count',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        );
      },
    );
  }
}

@HiveType(typeId: 15)
class BoxesAndStacksCountStrategy extends CountStrategy {
  BoxesAndStacksCountStrategy(this.perBox, this.perStack);

  BoxesAndStacksCountStrategy.fromJson(Json json)
    : perBox = json['perBox'] as int? ?? 1,
      perStack = json['perStack'] as int? ?? 1;
  @HiveField(0)
  int perBox;

  @HiveField(1)
  int perStack;

  @override
  Json toJson() => {
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
  String? getLastDisplay(int? field1, int? field2) {
    if (field1 == null && field2 == null) return null;
    final int? total = calculateCount(field1, field2);
    final int boxes = field1 ?? 0;
    final int stacks = field2 ?? 0;
    return '$total (${boxes}bx, ${stacks}stk)';
  }

  @override
  String get strategyText => 'Both ($perBox per box, $perStack per stack)';

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
                  areaModel.editItem(selectedOrder, newStrategy: this);
                } else {
                  final int? intValue = int.tryParse(value);
                  perBox = intValue ?? 1;
                  areaModel.editItem(selectedOrder, newStrategy: this);
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
                  areaModel.editItem(selectedOrder, newStrategy: this);
                } else {
                  final int? intValue = int.tryParse(value);
                  perStack = intValue ?? 1;
                  areaModel.editItem(selectedOrder, newStrategy: this);
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
              final int? intValue = int.tryParse(value);
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
              final int? intValue = int.tryParse(value);
              countModel.setField2(item, intValue);
            },
            onSubmitted: onSubmitted,
          ),
        ),
      ],
    );
  }

  @override
  Widget buildBumpDisplay(BuildContext context, Item item) {
    return _BoxesAndStacksBumpDisplay(
      item: item,
      perBox: perBox,
      perStack: perStack,
    );
  }

  @override
  void setZeroCount(CountModel countModel, Item item) {
    countModel
      ..setField1(item, 0)
      ..setField2(item, 0);
  }
}

class _BoxesAndStacksBumpDisplay extends StatefulWidget {
  const _BoxesAndStacksBumpDisplay({
    required Item item,
    required int perBox,
    required int perStack,
  }) : _perStack = perStack,
       _perBox = perBox,
       _item = item;

  final Item _item;
  final int _perBox;
  final int _perStack;

  @override
  State<_BoxesAndStacksBumpDisplay> createState() =>
      _BoxesAndStacksBumpDisplayState();
}

class _BoxesAndStacksBumpDisplayState
    extends State<_BoxesAndStacksBumpDisplay> {
  late final TextEditingController _boxController;
  late final TextEditingController _stackController;

  @override
  void initState() {
    super.initState();
    _boxController = TextEditingController();
    _stackController = TextEditingController();
  }

  @override
  void dispose() {
    _boxController.dispose();
    _stackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CountModel>(
      builder: (context, countModel, child) {
        final ItemCountType? itemCountType = countModel.getCount(widget._item);
        final isNotCounted = itemCountType is ItemNotCounted;
        final ItemCount? itemCount = itemCountType is ItemCount
            ? itemCountType
            : null;
        final Object? count = isNotCounted ? '-' : itemCount?.count;
        final int? boxes = itemCount?.field1;
        final int? stacks = itemCount?.field2;
        final String expectedBoxText = isNotCounted
            ? '-'
            : (boxes?.toString() ?? '');
        final String expectedStackText = isNotCounted
            ? '-'
            : (stacks?.toString() ?? '');

        if (_boxController.text != expectedBoxText &&
            !_boxController.selection.isValid) {
          _boxController.text = expectedBoxText;
        }
        if (_stackController.text != expectedStackText &&
            !_stackController.selection.isValid) {
          _stackController.text = expectedStackText;
        }

        return Row(
          // mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Boxes row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: isNotCounted
                          ? null
                          : () {
                              final int currentValue = boxes ?? 0;
                              if (currentValue <= 0) {
                                countModel.setField1(widget._item, null);
                                _boxController.text = '';
                              } else {
                                final int newValue = currentValue - 1;
                                countModel.setField1(widget._item, newValue);
                                _boxController.text = newValue.toString();
                              }
                            },
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(40, 40),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 50),
                      child: IntrinsicWidth(
                        child: TextField(
                          controller: _boxController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                          decoration: InputDecoration(
                            labelText: widget._perBox * widget._perStack == 1
                                ? null
                                : 'x${widget._perBox * widget._perStack}',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                          ),
                          onTap: () {
                            _boxController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _boxController.text.length,
                            );
                          },
                          onChanged: (value) {
                            final int? intValue = int.tryParse(value);
                            countModel.setField1(widget._item, intValue);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final currentValue = boxes;
                        if (currentValue == null) {
                          countModel.setField1(widget._item, 1);
                          _boxController.text = '1';
                        } else {
                          final int newValue = currentValue + 1;
                          countModel.setField1(widget._item, newValue);
                          _boxController.text = newValue.toString();
                        }
                      },
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(40, 40),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Stacks row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: isNotCounted
                          ? null
                          : () {
                              final int currentValue = stacks ?? 0;
                              if (currentValue <= 0) {
                                countModel.setField2(widget._item, null);
                                _stackController.text = '';
                              } else {
                                final int newValue = currentValue - 1;
                                countModel.setField2(widget._item, newValue);
                                _stackController.text = newValue.toString();
                              }
                            },
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(40, 40),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 50),
                      child: IntrinsicWidth(
                        child: TextField(
                          controller: _stackController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                          decoration: InputDecoration(
                            labelText: widget._perStack == 1
                                ? null
                                : 'x${widget._perStack}',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                          ),
                          onTap: () {
                            _stackController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _stackController.text.length,
                            );
                          },
                          onChanged: (value) {
                            final int? intValue = int.tryParse(value);
                            countModel.setField2(widget._item, intValue);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final currentValue = stacks;
                        if (currentValue == null) {
                          countModel.setField2(widget._item, 1);
                          _stackController.text = '1';
                        } else {
                          final int newValue = currentValue + 1;
                          countModel.setField2(widget._item, newValue);
                          _stackController.text = newValue.toString();
                        }
                      },
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(40, 40),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 16),
            Text('= $count', style: Theme.of(context).textTheme.headlineSmall),
          ],
        );
      },
    );
  }
}

@HiveType(typeId: 10)
class ItemCount extends ItemCountType {
  ItemCount(this.strategy, {this.field1, this.field2, super.doubleChecked});

  factory ItemCount.fromJson(Json json) {
    try {
      CountStrategy strategy;
      if (json['strategy'] != null && json['strategy'] is Json) {
        try {
          strategy = CountStrategy.fromJson(json['strategy'] as Json);
        } on Exception catch (e) {
          if (kDebugMode) print('Failed to parse strategy from JSON: $e');
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
        doubleChecked: json['doubleChecked'] as bool? ?? false,
      );
    } on Exception catch (e) {
      if (kDebugMode) print('Failed to parse ItemCount from JSON: $e');
      // If anything fails, return a basic ItemCount
      return ItemCount(SingularCountStrategy());
    }
  }
  @HiveField(1)
  int? field1;

  @HiveField(2)
  int? field2;

  @HiveField(3)
  CountStrategy strategy;

  int? get count => strategy.calculateCount(field1, field2);

  String? get lastDisplay => strategy.getLastDisplay(field1, field2);

  bool isCounted() => count != null;
  bool isEmpty() => strategy.isEmpty(field1, field2);

  @override
  Json toJson() => {
    'type': 'ItemCount',
    'field1': field1,
    'field2': field2,
    'strategy': strategy.toJson(),
    ...super.toJson(),
  };
}

@HiveType(typeId: 11)
class ItemNotCounted extends ItemCountType {
  ItemNotCounted({super.doubleChecked});

  ItemNotCounted.fromJson(Json json)
    : super(doubleChecked: json['doubleChecked'] as bool? ?? false);

  @override
  Json toJson() => {'type': 'ItemNotCounted', ...super.toJson()};
}

abstract class ItemCountType {
  ItemCountType({this.doubleChecked = false});

  factory ItemCountType.fromJson(Json json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'ItemCount':
        return ItemCount.fromJson(json);
      case 'ItemNotCounted':
        return ItemNotCounted.fromJson(json);
      default:
        return ItemNotCounted();
    }
  }
  @HiveField(0)
  bool doubleChecked;

  Json toJson() => {'doubleChecked': doubleChecked};
}
