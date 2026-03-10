import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/types/json.dart';

part 'export_entry.g.dart';

void registerExportEntryAdapters() {
  Hive
    ..registerAdapter<ExportItem>(ExportItemAdapter())
    ..registerAdapter<ExportTitle>(ExportTitleAdapter());
}

abstract class ExportEntry {
  factory ExportEntry.fromJson(Json json) {
    final type = json['type'] as String?;
    final ExportEntry Function(Json)? constructor = _registry[type];

    if (constructor == null) {
      throw Exception('Unknown ExportEntry type: $type');
    }

    return constructor(json);
  }

  String get name;
  set name(String value);

  bool get isHidden;
  set isHidden(bool value);

  bool get isNotCounted;
  set isNotCounted(bool value);

  String get entryType;

  static ({String name, bool isHidden, bool isNotCounted}) parseCommonFields(
    Json json,
  ) => (
    name: json['name'] as String? ?? '',
    isHidden: json['isHidden'] as bool? ?? false,
    isNotCounted: json['isNotCounted'] as bool? ?? false,
  );

  Json toJson();

  static Json toJsonFrom(ExportEntry entry) => {
    'type': entry.entryType,
    'name': entry.name,
    'isHidden': entry.isHidden,
    'isNotCounted': entry.isNotCounted,
  };

  static final Map<String, ExportEntry Function(Json)> _registry = {
    'ExportItem': ExportItem.fromJson,
    'ExportPlaceholder': ExportItem.fromJson, // For backward compatibility
    'ExportTitle': ExportTitle.fromJson,
  };
}

@HiveType(typeId: 7)
class ExportItem extends HiveObject implements ExportEntry {
  ExportItem(
    this.name, {
    this.isHidden = false,
    this.isNotCounted = false,
    this.omniName,
  });

  factory ExportItem.fromJson(Json json) {
    final ({bool isHidden, bool isNotCounted, String name}) fields =
        ExportEntry.parseCommonFields(json);
    return ExportItem(
      fields.name,
      isHidden: fields.isHidden,
      isNotCounted: fields.isNotCounted,
      omniName: json['omniName'] as String?,
    );
  }

  @override
  @HiveField(0)
  String name;

  @override
  @HiveField(1)
  bool isHidden = false;

  @override
  @HiveField(2)
  bool isNotCounted = false;

  @HiveField(3)
  String? omniName;

  @override
  Json toJson() => {...ExportEntry.toJsonFrom(this), 'omniName': omniName};

  @override
  String get entryType => 'ExportItem';
}

@HiveType(typeId: 9)
class ExportTitle extends HiveObject implements ExportEntry {
  ExportTitle(this.name, {this.isHidden = false, this.isNotCounted = false});

  factory ExportTitle.fromJson(Json json) {
    final ({bool isHidden, bool isNotCounted, String name}) fields =
        ExportEntry.parseCommonFields(json);
    return ExportTitle(
      fields.name,
      isHidden: fields.isHidden,
      isNotCounted: fields.isNotCounted,
    );
  }

  @override
  @HiveField(0)
  String name;

  @override
  @HiveField(1)
  bool isHidden = false;

  @override
  @HiveField(2)
  bool isNotCounted = false;

  @override
  Json toJson() => ExportEntry.toJsonFrom(this);

  @override
  String get entryType => 'ExportTitle';
}
