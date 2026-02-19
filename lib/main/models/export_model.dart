import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'count_model.dart';
import 'data/export_entry.dart';

class ExportModel with ChangeNotifier {
  ExportModel() {
    final Box<dynamic> box = Hive.box('settings');
    if (box.get('exportList') == null) {
      unawaited(box.put('exportList', <ExportEntry>[]));
    }

    unawaited(() async {
      await _fetch();
      _listenForChanges();
    }());
  }

  StreamSubscription<List<Map<String, dynamic>>>? _setupsSubscription;
  StreamSubscription<InternetConnectionStatus>? _connectionSubscription;
  DateTime? _lastTimestamp;

  Future<void> _fetch() async {
    try {
      final PostgrestList response = await Supabase.instance.client
          .from('setups')
          .select()
          .order('updated_at')
          .limit(1);

      await _updateFromResponse(response);
    } on Exception catch (e) {
      if (kDebugMode) print('Failed to fetch setups from Supabase: $e');
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
            onError: (e) {
              if (kDebugMode) print('Error listening to Supabase changes: $e');
            },
          );
    } on Exception catch (e) {
      if (kDebugMode) print('Failed to subscribe to Supabase changes: $e');
    }

    // TODO: If app starts offline, it stays offline
    // Listen for connectivity changes
    try {
      _connectionSubscription = InternetConnectionChecker
          .instance
          .onStatusChange
          .listen((status) async {
            if (status != InternetConnectionStatus.connected) return;

            await _fetch();
          });
    } on Exception catch (e) {
      if (kDebugMode) print('Failed to listen for connectivity changes: $e');
    }
  }

  Future<void> _updateFromResponse(List<Map<String, dynamic>> response) async {
    if (response.isEmpty) return;

    final Map<String, dynamic> setup = response.first;

    if (setup['udid'] == await FlutterUdid.udid) {
      // Don't update from our own changes
      return;
    }

    DateTime? updatedTimestamp;
    if (setup['updated_at'] != null) {
      updatedTimestamp = DateTime.tryParse(
        setup['updated_at'].toString(),
      )?.toUtc();
    }

    if (updatedTimestamp == null) return; // Should not be possible

    if (_lastTimestamp == null || _lastTimestamp!.isBefore(updatedTimestamp)) {
      final String jsonData = setup['json'] is String
          ? setup['json'] as String
          : jsonEncode(setup['json']);
      await importFromJson(jsonData);

      _lastTimestamp = updatedTimestamp;
    } else if (_lastTimestamp!.isAfter(updatedTimestamp)) {
      _updateSupabase();
    }
  }

  @override
  Future<void> dispose() async {
    await _setupsSubscription?.cancel();
    await _connectionSubscription?.cancel();
    super.dispose();
  }

  void _updateSupabase() {
    final String jsonString = exportToJson();

    final DateTime now = DateTime.now().toUtc();
    final id = '${DateFormat('yyyy-MM-dd HH').format(now)}h';

    _lastTimestamp = now;

    unawaited(() async {
      await Supabase.instance.client
          .from('setups')
          .upsert({
            'id': id,
            'updated_at': now.toIso8601String(),
            'json': jsonString,
            'udid': await FlutterUdid.udid,
          })
          .catchError((error) {
            if (kDebugMode) print('Failed to upsert to Supabase: $error');
          });
    }());
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

  Future<void> editEntry(
    int index, {
    String? name,
    bool? isHidden,
    bool? isNotCounted,
  }) async {
    final List<ExportEntry> currentExportList = exportList;
    final ExportEntry entry = currentExportList[index];

    if (name != null) entry.name = name;
    if (isHidden != null) entry.isHidden = isHidden;
    if (isNotCounted != null) entry.isNotCounted = isNotCounted;

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
    var titleNotCounted = false;
    for (final entry in currentExportList) {
      if (entry is ExportItem &&
          entry.name == countName &&
          !entry.isHidden &&
          !titleHidden &&
          !entry.isNotCounted &&
          !titleNotCounted) {
        return true;
      } else if (entry is ExportTitle) {
        titleHidden = entry.isHidden;
        titleNotCounted = entry.isNotCounted;
      }
    }
    return false;
  }

  String exportInExportOrder(CountModel countModel) {
    final List<ExportEntry> currentExportList = exportList;

    final Map<String, dynamic> data = {};

    var currentTitle = '';
    var titleHidden = false;
    var titleNotCounted = false;
    for (final entry in currentExportList) {
      if (entry is ExportItem && !entry.isHidden && !titleHidden) {
        final bool useNotCountedJson = entry.isNotCounted || titleNotCounted;

        final currentBucket = data[currentTitle] as Map<dynamic, dynamic>;
        currentBucket[entry.name] = useNotCountedJson
            ? countModel.getItemNotCountedJson()
            : countModel.getItemExportJson(entry.name);
      } else if (entry is ExportTitle) {
        currentTitle = entry.name;
        titleHidden = entry.isHidden;
        titleNotCounted = entry.isNotCounted;
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
