import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/count_model.dart';
import '../repositories/notes_local_repository.dart';

class NotesToolPage extends StatefulWidget {
  const NotesToolPage({super.key});

  @override
  State<NotesToolPage> createState() => _NotesToolPageState();
}

class _NotesToolPageState extends State<NotesToolPage> {
  static const String _uncheckedBox = '☐';
  static const String _checkedBox = '☑';

  late final _NotesEditingController _controller;
  final FocusNode _notesFocusNode = FocusNode();
  late final NotesLocalRepository _notesRepository;
  bool _isAdjustingSelection = false;
  int _prevOffset = 0;

  @override
  void initState() {
    super.initState();
    _controller = _NotesEditingController(
      uncheckedBox: _uncheckedBox,
      checkedBox: _checkedBox,
      onCheckboxTap: (index) => _toggleCheckboxAtIndex(
        context.read<CountModel>().selectedDate,
        index,
      ),
    );
    _controller.addListener(_normalizeSelection);
    _notesRepository = context.read<NotesLocalRepository>();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_normalizeSelection)
      ..dispose();
    super.dispose();
  }

  void _ensureControllerForDay(DateTime day) {
    final NotesDayData noteData = _notesRepository.readNotesForDay(day);
    final String editorText = _buildEditorText(noteData);
    _controller.value = TextEditingValue(
      text: editorText,
      selection: TextSelection.collapsed(offset: editorText.length),
    );
  }

  String _buildEditorText(NotesDayData data) {
    final sections = <String>[];
    if (data.text.isNotEmpty) {
      sections.add(data.text);
    }

    return sections.join('\n');
  }

  void _onNoteChanged(DateTime day, String note) {
    final updated = NotesDayData(text: note);
    unawaited(_notesRepository.writeNotesForDay(day, updated));
  }

  void _insertCheckbox(DateTime day) {
    final TextSelection selection = _controller.selection;
    final String text = _controller.text;
    final int cursorOffset = selection.isValid ? selection.start : text.length;
    final int lineStart = cursorOffset <= 0
        ? 0
        : text.lastIndexOf('\n', cursorOffset - 1) + 1;
    final bool hasUncheckedPrefix = text.startsWith(_uncheckedBox, lineStart);
    final bool hasCheckedPrefix = text.startsWith(_checkedBox, lineStart);

    late final String updatedText;
    late final int updatedCursorOffset;

    if (hasUncheckedPrefix || hasCheckedPrefix) {
      updatedText = text.replaceRange(lineStart, lineStart + 1, '');
      updatedCursorOffset = cursorOffset >= lineStart + 1
          ? cursorOffset - 1
          : lineStart;
    } else {
      const String insertion = _uncheckedBox;
      updatedText = text.replaceRange(lineStart, lineStart, insertion);
      updatedCursorOffset = cursorOffset + insertion.length;
    }

    // Preserve composing region if present to avoid cursor disappearance
    final TextRange composing = _controller.value.composing;
    _controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: updatedCursorOffset),
      composing: composing,
    );
    _onNoteChanged(day, updatedText);
    // Request focus to keep cursor visible
    _notesFocusNode.requestFocus();
  }

  void _toggleCheckboxAtIndex(DateTime day, int index) {
    final String text = _controller.text;
    if (index < 0 || index >= text.length) {
      return;
    }

    final String current = text[index];
    if (current != _uncheckedBox && current != _checkedBox) {
      return;
    }

    final String replacement = current == _checkedBox
        ? _uncheckedBox
        : _checkedBox;
    final String updatedText =
        text.substring(0, index) + replacement + text.substring(index + 1);

    _controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: index + 1),
    );
    _onNoteChanged(day, updatedText);
  }

  void _normalizeSelection() {
    if (_isAdjustingSelection) {
      return;
    }

    final TextSelection selection = _controller.selection;
    if (!selection.isValid) {
      _prevOffset = selection.baseOffset;
      return;
    }

    final String text = _controller.text;
    // Determine direction: left if offset decreased, right if increased
    final int currOffset = selection.baseOffset;
    final bool movingLeft = currOffset < _prevOffset;
    final bool movingRight =
        currOffset > _prevOffset ||
        (_prevOffset == currOffset && _prevOffset == 1);

    final normalized = TextSelection(
      baseOffset: _normalizedOffset(
        text,
        selection.baseOffset,
        movingLeft,
        movingRight,
      ),
      extentOffset: _normalizedOffset(
        text,
        selection.extentOffset,
        movingLeft,
        movingRight,
      ),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );

    _prevOffset = _normalizedOffset(
      text,
      selection.extentOffset,
      movingLeft,
      movingRight,
    );

    if (normalized == selection) {
      return;
    }

    _isAdjustingSelection = true;
    _controller.selection = normalized;
    _isAdjustingSelection = false;
  }

  int _normalizedOffset(
    String text,
    int offset,
    bool movingLeft,
    bool movingRight,
  ) {
    if (offset < 0 || offset > text.length) return offset;

    final String? textAtOffset = (offset >= 0 && offset < text.length)
        ? text[offset]
        : null;
    if (textAtOffset == null) return offset;

    final bool isBeforeCheckbox =
        offset >= 0 &&
        (textAtOffset == _uncheckedBox || textAtOffset == _checkedBox);

    if (isBeforeCheckbox) {
      if (offset == 0) offset = 2;
      return movingRight ? offset + 1 : offset - 1;
    }

    return offset;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CountModel>(
      builder: (context, countModel, child) {
        final DateTime selectedDate = countModel.selectedDate;
        final String formattedDate = MaterialLocalizations.of(
          context,
        ).formatMediumDate(selectedDate);

        // Ensure controller is updated for the selected day
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureControllerForDay(selectedDate);
        });

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.checklist),
                onPressed: () => _insertCheckbox(selectedDate),
              ),
            ],
            title: Text('Notes for $formattedDate'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              focusNode: _notesFocusNode,
              controller: _controller,
              inputFormatters: [
                _CheckboxLineStartFormatter(
                  uncheckedBox: _uncheckedBox,
                  checkedBox: _checkedBox,
                ),
              ],
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              autocorrect: true,
              onChanged: (value) => _onNoteChanged(selectedDate, value),
              decoration: const InputDecoration(
                hintText: 'Enter notes for this day',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckboxLineStartFormatter extends TextInputFormatter {
  _CheckboxLineStartFormatter({
    required this.uncheckedBox,
    required this.checkedBox,
  });

  final String uncheckedBox;
  final String checkedBox;

  TextEditingValue _maybeContinueCheckboxLine(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final TextSelection oldSelection = oldValue.selection;
    final TextSelection newSelection = newValue.selection;
    if (!oldSelection.isValid ||
        !newSelection.isValid ||
        !oldSelection.isCollapsed ||
        !newSelection.isCollapsed) {
      return newValue;
    }

    final int insertionOffset = oldSelection.baseOffset;
    if (insertionOffset < 0 || insertionOffset > oldValue.text.length) {
      return newValue;
    }

    final bool isSimpleNewlineInsertion =
        newValue.text.length == oldValue.text.length + 1 &&
        newValue.text[insertionOffset] == '\n' &&
        newValue.text ==
            '${oldValue.text.substring(0, insertionOffset)}\n'
                '${oldValue.text.substring(insertionOffset)}';
    if (!isSimpleNewlineInsertion) {
      return newValue;
    }

    final int lineStart = insertionOffset <= 0
        ? 0
        : oldValue.text.lastIndexOf('\n', insertionOffset - 1) + 1;
    final bool lineStartsWithCheckbox =
        oldValue.text.startsWith(uncheckedBox, lineStart) ||
        oldValue.text.startsWith(checkedBox, lineStart);
    if (!lineStartsWithCheckbox) {
      return newValue;
    }

    // If the line contains only a checkbox, remove it on Enter
    final String line = oldValue.text.substring(lineStart, insertionOffset);
    final bool onlyCheckbox = line == uncheckedBox || line == checkedBox;
    String continuedText;
    int newOffset;
    if (onlyCheckbox) {
      // Remove the checkbox and the newline
      // Find the previous newline
      final int prevNewline = oldValue.text.lastIndexOf(
        '\n',
        insertionOffset - 1,
      );
      // Remove from previous newline (or start) to insertionOffset
      final int removeStart = prevNewline == -1 ? 0 : prevNewline + 1;
      continuedText =
          oldValue.text.substring(0, removeStart) +
          oldValue.text.substring(insertionOffset);
      newOffset = removeStart;
    } else {
      // Continue with a checkbox
      final String insertion = uncheckedBox;
      continuedText = newValue.text.replaceRange(
        insertionOffset + 1,
        insertionOffset + 1,
        insertion,
      );
      newOffset = newSelection.baseOffset + insertion.length;
    }

    return newValue.copyWith(
      text: continuedText,
      selection: TextSelection.collapsed(offset: newOffset),
      composing: TextRange.empty,
    );
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final TextEditingValue processedValue = _maybeContinueCheckboxLine(
      oldValue,
      newValue,
    );

    for (final String line in processedValue.text.split('\n')) {
      for (var index = 0; index < line.length; index += 1) {
        final String character = line[index];
        if (character != uncheckedBox && character != checkedBox) {
          continue;
        }

        if (index != 0) {
          return oldValue;
        }
      }
    }

    return processedValue;
  }
}

class _NotesEditingController extends TextEditingController {
  _NotesEditingController({
    required this.uncheckedBox,
    required this.checkedBox,
    required this.onCheckboxTap,
  });

  final String uncheckedBox;
  final String checkedBox;
  final void Function(int index) onCheckboxTap;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final TextStyle resolvedStyle = style ?? DefaultTextStyle.of(context).style;
    final spans = <InlineSpan>[];
    var segmentStart = 0;

    for (var index = 0; index < text.length; index += 1) {
      final String character = text[index];
      if (character != uncheckedBox && character != checkedBox) {
        continue;
      }

      if (segmentStart < index) {
        spans.add(
          TextSpan(
            text: text.substring(segmentStart, index),
            style: resolvedStyle,
          ),
        );
      }

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 1),
            child: Transform.scale(
              scale: 0.9,
              child: Checkbox(
                key: ValueKey(index),
                value: character == checkedBox,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(color: resolvedStyle.color ?? Colors.white),
                onChanged: (_) => onCheckboxTap(index),
              ),
            ),
          ),
        ),
      );

      segmentStart = index + 1;
    }

    if (segmentStart < text.length) {
      spans.add(
        TextSpan(text: text.substring(segmentStart), style: resolvedStyle),
      );
    }

    return TextSpan(style: resolvedStyle, children: spans);
  }
}
