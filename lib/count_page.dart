import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/count_model.dart';
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
                        icon: const Icon(Icons.arrow_back_ios),
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
                        icon: const Icon(Icons.arrow_forward_ios),
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
  TreeViewController? _controller;

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

            return TreeView.simple(
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
                _controller = controller;
                controller.expandAllChildren(tree);
              },
              builder: (context, node) {
                final data = node.data;

                if (data is ItemTreeData) {
                  return Consumer<CountModel>(
                    builder: (context, countModel, child) {
                      final count = countModel.getCount(data.item);
                      return Card(
                        color: count == null
                            ? Colors.red.withValues(alpha: 0.1)
                            : null,
                        child: InkWell(
                          onTap: () {
                            final controller = TextEditingController(
                              text: count?.toString() ?? '',
                            );

                            showDialog(
                              context: context,
                              builder: (context) => CountDialog(
                                data: data,
                                controller: controller,
                              ),
                            );
                          },
                          child: ListTile(
                            title: Text(data.item.name),
                            trailing: Text(
                              count?.toString() ?? '-',
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
  const CountDialog({super.key, required this.data, required this.controller});

  final ItemTreeData data;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Consumer<CountModel>(
      builder: (context, countModel, child) {
        return AlertDialog(
          title: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
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
                          children: [
                            if (data.area != null)
                              TextSpan(
                                text: data.area!.name,
                                style: TextStyle(color: data.area!.color),
                              ),
                            if (data.area != null && data.shelf != null)
                              const TextSpan(text: ' > '),
                            if (data.shelf != null)
                              TextSpan(text: data.shelf!.name),
                          ],
                        ),
                      ),
                    Text(data.item.name),
                  ],
                ),
              ),
            ],
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Count',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              final intValue = int.tryParse(value);
              countModel.setCount(data.item, intValue ?? 0);
            },
            onSubmitted: (value) => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final intValue = int.tryParse(controller.text);
                countModel.setCount(data.item, intValue ?? 0);
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
