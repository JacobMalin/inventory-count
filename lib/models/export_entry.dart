import 'package:hive_flutter/hive_flutter.dart';

part 'export_entry.g.dart';

void registerExportEntryAdapters() {
  Hive.registerAdapter(ExportItemAdapter());
  Hive.registerAdapter(ExportPlaceholderAdapter());
  Hive.registerAdapter(ExportTitleAdapter());
}

abstract class ExportEntry {
  String get name;
  set name(String value);

  Map<String, dynamic> toJson();

  static final Map<String, ExportEntry Function(Map<String, dynamic>)>
  _registry = {
    'ExportItem': ExportItem.fromJson,
    'ExportPlaceholder': ExportPlaceholder.fromJson,
    'ExportTitle': ExportTitle.fromJson,
  };

  factory ExportEntry.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final constructor = _registry[type];

    if (constructor == null) {
      throw Exception('Unknown ExportEntry type: $type');
    }

    return constructor(json);
  }
}

@HiveType(typeId: 7)
class ExportItem extends HiveObject implements ExportEntry {
  @override
  @HiveField(0)
  String name;

  @HiveField(1)
  List<String> paths;

  ExportItem(this.name, {List<String>? paths}) : paths = paths ?? [];

  @override
  Map<String, dynamic> toJson() {
    return {'type': 'ExportItem', 'name': name, 'paths': paths};
  }

  static ExportItem fromJson(Map<String, dynamic> json) {
    final pathsList = json['paths'];
    return ExportItem(
      json['name'] as String? ?? '',
      paths: pathsList is List ? pathsList.whereType<String>().toList() : [],
    );
  }
}

@HiveType(typeId: 8)
class ExportPlaceholder extends HiveObject implements ExportEntry {
  @override
  @HiveField(0)
  String name;

  ExportPlaceholder(this.name);

  @override
  Map<String, dynamic> toJson() {
    return {'type': 'ExportPlaceholder', 'name': name};
  }

  static ExportPlaceholder fromJson(Map<String, dynamic> json) {
    return ExportPlaceholder(json['name'] as String? ?? '');
  }
}

@HiveType(typeId: 9)
class ExportTitle extends HiveObject implements ExportEntry {
  @override
  @HiveField(0)
  String name;

  ExportTitle(this.name);

  @override
  Map<String, dynamic> toJson() {
    return {'type': 'ExportTitle', 'name': name};
  }

  static ExportTitle fromJson(Map<String, dynamic> json) {
    return ExportTitle(json['name'] as String? ?? '');
  }
}
