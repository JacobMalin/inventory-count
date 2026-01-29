import 'dart:io';

import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:inventory_count/models/export_entry.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      child: Stack(
        children: [
          Consumer2<AreaModel, CountModel>(
            builder: (context, areaModel, countModel, child) {
              final exportList = areaModel.exportList;

              // Check if there are any items in the list
              final hasItems = exportList.any((entry) => entry is ExportItem);

              // Calculate the width needed for headers with padding
              final textStyle = Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

              final columnWidths = {
                'Back': _getTextWidth(context, 'Back', textStyle) + 24.0,
                'Cabinet': _getTextWidth(context, 'Cabinet', textStyle) + 24.0,
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
          Positioned(
            bottom: 16,
            left: 16,
            child: Consumer2<AreaModel, CountModel>(
              builder: (context, areaModel, countModel, child) {
                return FloatingActionButton.small(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);

                    try {
                      final jsonString = areaModel.exportInExportOrder(
                        countModel,
                      );

                      await Supabase.instance.client.from('counts').insert({
                        'json': jsonString,
                      });

                      messenger.showSnackBar(
                        SnackBar(
                          content: GestureDetector(
                            onTap: () => messenger.hideCurrentSnackBar(),
                            child: const Text('Exported successfully!'),
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: GestureDetector(
                            onTap: () => messenger.hideCurrentSnackBar(),
                            child: Text('Export failed: $e'),
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  elevation: 2,
                  child: const Icon(Icons.cloud_upload),
                );
              },
            ),
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

    return TableRow(
      children: [
        _buildItemNameCell(context, item.name),
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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
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
  }) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: textAlign == TextAlign.left
            ? Alignment.centerLeft
            : Alignment.center,
        child: Text(
          text,
          textAlign: textAlign,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
