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
  final Set<String> _itemsToFix = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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

  void _toggleItemToFix(String itemName) {
    setState(() {
      if (_itemsToFix.contains(itemName)) {
        _itemsToFix.remove(itemName);
      } else {
        _itemsToFix.add(itemName);
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            Consumer2<AreaModel, CountModel>(
              builder: (context, areaModel, countModel, child) {
                final exportList = areaModel.exportList;

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

                return Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 70.0),
                      child: Table(
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
                          for (final entry in exportList)
                            if (entry is ExportItem)
                              _buildItemRow(context, entry, countModel)
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
          ],
        ),
        floatingActionButton: FloatingActionButton.small(
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
    );
  }

  Widget _buildItemNameButton(
    BuildContext context,
    String itemName,
    bool isMarked,
  ) {
    return Container(
      color: isMarked ? Colors.yellow.withAlpha(80) : null,
      child: InkWell(
        onTap: () => _toggleItemToFix(itemName),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              if (isMarked)
                Icon(
                  Icons.check_box_outline_blank,
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

    final isMarkedToFix = _itemsToFix.contains(item.name);

    return TableRow(
      children: [
        _buildItemNameButton(context, item.name, isMarkedToFix),
        _buildDataCell(
          context,
          backIsNotCounted ? '-' : backSumNotation ?? '',
          TextAlign.center,
          backgroundColor: backIsNotCounted
              ? Colors.yellow.withValues(alpha: 0.3)
              : (backCount == null ? Colors.red.withValues(alpha: 0.1) : null),
        ),
        _buildDataCell(
          context,
          cabinetIsNotCounted ? '-' : cabinetSumNotation ?? '',
          TextAlign.center,
          backgroundColor: cabinetIsNotCounted
              ? Colors.yellow.withValues(alpha: 0.3)
              : (cabinetCount == null
                    ? Colors.red.withValues(alpha: 0.1)
                    : null),
        ),
        _buildDataCell(
          context,
          outIsNotCounted ? '-' : outSumNotation ?? '',
          TextAlign.center,
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
}
