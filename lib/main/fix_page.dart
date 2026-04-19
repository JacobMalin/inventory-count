import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/area_model.dart';
import 'models/count_model.dart';
import 'models/data/count_strategy.dart';
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

  Future<void> _showBumpCountDialog(
    BuildContext context,
    String itemName,
    CountPhase phase,
    bool isNotCounted,
    AreaModel areaModel,
    CountModel countModel,
  ) async {
    final List<Item> items = areaModel.findItemsByName(itemName, phase);
    final Set<String> itemPaths = items.map((item) => item.path).toSet();
    final List<MapEntry<String, CountEntry>> missingEntries =
        countModel.itemCounts.entries
            .where(
              (entry) =>
                  entry.value.name == itemName &&
                  entry.value.phase == phase &&
                  !itemPaths.contains(entry.key),
            )
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    if (items.isEmpty && missingEntries.isEmpty) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                phase.name,
                style: DefaultTextStyle.of(context).style.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: phase.color,
                ),
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
            for (final item in items)
              Builder(
                builder: (context) {
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
                              children: item.parent.richPath,
                            ),
                          ),
                          const Spacer(),
                          Consumer<CountModel>(
                            builder: (context, countModel, child) {
                              final ItemCountType? count = countModel.getCount(
                                item,
                              );

                              return Checkbox(
                                value: count?.doubleChecked ?? false,
                                onChanged: count == null
                                    ? null
                                    : (value) {
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
            for (final entry in missingEntries)
              Builder(
                builder: (context) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: DefaultTextStyle.of(context).style
                                      .copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.normal,
                                      ),
                                  // overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'This counted field is missing.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                            ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final bool added = areaModel
                                            .ensurePathExistsForCountEntry(
                                              entry.key,
                                              entry.value,
                                            );

                                        if (!context.mounted) return;

                                        Navigator.of(dialogContext).pop();
                                        if (added) {
                                          await _showBumpCountDialog(
                                            context,
                                            itemName,
                                            phase,
                                            isNotCounted,
                                            areaModel,
                                            countModel,
                                          );
                                        }
                                      },
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.fromLTRB(
                                          4,
                                          12,
                                          6,
                                          12,
                                        ),
                                        minimumSize: const Size(0, 24),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                        textStyle: const TextStyle(
                                          fontSize: 14,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add, size: 16),
                                          SizedBox(width: 4),
                                          Text('Add'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Consumer<CountModel>(
                            builder: (context, countModel, child) {
                              final CountEntry? currentEntry = countModel
                                  .getCountEntry(entry.key);

                              return Checkbox(
                                value:
                                    currentEntry?.countType.doubleChecked ??
                                    false,
                                onChanged: currentEntry == null
                                    ? null
                                    : (value) {
                                        countModel.setDoubleCheckedByPath(
                                          entry.key,
                                          doubleChecked: value ?? false,
                                        );
                                      },
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildMissingEntryEditor(context, entry.key),
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
                    if (countModel.hasCountsForItem(entry.name)) {
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

                    final columnWidths = <String, double>{
                      'Back': 50.0,
                      'Cabinet': 50.0,
                      'Out': 50.0,
                      'Total': 50.0,
                      'Diff': 50.0,
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
                              5: FixedColumnWidth(columnWidths['Diff']!),
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
                                    horizontalPadding: 12,
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
                                  _buildHeaderCell(
                                    context,
                                    'Diff',
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
                if (hasItems &&
                    dataRows.isNotEmpty &&
                    countModel.itemsToFix.isNotEmpty)
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
    TextStyle? textStyle, {
    double horizontalPadding = 4,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 12,
      ),
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
    final InlineSpan backSumSpan = _buildPhaseNotationSpan(
      context,
      item.name,
      CountPhase.back,
      areaModel,
      countModel,
    );
    final InlineSpan cabinetSumSpan = _buildPhaseNotationSpan(
      context,
      item.name,
      CountPhase.cabinet,
      areaModel,
      countModel,
    );
    final InlineSpan outSumSpan = _buildPhaseNotationSpan(
      context,
      item.name,
      CountPhase.out,
      areaModel,
      countModel,
    );

    final bool backHasOrphanedCounts = _hasOrphanedCountsForPhase(
      item.name,
      CountPhase.back,
      areaModel,
      countModel,
    );
    final bool cabinetHasOrphanedCounts = _hasOrphanedCountsForPhase(
      item.name,
      CountPhase.cabinet,
      areaModel,
      countModel,
    );
    final bool outHasOrphanedCounts = _hasOrphanedCountsForPhase(
      item.name,
      CountPhase.out,
      areaModel,
      countModel,
    );
    final bool totalHasOrphanedCounts =
        backHasOrphanedCounts ||
        cabinetHasOrphanedCounts ||
        outHasOrphanedCounts;

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

    final int? totalInt = hasAnyValue
        ? (backCount ?? 0) + (cabinetCount ?? 0) + (outCount ?? 0)
        : null;

    final String totalStr;
    if (hasAnyValue) {
      totalStr = totalInt!.toString();
    } else if (anyNotCounted) {
      totalStr = '-';
    } else {
      totalStr = '';
    }

    if (totalStr.isEmpty) return null;

    final bool isMarkedToFix = countModel.itemsToFix.containsKey(item.name);
    final bool isFixed = countModel.itemsToFix[item.name] ?? false;
    final int? expectedValue = countModel.getExpectedValue(
      item.name,
      item.omniName,
    );
    final int? diffValue = (totalInt != null && expectedValue != null)
        ? totalInt - expectedValue
        : null;
    final diffStr = diffValue == null
        ? ''
        : (diffValue > 0 ? '+$diffValue' : diffValue.toString());

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
          richTextSpan: backHasOrphanedCounts ? backSumSpan : null,
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
          richTextSpan: cabinetHasOrphanedCounts ? cabinetSumSpan : null,
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
          richTextSpan: outHasOrphanedCounts ? outSumSpan : null,
          backgroundColor: outIsNotCounted
              ? Colors.yellow.withValues(alpha: 0.3)
              : (outCount == null ? Colors.red.withValues(alpha: 0.1) : null),
        ),
        _buildDataCell(
          context,
          totalStr,
          TextAlign.center,
          textColor: totalHasOrphanedCounts
              ? Theme.of(context).colorScheme.error
              : null,
          backgroundColor: anyNotCounted
              ? Colors.yellow.withValues(alpha: 0.3)
              : ((backCount == null || cabinetCount == null || outCount == null)
                    ? Colors.red.withValues(alpha: 0.1)
                    : null),
        ),
        _buildDataCell(
          context,
          diffStr,
          TextAlign.center,
          textColor: diffValue == null
              ? null
              : (diffValue < 0
                    ? const Color.fromARGB(255, 239, 74, 62)
                    : (diffValue == 0
                          ? Colors.grey.withValues(alpha: 0.35)
                          : null)),
        ),
      ],
    );
  }

  bool _hasOrphanedCountsForPhase(
    String itemName,
    CountPhase phase,
    AreaModel areaModel,
    CountModel countModel,
  ) {
    final Set<String> validPaths = areaModel.getPathsForItem(itemName).toSet();

    for (final MapEntry<String, CountEntry> entry
        in countModel.itemCounts.entries) {
      if (entry.value.name == itemName &&
          entry.value.phase == phase &&
          !validPaths.contains(entry.key)) {
        return true;
      }
    }

    return false;
  }

  InlineSpan _buildPhaseNotationSpan(
    BuildContext context,
    String itemName,
    CountPhase phase,
    AreaModel areaModel,
    CountModel countModel,
  ) {
    final TextStyle baseStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final Color errorColor = Theme.of(context).colorScheme.error;
    final Set<String> validPaths = areaModel.getPathsForItem(itemName).toSet();

    final List<InlineSpan> spans = [];
    var isFirst = true;

    for (final MapEntry<String, CountEntry> entry
        in countModel.itemCounts.entries) {
      if (entry.value.name != itemName || entry.value.phase != phase) {
        continue;
      }

      if (!isFirst) {
        spans.add(TextSpan(text: ' + ', style: baseStyle));
      }

      final ItemCountType countType = entry.value.countType;
      if (countType is ItemNotCounted) {
        spans.add(TextSpan(text: '-', style: baseStyle));
      } else if (countType is ItemCount) {
        final bool isOrphan = !validPaths.contains(entry.key);
        spans.add(
          TextSpan(
            text: '${countType.count ?? ''}',
            style: baseStyle.copyWith(color: isOrphan ? errorColor : null),
          ),
        );
        if (countType.doubleChecked) {
          spans.add(TextSpan(text: ' ✓', style: baseStyle));
        }
      }

      isFirst = false;
    }

    return TextSpan(style: baseStyle, children: spans);
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
        const SizedBox(),
      ],
    );
  }

  Widget _buildDataCell(
    BuildContext context,
    String text,
    TextAlign textAlign, {
    Color? backgroundColor,
    Color? textColor,
  }) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: textAlign == TextAlign.left
            ? Alignment.centerLeft
            : Alignment.center,
        child: Text(
          text,
          textAlign: textAlign,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: textColor),
        ),
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
    Color? textColor,
    InlineSpan? richTextSpan,
  }) {
    return Container(
      color: backgroundColor,
      child: Consumer2<AreaModel, CountModel>(
        builder: (context, areaModel, countModel, child) {
          return InkWell(
            onTap: (isNotCounted || hasCounted)
                ? () => _showBumpCountDialog(
                    context,
                    itemName,
                    phase,
                    isNotCounted,
                    areaModel,
                    countModel,
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: richTextSpan != null
                    ? RichText(text: richTextSpan)
                    : Text(
                        text,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: textColor),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMissingEntryEditor(BuildContext context, String path) {
    return Consumer<CountModel>(
      builder: (context, countModel, child) {
        final CountEntry? currentEntry = countModel.getCountEntry(path);
        if (currentEntry == null) {
          return Text(
            'This counted field was removed.',
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }

        final ItemCountType countType = currentEntry.countType;
        if (countType is ItemNotCounted) {
          return Row(
            children: [
              Text(
                'Not Counted.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              OutlinedButton.icon(
                iconAlignment: IconAlignment.end,
                onPressed: () {
                  countModel.removeCountByPath(path);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.error,
                    width: 1.25,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('Delete Entry'),
              ),
            ],
          );
        }

        if (countType is ItemCount) {
          return countType.strategy.buildOrphanBumpDisplay(context, path);
        }

        return Text(
          'No count data',
          style: Theme.of(context).textTheme.bodyMedium,
        );
      },
    );
  }
}
