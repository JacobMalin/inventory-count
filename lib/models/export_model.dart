import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:intl/intl.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:inventory_count/models/export_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExportModel with ChangeNotifier {
  StreamSubscription<List<Map<String, dynamic>>>? _setupsSubscription;
  StreamSubscription<InternetConnectionStatus>? _connectionSubscription;
  DateTime? _lastTimestamp;

  ExportModel() {
    final box = Hive.box('settings');
    if (box.get('exportList') == null) {
      box.put('exportList', <ExportEntry>[]);
    }

    _fetch();
    _listenForChanges();
  }

  Future<void> _fetch() async {
    try {
      final response = await Supabase.instance.client
          .from('setups')
          .select()
          .order('updated_at', ascending: false)
          .limit(1);

      _updateFromResponse(response);
    } catch (_) {
      // On fail, do nothing
    }
  }

  void _listenForChanges() {
    try {
      _setupsSubscription = Supabase.instance.client
          .from('setups')
          .stream(primaryKey: ['updated_at'])
          .order('updated_at', ascending: false)
          .limit(1)
          .listen(
            _updateFromResponse,
            onError: (_) {
              // On fail, do nothing
            },
          );
    } catch (_) {
      // On fail, do nothing
    }

    // Listen for connectivity changes
    try {
      _connectionSubscription = InternetConnectionChecker
          .instance
          .onStatusChange
          .listen((InternetConnectionStatus status) async {
            if (status != InternetConnectionStatus.connected) return;

            await _fetch();
          });
    } catch (_) {
      // On fail, do nothing
    }
  }

  void _updateFromResponse(List<Map<String, dynamic>> response) {
    if (response.isEmpty) return;

    final setup = response.first;

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

    final jsonData = setup['json'] is String
        ? setup['json'] as String
        : jsonEncode(setup['json']);
    importFromJson(jsonData);

    _lastTimestamp = updatedTimestamp;
  }

  @override
  Future<void> dispose() async {
    await _setupsSubscription?.cancel();
    await _connectionSubscription?.cancel();
    super.dispose();
  }

  void _updateSupabase() async {
    try {
      final jsonString = exportToJson();

      final DateTime now = DateTime.now().toUtc();
      final id = '${DateFormat('yyyy-MM-dd HH').format(now)}h';

      _lastTimestamp = now;

      await Supabase.instance.client.from('setups').upsert({
        'id': id,
        'updated_at': now.toIso8601String(),
        'json': jsonString,
      });
    } catch (_) {
      // On fail, do nothing
    }
  }

  List<ExportEntry> get exportList {
    final rawList = Hive.box(
      'settings',
    ).get('exportList', defaultValue: <ExportEntry>[]);
    return (rawList as List).cast<ExportEntry>().toList();
  }

  void add(ExportEntry value) {
    var currentExportList = exportList;
    currentExportList.add(value);
    Hive.box('settings').put('exportList', currentExportList);
    _updateSupabase();
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    var currentExportList = exportList;
    final item = currentExportList.removeAt(oldIndex);
    currentExportList.insert(newIndex, item);
    Hive.box('settings').put('exportList', currentExportList);
    _updateSupabase();
    notifyListeners();
  }

  void editEntry(int index, {String? name, bool? isHidden}) {
    var currentExportList = exportList;
    var entry = currentExportList[index];

    if (name != null) entry.name = name;
    if (isHidden != null) entry.isHidden = isHidden;

    Hive.box('settings').put('exportList', currentExportList);
    _updateSupabase();
    notifyListeners();
  }

  void removeAt(int index) {
    var currentExportList = exportList;
    currentExportList.removeAt(index);
    Hive.box('settings').put('exportList', currentExportList);
    _updateSupabase();
    notifyListeners();
  }

  bool contains(String countName) {
    final currentExportList = exportList;

    var titleHidden = false;
    for (var entry in currentExportList) {
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
    final currentExportList = exportList;

    final data = {};

    var currentTitle = '';
    var titleHidden = false;
    for (var entry in currentExportList) {
      if (entry is ExportItem && !entry.isHidden && !titleHidden) {
        data[currentTitle][entry.name] = countModel.getItemExportJson(
          entry.name,
        );
      } else if (entry is ExportTitle) {
        currentTitle = entry.name;
        titleHidden = entry.isHidden;
        if (!data.containsKey(currentTitle)) data[currentTitle] = {};
      }
    }
    return jsonEncode(data);
  }

  String exportToJson() {
    final currentExportList = exportList;

    final data = {
      'exportList': currentExportList.map((entry) => entry.toJson()).toList(),
    };

    return jsonEncode(data);
  }

  void importFromJson(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    // Import export list
    if (data['exportList'] != null) {
      final exportListData = (data['exportList'] as List)
          .map((json) => ExportEntry.fromJson(json as Map<String, dynamic>))
          .toList();

      Hive.box('settings').put('exportList', exportListData);
    }

    notifyListeners();
  }
}
