import 'package:hive_flutter/hive_flutter.dart';

part 'export_entry.g.dart';

void registerExportEntryAdapters() {
  Hive
    ..registerAdapter<ExportItem>(ExportItemAdapter())
    ..registerAdapter<ExportTitle>(ExportTitleAdapter());
}

abstract class ExportEntry {
  factory ExportEntry.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final ExportEntry Function(Map<String, dynamic>)? constructor =
        _registry[type];

    if (constructor == null) {
      throw Exception('Unknown ExportEntry type: $type');
    }

    return constructor(json);
  }

  String get name;
  set name(String value);

  bool get isHidden;
  set isHidden(bool value);

  Map<String, dynamic> toJson();

  static final Map<String, ExportEntry Function(Map<String, dynamic>)>
  _registry = {
    'ExportItem': ExportItem.fromJson,
    'ExportPlaceholder': ExportItem.fromJson, // For backward compatibility
    'ExportTitle': ExportTitle.fromJson,
  };
}

@HiveType(typeId: 7)
class ExportItem extends HiveObject implements ExportEntry {
  ExportItem(this.name, {bool? isHidden}) : isHidden = isHidden ?? false;

  factory ExportItem.fromJson(Map<String, dynamic> json) {
    return ExportItem(
      json['name'] as String? ?? '',
      isHidden: json['isHidden'] as bool? ?? false,
    );
  }

  @override
  @HiveField(0)
  String name;

  @override
  @HiveField(1)
  bool isHidden = false;

  @override
  Map<String, dynamic> toJson() {
    return {'type': 'ExportItem', 'name': name, 'isHidden': isHidden};
  }
}

@HiveType(typeId: 9)
class ExportTitle extends HiveObject implements ExportEntry {
  ExportTitle(this.name, {bool? isHidden}) : isHidden = isHidden ?? false;

  factory ExportTitle.fromJson(Map<String, dynamic> json) {
    return ExportTitle(
      json['name'] as String? ?? '',
      isHidden: json['isHidden'] as bool? ?? false,
    );
  }

  @override
  @HiveField(0)
  String name;

  @override
  @HiveField(1)
  bool isHidden = false;

  @override
  Map<String, dynamic> toJson() {
    return {'type': 'ExportTitle', 'name': name, 'isHidden': isHidden};
  }
}
