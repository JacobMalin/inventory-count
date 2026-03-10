import 'dart:io';

import 'package:flutter/material.dart';

import '../main/models/data/inventory_models.dart';
import 'omniterm_interaction.dart';

class InventoryCountActionsDialog extends StatefulWidget {
  const InventoryCountActionsDialog({
    required String countName,
    required String time,
    required String profile,
    required String jsonString,
    required BuildContext hostContext,
    required Future<bool> Function(BuildContext, String) onPrintJson,
    super.key,
  }) : _onPrintJson = onPrintJson,
       _hostContext = hostContext,
       _jsonString = jsonString,
       _profile = profile,
       _time = time,
       _countName = countName;

  final String _countName;
  final String _time;
  final String _profile;
  final String _jsonString;
  final BuildContext _hostContext;
  final Future<bool> Function(BuildContext context, String json) _onPrintJson;

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

  Future<void> _handleFillOut() async {
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

    var success = false;
    try {
      success = await OmnitermInteraction.fillOutCount(widget._jsonString);

      if (mounted) {
        setState(() {
          _buildFillMessage = Text(
            success
                ? 'Omniterm autofill completed.'
                : 'Omniterm autofill canceled.',
          );
          _fillExitedWithError = !success;
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

      if (_shouldExitAfterFill && success) {
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
  }

  Future<void> _handlePrint() async {
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
        widget._jsonString,
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
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget._countName.isNotEmpty ? widget._countName : widget._time),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Profile(widget._profile).icon,
                size: 16,
                color: Profile(widget._profile).color,
              ),
              const SizedBox(width: 6),
              Text(
                widget._profile,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Profile(widget._profile).color,
                ),
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
                // Hive analyzer version doesnt support null aware operator
                // ignore: use_null_aware_elements
                if (_buildFillMessage != null) _buildFillMessage!,
                // Hive analyzer version doesnt support null aware operator
                // ignore: use_null_aware_elements
                if (_buildPrintMessage != null) _buildPrintMessage!,
              ],
            );
          }

          return Text(
            'Would you like to print the count or fill out Omniterm with the '
            'count updated on ${widget._time}?',
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: _isFillingOut || _isPrinting
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isFillingOut ? null : _handleFillOut,
          child: const Text('Fill Out Omniterm'),
        ),
        TextButton(
          onPressed: _isPrinting ? null : _handlePrint,
          child: const Text('Print'),
        ),
      ],
    );
  }
}
