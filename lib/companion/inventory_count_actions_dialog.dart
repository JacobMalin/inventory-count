import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/types/json.dart';
import '../main/models/data/inventory_models.dart';
import 'omniterm_interaction.dart';
import 'process_cancellation.dart';

class InventoryCountActionsDialog extends StatefulWidget {
  const InventoryCountActionsDialog({
    required String countKey,
    required String countName,
    required BuildContext hostContext,
    required Future<bool> Function(BuildContext, String, String?) onPrintJson,
    super.key,
  }) : _onPrintJson = onPrintJson,
       _hostContext = hostContext,
       _countKey = countKey,
       _countName = countName;

  final String _countKey;
  final String _countName;
  final BuildContext _hostContext;
  final Future<bool> Function(
    BuildContext context,
    String json,
    String? expectedJson,
  )
  _onPrintJson;

  @override
  State<InventoryCountActionsDialog> createState() =>
      _InventoryCountActionsDialogState();
}

class _InventoryCountActionsDialogState
    extends State<InventoryCountActionsDialog> {
  bool _isFillingOut = false;
  bool _fillExitedWithError = false;
  Widget? _buildFillMessage;
  bool _isPrinting = false;
  Widget? _buildPrintMessage;
  bool _shouldExitAfterFill = false;
  bool _isFillThenPrintRunning = false;
  bool _isCanceling = false;
  bool _cancelRequested = false;
  final FocusNode _keyboardFocusNode = FocusNode();
  bool _isControlPressed = false;
  late final Stream<List<Json>> _countStream;

  String? _currentExpectedJsonString;

  bool get _isAnyActionRunning =>
      _isFillingOut || _isPrinting || _isFillThenPrintRunning;

  void _updateControlPressedFromKeyboardState() {
    final Set<LogicalKeyboardKey> keys =
        HardwareKeyboard.instance.logicalKeysPressed;
    final bool nextPressed =
        keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);

    if (_isControlPressed != nextPressed && mounted) {
      setState(() {
        _isControlPressed = nextPressed;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _updateControlPressedFromKeyboardState();
    _countStream = Supabase.instance.client
        .from('counts')
        .stream(primaryKey: ['name'])
        .eq('name', widget._countKey);
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<bool> _handleFillOut(Profile profile, String jsonString) async {
    if (mounted) {
      setState(() {
        _isFillingOut = true;
        _fillExitedWithError = false;
        _buildFillMessage = const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Flexible(child: Text('Filling out Omniterm...')),
          ],
        );
      });
    }

    Map<String, int> expected;
    var success = false;
    try {
      expected = await OmnitermInteraction.fillOutCount(jsonString);
      success = true;

      await Supabase.instance.client
          .from('counts')
          .update(<String, dynamic>{
            'expected': expected,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('name', widget._countKey)
          .eq('profile', profile.name);
      _currentExpectedJsonString = jsonEncode(expected);

      if (mounted) {
        setState(() {
          _buildFillMessage = const Text('Omniterm autofill completed.');
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _buildFillMessage = Text(
            'Fill failed: $e',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          );
          _shouldExitAfterFill = false;
          _fillExitedWithError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFillingOut = false;
        });
      }

      if (_shouldExitAfterFill) {
        if (mounted) Navigator.of(context).pop();

        if (widget._hostContext.mounted) {
          ScaffoldMessenger.of(widget._hostContext).showSnackBar(
            const SnackBar(
              content: Text('Print and fill completed. Exiting...'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        await Future.delayed(const Duration(seconds: 2));
        exit(0);
      }
    }

    return success;
  }

  Future<bool> _handlePrint(String jsonString) async {
    if (mounted) {
      setState(() {
        _isPrinting = true;
        _buildPrintMessage = const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Flexible(child: Text('Printing...')),
          ],
        );
      });
    }

    var success = false;
    try {
      success = await widget._onPrintJson(
        widget._hostContext,
        jsonString,
        _currentExpectedJsonString,
      );

      if (mounted) {
        setState(() {
          _buildPrintMessage = Text(
            success ? 'Print completed.' : 'Print canceled.',
          );
        });
      }

      if (success) {
        if (_isFillingOut) {
          if (mounted) {
            setState(() {
              _shouldExitAfterFill = true;
            });
          }
        } else if (!_fillExitedWithError) {
          if (mounted) Navigator.of(context).pop();

          if (widget._hostContext.mounted) {
            ScaffoldMessenger.of(widget._hostContext).showSnackBar(
              const SnackBar(
                content: Text('Print completed. Exiting...'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }

          await Future.delayed(const Duration(seconds: 2));
          exit(0);
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _buildPrintMessage = Text(
            'Print failed: $e',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }

    return success;
  }

  Future<void> _handleFillThenPrint(Profile profile, String jsonString) async {
    if (mounted) {
      setState(() {
        _isFillThenPrintRunning = true;
        _cancelRequested = false;
      });
    }

    try {
      final bool fillSuccess = await _handleFillOut(profile, jsonString);
      if (!fillSuccess || _cancelRequested) return;
      await _handlePrint(jsonString);
    } finally {
      if (mounted) {
        setState(() {
          _isFillThenPrintRunning = false;
          _cancelRequested = false;
        });
      }
    }
  }

  Future<void> _handleCancelPressed() async {
    if (!_isAnyActionRunning) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (mounted) {
      setState(() {
        _isCanceling = true;
        _cancelRequested = true;
        if (_isFillingOut) {
          _buildFillMessage ??= const Text('Canceling fill...');
        }
        if (_isPrinting) {
          _buildPrintMessage ??= const Text('Canceling print...');
        }
      });
    }

    try {
      await OmnitermInteraction.cancelFillOutCount();
      await CompanionProcessCancellation.cancelPrintProcess();
    } finally {
      if (mounted) {
        setState(() {
          _isCanceling = false;
        });
      }
    }
  }

  Future<void> _handlePopInvoked(bool didPop) async {
    if (didPop || _isCanceling) {
      return;
    }

    if (_isAnyActionRunning) {
      await _handleCancelPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isAnyActionRunning && !_isCanceling,
      onPopInvokedWithResult: (didPop, _) => _handlePopInvoked(didPop),
      child: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: (_) => _updateControlPressedFromKeyboardState(),
        child: StreamBuilder<List<Json>>(
          stream: _countStream,
          builder: (context, asyncSnapshot) {
            if (!asyncSnapshot.hasData ||
                asyncSnapshot.data == null ||
                asyncSnapshot.data!.isEmpty) {
              return AlertDialog(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                title: Text(widget._countName),
                content: const Center(
                  heightFactor: 1,
                  child: CircularProgressIndicator(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            }

            final Json count = asyncSnapshot.data!.first;

            final profile = Profile(count['profile'] ?? 'Default');

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

            final String jsonString = count['json'] is String
                ? count['json'] as String
                : jsonEncode(count['json']);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              final String? newExpected = count['expected'] == null
                  ? null
                  : count['expected'] is String
                  ? count['expected'] as String
                  : jsonEncode(count['expected']);
              if (_currentExpectedJsonString != newExpected) {
                _currentExpectedJsonString = newExpected;
              }
            });

            return AlertDialog(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget._countName.isNotEmpty ? widget._countName : time),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(profile.icon, size: 16, color: profile.color),
                      const SizedBox(width: 6),
                      Text(
                        profile.name,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: profile.color),
                      ),
                    ],
                  ),
                ],
              ),
              content: Builder(
                builder: (context) {
                  if (_buildFillMessage != null || _buildPrintMessage != null) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 16,
                      children: [
                        // Hive analyzer version doesnt support null aware
                        // operator
                        // ignore: use_null_aware_elements
                        if (_buildFillMessage != null) _buildFillMessage!,
                        // Hive analyzer version doesnt support null aware
                        // operator
                        // ignore: use_null_aware_elements
                        if (_buildPrintMessage != null) _buildPrintMessage!,
                      ],
                    );
                  }

                  return Text(
                    'Would you like to print the count or fill out Omniterm '
                    'with the count updated on $time?',
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: _isCanceling ? null : _handleCancelPressed,
                  child: const Text('Cancel'),
                ),
                if (_isControlPressed)
                  TextButton(
                    onPressed: _isAnyActionRunning || _isCanceling
                        ? null
                        : () => _handleFillThenPrint(profile, jsonString),
                    child: const Text('Fill Out Omniterm + Print'),
                  )
                else ...[
                  TextButton(
                    onPressed:
                        _isFillingOut || _isFillThenPrintRunning || _isCanceling
                        ? null
                        : () => _handleFillOut(profile, jsonString),
                    child: const Text('Fill Out Omniterm'),
                  ),
                  TextButton(
                    onPressed:
                        _isPrinting || _isFillThenPrintRunning || _isCanceling
                        ? null
                        : () => _handlePrint(jsonString),
                    child: const Text('Print'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
