import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:inventory_count/models/count_strategy.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:provider/provider.dart';

class ItemTreeData {
  final Item item;

  final Area? area;
  final Shelf? shelf;

  ItemTreeData(this.item, {this.area, this.shelf});
}

class AreaTreeData {
  final Area area;

  final bool isAreaUsed;

  AreaTreeData(this.area, {this.isAreaUsed = false});
}

class CountPage extends StatefulWidget {
  const CountPage({super.key});

  @override
  State<CountPage> createState() => _CountPageState();
}

class _CountPageState extends State<CountPage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<CountModel>(
      builder: (context, countModel, child) {
        return Scaffold(
          body: CountList(),
          bottomNavigationBar: BottomAppBar(
            height: 124,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Back'),
                      Expanded(
                        child: Slider(
                          value: countModel.countPhase.index.toDouble(),
                          min: 0,
                          max: 2,
                          divisions: 2,
                          onChanged: (value) {
                            countModel.setCountPhase(
                              CountPhase.values[value.toInt()],
                            );
                          },
                        ),
                      ),
                      const Text('Out'),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: countModel.decrementDate,
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              countModel.date,
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            if (!countModel.isToday)
                              TextButton.icon(
                                onPressed: countModel.goToToday,
                                icon: const Icon(Icons.today, size: 16),
                                label: const Text('Today'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color.fromARGB(
                                    255,
                                    221,
                                    206,
                                    39,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: countModel.incrementDate,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CountList extends StatefulWidget {
  const CountList({super.key});

  @override
  State<CountList> createState() => _CountListState();
}

class _CountListState extends State<CountList> {
  TreeNode _buildTree(AreaModel areaModel, CountPhase currentPhase) {
    final root = TreeNode.root();

    for (int i = 0; i < areaModel.numAreas; i++) {
      final area = areaModel.getArea(i);
      final areaNode = TreeNode(key: 'area_$i', data: AreaTreeData(area));

      var isAreaUsed = false;
      for (int j = 0; j < area.shelvesAndItems.length; j++) {
        final shelfOrItem = area.shelvesAndItems[j];

        if (shelfOrItem is Shelf) {
          final shelfNode = TreeNode(key: 'shelf_${i}_$j', data: shelfOrItem);

          var isShelfUsed = false;
          for (int k = 0; k < shelfOrItem.items.length; k++) {
            final item = shelfOrItem.items[k] as Item;
            if ((item.personalCountPhase?.index ?? item.countPhase.index) <=
                currentPhase.index) {
              final data = ItemTreeData(item, shelf: shelfOrItem, area: area);
              final itemNode = TreeNode(key: 'item_${i}_${j}_$k', data: data);
              shelfNode.add(itemNode);
              isShelfUsed = true;
            }
          }
          if (isShelfUsed) {
            areaNode.add(shelfNode);
            isAreaUsed = true;
          }
        } else if (shelfOrItem is Item &&
            (shelfOrItem.personalCountPhase?.index ??
                    shelfOrItem.countPhase.index) <=
                currentPhase.index) {
          final data = ItemTreeData(shelfOrItem, area: area);
          final itemNode = TreeNode(key: 'item_${i}_$j', data: data);
          areaNode.add(itemNode);
          isAreaUsed = true;
        }
      }

      areaNode.data = AreaTreeData(area, isAreaUsed: isAreaUsed);
      root.add(areaNode);
    }

    return root;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return Consumer<CountModel>(
          builder: (context, countModel, child) {
            final tree = _buildTree(areaModel, countModel.countPhase);

            // Check if tree is empty (no items to count)
            if (tree.childrenAsList.isEmpty ||
                tree.childrenAsList.every(
                  (areaNode) => areaNode.childrenAsList.isEmpty,
                )) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Add items in Setup to begin counting!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              );
            }

            return TreeView.simple(
              key: ValueKey('tree_${countModel.countPhase.index}'),
              tree: tree,
              showRootNode: false,
              expansionIndicatorBuilder: (context, node) =>
                  ChevronIndicator.rightDown(
                    tree: node,
                    alignment: Alignment.centerLeft,
                    color: Colors.grey,
                  ),
              indentation: const Indentation(style: IndentStyle.roundJoint),
              onTreeReady: (controller) {
                controller.expandAllChildren(tree);
              },
              builder: (context, node) {
                final data = node.data;

                if (data is ItemTreeData) {
                  return Consumer<CountModel>(
                    builder: (context, countModel, child) {
                      final ItemCountType? count = countModel.getCount(
                        data.item,
                      );

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        color: switch (count) {
                          ItemCount() => null,
                          ItemNotCounted() => Colors.yellow.withValues(
                            alpha: 0.1,
                          ),
                          _ => Colors.red.withValues(alpha: 0.1),
                        },
                        child: InkWell(
                          onTap: () {
                            final controller = TextEditingController(
                              text: switch (count) {
                                ItemCount() => count.field1.toString(),
                                ItemNotCounted() => '-',
                                _ => '',
                              },
                            );

                            final secondaryController = TextEditingController(
                              text: switch (count) {
                                ItemCount() => count.field2.toString(),
                                ItemNotCounted() => '-',
                                _ => '',
                              },
                            );

                            showDialog(
                              context: context,
                              builder: (context) => CountDialog(
                                data: data,
                                controller: controller,
                                secondaryController: secondaryController,
                              ),
                            );
                          },
                          child: ListTile(
                            title: Text(data.item.name),
                            trailing: Text(
                              switch (count) {
                                ItemCount() => count.count.toString(),
                                ItemNotCounted() => '-',
                                _ => '',
                              },
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(
                      left: 28.0,
                      top: 4.0,
                      bottom: 4.0,
                    ),
                    child: Text(
                      data is AreaTreeData ? data.area.name : data.name,
                      style: TextStyle(
                        color: data is AreaTreeData
                            ? (data.isAreaUsed ? data.area.color : Colors.grey)
                            : null,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

class CountDialog extends StatelessWidget {
  const CountDialog({
    super.key,
    required this.data,
    required this.controller,
    required this.secondaryController,
  });

  final ItemTreeData data;
  final TextEditingController controller;
  final TextEditingController secondaryController;

  @override
  Widget build(BuildContext context) {
    return Consumer<CountModel>(
      builder: (context, CountModel countModel, child) {
        return AlertDialog(
          title: Stack(
            children: [
              AlertDialog(
                contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                insetPadding: EdgeInsets.zero,
                title: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (currentData.area != null || currentData.shelf != null)
                        RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                            ),
                            children: [
                              if (currentData.area != null)
                                TextSpan(
                                  text: currentData.area!.name,
                                  style: TextStyle(
                                    color: currentData.area!.color,
                                  ),
                                ),
                              if (currentData.area != null &&
                                  currentData.shelf != null)
                                const TextSpan(text: ' > '),
                              if (currentData.shelf != null)
                                TextSpan(text: currentData.shelf!.name),
                            ],
                          ),
                        ),
                      Text(
                        currentData.item.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                content: SizedBox(
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Count:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              displayCount,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      currentData.item.strategy.buildCountFields(
                        controller1: controller,
                        controller2: secondaryController,
                        focusNode: focusNode,
                        countModel: countModel,
                        item: currentData.item,
                        onSubmitted: (value) => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (data.area != null || data.shelf != null)
                      RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context).style.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed:
                                currentData.item.defaultCount != null ||
                                    currentData.item.strategy
                                        is NegativeCountStrategy
                                ? () {
                                    countModel.setDefaultCount(
                                      currentData.item,
                                    );
                                    if (hasNext) {
                                      _navigate(1);
                                    } else {
                                      Navigator.pop(context);
                                    }
                                  }
                                : null,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(100, 56),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              currentData.item.strategy is NegativeCountStrategy
                                  ? 'Default: 0'
                                  : currentData.item.defaultCount != null
                                  ? 'Default: ${currentData.item.defaultCount!.count}'
                                  : 'Default',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: hasPrevious ? () => _navigate(-1) : null,
                            icon: const Icon(Icons.chevron_left),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(56, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () {
                              if (currentData.item.strategy
                                  is NegativeCountStrategy) {
                                countModel.setField1(
                                  currentData.item,
                                  (currentData.item.strategy
                                          as NegativeCountStrategy)
                                      .from,
                                );
                              } else {
                                countModel.setField1(currentData.item, 0);
                              }
                              if (hasNext) {
                                _navigate(1);
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            style: TextButton.styleFrom(
                              minimumSize: const Size(56, 56),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('0'),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () {
                              countModel.setNotCounted(currentData.item);
                              if (hasNext) {
                                _navigate(1);
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            style: TextButton.styleFrom(
                              minimumSize: const Size(56, 56),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('-'),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: hasNext ? () => _navigate(1) : null,
                            icon: const Icon(Icons.chevron_right),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(56, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: data.item.strategy == CountStrategy.negative
                    ? TextInputType.numberWithOptions(signed: true)
                    : TextInputType.number,
                decoration: InputDecoration(
                  labelText: switch (data.item.strategy) {
                    CountStrategy.stacks =>
                      'Stacks${data.item.strategyInt != null ? ' (${data.item.strategyInt} per stack)' : ''}',
                    CountStrategy.boxesAndStacks =>
                      'Boxes${data.item.strategyInt != null ? ' (${data.item.strategyInt} stacks per box)' : ''}',
                    CountStrategy.negative =>
                      'Count (negative from ${data.item.strategyInt})',
                    _ => 'Count',
                  },
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final intValue = int.tryParse(value);
                  countModel.setField1(data.item, intValue);
                },
                onSubmitted: (value) => Navigator.pop(context),
              ),
              if (data.item.strategy == CountStrategy.boxesAndStacks)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: TextField(
                    controller: secondaryController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText:
                          'Stacks${data.item.strategyInt2 != null ? ' (${data.item.strategyInt2} per stack)' : ''}',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final intValue = int.tryParse(value);
                      countModel.setField2(data.item, intValue);
                    },
                    onSubmitted: (value) => Navigator.pop(context),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final intValue = int.tryParse(controller.text);
                final secondaryIntValue = int.tryParse(
                  secondaryController.text,
                );
                countModel.setField1(data.item, intValue);
                countModel.setField2(data.item, secondaryIntValue);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
