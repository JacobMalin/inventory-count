import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveErrorPage extends StatefulWidget {
  final String errorMessage;

  const HiveErrorPage({super.key, required this.errorMessage});

  @override
  State<HiveErrorPage> createState() => _HiveErrorPageState();
}

class _HiveErrorPageState extends State<HiveErrorPage> {
  bool _isDeleting = false;
  String? _statusMessage;
  bool _isChecking = true;

  final Map<String, bool> _boxesToDelete = {
    'areas': false,
    'counts': false,
    'settings': false,
  };

  final Map<String, String> _boxDescriptions = {
    'areas': 'Area, Shelf, and Item definitions',
    'counts': 'Count data and history',
    'settings': 'App settings and preferences',
  };

  @override
  void initState() {
    super.initState();
    _checkBoxes();
  }

  Future<void> _checkBoxes() async {
    setState(() {
      _isChecking = true;
      _statusMessage = 'Checking which boxes are corrupted...';
    });

    try {
      await Hive.close();
      await Hive.initFlutter('inventory_count');

      for (final boxName in _boxesToDelete.keys) {
        bool isCorrupted = false;
        try {
          if (boxName == 'counts') {
            await Hive.openBox<dynamic>(boxName);
          } else {
            await Hive.openBox(boxName);
          }
          await Hive.box(boxName).close();
        } catch (e) {
          isCorrupted = true;
        }

        setState(() {
          _boxesToDelete[boxName] = isCorrupted;
        });
      }

      final corruptedCount = _boxesToDelete.values.where((v) => v).length;
      setState(() {
        _isChecking = false;
        if (corruptedCount > 0) {
          _statusMessage =
              'Found $corruptedCount corrupted box(es). Please review and delete.';
        } else {
          _statusMessage =
              'No corrupted boxes detected. The error may be elsewhere.';
        }
      });
    } catch (e) {
      setState(() {
        _isChecking = false;
        _statusMessage = 'Unable to check boxes. You may need to delete all.';
        // If we can't check, select all by default
        _boxesToDelete.updateAll((key, value) => true);
      });
    }
  }

  Future<void> _deleteHiveData() async {
    final selectedBoxes = _boxesToDelete.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedBoxes.isEmpty) {
      setState(() {
        _statusMessage = 'Please select at least one box to delete.';
      });
      return;
    }

    setState(() {
      _isDeleting = true;
      _statusMessage = 'Deleting selected Hive boxes...';
    });

    try {
      // Close all open boxes
      await Hive.close();

      // Reinitialize Hive
      await Hive.initFlutter('inventory_count');

      int deletedCount = 0;

      for (final boxName in selectedBoxes) {
        try {
          // Use Hive's built-in method to delete the box
          await Hive.deleteBoxFromDisk(boxName);
          deletedCount++;
        } catch (e) {
          // Continue with other boxes even if one fails
          setState(() {
            _statusMessage = 'Warning: Failed to delete $boxName: $e';
          });
        }
      }

      setState(() {
        if (deletedCount > 0) {
          _statusMessage = 'Successfully deleted $deletedCount box(es)!';
        } else {
          _statusMessage = 'No boxes were deleted.';
        }
      });

      // Wait a moment before restarting
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _statusMessage = 'Please restart the app to continue.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error deleting data: $e';
      });
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 18, 75, 99),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Failed to Initialize Database',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'The app encountered an error while loading the database. This may be due to corrupted data.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withAlpha(76),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade700),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Error Details:',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.errorMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select boxes to delete:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ..._boxesToDelete.keys.map((boxName) {
                  return CheckboxListTile(
                    title: Text(boxName),
                    subtitle: Text(
                      _boxDescriptions[boxName] ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    value: _boxesToDelete[boxName],
                    onChanged: (_isDeleting || _isChecking)
                        ? null
                        : (value) {
                            setState(() {
                              _boxesToDelete[boxName] = value ?? false;
                            });
                          },
                    activeColor: Theme.of(context).colorScheme.errorContainer,
                    checkColor: Theme.of(context).colorScheme.onErrorContainer,
                  );
                }),
                const SizedBox(height: 16),
                if (_statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _statusMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _statusMessage!.contains('Successfully')
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: (_isDeleting || _isChecking)
                      ? null
                      : _deleteHiveData,
                  icon: (_isDeleting || _isChecking)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_forever),
                  label: Text(
                    _isChecking
                        ? 'Checking...'
                        : (_isDeleting
                              ? 'Deleting...'
                              : 'Delete Selected Boxes'),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.errorContainer,
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '⚠️ Warning: This will permanently delete the selected data!',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.orange),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
