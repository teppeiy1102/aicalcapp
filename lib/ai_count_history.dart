import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'ai_service.dart';

class AiCountHistoryEntry {
  final String id;
  final String instruction;
  final List<AiCountItem> items;
  final DateTime dateTime;
  final String imagePath; // relative path to image file

  AiCountHistoryEntry({
    required this.id,
    required this.instruction,
    required this.items,
    required this.dateTime,
    required this.imagePath,
  });

  int get count => items.fold(0, (total, item) => total + item.count);
  List<List<double>> get points => [for (final item in items) ...item.points];

  Map<String, dynamic> toJson() => {
    'id': id,
    'instruction': instruction,
    'count': count,
    'points': points,
    'items': items.map((item) => item.toJson()).toList(),
    'dateTime': dateTime.toIso8601String(),
    'imagePath': imagePath,
  };

  factory AiCountHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>?;
    final items = rawItems != null && rawItems.isNotEmpty
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => AiCountItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : [
            AiCountItem(
              target: json['instruction'] as String? ?? '',
              count: (json['count'] as num?)?.toInt() ?? 0,
              points:
                  (json['points'] as List<dynamic>?)
                      ?.whereType<List>()
                      .where((point) => point.length >= 2)
                      .map(
                        (point) => [
                          (point[0] as num).toDouble(),
                          (point[1] as num).toDouble(),
                        ],
                      )
                      .toList() ??
                  [],
            ),
          ];
    return AiCountHistoryEntry(
      id: json['id'] as String? ?? '',
      instruction: json['instruction'] as String? ?? '',
      items: items,
      dateTime:
          DateTime.tryParse(json['dateTime'] as String? ?? '') ??
          DateTime.now(),
      imagePath: json['imagePath'] as String? ?? '',
    );
  }
}

/// AIカウントの履歴を管理するシングルトン
class AiCountHistoryManager {
  AiCountHistoryManager._();
  static final AiCountHistoryManager instance = AiCountHistoryManager._();

  static const _kPrefsKey = 'ai_count_history_v1';
  static const int _kMaxEntries = 30;

  final List<AiCountHistoryEntry> _entries = [];
  bool _loaded = false;

  List<AiCountHistoryEntry> get entries => List.unmodifiable(_entries);

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
            (e) => AiCountHistoryEntry.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          ),
        );
      }
    } catch (_) {}
  }

  Future<String> _saveImage(Uint8List imageBytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final historyDir = Directory('${dir.path}/ai_count_history');
    if (!await historyDir.exists()) {
      await historyDir.create(recursive: true);
    }
    final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File('${historyDir.path}/$filename');
    await file.writeAsBytes(imageBytes);
    return 'ai_count_history/$filename';
  }

  Future<void> addEntry({
    required Uint8List imageBytes,
    required String instruction,
    required List<AiCountItem> items,
  }) async {
    await _ensureLoaded();
    final imagePath = await _saveImage(imageBytes);
    final entry = AiCountHistoryEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      instruction: instruction,
      items: items,
      dateTime: DateTime.now(),
      imagePath: imagePath,
    );
    _entries.insert(0, entry);
    if (_entries.length > _kMaxEntries) {
      // 古いエントリの画像ファイルも削除
      final removed = _entries.sublist(_kMaxEntries);
      _entries.removeRange(_kMaxEntries, _entries.length);
      for (final r in removed) {
        await _deleteImageFile(r.imagePath);
      }
    }
    _save();
  }

  Future<void> clearAll() async {
    await _ensureLoaded();
    // 全ての画像ファイルを削除
    for (final entry in _entries) {
      await _deleteImageFile(entry.imagePath);
    }
    _entries.clear();
    _save();
  }

  Future<void> deleteEntry(String id) async {
    await _ensureLoaded();
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final removed = _entries.removeAt(idx);
      await _deleteImageFile(removed.imagePath);
      _save();
    }
  }

  Future<void> _deleteImageFile(String relativePath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$relativePath');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<File?> getImageFile(String relativePath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$relativePath');
      if (await file.exists()) return file;
    } catch (_) {}
    return null;
  }

  Future<List<AiCountHistoryEntry>> loadAll() async {
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
