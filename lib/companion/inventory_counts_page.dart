import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/types/json.dart';
import '../main/models/data/inventory_models.dart';
import 'inventory_count_actions_dialog.dart';
import 'process_cancellation.dart';
import 'window_model.dart';

class InventoryCountsPage extends StatefulWidget {
  const InventoryCountsPage({super.key});

  @override
  State<InventoryCountsPage> createState() => _InventoryCountsPageState();
}

class _InventoryCountsPageState extends State<InventoryCountsPage> {
  static const Duration _minimumOfflineReloadDuration = Duration(
    milliseconds: 500,
  );

  late Stream<List<Json>> _countsStream;
  bool _isReloadingOffline = false;
  DateTime? _offlineReloadStartedAt;
  bool _isOfflineReloadReleaseQueued = false;

  @override
  void initState() {
    super.initState();
    _countsStream = _createCountsStream();
  }

  Stream<List<Json>> _createCountsStream() {
    return Supabase.instance.client
        .from('counts')
        .stream(primaryKey: ['name'])
        .order('updated_at');
  }

  void _reloadCounts() {
    setState(() {
      _isReloadingOffline = true;
      _offlineReloadStartedAt = DateTime.now();
      _isOfflineReloadReleaseQueued = false;
      _countsStream = _createCountsStream();
    });
  }

  void _finishOfflineReload() {
    if (_isOfflineReloadReleaseQueued) return;

    _isOfflineReloadReleaseQueued = true;
    final DateTime startedAt = _offlineReloadStartedAt ?? DateTime.now();
    final Duration elapsed = DateTime.now().difference(startedAt);
    final Duration remaining = elapsed >= _minimumOfflineReloadDuration
        ? Duration.zero
        : _minimumOfflineReloadDuration - elapsed;

    Future<void>.delayed(remaining, () {
      if (!mounted || !_isReloadingOffline) return;
      setState(() {
        _isReloadingOffline = false;
        _offlineReloadStartedAt = null;
        _isOfflineReloadReleaseQueued = false;
      });
    });
  }

