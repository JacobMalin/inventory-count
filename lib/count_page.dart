import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:provider/provider.dart';

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

class CountList extends StatelessWidget {
  const CountList({super.key});

  TreeNode _buildTree(AreaModel areaModel) {
    final root = TreeNode.root();

    for (int i = 0; i < areaModel.numAreas; i++) {
      final area = areaModel.getArea(i);
      final areaNode = TreeNode(key: 'area_$i', data: area);

      for (int j = 0; j < area.shelvesAndItems.length; j++) {
        final shelfOrItem = area.shelvesAndItems[j];

        if (shelfOrItem is Shelf) {
          final shelfNode = TreeNode(key: 'shelf_${i}_$j', data: shelfOrItem);

          for (int k = 0; k < shelfOrItem.items.length; k++) {
            final item = shelfOrItem.items[k] as Item;
            final itemNode = TreeNode(key: 'item_${i}_${j}_$k', data: item);
            shelfNode.add(itemNode);
          }

          areaNode.add(shelfNode);
        } else if (shelfOrItem is Item) {
          final itemNode = TreeNode(key: 'item_${i}_$j', data: shelfOrItem);
          areaNode.add(itemNode);
        }
      }

      root.add(areaNode);
    }

    return root;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        final tree = _buildTree(areaModel);

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
          onTreeReady: (controller) => controller.expandAllChildren(tree),
          builder: (context, node) {
            final data = node.data;

            if (data is Item) {
              return Card(
                child: Consumer<CountModel>(
                  builder: (context, countModel, child) {
                    return InkWell(
                      onTap: () {
                        final controller = TextEditingController(
                          text: countModel.getCount(data)?.toString() ?? '',
                        );
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(data.name),
                            content: TextField(
                              controller: controller,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Count',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (value) {
                                final intValue = int.tryParse(value);
                                countModel.setCount(data, intValue ?? 0);
                                Navigator.pop(context);
                              },
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  final intValue = int.tryParse(
                                    controller.text,
                                  );
                                  countModel.setCount(data, intValue ?? 0);
                                  Navigator.pop(context);
                                },
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: ListTile(title: Text(data.name)),
                    );
                  },
                ),
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
                  data.name,
                  style: TextStyle(
                    color: data is Area ? data.color : null,
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
  }
}
