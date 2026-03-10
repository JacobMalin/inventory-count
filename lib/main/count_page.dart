import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/area_model.dart';
import 'models/count_model.dart';
import 'models/data/count_strategy.dart';
import 'models/data/inventory_models.dart';
import 'models/export_model.dart';

abstract class StorageObjectTreeData {
  int get uncountedItems;
}

class ItemTreeData extends StorageObjectTreeData {
  ItemTreeData(this.item);

  final Item item;

  @override
  int get uncountedItems => 0;
}

class ShelfTreeData extends StorageObjectTreeData {
  ShelfTreeData(this.shelf, {this.uncountedItems = 0});

  final Shelf shelf;
  @override
  final int uncountedItems;
}

class AreaTreeData extends StorageObjectTreeData {
  AreaTreeData(this.area, {this.isAreaUsed = false, this.uncountedItems = 0});

  final Area area;

  final bool isAreaUsed;
  @override
  final int uncountedItems;
}

class CountPage extends StatefulWidget {
  const CountPage({super.key});

  @override
  State<CountPage> createState() => _CountPageState();
}

class _CountPageState extends State<CountPage> {
  void Function()? _expandUncountedCallback;
  bool _isFullyExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<CountModel>(
      builder: (context, countModel, child) {
        return Scaffold(
          body: CountList(
            hideCountedItems: countModel.hideCountedItems,
            onExpandCallbackChanged: (callback, {required isExpanded}) {
              setState(() {
                _expandUncountedCallback = callback;
                _isFullyExpanded = isExpanded;
              });
            },
          ),
          bottomNavigationBar: BottomAppBar(
            height: 68,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    countModel.hideCountedItems
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    countModel.hideCountedItems = !countModel.hideCountedItems;
                  },
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                const Text('Back'),
                Expanded(
                  child: Slider(
                    value: countModel.countPhase.index.toDouble(),
                    max: 2,
                    divisions: 2,
                    onChanged: (value) {
                      countModel.setCountPhase(
                        CountPhase.values[value.toInt()],
                      );

                      if (_isFullyExpanded) {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          _expandUncountedCallback?.call();
                        });
                      }
                    },
                  ),
                ),
                const Text('Out'),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(
                    _isFullyExpanded ? Icons.unfold_less : Icons.unfold_more,
                  ),
                  onPressed: _expandUncountedCallback,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CountList extends StatefulWidget {
  const CountList({
    required void Function(void Function()?, {required bool isExpanded})
    onExpandCallbackChanged,
    required bool hideCountedItems,
    super.key,
  }) : _onExpandCallbackChanged = onExpandCallbackChanged,
       _hideCountedItems = hideCountedItems;

  final void Function(void Function()?, {required bool isExpanded})
  _onExpandCallbackChanged;
  final bool _hideCountedItems;

  @override
  State<CountList> createState() => _CountListState();
}

class _CountListState extends State<CountList> {
  static final Set<String> _expandedKeys = {};
  TreeViewController? _treeController;
  final AutoScrollController _scrollController = AutoScrollController();
  bool _isAtBottom = false;
  bool _hasScrollableContent = false;
  bool _wasFullyExpanded = false;

  String _sanitizeTreeKey(String value) {
    return value.replaceAll('.', '_dot_');
  }

  TreeNode _buildTree(
    AreaModel areaModel,
    CountModel countModel,
    ExportModel exportModel,
  ) {
    final TreeNode<StorageObjectTreeData> root = TreeNode.root();
    final CountPhase currentPhase = countModel.countPhase;

    for (var i = 0; i < areaModel.numAreas; i++) {
      final Area area = areaModel.getArea(i);
      final TreeNode<AreaTreeData> areaNode = TreeNode(
        key: 'area_${_sanitizeTreeKey(area.name)}',
        data: AreaTreeData(area),
      );

      var isAreaUsed = false;
      var areaUncountedCount = 0;

      for (var j = 0; j < area.numItemsAndShelves; j++) {
        final StorageObject shelfOrItem = area[j];

        if (shelfOrItem is Shelf) {
          final TreeNode<ShelfTreeData> shelfNode = TreeNode(
            key:
                'shelf_${_sanitizeTreeKey(area.name)}_'
                '${_sanitizeTreeKey(shelfOrItem.name)}',
            data: ShelfTreeData(shelfOrItem),
          );

          var isShelfUsed = false;
          var shelfUncountedCount = 0;

          for (var k = 0; k < shelfOrItem.numItems; k++) {
            final Item item = shelfOrItem[k];
            if ((item.personalCountPhase?.index ?? item.countPhase.index) <=
                currentPhase.index) {
              final ItemCountType? count = countModel.getCount(item);

              // Skip counted items if hideCountedItems is true
              if (widget._hideCountedItems && count != null ||
                  !item.getIsValid(exportModel)) {
                continue;
              }

              final TreeNode<ItemTreeData> itemNode = TreeNode(
                key: 'item_${_sanitizeTreeKey(item.path)}',
                data: ItemTreeData(item),
              );
              shelfNode.add(itemNode);
              isShelfUsed = true;

              // Check if item is uncounted
              if (count == null) {
                shelfUncountedCount++;
              }
            }
          }
          if (isShelfUsed) {
            shelfNode.data = ShelfTreeData(
              shelfOrItem,
              uncountedItems: shelfUncountedCount,
            );
            areaNode.add(shelfNode);
            isAreaUsed = true;
            areaUncountedCount += shelfUncountedCount;
          }
        } else if (shelfOrItem is Item &&
            (shelfOrItem.personalCountPhase?.index ??
                    shelfOrItem.countPhase.index) <=
                currentPhase.index) {
          final ItemCountType? count = countModel.getCount(shelfOrItem);

          // Skip counted items if hideCountedItems is true
          if (widget._hideCountedItems && count != null ||
              !shelfOrItem.getIsValid(exportModel)) {
            continue;
          }

          final TreeNode<ItemTreeData> itemNode = TreeNode(
            key: 'item_${_sanitizeTreeKey(shelfOrItem.path)}',
            data: ItemTreeData(shelfOrItem),
          );
          areaNode.add(itemNode);
          isAreaUsed = true;

          // Check if item is uncounted
          if (count == null) {
            areaUncountedCount++;
          }
        }
      }

      areaNode.data = AreaTreeData(
        area,
        isAreaUsed: isAreaUsed,
        uncountedItems: areaUncountedCount,
      );
      root.add(areaNode);
    }

    return root;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      widget._onExpandCallbackChanged(_toggleUncountedItems, isExpanded: false);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      _onScroll();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final double maxExtent = _scrollController.position.maxScrollExtent;
      final bool isAtBottom =
          _scrollController.position.pixels >= maxExtent - 50;
      final bool hasScrollableContent = maxExtent > 0;

      if (isAtBottom != _isAtBottom ||
          hasScrollableContent != _hasScrollableContent) {
        setState(() {
          _isAtBottom = isAtBottom;
          _hasScrollableContent = hasScrollableContent;
        });
      }
    }
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      // Scroll again in case the extent changed during animation
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  Future<void> _scrollToTop() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  bool _areAllUncountedExpanded() {
    if (_treeController == null) return false;

    bool checkExpanded(ITreeNode<StorageObjectTreeData> node) {
      final StorageObjectTreeData? data = node.data;
      var hasUncounted = false;

      if (data is AreaTreeData && data.uncountedItems > 0) {
        hasUncounted = true;
      } else if (data is ShelfTreeData && data.uncountedItems > 0) {
        hasUncounted = true;
      }

      if (hasUncounted && node is TreeNode) {
        if (!_expandedKeys.contains(node.key)) {
          return false;
        }
        for (final INode child in node.childrenAsList) {
          if (!checkExpanded(child as ITreeNode<StorageObjectTreeData>)) {
            return false;
          }
        }
      }
      return true;
    }

    final tree = _treeController!.tree as ITreeNode<StorageObjectTreeData>;
    for (final INode child in tree.childrenAsList) {
      if (!checkExpanded(child as ITreeNode<StorageObjectTreeData>)) {
        return false;
      }
    }
    return true;
  }

  bool _hasAnyUncountedItems() {
    if (_treeController == null) return false;

    bool hasUncounted(ITreeNode<StorageObjectTreeData> node) {
      final StorageObjectTreeData? data = node.data;
      if (data is AreaTreeData && data.uncountedItems > 0) {
        return true;
      }
      if (data is ShelfTreeData && data.uncountedItems > 0) {
        return true;
      }

      for (final INode child in node.childrenAsList) {
        if (hasUncounted(child as ITreeNode<StorageObjectTreeData>)) {
          return true;
        }
      }

      return false;
    }

    final tree = _treeController!.tree as ITreeNode<StorageObjectTreeData>;
    for (final INode child in tree.childrenAsList) {
      if (hasUncounted(child as ITreeNode<StorageObjectTreeData>)) {
        return true;
      }
    }

    return false;
  }

  bool _areAllItemsExpanded() {
    if (_treeController == null) return false;

    bool checkExpanded(ITreeNode<StorageObjectTreeData> node) {
      if (node is TreeNode) {
        if (!_expandedKeys.contains(node.key)) {
          return false;
        }
        for (final INode child in node.childrenAsList) {
          if (!checkExpanded(child as ITreeNode<StorageObjectTreeData>)) {
            return false;
          }
        }
      }
      return true;
    }

    final tree = _treeController!.tree as ITreeNode<StorageObjectTreeData>;
    for (final INode child in tree.childrenAsList) {
      if (!checkExpanded(child as ITreeNode<StorageObjectTreeData>)) {
        return false;
      }
    }

    return true;
  }

  void _expandAllItems() {
    if (_treeController == null) return;

    void expandAll(ITreeNode<StorageObjectTreeData> node) {
      if (node is TreeNode) {
        _treeController!.expandNode(node);
        setState(() {
          _expandedKeys.add(node.key);
        });
        for (final INode child in node.childrenAsList) {
          expandAll(child as ITreeNode<StorageObjectTreeData>);
        }
      }
    }

    final tree = _treeController!.tree as ITreeNode<StorageObjectTreeData>;
    for (final INode child in tree.childrenAsList) {
      expandAll(child as ITreeNode<StorageObjectTreeData>);
    }

    _updateExpandedState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      _onScroll();
    });
  }