  Widget _buildNoInternetError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text("You're offline", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Check your network connection and try again.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isReloadingOffline ? null : _reloadCounts,
            icon: _isReloadingOffline
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(_isReloadingOffline ? 'Reloading...' : 'Reload'),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamError(BuildContext context, Object? error) {
    if (error is SocketException) return _buildNoInternetError(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.25),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Could not load inventory counts',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          error?.toString() ?? 'Unknown error',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _sumTotals(String jsonData) {
    Object? decoded;
    try {
      decoded = jsonDecode(jsonData);
    } on FormatException {
      return 0;
    }

    if (decoded is! Map) return 0;

    var sum = 0;
    for (final Map category in decoded.values) {
      for (final Map item in category.values) {
        final dynamic total = item['Total'];
        if (total == null) continue;
        final int? value = int.tryParse(
          total.toString().replaceAll(RegExp('[^0-9]'), ''),
        );
        if (value != null) sum += value;
      }
    }
    return sum;
  }

  String _formatCountName(String rawName) {
    final DateTime? isoParsed = DateTime.tryParse(rawName);
    if (isoParsed != null) {
      return DateFormat.yMMMMd().format(isoParsed);
    }

    return rawName;
  }

  String _normalizeExpectedKey(String key) {
    return key.toLowerCase().replaceAll('&', '').trim();
  }

  int? _toExpectedInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final String digits = value.replaceAll(RegExp('[^0-9-]'), '');
      if (digits.isEmpty) return null;
      return int.tryParse(digits);
    }
    return null;
  }

  Object _spoolCountAndExpectedJson(String countJson, String? expectedJson) {
    final Object decodedCount = jsonDecode(countJson);
    if (expectedJson == null || expectedJson.trim().isEmpty) {
      return decodedCount;
    }

    final Object? decodedExpected = jsonDecode(expectedJson);

    if (decodedCount is! Map) return decodedCount;
    if (decodedExpected is! Map) return decodedCount;

    final expectedByKey = <String, int>{};
    for (final MapEntry<dynamic, dynamic> entry in decodedExpected.entries) {
      final int? expectedValue = _toExpectedInt(entry.value);
      if (expectedValue == null) continue;
      expectedByKey[_normalizeExpectedKey(entry.key.toString())] =
          expectedValue;
    }

    if (expectedByKey.isEmpty) return decodedCount;

    final merged = <String, dynamic>{};
    for (final MapEntry<dynamic, dynamic> categoryEntry
        in decodedCount.entries) {
      final Object? categoryValue = categoryEntry.value;
      if (categoryValue is! Map) {
        merged[categoryEntry.key.toString()] = categoryValue;
        continue;
      }

      final mergedCategory = <String, dynamic>{};
      for (final MapEntry<dynamic, dynamic> itemEntry
          in categoryValue.entries) {
        final itemName = itemEntry.key.toString();
        final Object? itemValue = itemEntry.value;

        if (itemValue is! Map) {
          mergedCategory[itemName] = itemValue;
          continue;
        }

        final mergedItem = Map<String, dynamic>.from(itemValue);
        final omniName = mergedItem['omniName']?.toString();

        final String normalizedItemName = _normalizeExpectedKey(itemName);
        final String? normalizedOmniName = omniName == null
            ? null
            : _normalizeExpectedKey(omniName);

        final int? expectedValue =
            expectedByKey[normalizedOmniName] ??
            expectedByKey[normalizedItemName];

        if (expectedValue != null) {
          mergedItem['Expected'] = expectedValue;
        }

        mergedCategory[itemName] = mergedItem;
      }

      merged[categoryEntry.key.toString()] = mergedCategory;
    }

    return merged;
  }

  ({String? status, String? message}) _extractPrintStatus(String stdoutText) {
    const prefix = 'IC_PRINT_STATUS|';

    final List<String> lines = LineSplitter.split(stdoutText).toList();
    for (final String line in lines.reversed) {
      if (!line.startsWith(prefix)) continue;

      final String payload = line.substring(prefix.length);
      final List<String> parts = payload.split('|');
      if (parts.isEmpty) continue;

      final String status = parts.first.trim().toLowerCase();
      final String? message = parts.length > 1
          ? parts.sublist(1).join('|').trim()
          : null;

      return (status: status, message: message);
    }

    return (status: null, message: null);
  }

  Future<bool> printJson(
    BuildContext context,
    String json,
    String? expected,
  ) async {
    final windowModel = WindowModel();

    // Prompt user to locate Excel if not configured
    if (windowModel.countExcelPath == null ||
        !File(windowModel.countExcelPath!).existsSync()) {
      if (!context.mounted) return false;
      final bool? locate = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Locate Conc Inventory Count Sheet'),
          content: const Text(
            'Inventory Sheet path is not configured. '
            'Would you like to locate the Excel sheet?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Locate'),
            ),
          ],
        ),
      );

      if (locate != true) return false;

      final FilePickerResult? result = await FilePicker.pickFiles(
        dialogTitle: 'Select Excel sheet',
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'xlsm'],
      );
      final String? path = result?.files.single.path;
      if (path == null) return false;
      windowModel.countExcelPath = path;
    }

    if (!context.mounted) return false;

    final String printCountVbs = await DefaultAssetBundle.of(
      context,
    ).loadString('assets/PrintCount.vbs');

    if (!context.mounted) return false;

    final String vbsJsonVbs = await DefaultAssetBundle.of(
      context,
    ).loadString('assets/VbsJson.vbs');

    // Create temporary VBS script and JSON file
    final Directory tempDir = Directory.systemTemp;
    final File scriptFile = await File(
      '${tempDir.path}\\print_count_${DateTime.now().millisecondsSinceEpoch}.vbs',
    ).create();
    await scriptFile.writeAsString(printCountVbs);

    final File vbsJsonFile = await File(
      '${tempDir.path}\\vbs_json_${DateTime.now().millisecondsSinceEpoch}.vbs',
    ).create();
    await vbsJsonFile.writeAsString(vbsJsonVbs);

    final File jsonFile = await File(
      '${tempDir.path}\\count_${DateTime.now().millisecondsSinceEpoch}.json',
    ).create();
    final Object printPayload = _spoolCountAndExpectedJson(json, expected);
    await jsonFile.writeAsString(jsonEncode(printPayload));

    Process? proc;
    try {
      if (!Platform.isWindows) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Printing is only supported on Windows.'),
            ),
          );
        }
        return false;
      }

      proc = await Process.start('cscript', [
        '//Nologo',
        scriptFile.path,
        vbsJsonFile.path,
        windowModel.countExcelPath!,
        jsonFile.path,
      ]);
      CompanionProcessCancellation.registerPrintProcess(proc);

      final Future<String> stdoutData = proc.stdout
          .transform(utf8.decoder)
          .join();
      final Future<String> stderrData = proc.stderr
          .transform(utf8.decoder)
          .join();

      final int exitCode = await proc.exitCode;
      final String out = await stdoutData;
      final String err = await stderrData;
      final ({String? status, String? message}) scriptStatus =
          _extractPrintStatus(out);

      if (CompanionProcessCancellation.consumePrintCancelRequested()) {
        return false;
      }

      if (scriptStatus.status == 'cancelled') {
        return false;
      }

      if (scriptStatus.status == 'failed') {
        throw Exception(
          scriptStatus.message ?? 'Print failed: ${err.isNotEmpty ? err : out}',
        );
      }

      if (exitCode != 0) {
        throw Exception(
          'cscript failed (exit $exitCode): '
          '${scriptStatus.message ?? (err.isNotEmpty ? err : out)}',
        );
      }

      return true;
    } finally {
      if (proc != null) {
        CompanionProcessCancellation.clearPrintProcess(proc);
      }
      try {
        if (scriptFile.existsSync()) await scriptFile.delete();
      } on Exception {
        // On fail, do nothing
      }
      try {
        if (vbsJsonFile.existsSync()) await vbsJsonFile.delete();
      } on Exception {
        // On fail, do nothing
      }
      try {
        if (jsonFile.existsSync()) await jsonFile.delete();
      } on Exception {
        // On fail, do nothing
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Json>>(
        stream: _countsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            if (_isReloadingOffline) {
              return _buildNoInternetError(context);
            }
            return const Center(child: CircularProgressIndicator());
          }

          if (_isReloadingOffline) {
            _finishOfflineReload();
          }

          if (snapshot.hasError) {
            return _buildStreamError(context, snapshot.error);
          }

          final List<Json> counts = snapshot.data ?? [];
          if (counts.isEmpty) {
            return const Center(child: Text('No counts found.'));
          }

          return ListView.separated(
            itemCount: counts.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 36, endIndent: 36),
            itemBuilder: (context, index) {
              final Json count = counts[index];

              final String profile = count['profile'] ?? 'Default';
              final countName = (count['name'] ?? '').toString();
              final String formattedCountName = _formatCountName(countName);

              var time = '';
              if (count['updated_at'] != null) {
                final DateTime? dt = DateTime.tryParse(
                  count['updated_at'].toString(),
                )?.toLocal();

                if (dt != null) {
                  time = DateFormat.yMMMd().add_jm().format(dt);
                } else {
                  time = count['updated_at'].toString();
                }
              }

              final int totalSum = _sumTotals(count['json']);
              final String formattedSum = NumberFormat.decimalPattern().format(
                totalSum,
              );

              return ListTile(
                title: Text(
                  formattedCountName.isNotEmpty ? formattedCountName : 'Count',
                  overflow: TextOverflow.ellipsis,
                ),
                leading: Icon(
                  Profile(profile).icon,
                  color: Profile(profile).color,
                ),
                subtitle: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: profile,
                        style: TextStyle(color: Profile(profile).color),
                      ),
                      TextSpan(
                        text: ' • Updated: $time',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      TextSpan(
                        text: ' • $formattedSum counted',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                onTap: () async {
                  try {
                    if (!context.mounted) return;
                    final hostContext = context;
                    await showDialog(
                      context: context,
                      builder: (context) => InventoryCountActionsDialog(
                        countKey: countName,
                        countName: formattedCountName,
                        hostContext: hostContext,
                        onPrintJson: printJson,
                      ),
                    );
                  } on Exception catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Download failed: $e')),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
