import 'package:hive_flutter/hive_flutter.dart';

import '../models/data/export_entry.dart';
import 'repository.dart';

abstract class ExportLocalRepository extends LocalRepository {
  Future<void> ensureInitialized();

  List<ExportEntry> readExportList();
  Future<void> writeExportList(List<ExportEntry> exportList);
}

class HiveExportLocalRepository implements ExportLocalRepository {
  HiveExportLocalRepository({Box<dynamic>? settingsBox})
    : _settingsBox = settingsBox ?? Hive.box('settings');

  final Box<dynamic> _settingsBox;

  @override
  Future<void> ensureInitialized() async {
    if (_settingsBox.get('exportList') == null) {
      await _settingsBox.put('exportList', <ExportEntry>[]);
    }
  }

  @override
  List<ExportEntry> readExportList() {
    final List<dynamic> rawList = _settingsBox.get(
      'exportList',
      defaultValue: <ExportEntry>[],
    );

    return rawList.cast<ExportEntry>().toList();
  }

  @override
  Future<void> writeExportList(List<ExportEntry> exportList) {
    return _settingsBox.put('exportList', exportList);
  }
}
