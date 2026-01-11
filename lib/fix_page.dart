import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:inventory_count/models/export_entry.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:provider/provider.dart';

class FixPage extends StatefulWidget {
  const FixPage({super.key});

  @override
  State<FixPage> createState() => _FixPageState();
}

class _FixPageState extends State<FixPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = false;
  static bool _showAllItems = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final isAtBottom =
          _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50;
      if (isAtBottom != _isAtBottom) {
        setState(() {
          _isAtBottom = isAtBottom;
        });
      }
    }
  }

  void _toggleItemToFix(
    String itemName,
    CountModel countModel,
    bool showAllItems,
  ) {
    final itemsToFix = countModel.itemsToFix;
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

  void _scrollToBottom() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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

  double _getTextWidth(BuildContext context, String text, TextStyle? style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return textPainter.width;
  }

  void _showBumpCountDialog(
    BuildContext context,
    String itemName,
    CountPhase phase,
    bool isNotCounted,
    CountModel countModel,
    AreaModel areaModel,
  ) {
    final items = countModel.findItemsByName(itemName, phase, areaModel);
    if (items.isEmpty) return;

    showDialog(
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
                  final itemArea = itemData.area;
                  final itemShelf = itemData.shelf;
                  final item = itemData.item;

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
                              children: [
                                if (itemArea != null)
                                  TextSpan(
                                    text: itemArea.name,
                                    style: TextStyle(color: itemArea.color),
                                  ),
                                if (itemArea != null && itemShelf != null)
                                  const TextSpan(text: ' > '),
                                if (itemShelf != null)
                                  TextSpan(text: itemShelf.name),
                              ],
                            ),
                          ),
                          Spacer(),
                          Consumer<CountModel>(
                            builder: (context, countModel, child) {
                              return Checkbox(
                                value: countModel.getCount(item)?.doubleChecked,
                                onChanged: (value) {
                                  countModel.setDoubleChecked(
                                    item,
                                    value ?? false,
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: item.strategy.buildBumpDisplay(context, item),
                      ),
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
        body: Stack(
          children: [
            Consumer2<AreaModel, CountModel>(
              builder: (context, areaModel, countModel, child) {
                final exportList = areaModel.exportList;

                // Filter items if needed
                final List<ExportEntry> displayList;
                if (_showAllItems) {
                  displayList = exportList;
                } else {
                  // First pass: filter items and mark which titles have children
                  final filteredItems = <ExportEntry>[];
                  final titlesWithChildren = <ExportTitle>{};

                  for (int i = 0; i < exportList.length; i++) {
                    final entry = exportList[i];

                    if (entry is ExportItem) {
                      if (countModel.itemsToFix.containsKey(entry.name)) {
                        filteredItems.add(entry);

                        // Find the parent title for this item
                        for (int j = i - 1; j >= 0; j--) {
                          if (exportList[j] is ExportTitle) {
                            titlesWithChildren.add(
                              exportList[j] as ExportTitle,
                            );
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
                final hasItems = displayList.any(
                  (entry) => entry is ExportItem,
                );

                // Calculate the width needed for headers with padding
                final textStyle = Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

                final columnWidths = {
                  'Back': _getTextWidth(context, 'Back', textStyle) + 24.0,
                  'Cabinet':
                      _getTextWidth(context, 'Cabinet', textStyle) + 24.0,
                  'Out': _getTextWidth(context, 'Out', textStyle) + 24.0,
                  'Total': _getTextWidth(context, 'Total', textStyle) + 24.0,
                };

                // Show message if no items
                if (!hasItems) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Add items in Setup to begin counting!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }

                return Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    key: PageStorageKey('fix_page_scroll'),
                    controller: _scrollController,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 70.0),
                      child: Table(
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        border: TableBorder.all(
                          color: Theme.of(context).colorScheme.outline,
                          width: 1,
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
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 189, 124, 27),
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
                          for (final entry in displayList)
                            if (entry is ExportItem)
                              _buildItemRow(
                                context,
                                entry,
                                countModel,
                                areaModel,
                                _showAllItems,
                              )
                            else if (entry is ExportTitle)
                              _buildTitleRow(context, entry)
                            else if (entry is ExportPlaceholder)
                              _buildPlaceholderRow(context, entry),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: FloatingActionButton.small(
                onPressed: () {
                  setState(() {
                    _showAllItems = !_showAllItems;
                  });
                },
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                elevation: 2,
                child: Icon(
                  _showAllItems ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.small(
                onPressed: _isAtBottom ? _scrollToTop : _scrollToBottom,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                elevation: 2,
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: _isAtBottom ? -0.5 : 0,
                  child: const Icon(Icons.arrow_downward),
                ),
              ),
            ),
          ],
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
          padding: const EdgeInsets.all(12.0),
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
      padding: const EdgeInsets.all(12.0),
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

  TableRow _buildItemRow(
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

    String? backSumNotation = countModel.getCountSumNotationByName(
      item.name,
      CountPhase.back,
    );
    String? cabinetSumNotation = countModel.getCountSumNotationByName(
      item.name,
      CountPhase.cabinet,
    );
    String? outSumNotation = countModel.getCountSumNotationByName(
      item.name,
      CountPhase.out,
    );

    bool backIsNotCounted = backCount == -1;
    bool cabinetIsNotCounted = cabinetCount == -1;
    bool outIsNotCounted = outCount == -1;

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
      final total = (backCount ?? 0) + (cabinetCount ?? 0) + (outCount ?? 0);
      totalStr = total.toString();
    } else if (anyNotCounted) {
      totalStr = '-';
    } else {
      totalStr = '';
    }

    final isMarkedToFix = countModel.itemsToFix.containsKey(item.name);
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
          countModel,
          areaModel,
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
          countModel,
          areaModel,
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
          countModel,
          areaModel,
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
      decoration: BoxDecoration(color: const Color.fromARGB(255, 94, 71, 37)),
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
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

  TableRow _buildPlaceholderRow(
    BuildContext context,
    ExportPlaceholder placeholder,
  ) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.yellow.withValues(alpha: 0.2)),
      children: [
        _buildDataCell(context, placeholder.name, TextAlign.left),
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
      padding: const EdgeInsets.all(12.0),
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
    bool hasCounted,
    CountModel countModel,
    AreaModel areaModel, {
    Color? backgroundColor,
  }) {
    return Container(
      color: backgroundColor,
      child: InkWell(
        onTap: (isNotCounted || hasCounted)
            ? () => _showBumpCountDialog(
                context,
                itemName,
                phase,
                isNotCounted,
                countModel,
                areaModel,
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      ),
    );
  }
}
