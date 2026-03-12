import 'package:hive_flutter/hive_flutter.dart';

import '../../core/types/json.dart';

class NotesChecklistItem {
  const NotesChecklistItem({required this.label, required this.checked});

  factory NotesChecklistItem.fromJson(Map<dynamic, dynamic> json) {
    return NotesChecklistItem(
      label: json['label']?.toString() ?? '',
      checked: json['checked'] == true,
    );
  }

  final String label;
  final bool checked;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'label': label, 'checked': checked};
  }

  NotesChecklistItem copyWith({String? label, bool? checked}) {
    return NotesChecklistItem(
      label: label ?? this.label,
      checked: checked ?? this.checked,
    );
  }
}

class NotesDayData {
  const NotesDayData({required this.text, required this.checklist});

  const NotesDayData.empty()
    : text = '',
      checklist = const <NotesChecklistItem>[];

  final String text;
  final List<NotesChecklistItem> checklist;

  bool get isEmpty => text.trim().isEmpty && checklist.isEmpty;

  NotesDayData copyWith({String? text, List<NotesChecklistItem>? checklist}) {
    return NotesDayData(
      text: text ?? this.text,
      checklist: checklist ?? this.checklist,
    );
  }
}

abstract class NotesLocalRepository {
  Future<void> ensureInitialized();

  NotesDayData readNotesForDay(String dayKey);
  Future<void> writeNotesForDay(String dayKey, NotesDayData data);
}

class HiveNotesLocalRepository implements NotesLocalRepository {
  HiveNotesLocalRepository({Box<dynamic>? notesBox})
    : _notesBox = notesBox ?? Hive.box('notes');

  static const String _dayPrefix = 'day:';

  final Box<dynamic> _notesBox;

  String _storageKey(String dayKey) => '$_dayPrefix$dayKey';

  NotesDayData _parseDayData(Json raw) {
    final String text = raw['text']?.toString() ?? '';
    final dynamic rawChecklist = raw['checklist'];
    final List<NotesChecklistItem> checklist = rawChecklist is List
        ? rawChecklist
              .whereType<Map>()
              .map(NotesChecklistItem.fromJson)
              .toList()
        : <NotesChecklistItem>[];
    return NotesDayData(text: text, checklist: checklist);
  }

  @override
  Future<void> ensureInitialized() async {
    // No legacy migration needed
    return;
  }

  @override
  NotesDayData readNotesForDay(String dayKey) {
    final dynamic raw = _notesBox.get(_storageKey(dayKey));
    if (raw is Json) {
      return _parseDayData(raw);
    } else {
      return const NotesDayData.empty();
    }
  }

  @override
  Future<void> writeNotesForDay(String dayKey, NotesDayData data) {
    if (data.isEmpty) {
      return _notesBox.delete(_storageKey(dayKey));
    }

    return _notesBox.put(_storageKey(dayKey), <String, dynamic>{
      'text': data.text,
      'checklist': data.checklist.map((item) => item.toJson()).toList(),
    });
  }
}
