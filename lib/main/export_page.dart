import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/area_model.dart';
import 'models/count_model.dart';
import 'models/data/count_strategy.dart';
import 'models/data/export_entry.dart';
import 'models/data/inventory_models.dart';
import 'models/export_model.dart';

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = false;

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
      if (isAtBottom != _isAtBottom) {
        setState(() {
          _isAtBottom = isAtBottom;
        });
      }
    }
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
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return textPainter.width;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Consumer3<AreaModel, ExportModel, CountModel>(
            builder: (context, areaModel, exportModel, countModel, child) {
              final List<ExportEntry> exportList = exportModel.exportList;

              // Check if there are any items in the list
              final bool hasItems = exportList.any(
                (entry) => entry is ExportItem,
              );

              // Calculate the width needed for headers with padding
              final TextStyle? textStyle = Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

              final Map<String, double> columnWidths = {
                'Back': _getTextWidth(context, 'Back', textStyle) + 24.0,
                'Cabinet': _getTextWidth(context, 'Cabinet', textStyle) + 24.0,
                'Out': _getTextWidth(context, 'Out', textStyle) + 24.0,
                'Total': _getTextWidth(context, 'Total', textStyle) + 24.0,
              };

              // Show message if no items
              if (!hasItems) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Add items in Setup to begin counting!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  key: const PageStorageKey('export_table_scroll'),
                  controller: _scrollController,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 70),
                    child: Table(
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
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
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
                        ...(() {
                          var currentTitleHidden = false;
                          var currentTitleNotCounted = false;
                          final rows = <TableRow>[];

                          for (final entry in exportList) {
                            if (entry is ExportTitle) {
                              currentTitleHidden = entry.isHidden;
                              currentTitleNotCounted = entry.isNotCounted;
                              if (!entry.isHidden) {
                                rows.add(_buildTitleRow(context, entry));
                              }
                            } else if (entry is ExportItem) {
                              if (!entry.isHidden && !currentTitleHidden) {
                                if (!countModel.hasCountsForItem(entry.name) ||
                                    entry.isNotCounted ||
                                    currentTitleNotCounted) {
                                  rows.add(
                                    _buildPlaceholderRow(context, entry),
                                  );
                                } else {
                                  rows.add(
                                    _buildItemRow(
                                      context,
                                      entry,
                                      countModel,
                                      areaModel,
                                    ),
                                  );
                                }
                              }
                            }
                          }

                          return rows;
                        }()),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          Positioned(
            bottom: 16,
            right: 16,
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

  Color? _countCellBackgroundColor({
    required bool isNotCounted,
    required int? count,
  }) {
    if (isNotCounted) {
      return Colors.yellow.withValues(alpha: 0.3);
    }

    if (count == null) {
      return Colors.red.withValues(alpha: 0.1);
    }

    return null;
  }

  Color? _totalCellBackgroundColor({
    required bool anyNotCounted,
    required int? backCount,
    required int? cabinetCount,
    required int? outCount,
  }) {
    if (anyNotCounted) {
      return Colors.yellow.withValues(alpha: 0.3);
    }

    if (backCount == null || cabinetCount == null || outCount == null) {
      return Colors.red.withValues(alpha: 0.1);
    }

    return null;
  }

  TableRow _buildItemRow(
    BuildContext context,
    ExportItem item,
    CountModel countModel,
    AreaModel areaModel,
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

    return TableRow(
      children: [
        _buildItemNameCell(context, item.name),
        _buildDataCell(
          context,
          backIsNotCounted ? '-' : backSumNotation ?? '',
          TextAlign.center,
          richTextSpan: backHasOrphanedCounts ? backSumSpan : null,
          backgroundColor: _countCellBackgroundColor(
            isNotCounted: backIsNotCounted,
            count: backCount,
          ),
        ),
        _buildDataCell(
          context,
          cabinetIsNotCounted ? '-' : cabinetSumNotation ?? '',
          TextAlign.center,
          richTextSpan: cabinetHasOrphanedCounts ? cabinetSumSpan : null,
          backgroundColor: _countCellBackgroundColor(
            isNotCounted: cabinetIsNotCounted,
            count: cabinetCount,
          ),
        ),
        _buildDataCell(
          context,
          outIsNotCounted ? '-' : outSumNotation ?? '',
          TextAlign.center,
          richTextSpan: outHasOrphanedCounts ? outSumSpan : null,
          backgroundColor: _countCellBackgroundColor(
            isNotCounted: outIsNotCounted,
            count: outCount,
          ),
        ),
        _buildDataCell(
          context,
          totalStr,
          TextAlign.center,
          textColor: totalHasOrphanedCounts
              ? Theme.of(context).colorScheme.error
              : null,
          backgroundColor: _totalCellBackgroundColor(
            anyNotCounted: anyNotCounted,
            backCount: backCount,
            cabinetCount: cabinetCount,
            outCount: outCount,
          ),
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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
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

  TableRow _buildPlaceholderRow(BuildContext context, ExportItem placeholder) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.yellow.withValues(alpha: 0.2)),
      children: [
        _buildItemNameCell(context, placeholder.name),
        const SizedBox(),
        const SizedBox(),
        const SizedBox(),
        const SizedBox(),
      ],
    );
  }

  Widget _buildItemNameCell(BuildContext context, String itemName) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Text(
        itemName,
        textAlign: TextAlign.left,
        style: Theme.of(context).textTheme.bodyMedium,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }

  Widget _buildDataCell(
    BuildContext context,
    String text,
    TextAlign textAlign, {
    Color? backgroundColor,
    Color? textColor,
    InlineSpan? richTextSpan,
  }) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: textAlign == TextAlign.left
            ? Alignment.centerLeft
            : Alignment.center,
        child: richTextSpan != null
            ? RichText(text: richTextSpan, textAlign: textAlign)
            : Text(
                text,
                textAlign: textAlign,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: textColor),
              ),
      ),
    );
  }
}
