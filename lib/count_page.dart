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
  final int uncountedItems;

  AreaTreeData(this.area, {this.isAreaUsed = false, this.uncountedItems = 0});
}

class ShelfTreeData {
  final Shelf shelf;
  final int uncountedItems;

  ShelfTreeData(this.shelf, {this.uncountedItems = 0});
}

class CountPage extends StatefulWidget {
  const CountPage({super.key});

  @override
  State<CountPage> createState() => _CountPageState();
}

class _CountPageState extends State<CountPage> {
  void Function()? _expandUncountedCallback;
  bool _hideCountedItems = false;
  bool _isFullyExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<CountModel>(
      builder: (context, countModel, child) {
        return Scaffold(
          body: CountList(
            hideCountedItems: _hideCountedItems,
            onExpandCallbackChanged: (callback, isExpanded) {
              setState(() {
                _expandUncountedCallback = callback;
                _isFullyExpanded = isExpanded;
              });
            },
          ),
          bottomNavigationBar: BottomAppBar(
            height: 124,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _hideCountedItems
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _hideCountedItems = !_hideCountedItems;
                        });
                      },
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 16),
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
                    const SizedBox(width: 16),
                    IconButton(
                      icon: Icon(
                        _isFullyExpanded
                            ? Icons.unfold_less
                            : Icons.unfold_more,
                      ),
                      onPressed: _expandUncountedCallback,
                      constraints: const BoxConstraints(),
                    ),
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
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
        );
      },
    );
  }
}

class CountList extends StatefulWidget {
  const CountList({
    super.key,
    required this.onExpandCallbackChanged,
    required this.hideCountedItems,
  });

  final void Function(void Function()?, bool) onExpandCallbackChanged;
  final bool hideCountedItems;

  @override
  State<CountList> createState() => _CountListState();
}

class _CountListState extends State<CountList> {
  static final Set<String> _expandedKeys = {};
  TreeViewController? _treeController;
  final AutoScrollController _scrollController = AutoScrollController();
  bool _isAtBottom = false;
  bool _hasScrollableContent = false;

