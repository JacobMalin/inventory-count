import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:provider/provider.dart';

class ExportPage extends StatelessWidget {
  const ExportPage({super.key});

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

          return Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              child: Table(
                border: TableBorder.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1,
                ),
                defaultColumnWidth: const IntrinsicColumnWidth(),
                children: [
                  // Header row
                  TableRow(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    children: [
                      _buildHeaderCell(context, 'Item', TextAlign.left),
                      _buildHeaderCell(context, 'Back', TextAlign.center),
                      _buildHeaderCell(context, 'Cabinet', TextAlign.center),
                      _buildHeaderCell(context, 'Out', TextAlign.center),
                      _buildHeaderCell(context, 'Total', TextAlign.center),
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
  ) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        textAlign: textAlign,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  TableRow _buildItemRow(
    BuildContext context,
    ExportItem item,
    CountModel countModel,
  ) {
    // Get counts for each phase
    final backCount = countModel.getCountTrueByName(item.name, CountPhase.back);
    final cabinetCount = countModel.getCountTrueByName(
      item.name,
      CountPhase.cabinet,
    );
    final outCount = countModel.getCountTrueByName(item.name, CountPhase.out);

    // Calculate total
    final total = (backCount ?? 0) + (cabinetCount ?? 0) + (outCount ?? 0);
    final totalStr = total > 0 ? total.toString() : '';

    return TableRow(
      children: [
        _buildDataCell(context, item.name, TextAlign.left),
        _buildDataCell(context, backCount?.toString() ?? '', TextAlign.center),
        _buildDataCell(
          context,
          cabinetCount?.toString() ?? '',
          TextAlign.center,
        ),
        _buildDataCell(context, outCount?.toString() ?? '', TextAlign.center),
        _buildDataCell(context, totalStr, TextAlign.center),
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
    TextAlign textAlign,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        textAlign: textAlign,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
