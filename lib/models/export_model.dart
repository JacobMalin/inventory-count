import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'count_model.dart';
import 'export_entry.dart';

class ExportModel with ChangeNotifier {
  ExportModel() {
    final Box<dynamic> box = Hive.box('settings');
    if (box.get('exportList') == null) {
      unawaited(box.put('exportList', <ExportEntry>[]));
    }

    unawaited(_fetch());
    _listenForChanges();
  }

  StreamSubscription<List<Map<String, dynamic>>>? _setupsSubscription;
  StreamSubscription<InternetConnectionStatus>? _connectionSubscription;
  DateTime? _lastTimestamp;

  Future<void> _fetch() async {
    try {
      final PostgrestList response = await Supabase.instance.client
          .from('setups')
          .select()
          .order('updated_at', ascending: false)
          .limit(1);

      await _updateFromResponse(response);
    } on Exception catch (_) {
      // On fail, do nothing
    }
  }

  void _listenForChanges() {
    try {
      _setupsSubscription = Supabase.instance.client
          .from('setups')
          .stream(primaryKey: ['updated_at'])
          .order('updated_at')
          .limit(1)
          .listen(
            _updateFromResponse,
            onError: (_) {
              // On fail, do nothing
            },
          );
    } on Exception catch (_) {
      // On fail, do nothing
    }

    // Listen for connectivity changes
    try {
      _connectionSubscription = InternetConnectionChecker
          .instance
          .onStatusChange
          .listen((status) async {
            if (status != InternetConnectionStatus.connected) return;

            await _fetch();
          });
    } on Exception catch (_) {
      // On fail, do nothing
    }
  }

  Future<void> _updateFromResponse(List<Map<String, dynamic>> response) async {
    if (response.isEmpty) return;

    final Map<String, dynamic> setup = response.first;

    DateTime? updatedTimestamp;
    if (setup['updated_at'] != null) {
      updatedTimestamp = DateTime.tryParse(
        setup['updated_at'].toString(),
      )?.toLocal();
    }

    if (_lastTimestamp != null &&
        updatedTimestamp != null &&
        _lastTimestamp!.isAfter(updatedTimestamp)) {
      _updateSupabase();
      return;
    }

    final String jsonData = setup['json'] is String
        ? setup['json'] as String
        : jsonEncode(setup['json']);
    await importFromJson(jsonData);

    _lastTimestamp = updatedTimestamp;
  }

  @override
  Future<void> dispose() async {
    await _setupsSubscription?.cancel();
    await _connectionSubscription?.cancel();
    super.dispose();
  }

  void _updateSupabase() {
    try {
      final String jsonString = exportToJson();

      final DateTime now = DateTime.now().toUtc();
      final id = '${DateFormat('yyyy-MM-dd HH').format(now)}h';

      _lastTimestamp = now;

      unawaited(
        Supabase.instance.client.from('setups').upsert({
          'id': id,
          'updated_at': now.toIso8601String(),
          'json': jsonString,
        }),
      );
    } on Exception catch (_) {
      // On fail, do nothing
    }
  }

  List<ExportEntry> get exportList {
    final List<dynamic> rawList = Hive.box(
      'settings',
    ).get('exportList', defaultValue: <ExportEntry>[]);
    return rawList.cast<ExportEntry>().toList();
  }

  Future<void> add(ExportEntry value) async {
    final List<ExportEntry> currentExportList = exportList..add(value);
    await Hive.box('settings').put('exportList', currentExportList);
    _updateSupabase();
    notifyListeners();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final List<ExportEntry> currentExportList = exportList;
    final ExportEntry item = currentExportList.removeAt(oldIndex);
    currentExportList.insert(newIndex, item);
    await Hive.box('settings').put('exportList', currentExportList);
    _updateSupabase();
    notifyListeners();
  }

  Future<void> editEntry(int index, {String? name, bool? isHidden}) async {
    final List<ExportEntry> currentExportList = exportList;
    final ExportEntry entry = currentExportList[index];

    if (name != null) entry.name = name;
    if (isHidden != null) entry.isHidden = isHidden;

    await Hive.box('settings').put('exportList', currentExportList);
    _updateSupabase();
    notifyListeners();
  }

  Future<void> removeAt(int index) async {
    final List<ExportEntry> currentExportList = exportList..removeAt(index);
    await Hive.box('settings').put('exportList', currentExportList);
    _updateSupabase();
    notifyListeners();
  }

  bool contains(String countName) {
    final List<ExportEntry> currentExportList = exportList;

    var titleHidden = false;
    for (final entry in currentExportList) {
      if (entry is ExportItem &&
          entry.name == countName &&
          !entry.isHidden &&
          !titleHidden) {
        return true;
      } else if (entry is ExportTitle) {
        titleHidden = entry.isHidden;
      }
    }
    return false;
  }

  String exportInExportOrder(CountModel countModel) {
    final List<ExportEntry> currentExportList = exportList;

    final Map<String, dynamic> data = {};

    var currentTitle = '';
    var titleHidden = false;
    for (final entry in currentExportList) {
      if (entry is ExportItem && !entry.isHidden && !titleHidden) {
        (data[currentTitle] as Map<String, dynamic>)[entry.name] = countModel
            .getItemExportJson(entry.name);
      } else if (entry is ExportTitle) {
        currentTitle = entry.name;
        titleHidden = entry.isHidden;
        if (!data.containsKey(currentTitle)) data[currentTitle] = {};
      }
    }
    return jsonEncode(data);
  }

  String exportToJson() {
    final List<ExportEntry> currentExportList = exportList;

    final Map<String, List<Map<String, dynamic>>> data = {
      'exportList': currentExportList.map((entry) => entry.toJson()).toList(),
    };

    return jsonEncode(data);
  }

  Future<void> importFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    // Import export list
    if (data['exportList'] != null) {
      final List<ExportEntry> exportListData = (data['exportList'] as List)
          .map((json) => ExportEntry.fromJson(json as Map<String, dynamic>))
          .toList();

      await Hive.box('settings').put('exportList', exportListData);
    }

    notifyListeners();
  }
}
