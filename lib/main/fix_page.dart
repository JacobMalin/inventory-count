import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'count_page.dart';
import 'models/area_model.dart';
import 'models/count_model.dart';
import 'models/data/export_entry.dart';
import 'models/data/inventory_models.dart';
import 'models/export_model.dart';

class FixPage extends StatefulWidget {
  const FixPage({super.key});

  @override
  State<FixPage> createState() => _FixPageState();
}

class _FixPageState extends State<FixPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = false;
  static bool _showAllItems = true;
  bool _hasScrollableContent = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
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
      final bool isAtBottom =
          _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50;
      final bool hasScrollableContent =
          _scrollController.position.maxScrollExtent > 0;

      if (isAtBottom != _isAtBottom ||
          hasScrollableContent != _hasScrollableContent) {
        setState(() {
          _isAtBottom = isAtBottom;
          _hasScrollableContent = hasScrollableContent;
        });
      }
    }
  }

  void _toggleItemToFix(
    String itemName,
    CountModel countModel,
    bool showAllItems,
  ) {
    final Map<String, bool> itemsToFix = countModel.itemsToFix;
    if (showAllItems) {
      // In show-all mode, toggle presence in the map
      if (itemsToFix.containsKey(itemName)) {
        itemsToFix.remove(itemName);
      } else {
        itemsToFix[itemName] = false;
      }
    } else {
      // In filtered mode, toggle the fixed status
      itemsToFix[itemName] = !(itemsToFix[itemName] ?? false);
    }
    countModel.setItemsToFix(itemsToFix);
  }

  Future<void> _scrollToBottom() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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

  double _getTextWidth(BuildContext context, String text, TextStyle? style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return textPainter.width;
  }

  List<TextSpan> _buildAreaShelfTextSpans(Area? itemArea, Shelf? itemShelf) => [
    if (itemArea != null)
      TextSpan(
        text: itemArea.name,
        style: TextStyle(color: itemArea.color),
      ),
    if (itemArea != null && itemShelf != null) const TextSpan(text: ' > '),
    if (itemShelf != null) TextSpan(text: itemShelf.name),
  ];

  Future<void> _showBumpCountDialog(
    BuildContext context,
    String itemName,
    CountPhase phase,
    bool isNotCounted,
    AreaModel areaModel,
  ) async {
    final List<ItemTreeData> items = areaModel.findItemsByName(itemName, phase);
    if (items.isEmpty) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                phase.name,
                style: DefaultTextStyle.of(
                  context,
                ).style.copyWith(fontSize: 14, fontWeight: FontWeight.normal),
              ),
              Text(itemName, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            for (final itemData in items)
              Builder(
                builder: (context) {
                  final Area? itemArea = itemData.area;
                  final Shelf? itemShelf = itemData.shelf;
                  final Item item = itemData.item;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          RichText(
                            text: TextSpan(
                              style: DefaultTextStyle.of(context).style
                                  .copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal,
                                  ),
                              children: _buildAreaShelfTextSpans(
                                itemArea,
                                itemShelf,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Consumer<CountModel>(
                            builder: (context, countModel, child) {
                              return Checkbox(
                                value: countModel.getCount(item)?.doubleChecked,
                                onChanged: (value) {
                                  countModel.setDoubleChecked(
                                    item,
                                    doubleChecked: value ?? false,
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      item.strategy.buildBumpDisplay(context, item),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Consumer3<AreaModel, ExportModel, CountModel>(
          builder: (context, areaModel, exportModel, countModel, child) {
            final List<ExportEntry> exportList = exportModel.exportList;

            // Filter items if needed
            final List<ExportEntry> displayList;
            if (_showAllItems) {
              displayList = exportList;
            } else {
              // First pass: filter items and mark which titles have children
              final filteredItems = <ExportEntry>[];
              final titlesWithChildren = <ExportTitle>{};

              for (var i = 0; i < exportList.length; i++) {
                final ExportEntry entry = exportList[i];

                if (entry is ExportItem) {
                  if (countModel.itemsToFix.containsKey(entry.name)) {
                    filteredItems.add(entry);

                    // Find the parent title for this item
                    for (int j = i - 1; j >= 0; j--) {
                      if (exportList[j] is ExportTitle) {
                        titlesWithChildren.add(exportList[j] as ExportTitle);
                        break;
                      }
                    }
                  }
                } else if (entry is ExportTitle) {
                  filteredItems.add(entry);
                }
                // Skip ExportPlaceholder entries
              }

              // Second pass: remove titles without children
              displayList = filteredItems.where((entry) {
                if (entry is ExportTitle) {
                  return titlesWithChildren.contains(entry);
                }
                return true;
              }).toList();
            }

            // Check if there are any items in the filtered list
            final bool hasItems = displayList.any(
              (entry) => entry is ExportItem,
            );
            final List<TableRow> dataRows = () {
              var currentTitleHidden = false;
              var currentTitleNotCounted = false;
              ExportTitle? pendingTitle;
              final rows = <TableRow>[];

              for (final entry in displayList) {
                if (entry is ExportTitle) {
                  currentTitleHidden = entry.isHidden;
                  currentTitleNotCounted = entry.isNotCounted;
                  pendingTitle = currentTitleNotCounted || currentTitleHidden
                      ? null
                      : entry;
                } else if (entry is ExportItem) {
                  if (!entry.isHidden &&
                      !entry.isNotCounted &&
                      !currentTitleHidden &&
                      !currentTitleNotCounted) {
                    if (areaModel.getPathsForItem(entry.name).isNotEmpty) {
                      final TableRow? row = _buildItemRow(
                        context,
                        entry,
                        countModel,
                        areaModel,
                        _showAllItems,
                      );
                      if (row != null) {
                        if (pendingTitle != null) {
                          rows.add(_buildTitleRow(context, pendingTitle));
                          pendingTitle = null;
                        }
                        rows.add(row);
                      }
                    }
                  }
                }
              }

              return rows;
            }();
            return Stack(
              children: [
                Builder(
                  builder: (context) {
                    // Calculate the width needed for headers with padding
                    final TextStyle? textStyle = Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold);

                    final Map<String, double> columnWidths = {
                      'Back': _getTextWidth(context, 'Back', textStyle) + 24.0,
                      'Cabinet':
                          _getTextWidth(context, 'Cabinet', textStyle) + 24.0,
                      'Out': _getTextWidth(context, 'Out', textStyle) + 24.0,
                      'Total':
                          _getTextWidth(context, 'Total', textStyle) + 24.0,
                    };

                    // Show message if no items
                    if (!hasItems) {
                      if (areaModel.hasAnyItems()) {
                        // There are items, but none are selected (all hidden)
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No items are selected to fix.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        );
                      } else {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Add items in Setup to begin counting!',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        );
                      }
                    }

                    if (dataRows.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Count items to see them here',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      );
                    }

                    return Align(
                      alignment: Alignment.topCenter,
                      child: SingleChildScrollView(
                        key: const PageStorageKey('fix_page_scroll'),
                        controller: _scrollController,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 70),
                          child: Table(
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            border: TableBorder.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            columnWidths: {
                              0: const FlexColumnWidth(),
                              1: FixedColumnWidth(columnWidths['Back']!),
                              2: FixedColumnWidth(columnWidths['Cabinet']!),
                              3: FixedColumnWidth(columnWidths['Out']!),
                              4: FixedColumnWidth(columnWidths['Total']!),
                            },
                            children: [
                              // Header row
                              TableRow(
                                decoration: const BoxDecoration(
                                  color: Color.fromARGB(255, 189, 124, 27),
                                ),
                                children: [
                                  _buildHeaderCell(
                                    context,
                                    'Item',
                                    TextAlign.left,
                                    textStyle,
                                  ),
                                  _buildHeaderCell(
                                    context,
                                    'Back',
                                    TextAlign.center,
                                    textStyle,
                                  ),
                                  _buildHeaderCell(
                                    context,
                                    'Cabinet',
                                    TextAlign.center,
                                    textStyle,
                                  ),
                                  _buildHeaderCell(
                                    context,
                                    'Out',
                                    TextAlign.center,
                                    textStyle,
                                  ),
                                  _buildHeaderCell(
                                    context,
                                    'Total',
                                    TextAlign.center,
                                    textStyle,
                                  ),
                                ],
                              ),
                              // Data rows
                              ...dataRows,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (hasItems && dataRows.isNotEmpty)
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: FloatingActionButton.small(
                      onPressed: () {
                        setState(() {
                          _showAllItems = !_showAllItems;
                        });

                        // Update scroll arrow state after collapse
                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                          await Future.delayed(
                            const Duration(milliseconds: 300),
                          );
                          _onScroll();
                        });
                      },
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                      elevation: 2,
                      child: Icon(
                        _showAllItems ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                if (_hasScrollableContent && hasItems)
                  Positioned(
                    right: 16,
                    bottom: 16,
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
        ),
      ),
    );
  }

  Widget _buildItemNameButton(
    BuildContext context,
    String itemName,
    bool isMarked,
    bool isFixed,
    CountModel countModel,
    bool showAllItems,
  ) {
    return Container(
      color: isMarked ? Colors.yellow.withAlpha(80) : null,
      child: InkWell(
        onTap: () => _toggleItemToFix(itemName, countModel, showAllItems),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (isMarked)
                Icon(
                  isFixed ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 16,
                  color: Colors.yellow.withAlpha(160),
                ),
              if (isMarked) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  itemName,
                  textAlign: TextAlign.left,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(
    BuildContext context,
    String text,
    TextAlign textAlign,
    TextStyle? textStyle,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        textAlign: textAlign,
        style: textStyle,
        overflow: TextOverflow.fade,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }

  TableRow? _buildItemRow(
    BuildContext context,
    ExportItem item,
    CountModel countModel,
    AreaModel areaModel,
    bool showAllItems,
  ) {
    // Get counts for each phase
    int? backCount = countModel.getCountValueByName(item.name, CountPhase.back);
    int? cabinetCount = countModel.getCountValueByName(
      item.name,
      CountPhase.cabinet,
    );
    int? outCount = countModel.getCountValueByName(item.name, CountPhase.out);

    final String? backSumNotation = countModel.getCountSumNotationByName(
      item.name,
      CountPhase.back,
    );
    final String? cabinetSumNotation = countModel.getCountSumNotationByName(
      item.name,
      CountPhase.cabinet,
    );
    final String? outSumNotation = countModel.getCountSumNotationByName(
      item.name,
      CountPhase.out,
    );

    final backIsNotCounted = backCount == -1;
    final cabinetIsNotCounted = cabinetCount == -1;
    final outIsNotCounted = outCount == -1;

    if (backIsNotCounted) {
      backCount = null;
    }
    if (cabinetIsNotCounted) {
      cabinetCount = null;
    }
    if (outIsNotCounted) {
      outCount = null;
    }

    // Calculate total
    final bool anyNotCounted =
        backIsNotCounted || cabinetIsNotCounted || outIsNotCounted;
    final bool hasAnyValue =
        (!backIsNotCounted && backCount != null) ||
        (!cabinetIsNotCounted && cabinetCount != null) ||
        (!outIsNotCounted && outCount != null);

    final String totalStr;
    if (hasAnyValue) {
      final int total =
          (backCount ?? 0) + (cabinetCount ?? 0) + (outCount ?? 0);
      totalStr = total.toString();
    } else if (anyNotCounted) {
      totalStr = '-';
    } else {
      totalStr = '';
    }

    if (totalStr.isEmpty) return null;

    final bool isMarkedToFix = countModel.itemsToFix.containsKey(item.name);
    final bool isFixed = countModel.itemsToFix[item.name] ?? false;

    return TableRow(
      children: [
        _buildItemNameButton(
          context,
          item.name,
          isMarkedToFix,
          isFixed,
          countModel,
          showAllItems,
        ),
        _buildClickableCountCell(
          context,
          backIsNotCounted ? '-' : backSumNotation ?? '',
          item.name,
          CountPhase.back,
          backIsNotCounted,
          backCount != null || backIsNotCounted,
          backgroundColor: backIsNotCounted
              ? Colors.yellow.withValues(alpha: 0.3)
              : (backCount == null ? Colors.red.withValues(alpha: 0.1) : null),
        ),
        _buildClickableCountCell(
          context,
          cabinetIsNotCounted ? '-' : cabinetSumNotation ?? '',
          item.name,
          CountPhase.cabinet,
          cabinetIsNotCounted,
          cabinetCount != null || cabinetIsNotCounted,
          backgroundColor: cabinetIsNotCounted
              ? Colors.yellow.withValues(alpha: 0.3)
              : (cabinetCount == null
                    ? Colors.red.withValues(alpha: 0.1)
                    : null),
        ),
        _buildClickableCountCell(
          context,
          outIsNotCounted ? '-' : outSumNotation ?? '',
          item.name,
          CountPhase.out,
          outIsNotCounted,
          outCount != null || outIsNotCounted,
          backgroundColor: outIsNotCounted
              ? Colors.yellow.withValues(alpha: 0.3)
              : (outCount == null ? Colors.red.withValues(alpha: 0.1) : null),
        ),
        _buildDataCell(
          context,
          totalStr,
          TextAlign.center,
          backgroundColor: anyNotCounted
              ? Colors.yellow.withValues(alpha: 0.3)
              : ((backCount == null || cabinetCount == null || outCount == null)
                    ? Colors.red.withValues(alpha: 0.1)
                    : null),
        ),
      ],
    );
  }

  TableRow _buildTitleRow(BuildContext context, ExportTitle title) {
    return TableRow(
      decoration: const BoxDecoration(color: Color.fromARGB(255, 94, 71, 37)),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            title.name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            softWrap: false,
          ),
        ),
        const SizedBox(),
        const SizedBox(),
        const SizedBox(),
        const SizedBox(),
      ],
    );
  }

  Widget _buildDataCell(
    BuildContext context,
    String text,
    TextAlign textAlign, {
    Color? backgroundColor,
  }) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        textAlign: textAlign,
        style: Theme.of(context).textTheme.bodyMedium,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }

  Widget _buildClickableCountCell(
    BuildContext context,
    String text,
    String itemName,
    CountPhase phase,
    bool isNotCounted,
    bool hasCounted, {
    Color? backgroundColor,
  }) {
    return Container(
      color: backgroundColor,
      child: Consumer<AreaModel>(
        builder: (context, areaModel, child) {
          return InkWell(
            onTap: (isNotCounted || hasCounted)
                ? () => _showBumpCountDialog(
                    context,
                    itemName,
                    phase,
                    isNotCounted,
                    areaModel,
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