  TreeNode _buildTree(AreaModel areaModel, CountPhase currentPhase) {
    final root = TreeNode.root();
    final countModel = Provider.of<CountModel>(context, listen: false);

    for (int i = 0; i < areaModel.numAreas; i++) {
      final area = areaModel.getArea(i);
      final areaNode = TreeNode(
        key: 'area_${area.name}',
        data: AreaTreeData(area),
      );

      var isAreaUsed = false;
      var areaUncountedCount = 0;

      for (int j = 0; j < area.shelvesAndItems.length; j++) {
        final shelfOrItem = area.shelvesAndItems[j];

        if (shelfOrItem is Shelf) {
          final shelfNode = TreeNode(
            key: 'shelf_${area.name}_${shelfOrItem.name}',
            data: ShelfTreeData(shelfOrItem),
          );

          var isShelfUsed = false;
          var shelfUncountedCount = 0;

          for (int k = 0; k < shelfOrItem.items.length; k++) {
            final item = shelfOrItem.items[k] as Item;
            if ((item.personalCountPhase?.index ?? item.countPhase.index) <=
                currentPhase.index) {
              final count = countModel.getCount(item);

              // Skip counted items if hideCountedItems is true
              if (widget.hideCountedItems && count != null) {
                continue;
              }

              final data = ItemTreeData(item, shelf: shelfOrItem, area: area);
              final itemNode = TreeNode(key: 'item_${item.id}', data: data);
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
          final count = countModel.getCount(shelfOrItem);

          // Skip counted items if hideCountedItems is true
          if (!widget.hideCountedItems || count == null) {
            final data = ItemTreeData(shelfOrItem, area: area);
            final itemNode = TreeNode(
              key: 'item_${shelfOrItem.id}',
              data: data,
            );
            areaNode.add(itemNode);
            isAreaUsed = true;

            // Check if item is uncounted
            if (count == null) {
              areaUncountedCount++;
            }
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
      widget.onExpandCallbackChanged(_toggleUncountedItems, false);
      await Future.delayed(const Duration(milliseconds: 300));
      _onScroll();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      final isAtBottom = _scrollController.position.pixels >= maxExtent - 50;
      final hasScrollableContent = maxExtent > 0;

      if (isAtBottom != _isAtBottom ||
          hasScrollableContent != _hasScrollableContent) {
        setState(() {
          _isAtBottom = isAtBottom;
          _hasScrollableContent = hasScrollableContent;
        });
      }
    }
  }

  void _scrollToBottom() async {
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

  void _scrollToTop() async {
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

    bool checkExpanded(dynamic node) {
      final data = node.data;
      bool hasUncounted = false;

      if (data is AreaTreeData && data.uncountedItems > 0) {
        hasUncounted = true;
      } else if (data is ShelfTreeData && data.uncountedItems > 0) {
        hasUncounted = true;
      }

      if (hasUncounted && node is TreeNode) {
        if (!_expandedKeys.contains(node.key)) {
          return false;
        }
        for (var child in node.childrenAsList) {
          if (!checkExpanded(child)) {
            return false;
          }
        }
      }
      return true;
    }

    final tree = _treeController!.tree;
    for (var child in tree.childrenAsList) {
      if (!checkExpanded(child)) {
        return false;
      }
    }
    return true;
  }

  void _toggleUncountedItems() {
    if (_treeController == null) return;

    final bool shouldCollapse = _areAllUncountedExpanded();

    if (shouldCollapse) {
      _collapseUncountedItems();
    } else {
      _expandUncountedItems();
    }
  }

  void _collapseUncountedItems() {
    if (_treeController == null) return;

    void collapseIfHasUncounted(dynamic node) {
      final data = node.data;
      bool hasUncounted = false;

      if (data is AreaTreeData && data.uncountedItems > 0) {
        hasUncounted = true;
      } else if (data is ShelfTreeData && data.uncountedItems > 0) {
        hasUncounted = true;
      }

      if (hasUncounted && node is TreeNode) {
        _treeController!.collapseNode(node);
        setState(() {
          _expandedKeys.remove(node.key);
        });
      }
    }

    final tree = _treeController!.tree;
    for (var child in tree.childrenAsList) {
      collapseIfHasUncounted(child);
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

    void expandIfHasUncounted(dynamic node) {
      final data = node.data;
      bool hasUncounted = false;

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
        for (var child in node.childrenAsList) {
          expandIfHasUncounted(child);
        }
      }
    }

    final tree = _treeController!.tree;
    for (var child in tree.childrenAsList) {
      expandIfHasUncounted(child);
    }

    _updateExpandedState();

    // Update scroll arrow state after expansion
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      _onScroll();
    });
  }

  void _updateExpandedState() {
    final isExpanded = _areAllUncountedExpanded();
    widget.onExpandCallbackChanged(_toggleUncountedItems, isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return Consumer<CountModel>(
          builder: (context, countModel, child) {
            final tree = _buildTree(areaModel, countModel.countPhase);

            // Check if tree is empty (no items to count)
            final bool treeIsEmpty =
                tree.childrenAsList.isEmpty ||
                tree.childrenAsList.every(
                  (areaNode) => areaNode.childrenAsList.isEmpty,
                );

            if (treeIsEmpty) {
              // Check if there are any items at all for the current phase
              bool hasAnyItems = false;
              for (int i = 0; i < areaModel.numAreas; i++) {
                final area = areaModel.getArea(i);
                for (var shelfOrItem in area.shelvesAndItems) {
                  if (shelfOrItem is Shelf) {
                    for (var item in shelfOrItem.items) {
                      if (item is Item &&
                          (item.personalCountPhase?.index ??
                                  item.countPhase.index) <=
                              countModel.countPhase.index) {
                        hasAnyItems = true;
                        break;
                      }
                    }
                  } else if (shelfOrItem is Item &&
                      (shelfOrItem.personalCountPhase?.index ??
                              shelfOrItem.countPhase.index) <=
                          countModel.countPhase.index) {
                    hasAnyItems = true;
                    break;
                  }
                  if (hasAnyItems) break;
                }
                if (hasAnyItems) break;
              }

              final message = hasAnyItems
                  ? 'All items counted!'
                  : 'Add items in Setup to begin counting!';

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              );
            }

            // Update callback whenever tree rebuilds
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateExpandedState();
            });

            // Build flat list of all items for navigation
            List<ItemTreeData> allItems = [];
            void collectItems(dynamic node) {
              if (node.data is ItemTreeData) {
                allItems.add(node.data);
              }
              for (var child in node.childrenAsList) {
                collectItems(child);
              }
            }

            for (var child in tree.childrenAsList) {
              collectItems(child);
            }

            return Stack(
              children: [
                TreeView.simple(
                  key: ValueKey(
                    '${countModel.countPhase.index}_${widget.hideCountedItems}',
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
                    void restoreExpansion(dynamic node) {
                      if (_expandedKeys.contains(node.key) &&
                          node is TreeNode) {
                        controller.expandNode(node);
                        for (var child in node.childrenAsList) {
                          restoreExpansion(child);
                        }
                      } else {
                        // Remove all children keys, recursively
                        void removeDescendants(dynamic node) {
                          for (var child in node.childrenAsList) {
                            _expandedKeys.remove(child.key);
                            removeDescendants(child);
                          }
                        }

                        removeDescendants(node);
                      }
                    }

                    for (var child in tree.childrenAsList) {
                      restoreExpansion(child);
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
                              _ => Colors.red.withValues(alpha: 0.2),
                            },
                            child: InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => CountDialog(
                                    initialData: data,
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
                          left: 28.0,
                          top: 4.0,
                          bottom: 4.0,
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
                                    color: Colors.red.withValues(alpha: 1.0),
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
    super.key,
    required this.initialData,
    required this.allItems,
  });

  final ItemTreeData initialData;
  final List<ItemTreeData> allItems;

  @override
  State<CountDialog> createState() => _CountDialogState();
}

class _CountDialogState extends State<CountDialog> {
  late ItemTreeData currentData;
  late TextEditingController controller;
  late TextEditingController secondaryController;
  late FocusNode focusNode;

  @override
  void initState() {
    super.initState();
    currentData = widget.initialData;
    focusNode = FocusNode();
    _initializeControllers(selectAll: false);
  }

  void _initializeControllers({bool selectAll = false}) {
    final countModel = Provider.of<CountModel>(context, listen: false);
    final count = countModel.getCount(currentData.item);

    final primaryText = switch (count) {
      ItemCount() => count.field1?.toString() ?? '',
      ItemNotCounted() => '-',
      _ => '',
    };

    controller = TextEditingController(text: primaryText);

    if (selectAll && primaryText.isNotEmpty) {
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: primaryText.length,
      );
    }

    secondaryController = TextEditingController(
      text: switch (count) {
        ItemCount() => count.field2?.toString() ?? '',
        ItemNotCounted() => '-',
        _ => '',
      },
    );
  }

  void _navigate(int direction) {
    final currentIndex = widget.allItems.indexWhere(
      (item) => item.item.id == currentData.item.id,
    );
    final newIndex = currentIndex + direction;

    if (newIndex >= 0 && newIndex < widget.allItems.length) {
      final oldController = controller;
      final oldSecondaryController = secondaryController;

      setState(() {
        currentData = widget.allItems[newIndex];
        _initializeControllers(selectAll: true);
      });

      // Dispose old controllers after the frame is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldController.dispose();
        oldSecondaryController.dispose();
      });

      focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    secondaryController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.allItems.indexWhere(
      (item) => item.item.id == currentData.item.id,
    );
    final hasNext = currentIndex < widget.allItems.length - 1;
    final hasPrevious = currentIndex > 0;

    return Consumer<CountModel>(
      builder: (context, CountModel countModel, child) {
        final ItemCountType? count = countModel.getCount(currentData.item);
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
              const SizedBox(height: 12),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                                  .getLastCount(currentData.item);

                              return TextButton(
                                onPressed: lastCount != null
                                    ? () {
                                        countModel.setLastCount(
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
                                  ItemCount() => 'Last: ${lastCount.count}',
                                  ItemNotCounted() => 'Last: -',
                                  _ => 'Last',
                                }),
                              );
                            },
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
        );
      },
    );
  }
}
