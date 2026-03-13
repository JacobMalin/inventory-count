import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/types/json.dart';

class NotesDayData {
  const NotesDayData({required this.text});

  const NotesDayData.empty() : text = '';

  final String text;

  bool get isEmpty => text.trim().isEmpty;

  NotesDayData copyWith({String? text}) {
    return NotesDayData(text: text ?? this.text);
  }
}

abstract class NotesLocalRepository {
  NotesDayData readNotesForDay(DateTime day);
  Future<void> writeNotesForDay(DateTime day, NotesDayData data);
}

class HiveNotesLocalRepository implements NotesLocalRepository {
  HiveNotesLocalRepository({Box<dynamic>? notesBox})
    : _notesBox = notesBox ?? Hive.box('notes');

  final Box<dynamic> _notesBox;

  DateFormat keyDateFormat = DateFormat('yyyy-MM-dd');

  NotesDayData _parseDayData(Json raw) {
    final String text = raw['text']?.toString() ?? '';
    return NotesDayData(text: text);
  }

  @override
  NotesDayData readNotesForDay(DateTime day) {
    final dynamic raw = _notesBox.get(keyDateFormat.format(day));
    if (raw is Map) {
      return _parseDayData(Json.from(raw));
    } else {
      return const NotesDayData.empty();
    }
  }

  @override
  Future<void> writeNotesForDay(DateTime day, NotesDayData data) {
    final String dayKey = keyDateFormat.format(day);
    if (data.isEmpty) {
      return _notesBox.delete(dayKey);
    }

    return _notesBox.put(dayKey, <String, dynamic>{'text': data.text});
  }
}
