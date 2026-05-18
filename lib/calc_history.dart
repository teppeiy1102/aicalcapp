import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalcHistoryEntry {
  final String expression;
  final String result;
  final DateTime dateTime;

  CalcHistoryEntry({
    required this.expression,
    required this.result,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() => {
    'expression': expression,
    'result': result,
    'dateTime': dateTime.toIso8601String(),
  };

  factory CalcHistoryEntry.fromJson(Map<String, dynamic> json) =>
      CalcHistoryEntry(
        expression: json['expression'] as String? ?? '',
        result: json['result'] as String? ?? '',
        dateTime:
            DateTime.tryParse(json['dateTime'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// 電卓の計算履歴を管理するシングルトン
class CalcHistoryManager {
  CalcHistoryManager._();
  static final CalcHistoryManager instance = CalcHistoryManager._();

  static const _kPrefsKey = 'calc_history_v1';
  static const int _kMaxEntries = 200;

  final List<CalcHistoryEntry> _entries = [];
  final ValueNotifier<int> changeNotifier = ValueNotifier(0);
  bool _loaded = false;

  List<CalcHistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kPrefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = json.decode(jsonStr) as List<dynamic>;
        _entries.clear();
        _entries.addAll(
          list.map(
            (e) =>
                CalcHistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)),
          ),
        );
      }
    } catch (_) {
      // 読み込み失敗は無視
    }
  }

  Future<void> addEntry(String expression, String result) async {
    await _ensureLoaded();
    _entries.insert(
      0,
      CalcHistoryEntry(
        expression: expression,
        result: result,
        dateTime: DateTime.now(),
      ),
    );
    if (_entries.length > _kMaxEntries) {
      _entries.removeRange(_kMaxEntries, _entries.length);
    }
    changeNotifier.value++;
    _save();
  }

  Future<void> clearAll() async {
    await _ensureLoaded();
    _entries.clear();
    changeNotifier.value++;
    _save();
  }

  Future<List<CalcHistoryEntry>> loadAll() async {
    await _ensureLoaded();
    return entries;
  }

  void _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(_entries.map((e) => e.toJson()).toList());
      await prefs.setString(_kPrefsKey, jsonStr);
    } catch (_) {}
  }
}