  void _toggleUncountedItems() {
    if (_treeController == null) return;

    if (!_hasAnyUncountedItems()) {
      if (_areAllItemsExpanded()) {
        _collapseUncountedItems();
      } else {
        _expandAllItems();
      }
      return;
    }

    final bool shouldCollapse = _areAllUncountedExpanded();

    if (shouldCollapse) {
      _collapseUncountedItems();
    } else {
      _expandUncountedItems();
    }
  }

  void _collapseUncountedItems() {
    if (_treeController == null) return;

    void collapseAll(ITreeNode<StorageObjectTreeData> node) {
      if (node is TreeNode) {
        _treeController!.collapseNode(node);
        setState(() {
          _expandedKeys.remove(node.key);
        });
        for (final INode child in node.childrenAsList) {
          collapseAll(child as ITreeNode<StorageObjectTreeData>);
        }
      }
    }

    final tree = _treeController!.tree as ITreeNode<StorageObjectTreeData>;
    for (final INode child in tree.childrenAsList) {
      collapseAll(child as ITreeNode<StorageObjectTreeData>);
    }

    _updateExpandedState();

    // Update scroll arrow state after collapse
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      _onScroll();
    });
  }

  void _expandUncountedItems() {
    if (_treeController == null) return;

    void expandIfHasUncounted(ITreeNode<StorageObjectTreeData> node) {
      final StorageObjectTreeData? data = node.data;
      var hasUncounted = false;

      if (data is AreaTreeData && data.uncountedItems > 0) {
        hasUncounted = true;
      } else if (data is ShelfTreeData && data.uncountedItems > 0) {
        hasUncounted = true;
      }

      if (hasUncounted && node is TreeNode) {
        _treeController!.expandNode(node);
        setState(() {
          _expandedKeys.add(node.key);
        });
        for (final INode child in node.childrenAsList) {
          expandIfHasUncounted(child as ITreeNode<StorageObjectTreeData>);
        }
      }
    }

    final tree = _treeController!.tree as ITreeNode<StorageObjectTreeData>;
    for (final INode child in tree.childrenAsList) {
      expandIfHasUncounted(child as ITreeNode<StorageObjectTreeData>);
    }

    _updateExpandedState();

    // Update scroll arrow state after expansion
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      _onScroll();
    });
  }

  void _updateExpandedState() {
    final bool isExpanded = _areAllUncountedExpanded();
    _wasFullyExpanded = isExpanded;
    widget._onExpandCallbackChanged(
      _toggleUncountedItems,
      isExpanded: isExpanded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return Consumer2<CountModel, ExportModel>(
          builder: (context, countModel, exportModel, child) {
            final TreeNode<dynamic> tree = _buildTree(
              areaModel,
              countModel,
              exportModel,
            );

            // Check if tree is empty (no items to count)
            final bool treeIsEmpty =
                tree.childrenAsList.isEmpty ||
                tree.childrenAsList.every(
                  (areaNode) => areaNode.childrenAsList.isEmpty,
                );

            if (treeIsEmpty) {
              _treeController = null;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                widget._onExpandCallbackChanged(null, isExpanded: false);
              });

              // Check if there are any items at all for the current phase
              final bool hasAnyItems = areaModel.hasAnyItems();

              final String message;
              final String title;
              final IconData icon;
              var showNextPhaseButton = false;

              if (!hasAnyItems) {
                title = 'No items to count';
                message = 'Add items in Setup to begin counting!';
                icon = Icons.inventory_2_outlined;
              } else {
                switch (countModel.countPhase) {
                  case CountPhase.back:
                    title = 'Back count complete';
                    message = 'All items counted in the back!';
                    icon = Icons.task_alt_rounded;
                    showNextPhaseButton = true;
                  case CountPhase.cabinet:
                    title = 'Cabinet count complete';
                    message = 'All items in cabinets counted!';
                    icon = Icons.task_alt_rounded;
                    showNextPhaseButton = true;
                  case CountPhase.out:
                    title = 'Count complete';
                    message = 'All items counted!';
                    icon = Icons.emoji_events_outlined;
                }
              }

              return SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                ),
                                child: Icon(
                                  icon,
                                  size: 32,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                message,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              if (showNextPhaseButton) ...[
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    iconAlignment: IconAlignment.end,
                                    onPressed: () {
                                      final bool shouldReexpandInNextPhase =
                                          _wasFullyExpanded;

                                      countModel.setCountPhase(
                                        CountPhase.values[countModel
                                                .countPhase
                                                .index +
                                            1],
                                      );

                                      if (shouldReexpandInNextPhase) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) async {
                                              await Future.delayed(
                                                const Duration(
                                                  milliseconds: 300,
                                                ),
                                              );
                                              if (!mounted) return;
                                              _expandUncountedItems();
                                            });
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.arrow_forward_rounded,
                                    ),
                                    label: const Text('Go to next phase'),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: const EdgeInsets.only(
                                        left: 30,
                                        right: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            // Update callback whenever tree rebuilds
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateExpandedState();
            });

            // Update scroll arrow after tree rebuilds
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await Future.delayed(const Duration(milliseconds: 300));
              _onScroll();
            });

            // Build flat list of all items for navigation
            final List<Item> allItems = [];
            void collectItems(ITreeNode<StorageObjectTreeData> node) {
              if (node.data is ItemTreeData) {
                allItems.add((node.data! as ItemTreeData).item);
              }
              for (final INode child in node.childrenAsList) {
                collectItems(child as ITreeNode<StorageObjectTreeData>);
              }
            }

            for (final INode child in tree.childrenAsList) {
              collectItems(child as ITreeNode<StorageObjectTreeData>);
            }

            return Stack(
              children: [
                TreeView.simple(
                  key: ValueKey(
                    '${countModel.countPhase.index}_'
                    '${widget._hideCountedItems}',
                  ),
                  tree: tree,
                  showRootNode: false,
                  scrollController: _scrollController,
                  expansionIndicatorBuilder: (context, node) =>
                      ChevronIndicator.rightDown(
                        tree: node,
                        alignment: Alignment.centerLeft,
                        color: Colors.grey,
                      ),
                  indentation: const Indentation(style: IndentStyle.roundJoint),
                  onTreeReady: (controller) {
                    _treeController = controller;
                    // Restore expansion state by traversing tree
                    void restoreExpansion(
                      ITreeNode<StorageObjectTreeData> node,
                    ) {
                      if (_expandedKeys.contains(node.key) &&
                          node is TreeNode) {
                        controller.expandNode(
                          node as TreeNode<StorageObjectTreeData>,
                        );
                        for (final INode child in node.childrenAsList) {
                          restoreExpansion(
                            child as ITreeNode<StorageObjectTreeData>,
                          );
                        }
                      } else {
                        // Remove all children keys, recursively
                        void removeDescendants(
                          ITreeNode<StorageObjectTreeData> node,
                        ) {
                          for (final INode child in node.childrenAsList) {
                            _expandedKeys.remove(child.key);
                            removeDescendants(
                              child as ITreeNode<StorageObjectTreeData>,
                            );
                          }
                        }

                        removeDescendants(node);
                      }
                    }

                    for (final INode child in tree.childrenAsList) {
                      restoreExpansion(
                        child as ITreeNode<StorageObjectTreeData>,
                      );
                    }
                  },
                  onItemTap: (item) {
                    // Track expansion state changes (state is BEFORE the tap)
                    // If currently expanded before tap, it will be collapsed
                    // If currently collapsed before tap, it will be expanded
                    setState(() {
                      if (_expandedKeys.contains(item.key)) {
                        _expandedKeys.remove(item.key);
                      } else {
                        _expandedKeys.add(item.key);
                      }
                    });

                    // Update expansion state
                    _updateExpandedState();

                    // Update scroll arrow state after expansion/collapse
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      await Future.delayed(const Duration(milliseconds: 300));
                      _onScroll();
                    });
                  },
                  builder: (context, node) {
                    final StorageObjectTreeData data = node.data;

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
                              _ => Colors.red.withValues(alpha: 0.2),
                            },
                            child: InkWell(
                              onTap: () async {
                                await showDialog(
                                  context: context,
                                  builder: (context) => CountDialog(
                                    initialItem: data.item,
                                    allItems: allItems,
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
                      final String name;
                      final Color? color;
                      final int? uncountedCount;

                      if (data is AreaTreeData) {
                        name = data.area.name;
                        color = data.isAreaUsed ? data.area.color : Colors.grey;
                        uncountedCount = data.uncountedItems > 0
                            ? data.uncountedItems
                            : null;
                      } else if (data is ShelfTreeData) {
                        name = data.shelf.name;
                        color = null;
                        uncountedCount = data.uncountedItems > 0
                            ? data.uncountedItems
                            : null;
                      } else {
                        name = '';
                        color = null;
                        uncountedCount = null;
                      }

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(
                          left: 28,
                          top: 4,
                          bottom: 4,
                        ),
                        child: Row(
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (uncountedCount != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$uncountedCount',
                                  style: TextStyle(
                                    color: Colors.red.withValues(alpha: 1),
                                    fontSize: 11,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }
                  },
                ),
                if (_hasScrollableContent)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.small(
                      onPressed: _isAtBottom ? _scrollToTop : _scrollToBottom,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                      elevation: 2,
                      child: AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: _isAtBottom ? -0.5 : 0,
                        child: const Icon(Icons.arrow_downward),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class CountDialog extends StatefulWidget {
  const CountDialog({
    required Item initialItem,
    required List<Item> allItems,
    super.key,
  }) : _allItems = allItems,
       _initialItem = initialItem;

  final Item _initialItem;
  final List<Item> _allItems;

  @override
  State<CountDialog> createState() => _CountDialogState();
}

class _CountDialogState extends State<CountDialog> {
  late Item _currentItem;
  late TextEditingController _controller;
  late TextEditingController _secondaryController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _currentItem = widget._initialItem;
    _focusNode = FocusNode();
    _initializeControllers(selectAll: true);
  }

  void _initializeControllers({bool selectAll = false}) {
    final CountModel countModel = Provider.of<CountModel>(
      context,
      listen: false,
    );
    final ItemCountType? count = countModel.getCount(_currentItem);

    final String primaryText = switch (count) {
      ItemCount() => count.field1?.toString() ?? '',
      ItemNotCounted() => '-',
      _ => '',
    };

    _controller = TextEditingController(text: primaryText);

    if (selectAll && primaryText.isNotEmpty) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: primaryText.length,
      );
    }

    _secondaryController = TextEditingController(
      text: switch (count) {
        ItemCount() => count.field2?.toString() ?? '',
        ItemNotCounted() => '-',
        _ => '',
      },
    );
  }

  void _navigate(int direction) {
    final int currentIndex = widget._allItems.indexWhere(
      (item) => item.path == _currentItem.path,
    );
    final int newIndex = currentIndex + direction;

    if (newIndex >= 0 && newIndex < widget._allItems.length) {
      final TextEditingController oldController = _controller;
      final TextEditingController oldSecondaryController = _secondaryController;

      setState(() {
        _currentItem = widget._allItems[newIndex];
        _initializeControllers(selectAll: true);
      });

      // Wait for the rebuilt input widget to mount before requesting focus.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldController.dispose();
        oldSecondaryController.dispose();

        if (!mounted) return;
        FocusScope.of(context).requestFocus(_focusNode);
      });
    }
  }

  void _navigateNextOrClose(bool hasNext) {
    if (hasNext) {
      _navigate(1);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _secondaryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int currentIndex = widget._allItems.indexWhere(
      (item) => item.path == _currentItem.path,
    );
    final bool hasNext = currentIndex < widget._allItems.length - 1;
    final bool hasPrevious = currentIndex > 0;

    return Consumer<CountModel>(
      builder: (context, countModel, child) {
        final ItemCountType? count = countModel.getCount(_currentItem);
        final String displayCount = switch (count) {
          ItemCount() => count.count.toString(),
          ItemNotCounted() => 'Not Counted',
          _ => 'Not Set',
        };

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AlertDialog(
                contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                insetPadding: EdgeInsets.zero,
                title: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context).style.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                          children: _currentItem.parent.richPath,
                        ),
                      ),
                      Text(_currentItem.name, overflow: TextOverflow.ellipsis),
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
                      _currentItem.strategy.buildCountFields(
                        controller1: _controller,
                        controller2: _secondaryController,
                        focusNode: _focusNode,
                        countModel: countModel,
                        item: _currentItem,
                        onSubmitted: (value) => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Builder(
                            builder: (context) {
                              final ItemCountType? lastCount = countModel
                                  .getLastCount(_currentItem);

                              return TextButton(
                                onPressed: lastCount != null
                                    ? () {
                                        countModel.setLastCount(_currentItem);
                                        _navigateNextOrClose(hasNext);
                                      }
                                    : null,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(80, 56),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(switch (lastCount) {
                                  ItemCount() =>
                                    'Last: ${lastCount.lastDisplay}',
                                  ItemNotCounted() => 'Last: -',
                                  _ => 'Last',
                                }),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          Builder(
                            builder: (context) {
                              final ItemCount? defaultCount =
                                  _currentItem.defaultCount;

                              return TextButton(
                                onPressed:
                                    defaultCount != null ||
                                        _currentItem.strategy
                                            is NegativeCountStrategy
                                    ? () {
                                        countModel.setDefaultCount(
                                          _currentItem,
                                        );
                                        _navigateNextOrClose(hasNext);
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
                                  'Default'
                                  '${_currentItem.defaultButtonText}',
                                ),
                              );
                            },
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
                              if (_currentItem.strategy
                                  is NegativeCountStrategy) {
                                countModel.setField1(
                                  _currentItem,
                                  (_currentItem.strategy
                                          as NegativeCountStrategy)
                                      .from,
                                );
                              } else {
                                countModel.setField1(_currentItem, 0);
                              }
                              _navigateNextOrClose(hasNext);
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
                              countModel.setNotCounted(_currentItem);
                              _navigateNextOrClose(hasNext);
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
                            onPressed: () => _navigateNextOrClose(hasNext),
                            icon: hasNext
                                ? const Icon(Icons.chevron_right)
                                : const Icon(Icons.last_page),
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
        );
      },
    );
  }
}
