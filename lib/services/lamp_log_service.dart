import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lamp_log_entry.dart';

class LampLogService {
  static const _maxEntries = 1000; // Limit stored entries
  final String deviceId;

  LampLogService(this.deviceId);

  String get _storageKey => 'lamp_logs_$deviceId';

  Future<void> addEntry(LampLogEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await getLogs();

    logs.add(entry);

    // Keep only last _maxEntries
    if (logs.length > _maxEntries) {
      logs.removeRange(0, logs.length - _maxEntries);
    }

    await prefs.setString(
      _storageKey,
      jsonEncode(logs.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<LampLogEntry>> getLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? logsJson = prefs.getString(_storageKey);

    if (logsJson == null) return [];

    final List<dynamic> decoded = jsonDecode(logsJson);
    return decoded.map((json) => LampLogEntry.fromJson(json)).toList();
  }

  Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
