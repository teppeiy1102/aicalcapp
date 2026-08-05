import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiPromptHistoryEntry {
  final String instruction;
  final DateTime dateTime;

  AiPromptHistoryEntry({
    required this.instruction,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() => {
    'instruction': instruction,
    'dateTime': dateTime.toIso8601String(),
  };

  factory AiPromptHistoryEntry.fromJson(Map<String, dynamic> json) =>
      AiPromptHistoryEntry(
        instruction: json['instruction'] as String? ?? '',
        dateTime:
            DateTime.tryParse(json['dateTime'] as String? ?? '') ??
            DateTime.now(),
      );
}

class AiPromptHistoryManager {
  AiPromptHistoryManager._();
  static final AiPromptHistoryManager instance = AiPromptHistoryManager._();

  static const _kPrefsKey = 'ai_prompt_history_v1';
  static const int _kMaxEntries = 50;

  final List<AiPromptHistoryEntry> _entries = [];
  final ValueNotifier<int> changeNotifier = ValueNotifier(0);
  bool _loaded = false;

  List<AiPromptHistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kPrefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = json.decode(jsonStr) as List<dynamic>;
        _entries
          ..clear()
          ..addAll(
            list.map(
              (e) => AiPromptHistoryEntry.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            ),
          );
      }
    } catch (_) {}
  }

  Future<void> addEntry(String instruction) async {
    final trimmed = instruction.trim();
    if (trimmed.isEmpty) return;
    await _ensureLoaded();
    _entries.removeWhere((entry) => entry.instruction == trimmed);
    _entries.insert(
      0,
      AiPromptHistoryEntry(
        instruction: trimmed,
        dateTime: DateTime.now(),
      ),
    );
    if (_entries.length > _kMaxEntries) {
      _entries.removeRange(_kMaxEntries, _entries.length);
    }
    changeNotifier.value++;
    _save();
  }

  Future<List<AiPromptHistoryEntry>> loadAll() async {
    await _ensureLoaded();
    return entries;
  }

  Future<void> clearAll() async {
    await _ensureLoaded();
    _entries.clear();
    changeNotifier.value++;
    _save();
  }

  void _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kPrefsKey,
        json.encode(_entries.map((entry) => entry.toJson()).toList()),
      );
    } catch (_) {}
  }
}
