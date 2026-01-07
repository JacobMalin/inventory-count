import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:inventory_count/models/export_entry.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:provider/provider.dart';

class ExportPage extends StatelessWidget {
  const ExportPage({super.key});

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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Export View',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Consumer2<AreaModel, CountModel>(
        builder: (context, areaModel, countModel, child) {
          final exportList = areaModel.exportList;

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

          return Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
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
                      color: Theme.of(context).colorScheme.primaryContainer,
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
          );
        },
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
        _buildDataCell(context, item.name, TextAlign.left),
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
