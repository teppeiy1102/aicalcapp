library widget_page;

import 'pro_guard.dart';

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_service.dart';
import 'calc_history.dart';
import 'link_graph_page.dart';
import 'revenuecat_service.dart';
import 'store_page.dart';

part 'calc_input_widgets.dart';
part 'calculator_widget.dart';
part 'calculator_widget_links.dart';
part 'calculator_widget_calc.dart';
part 'calculator_widget_sheets.dart';
part 'calculator_widget_table.dart';
part 'calculator_widget_view.dart';
part 'calculator_row.dart';
part 'calculator_widget_source_picker.dart';
part 'memo_ai_widgets.dart';

// ── 数値文字列に3桁区切りカンマを追加するユーティリティ ────────────────────────────────
/// 数値文字列 (例: "1234567.89") を "1,234,567.89" に変換する。
/// 指数表記 ("1e15") はそのまま返す。
String _addCommas(String s) {
  if (s.contains('e') || s.contains('E')) return s;
  final neg = s.startsWith('-');
  final abs = neg ? s.substring(1) : s;
  final dotIdx = abs.indexOf('.');
  final intPart = dotIdx >= 0 ? abs.substring(0, dotIdx) : abs;
  final decPart = dotIdx >= 0 ? abs.substring(dotIdx) : '';
  final formatted = intPart.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[0]},',
  );
  return '${neg ? '-' : ''}$formatted$decPart';
}

// ── 履歴エントリから計算行アイテムを生成するヘルパー ────────────────────────────────────
/// 履歴の expression 文字列 (例: "3 + 5 × 2") を解析して
/// _CalculatorRow が期待する Map<String, dynamic> を返す。
Map<String, dynamic> _historyEntryToItem(CalcHistoryEntry e) {
  String _convertOp(String op) {
    if (op == '×') return 'x';
    if (op == '÷') return '/';
    return op;
  }

  final parts = e.expression.trim().split(' ');
  // 有効な形式: value op value [op value ...]  → 要素数が奇数かつ 3 以上
  if (parts.length >= 3 && parts.length % 2 == 1) {
    final input = double.tryParse(parts[0]) ?? 0.0;
    final op = _convertOp(parts[1]);
    final operand = double.tryParse(parts[2]) ?? 0.0;
    final others = <Map<String, dynamic>>[];
    for (int i = 3; i + 1 < parts.length; i += 2) {
      others.add({
        'op': _convertOp(parts[i]),
        'val': double.tryParse(parts[i + 1]) ?? 0.0,
        'unit': '',
      });
    }
    return {
      'name': '計算',
      'input': input,
      'op': op,
      'operand': operand,
      'others': others,
      'brackets': [],
    };
  }
  // フォールバック: 結果値のみ使用
  final val = double.tryParse(e.result) ?? 0.0;
  return {
    'name': '計算',
    'input': val,
    'op': '+',
    'operand': 0.0,
    'others': [],
    'brackets': [],
  };
}

// ── アプリ設定 ────────────────────────────────────────────────────────────────────────────
class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _kVibrateKey = 'vibrate_on_tap';

  bool vibrateOnTap = true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    vibrateOnTap = prefs.getBool(_kVibrateKey) ?? true;
  }

  Future<void> setVibrateOnTap(bool value) async {
    vibrateOnTap = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVibrateKey, value);
  }
}

// ── WidgetConfig ──────────────────────────────────────────────────────────────
class WidgetConfig {
  final String id;
  final String type;
  final Map<String, dynamic> data;

  const WidgetConfig({
    required this.id,
    required this.type,
    required this.data,
  });

  WidgetConfig copyWith({Map<String, dynamic>? data}) {
    return WidgetConfig(id: id, type: type, data: data ?? this.data);
  }
}

// ── カラープリセット ───────────────────────────────────────────────────────────
class _NoteColorPreset {
  final int value;
  final bool isDark;
  const _NoteColorPreset(this.value, {this.isDark = false});
}

const List<_NoteColorPreset> _kNoteColorPresets = [
  // ── ライト系 (10) ──
  _NoteColorPreset(0xFFFFFFFF, isDark: false), // 白
  _NoteColorPreset(0xFFF5F5F5, isDark: false), // オフホワイト
  _NoteColorPreset(0xFFECEFF1, isDark: false), // ブルーグレー
  _NoteColorPreset(0xFFE8F4FD, isDark: false), // ライトブルー
  _NoteColorPreset(0xFFE0F7FA, isDark: false), // ライトシアン
  _NoteColorPreset(0xFFFFF9C4, isDark: false), // ライトイエロー
  _NoteColorPreset(0xFFFFF3E0, isDark: false), // ライトオレンジ
  _NoteColorPreset(0xFFE8F5E9, isDark: false), // ライトグリーン
  _NoteColorPreset(0xFFFCE4EC, isDark: false), // ライトピンク
  _NoteColorPreset(0xFFF3E5F5, isDark: false), // ライトラベンダー
  // ── ダーク系 (10) ──
  _NoteColorPreset(0xFF1A1A2E, isDark: true),
  _NoteColorPreset(0xFF16213E, isDark: true),
  _NoteColorPreset(0xFF0F3460, isDark: true),
  _NoteColorPreset(0xFF1B1B2F, isDark: true),
  _NoteColorPreset(0xFF2C2C54, isDark: true),
  _NoteColorPreset(0xFF222831, isDark: true),
  _NoteColorPreset(0xFF2D4A22, isDark: true),
  _NoteColorPreset(0xFF4A1942, isDark: true),
  _NoteColorPreset(0xFF3D1C02, isDark: true),
  _NoteColorPreset(0xFF000000, isDark: true), // 黒
];

// ── AI プロンプト入力シート ────────────────────────────────────────────────────
class _AiPromptSheet extends StatefulWidget {
  final String title;
  final String initialText;
  final bool showModeSwitcher;

  const _AiPromptSheet({
    required this.title,
    required this.initialText,
    this.showModeSwitcher = false,
  });

  @override
  State<_AiPromptSheet> createState() => _AiPromptSheetState();
}

class _AiPromptSheetState extends State<_AiPromptSheet> {
  late final TextEditingController _ctrl;
  bool _isModify = false;
  Uint8List? _attachedImage;
  int? _remainingUses;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
    _loadRemainingUses();
  }

  Future<void> _loadRemainingUses() async {
    final uses = await RevenueCatService.getRemainingUses();
    if (mounted) setState(() => _remainingUses = uses);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final remaining = _remainingUses;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (remaining != null)
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StorePage()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '残りAI使用回数: $remaining 回 (追加購入)',
                        style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white70),
              title: const Text(
                'カメラで撮影',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white70),
              title: const Text(
                'ギャラリーから選択',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    final file = await picker.pickImage(source: source, maxWidth: 1024);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _attachedImage = bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1E1E), Color.fromARGB(255, 56, 116, 165)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_remainingUses != null) ...
                      [
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const StorePage()),
                            );
                          },
                          child: Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: Colors.purpleAccent,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '残りAI使用回数: $_remainingUses 回 (追加購入)',
                                style: const TextStyle(
                                  color: Colors.purpleAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.showModeSwitcher) ...[
            Row(
              children: [
                _modeChip('新規作成', false),
                const SizedBox(width: 8),
                _modeChip('修正・追加', true),
              ],
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'AIへの指示を入力…（例: 消費税の計算）',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          if (_attachedImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.memory(
                      _attachedImage!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _attachedImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    final text = _ctrl.text.trim();
                    if (text.isEmpty && _attachedImage == null) return;
                    Navigator.pop(context, (
                      instruction: text,
                      isModify: _isModify,
                      imageBytes: _attachedImage,
                    ));
                  },
                  child: const Text('生成', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(14),
                ),
                onPressed: _pickImage,
                icon: const Icon(
                  Icons.add_a_photo_outlined,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeChip(String label, bool value) {
    final selected = _isModify == value;
    return GestureDetector(
      onTap: () => setState(() => _isModify = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.purpleAccent.withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.purpleAccent : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.purpleAccent : Colors.white54,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── カリキュレーターボトムシート ─────────────────────────────────────────────
// WidgetDetailPage から独立して動作する電卓ウィジェット
class _CalcBottomSheet extends StatefulWidget {
  final int existingItemCount;
  final void Function(Map<String, dynamic> item) onAddItem;
  final void Function(List<Map<String, dynamic>> items)? onAddItems;
  final bool isDark;
  final VoidCallback onClose;
  final ScrollController? scrollController;
  final DraggableScrollableController? sheetController;
  final String? initialDisplay;
  final Future<void> Function()? onRequestAiCount;

  /// 履歴シートをオーバーレイより上に表示するための委譲コールバック。
  /// (onSelect, onClear) を受け取って呼び出し元で showModalBottomSheet する。
  final void Function(
    void Function(CalcHistoryEntry) onSelect,
    VoidCallback onClear,
  )?
  onRequestHistory;

  const _CalcBottomSheet({
    required this.existingItemCount,
    required this.onAddItem,
    required this.onClose,
    this.isDark = true,
    this.scrollController,
    this.sheetController,
    this.initialDisplay,
    this.onRequestAiCount,
    this.onRequestHistory,
    this.onAddItems,
  });

  @override
  State<_CalcBottomSheet> createState() => _CalcBottomSheetState();
}

class _CalcBottomSheetState extends State<_CalcBottomSheet> {
  late String _display;
  double? _calcA;
  String _calcOp = '';
  double _calcLastA = 0;
  double _calcLastB = 0;
  String _calcLastOp = '+';
  bool _newEntry = true;
  bool _hasResult = false;
  String _exprStr = '';
  bool _isClearState = true;

  @override
  void initState() {
    super.initState();
    _display = widget.initialDisplay ?? '0';
    if (widget.initialDisplay != null) _isClearState = false;
  }

  bool _isAiCounting = false;
  List<double> _termValues = [];
  List<String> _termOps = [];

  String _fmt(double v) {
    if (v.isInfinite || v.isNaN) return '0';
    if (v == 0) return '0';
    if (v == v.truncateToDouble() && v.abs() < 1e15)
      return v.toInt().toString();
    if (v.abs() < 1e-15 || v.abs() >= 1e15) return v.toString();
    int intDigits = v.abs() >= 1 ? v.abs().toInt().toString().length : 0;
    int decDigits = (10 - intDigits).clamp(0, 10);
    String s = v.toStringAsFixed(decDigits);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  double _evalSimple(double a, String op, double b) {
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '×':
        return a * b;
      case '÷':
        return b != 0 ? a / b : 0;
      default:
        return a;
    }
  }

  String _opToDart(String op) {
    switch (op) {
      case '×':
        return 'x';
      case '÷':
        return '/';
      default:
        return op;
    }
  }

  void _onKey(String key) {
    setState(() {
      if (key == 'C' || key == 'AC') {
        if (_display == '0' || key == 'AC') {
          _display = '0';
          _calcA = null;
          _calcOp = '';
          _newEntry = true;
          _hasResult = false;
          _exprStr = '';
          _termValues = [];
          _termOps = [];
          _isClearState = true;
        } else {
          _display = '0';
          _newEntry = true;
          _isClearState = true;
        }
      } else if (key == '⌫') {
        if (!_newEntry && _display.length > 1) {
          _display = _display.substring(0, _display.length - 1);
        } else {
          _display = '0';
          _newEntry = true;
        }
      } else if (key == '+/-') {
        _isClearState = false;
        _display = _fmt(-(double.tryParse(_display) ?? 0));
      } else if (key == '%') {
        _isClearState = false;
        _display = _fmt((double.tryParse(_display) ?? 0) / 100);
      } else if (key == '=') {
        _isClearState = true;
        if (_calcA != null && _calcOp.isNotEmpty) {
          final List<double> allTerms;
          final List<String> effectiveOps;
          if (_newEntry) {
            allTerms = List<double>.from(_termValues);
            effectiveOps = List<String>.from(_termOps)..removeLast();
          } else {
            final b = double.tryParse(_display) ?? 0;
            allTerms = List<double>.from(_termValues)..add(b);
            effectiveOps = List<String>.from(_termOps);
            _calcLastA = _calcA!;
            _calcLastOp = _opToDart(_calcOp);
            _calcLastB = b;
          }
          double result;
          if (allTerms.length == effectiveOps.length + 1 &&
              allTerms.length >= 2) {
            result = allTerms[0];
            for (int i = 0; i < effectiveOps.length; i++) {
              result = _evalSimple(result, effectiveOps[i], allTerms[i + 1]);
            }
          } else {
            result = allTerms.isNotEmpty ? allTerms.last : (_calcA ?? 0);
          }
          final parts = <String>[];
          for (int i = 0; i < allTerms.length; i++) {
            parts.add(_fmt(allTerms[i]));
            if (i < effectiveOps.length) parts.add(effectiveOps[i]);
          }
          final displayParts = parts.map((p) => double.tryParse(p) != null ? _addCommas(p) : p).toList();
          _exprStr = '${displayParts.join(' ')} = ${_addCommas(_fmt(result))}';
          _termValues = allTerms;
          _termOps = effectiveOps;
          _calcA = result;
          _calcOp = '';
          _display = _fmt(result);
          _hasResult = true;
          _newEntry = true;
          // 履歴に保存
          CalcHistoryManager.instance.addEntry(parts.join(' '), _fmt(result));
        } else {
          if (_display != '0' || _calcA != null) _hasResult = true;
        }
      } else if (['+', '-', '×', '÷'].contains(key)) {
        _isClearState = true;
        if (!_newEntry || _calcA == null) {
          final cur = double.tryParse(_display) ?? 0;
          if (_termValues.isEmpty) {
            _termValues.add(cur);
          } else if (!_newEntry) {
            _termValues.add(cur);
          }
          _termOps.add(key);
          _calcA = cur;
          // 複数項がある場合、そこまでの計算結果を表示
          if (_termValues.length >= 2) {
            double runningResult = _termValues[0];
            for (int i = 0; i + 1 < _termValues.length; i++) {
              runningResult = _evalSimple(
                runningResult,
                _termOps[i],
                _termValues[i + 1],
              );
            }
            _display = _fmt(runningResult);
            _calcA = runningResult;
          }
        } else if (_calcOp.isNotEmpty) {
          if (_termOps.isNotEmpty) _termOps[_termOps.length - 1] = key;
          _calcOp = key;
          return;
        } else {
          _termValues = [_calcA!];
          _termOps = [key];
        }
        _calcOp = key;
        _newEntry = true;
        _hasResult = false;
      } else if (key == '.') {
        _isClearState = false;
        if (_newEntry) {
          _display = '0.';
          _newEntry = false;
          _hasResult = false;
        } else if (!_display.contains('.')) {
          _display += '.';
        }
      } else {
        _isClearState = false;
        if (_newEntry || _display == '0') {
          if (_hasResult && _calcOp.isEmpty) {
            _termValues = [];
            _termOps = [];
            _calcA = null;
          }
          _display = key;
          _newEntry = false;
          _hasResult = false;
        } else if (_display.length < 12) {
          _display += key;
        }
      }
    });
  }

  void _addResult() {
    if (!_hasResult) return;
    final name = '計算 ${widget.existingItemCount + 1}';
    Map<String, dynamic> item;
    if (_termValues.length >= 3 && _termOps.length == _termValues.length - 1) {
      final others = List.generate(
        _termValues.length - 2,
        (i) => {
          'op': _opToDart(_termOps[i + 1]),
          'val': _termValues[i + 2],
          'unit': '',
        },
      );
      item = {
        'name': name,
        'input': _termValues[0],
        'op': _opToDart(_termOps[0]),
        'operand': _termValues[1],
        'others': others,
        'brackets': [],
      };
    } else {
      item = {
        'name': name,
        'input': _calcLastA,
        'op': _calcLastOp,
        'operand': _calcLastB,
        'others': [],
        'brackets': [],
      };
    }
    widget.onAddItem(item);
    if (mounted) widget.onClose();
  }

  void _showAiCountDialog() async {
    // OverlayEntry として表示されている場合、Navigator.push はオーバーレイより下に
    // 表示されてしまうため、親に委譲して先にオーバーレイを閉じてもらう
    if (widget.onRequestAiCount != null) {
      await widget.onRequestAiCount!();
      // このウィジェットはオーバーレイ除去で dispose されるため、以降は何もしない
      return;
    }
    final ai = GemmaAi();
    setState(() => _isAiCounting = true);
    final count = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => _AiCountPage(onCount: ai.countInImage),
      ),
    );
    if (!mounted) return;
    setState(() {
      _isAiCounting = false;
      if (count != null) {
        _display = count.toString();
        _newEntry = true;
        _hasResult = false;
        _isClearState = false;
        _calcA = null;
        _calcOp = '';
        _termValues = [];
        _termOps = [];
        _exprStr = '';
      }
    });
  }

  void _showHistory() async {
    // OverlayEntry 内から showModalBottomSheet を呼ぶと履歴が電卓の後ろに表示される
    // ため、onRequestHistory が設定されている場合は親ページへ委譲する。
    if (widget.onRequestHistory != null) {
      widget.onRequestHistory!((entry) {
        if (!mounted) return;
        setState(() {
          _display = entry.result;
          _hasResult = true;
          _isClearState = true;
          _calcOp = '';
          _newEntry = true;

          final parts = entry.expression.trim().split(' ');
          final termVals = <double>[];
          final termOps = <String>[];
          bool valid = parts.length >= 3 && parts.length % 2 == 1;
          if (valid) {
            for (int i = 0; i < parts.length; i++) {
              if (i % 2 == 0) {
                final v = double.tryParse(parts[i]);
                if (v == null) { valid = false; break; }
                termVals.add(v);
              } else {
                termOps.add(parts[i]);
              }
            }
          }
          if (valid && termVals.length >= 2) {
            _termValues = termVals;
            _termOps = termOps;
            _calcA = double.tryParse(entry.result);
            _calcLastA = termVals[0];
            _calcLastOp = _opToDart(termOps[0]);
            _calcLastB = termVals[1];
          } else {
            _calcA = double.tryParse(entry.result);
            _termValues = _calcA != null ? [_calcA!] : [];
            _termOps = [];
          }
          _exprStr = '${entry.expression.split(' ').map((p) => double.tryParse(p) != null ? _addCommas(p) : p).join(' ')} = ${_addCommas(entry.result)}';
        });
      }, () => CalcHistoryManager.instance.clearAll());
      return;
    }
    final entries = await CalcHistoryManager.instance.loadAll();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CalcHistorySheet(
        entries: entries,
        isDark: widget.isDark,
        onSelect: (entry) {
          Navigator.pop(ctx);
          setState(() {
            _display = entry.result;
            _hasResult = true;
            _isClearState = true;
            _calcOp = '';
            _newEntry = true;

            final parts = entry.expression.trim().split(' ');
            final termVals = <double>[];
            final termOps = <String>[];
            bool valid = parts.length >= 3 && parts.length % 2 == 1;
            if (valid) {
              for (int i = 0; i < parts.length; i++) {
                if (i % 2 == 0) {
                  final v = double.tryParse(parts[i]);
                  if (v == null) { valid = false; break; }
                  termVals.add(v);
                } else {
                  termOps.add(parts[i]);
                }
              }
            }
            if (valid && termVals.length >= 2) {
              _termValues = termVals;
              _termOps = termOps;
              _calcA = double.tryParse(entry.result);
              _calcLastA = termVals[0];
              _calcLastOp = _opToDart(termOps[0]);
              _calcLastB = termVals[1];
            } else {
              _calcA = double.tryParse(entry.result);
              _termValues = _calcA != null ? [_calcA!] : [];
              _termOps = [];
            }
            _exprStr = '${entry.expression.split(' ').map((p) => double.tryParse(p) != null ? _addCommas(p) : p).join(' ')} = ${_addCommas(entry.result)}';
          });
        },
        onClear: () {
          CalcHistoryManager.instance.clearAll();
          Navigator.pop(ctx);
        },
        onAddMultiple: (selectedEntries) {
          Navigator.pop(ctx);
          final items = selectedEntries.map(_historyEntryToItem).toList();
          widget.onAddItems != null
              ? widget.onAddItems!(items)
              : items.forEach(widget.onAddItem);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dsc = widget.sheetController;
    if (dsc != null) {
      return AnimatedBuilder(
        animation: dsc,
        builder: (ctx, _) => _buildLayout(ctx),
      );
    }
    return _buildLayout(context);
  }

  Widget _buildLayout(BuildContext context) {
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white : Colors.black;
    final keyBg = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.white.withOpacity(1);
    final opColor = isDark ? Colors.blueAccent : Colors.black;
    final eqColor = isDark ? Colors.orangeAccent : Colors.black;

    String inProg = '';
    if (_termValues.isNotEmpty) {
      final parts = <String>[];
      for (int i = 0; i < _termValues.length; i++) {
        parts.add(_addCommas(_fmt(_termValues[i])));
        if (i < _termOps.length) parts.add(_termOps[i]);
      }
      inProg = parts.join(' ');
    }
    final subtitle = _hasResult ? _exprStr : inProg;

    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

    // DraggableScrollableController.size で正確なシート高さを取得
    final dsc = widget.sheetController;
    final extent = (dsc != null && dsc.isAttached) ? dsc.size : 0.72;
    final sheetH = extent * screenH;

    // 固定 UI 要素の高さ（グリッド外）
    const kFixedH =
        242.0; // ハンドル12 + ヘッダー40 + gap4 + 追加ボタン40 + 表示部80 + gap6 + pad上8 + pad下16
    const kGridGapH = 24.0; // 4行間 × 6px

    final gridAvail = sheetH - kFixedH - kGridGapH - viewInsetsBottom;
    final buttonH = (gridAvail / 5).clamp(24.0, 72.0);
    final buttonW = (screenW - 40.0 - 18.0) / 4;
    final ratio = buttonW / buttonH;
    final fontSize = (buttonH * 0.45).clamp(13.0, 32.0);

    Widget calcKey(String label, {Color? bg, Color? fg}) {
      final lbl = (label == 'C' || label == 'AC')
          ? (_isClearState ? 'AC' : 'C')
          : label;
      return _CalcKeyButton(
        label: lbl,
        bg: bg ?? keyBg,
        fg: fg ?? textColor,
        fontSize: fontSize,
        onTap: () => _onKey(lbl),
      );
    }

    return SingleChildScrollView(
      controller: widget.scrollController,
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.only(
          left: 10,
          right: 10,
          top: 0,
          //bottom: viewInsetsBottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 22),
            // ドラッグハンドル + 閉じるボタン
            SizedBox(
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: -8,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 30),
                      color: isDark ? Colors.white38 : Colors.black38,
                      splashRadius: 20,
                      onPressed: widget.onClose,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),
            // カメラ・履歴ボタンと「追加」ボタンを横並びに
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // AIカウントアイコンボタン
                GestureDetector(
                  onTap: _isAiCounting ? null : _showAiCountDialog,
                  child: AnimatedOpacity(
                    opacity: _isAiCounting ? 0.4 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
  gradient: const LinearGradient(
                                colors: [Color.fromARGB(255, 255, 207, 165), Color.fromARGB(255, 163, 182, 252)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        borderRadius: BorderRadius.circular(1000),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.45),
                          width: 0.8,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 14,
                            bottom: 0,

                            child: Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.black,
                              size: 24,
                            ),
                          ),
                          if (_isAiCounting)
                            SizedBox(
                              width: (buttonH * 0.5).clamp(24.0, 38.0),
                              height: (buttonH * 0.5).clamp(24.0, 38.0),
                              child: const CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white,
                              ),
                            ),
  Positioned(
                                     top: -0,
                                     child: Text(
                                      'ai',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                                                       ),
                                   )
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 履歴ボタン
                GestureDetector(
                  onTap: _showHistory,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(1000),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.45),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 「この計算を追加」ボタン
                Expanded(
                  child: AnimatedOpacity(
                    opacity: _hasResult ? 1.0 : 0.35,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: _hasResult ? _addResult : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _hasResult
                              ? Colors.blueAccent
                              : Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'この計算を追加',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            // 表示部
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 数値・式表示エリア
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (subtitle.isNotEmpty)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                height: 0.9,
                                color: textColor.withOpacity(0.45),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        FittedBox(
                          child: Text(
                            _addCommas(_display),
                            maxLines: 1,
                            style: TextStyle(
                              height: 1,
                              color: textColor,
                              fontSize: 64,
                              fontWeight: FontWeight.w200,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // ボタングリッド（シート高さに応じてボタンサイズ可変）
            Container(
              constraints: BoxConstraints(
                maxWidth:400
              ),
              child: GridView.count(
                padding: EdgeInsets.zero,
                crossAxisCount: 4,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: ratio,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  calcKey(
                    'C',
                    bg: Colors.redAccent.withOpacity(0.18),
                    fg: Colors.redAccent,
                  ),
                  calcKey('+/-', bg: keyBg),
                  calcKey('%', bg: keyBg),
                  calcKey('÷', bg: opColor.withOpacity(0.18), fg: opColor),
                  calcKey('7'),
                  calcKey('8'),
                  calcKey('9'),
                  calcKey('×', bg: opColor.withOpacity(0.18), fg: opColor),
                  calcKey('4'),
                  calcKey('5'),
                  calcKey('6'),
                  calcKey('-', bg: opColor.withOpacity(0.18), fg: opColor),
                  calcKey('1'),
                  calcKey('2'),
                  calcKey('3'),
                  calcKey('+', bg: opColor.withOpacity(0.18), fg: opColor),
                  calcKey('⌫', bg: keyBg),
                  calcKey('0'),
                  calcKey('.'),
                  calcKey('=', bg: eqColor.withOpacity(0.8), fg: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 計算履歴ボトムシート ──────────────────────────────────────────────────────
enum _HistorySelectMode { none, add, delete }

class _CalcHistorySheet extends StatefulWidget {
  final List<CalcHistoryEntry> entries;
  final bool isDark;
  final void Function(CalcHistoryEntry) onSelect;
  final VoidCallback onClear;

  /// 複数選択してシートに追加するコールバック。null の場合は機能を非表示。
  final void Function(List<CalcHistoryEntry>)? onAddMultiple;

  /// 複数選択追加ボタンのラベル（デフォルト: "シートに追加"）
  final String addMultipleLabel;

  const _CalcHistorySheet({
    required this.entries,
    required this.isDark,
    required this.onSelect,
    required this.onClear,
    this.onAddMultiple,
    this.addMultipleLabel = 'シートに追加',
  });

  @override
  State<_CalcHistorySheet> createState() => _CalcHistorySheetState();
}

class _CalcHistorySheetState extends State<_CalcHistorySheet> {
  _HistorySelectMode _selectMode = _HistorySelectMode.none;
  final Set<int> _selectedIndices = {};
  late List<CalcHistoryEntry> _localEntries;

  @override
  void initState() {
    super.initState();
    _localEntries = List.from(widget.entries);
  }

  @override
  void didUpdateWidget(_CalcHistorySheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries) {
      setState(() => _localEntries = List.from(widget.entries));
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    if (d == today) return '今日 $h:$m';
    final yesterday = today.subtract(const Duration(days: 1));
    if (d == yesterday) return '昨日 $h:$m';
    return '${dt.month}/${dt.day} $h:$m';
  }

  void _enterSelectMode(_HistorySelectMode mode, {int? initialIndex}) {
    setState(() {
      _selectMode = mode;
      _selectedIndices.clear();
      if (initialIndex != null) _selectedIndices.add(initialIndex);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = _HistorySelectMode.none;
      _selectedIndices.clear();
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) {
          _selectMode = _HistorySelectMode.none;
        }
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _addSelected() {
    if (_selectedIndices.isEmpty) return;
    final selected = _selectedIndices.toList()..sort();
    final selectedEntries = selected.map((i) => _localEntries[i]).toList();
    widget.onAddMultiple!(selectedEntries);
    _exitSelectMode();
  }

  Future<bool?> _showConfirmation({
    required String title,
    required String content,
    required String confirmLabel,
  }) async {
    final isDark = widget.isDark;
    final completer = Completer<bool?>();
    bool removed = false;
    late OverlayEntry entry;
    void close(bool? result) {
      if (!removed) {
        removed = true;
        entry.remove();
      }
      if (!completer.isCompleted) completer.complete(result);
    }
    entry = OverlayEntry(
      builder: (_) => Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      content,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => close(false),
                        child: Text(
                          'キャンセル',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => close(true),
                        child: Text(
                          confirmLabel,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    return completer.future;
  }

  Future<void> _deleteSelected() async {
    if (_selectedIndices.isEmpty) return;
    final count = _selectedIndices.length;
    final confirmed = await _showConfirmation(
      title: '履歴を削除',
      content: '選択した$count件の履歴を削除しますか？',
      confirmLabel: '削除',
    );
    if (confirmed != true || !mounted) return;
    final sorted = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
    final toDelete = sorted.map((i) => _localEntries[i]).toList();
    await CalcHistoryManager.instance.deleteEntries(toDelete);
    setState(() {
      for (final i in sorted) {
        _localEntries.removeAt(i);
      }
      _selectMode = _HistorySelectMode.none;
      _selectedIndices.clear();
    });
  }

  Future<void> _confirmAndClearAll() async {
    final confirmed = await _showConfirmation(
      title: '全削除',
      content: 'すべての履歴を削除しますか？',
      confirmLabel: '削除',
    );
    if (confirmed != true || !mounted) return;
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark ? const Color(0xFF111118) : Colors.white;
    final fgColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black45;
    final entries = _localEntries;
    final inSelectMode = _selectMode != _HistorySelectMode.none;
    final isDeleteMode = _selectMode == _HistorySelectMode.delete;
    final checkboxColor = isDeleteMode ? Colors.redAccent : Colors.blueAccent;
    final selectedBgColor =
        isDeleteMode ? Colors.redAccent.withOpacity(0.15) : Colors.blueAccent.withOpacity(0.15);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ヘッダー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
            child: Row(
              children: [
                if (inSelectMode)...[
                  TextButton(
                    onPressed: _exitSelectMode,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'キャンセル',
                      style: TextStyle(color: subColor, fontSize: 13),
                    ),
                  ),
                  Spacer()
                  
                  ]
                else
                  ...[Text(
                    '計算履歴',
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                const Spacer(),
                  ],

                if (inSelectMode) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedIndices.length}件選択',
                    style: TextStyle(color: subColor, fontSize: 13),
                  ),
                ],
                // 削除モード時は全削除ボタンを表示
                if (isDeleteMode)
                  TextButton(
                    onPressed: _confirmAndClearAll,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '全削除',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                // 通常モード時は追加・削除ボタンを表示
                if (!inSelectMode && entries.isNotEmpty) ...[
                  if (widget.onAddMultiple != null)
                    TextButton(
                      onPressed: () => _enterSelectMode(_HistorySelectMode.add),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '追加',
                        style: TextStyle(color: Colors.blueAccent, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 14),
                  TextButton(
                    onPressed: () => _enterSelectMode(_HistorySelectMode.delete),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '削除',
                      style: TextStyle(color: Colors.redAccent, fontSize: 14),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Text(
                'まだ履歴がありません',
                style: TextStyle(color: subColor, fontSize: 14),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: entries.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: fgColor.withOpacity(0.06)),
                itemBuilder: (ctx, i) {
                  final e = entries[i];
                  final isSelected = _selectedIndices.contains(i);
                  return InkWell(
                    onTap: () {
                      if (inSelectMode) {
                        _toggleSelection(i);
                      } else {
                        widget.onSelect(e);
                      }
                    },
                    onLongPress: !inSelectMode
                        ? () => _enterSelectMode(
                              _HistorySelectMode.delete,
                              initialIndex: i,
                            )
                        : null,
                    child: Container(
                      color: isSelected ? selectedBgColor : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          if (inSelectMode) ...[
                            Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleSelection(i),
                              activeColor: checkboxColor,
                              side: BorderSide(color: subColor),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.expression.split(' ').map((p) => double.tryParse(p) != null ? _addCommas(p) : p).join(' '),
                                  style: TextStyle(
                                    color: subColor,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '= ${_addCommas(e.result)}',
                                  style: TextStyle(
                                    color: fgColor,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatDate(e.dateTime),
                            style: TextStyle(color: subColor, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          // 選択時アクションバー
          if (inSelectMode)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: fgColor.withOpacity(0.1)),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              child: _selectMode == _HistorySelectMode.add &&
                      widget.onAddMultiple != null
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _selectedIndices.isNotEmpty ? _addSelected : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          disabledBackgroundColor:
                              Colors.blueAccent.withOpacity(0.3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          _selectedIndices.isEmpty
                              ? widget.addMultipleLabel
                              : '${widget.addMultipleLabel} (${_selectedIndices.length}件)',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _selectedIndices.isNotEmpty
                            ? _deleteSelected
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          disabledBackgroundColor:
                              Colors.redAccent.withOpacity(0.3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.delete_rounded, size: 18),
                        label: Text(
                          _selectedIndices.isEmpty
                              ? '削除'
                              : '削除 (${_selectedIndices.length}件)',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            )
          else
            SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ── ウィジェット詳細ページ ────────────────────────────────────────────────────
class WidgetDetailPage extends StatefulWidget {
  final WidgetConfig initialConfig;
  final void Function(Map<String, dynamic> data) onUpdate;
  final VoidCallback onDuplicate;
  final List<Map<String, dynamic>> globalConstants;
  final ValueNotifier<Map<String, dynamic>?>? clipboardNotifier;
  final List<WidgetConfig> allConfigs;

  const WidgetDetailPage({
    super.key,
    required this.initialConfig,
    required this.onUpdate,
    required this.onDuplicate,
    this.globalConstants = const [],
    this.clipboardNotifier,
    this.allConfigs = const [],
  });

  @override
  State<WidgetDetailPage> createState() => _WidgetDetailPageState();
}

class _WidgetDetailPageState extends State<WidgetDetailPage> {
  late WidgetConfig _config;
  final _calcKey = GlobalKey<_CalculatorWidgetState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scrollController = ScrollController();
  bool _calcSheetOpen = false;
  bool _isAiGenerating = false;
  String? _pendingCalcDisplay; // AIカウント結果を電卓再オープン時に引き渡す
  OverlayEntry? _calcSheetOverlay;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    widget.clipboardNotifier?.addListener(_onClipboardChanged);
  }

  @override
  void didUpdateWidget(WidgetDetailPage old) {
    super.didUpdateWidget(old);
    if (old.clipboardNotifier != widget.clipboardNotifier) {
      old.clipboardNotifier?.removeListener(_onClipboardChanged);
      widget.clipboardNotifier?.addListener(_onClipboardChanged);
    }
  }

  @override
  void dispose() {
    widget.clipboardNotifier?.removeListener(_onClipboardChanged);
    _calcSheetOverlay?.remove();
    _calcSheetOverlay = null;
    _scrollController.dispose();
    super.dispose();
  }

  void _onClipboardChanged() {
    if (mounted) setState(() {});
  }

  void _handleUpdate(Map<String, dynamic> data) {
    setState(() {
      _config = _config.copyWith(data: data);
    });
    widget.onUpdate(data);
  }

  void _closeCalcSheet() {
    _calcSheetOverlay?.remove();
    _calcSheetOverlay = null;
    if (mounted) setState(() => _calcSheetOpen = false);
  }

  /// OverlayEntry 内の電卓から履歴シートを開く委譲ハンドラ。
  /// showModalBottomSheet は OverlayEntry より下に表示されるため、
  /// 代わりに OverlayEntry を使って電卓オーバーレイの上に表示する。
  void _showHistoryForCalc(
    void Function(CalcHistoryEntry) onSelect,
    VoidCallback onClear,
  ) async {
    final entries = await CalcHistoryManager.instance.loadAll();
    if (!mounted) return;
    final bgColorValue = _config.data['bgColor'] as int?;
    final isDark = bgColorValue != null
        ? _kNoteColorPresets
              .firstWhere(
                (p) => p.value == bgColorValue,
                orElse: () => _kNoteColorPresets.first,
              )
              .isDark
        : true;

    OverlayEntry? historyEntry;
    void closeHistory() {
      historyEntry?.remove();
      historyEntry = null;
    }

    historyEntry = OverlayEntry(
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: closeHistory,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              Container(color: Colors.black54),
              Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () {},
                  child: _CalcHistorySheet(
                    entries: entries,
                    isDark: isDark,
                    onSelect: (entry) {
                      closeHistory();
                      onSelect(entry);
                    },
                    onClear: () {
                      onClear();
                      closeHistory();
                    },
                    onAddMultiple: (selectedEntries) {
                      closeHistory();
                      _calcKey.currentState?._addItemsFromMaps(
                        selectedEntries.map(_historyEntryToItem).toList(),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final entry = historyEntry!;
    if (_calcSheetOverlay != null) {
      Overlay.of(context).insert(entry, above: _calcSheetOverlay!);
    } else {
      Overlay.of(context).insert(entry);
    }
  }

  /// カメラボタン押下時: オーバーレイを閉じてから AIカウント画面へ遷移し、
  /// 結果を持って電卓を再オープンする。
  Future<void> _handleCalcAiCountRequest() async {
    _closeCalcSheet();
    final ai = GemmaAi();
    if (!mounted) return;
    final count = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => _AiCountPage(onCount: ai.countInImage),
      ),
    );
    if (!mounted) return;
    if (count != null) {
      _pendingCalcDisplay = count.toString();
    }
    _openCalcSheet();
  }

  void _openCalcSheet() {
    if (_calcSheetOpen) {
      _closeCalcSheet();
      return;
    }
    final state = _calcKey.currentState;
    final currentItems =
        state?._items ?? (_config.data['items'] as List<dynamic>? ?? []);
    final bgColorValue = _config.data['bgColor'] as int?;
    final isDark = bgColorValue != null
        ? _kNoteColorPresets
              .firstWhere(
                (p) => p.value == bgColorValue,
                orElse: () => _kNoteColorPresets.first,
              )
              .isDark
        : true;

    setState(() => _calcSheetOpen = true);
    final pendingDisplay = _pendingCalcDisplay;
    _pendingCalcDisplay = null;
    _calcSheetOverlay = OverlayEntry(
      builder: (ctx) => _CalcDraggableSheetContent(
        existingItemCount: currentItems.length,
        isDark: isDark,
        bgColor: bgColorValue,
        initialDisplay: pendingDisplay,
        onRequestAiCount: _handleCalcAiCountRequest,
        onRequestHistory: _showHistoryForCalc,
        onAddItem: (item) {
          state?._addItemFromMap(item);
        },
        onAddItems: (items) => state?._addItemsFromMaps(items),
        onClose: _closeCalcSheet,
      ),
    );
    Overlay.of(context).insert(_calcSheetOverlay!);
  }

  @override
  Widget build(BuildContext context) {
    final title = _config.data['title'] as String? ?? '定型計算';
    final bgColorValue = _config.data['bgColor'] as int?;
    final scaffoldBgColor = bgColorValue != null
        ? Color(bgColorValue)
        : const Color(0xFF0D0D14);
    final isDark = scaffoldBgColor.computeLuminance() < 0.5;
    final fgColor = isDark ? Colors.white : Colors.black;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: scaffoldBgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: scaffoldBgColor.withOpacity(0.85),
        surfaceTintColor: Colors.transparent,
        foregroundColor: fgColor,
        elevation: 0,
        title: GestureDetector(
          onTap: () => _calcKey.currentState?._editTitle(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: fgColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
  const Padding(
                padding: EdgeInsets.only(right: 0.0),
                child: ProBadge(),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.link_rounded, size: 22),
                onPressed: () => ProGuard.checkAndRun(
                  context,
                  () => _calcKey.currentState?._showSheetLinkSettingsDialog(),
                ),
                tooltip: '値をリンク',
              ),
            
            ],
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, size: 24),
            onPressed: () => _calcKey.currentState?._showActionSheet(),
            tooltip: 'メニュー',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // 背景装飾
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF5E81FF).withOpacity(0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: _calcSheetOpen
                    ? EdgeInsets.only(
                        bottom: MediaQuery.of(context).size.height * 0.60,
                      )
                    : EdgeInsets.only(bottom: 50),
                child: _CalculatorWidget(
                  key: _calcKey,
                  config: _config,
                  onUpdate: _handleUpdate,
                  onDuplicate: widget.onDuplicate,
                  showToolbar: false,
                  showHeader: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  onAiGeneratingChanged: (v) =>
                      setState(() => _isAiGenerating = v),
                  globalConstants: widget.globalConstants,
                  clipboardNotifier: widget.clipboardNotifier,
                  allConfigs: widget.allConfigs,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton(
          onPressed: () => _calcKey.currentState?._addItem(),
          backgroundColor: isDark ? Colors.white : Colors.black,
          foregroundColor: scaffoldBgColor,
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    final isViewMode = _config.data['viewMode'] as bool? ?? false;
    final isTableMode = _config.data['tableMode'] as bool? ?? false;
    final bgColorValue = _config.data['bgColor'] as int?;
    final barBgColor = bgColorValue != null
        ? Color(bgColorValue)
        : const Color(0xFF161625);
    final isDarkBar = barBgColor.computeLuminance() < 0.5;

    // 現在のモードアイコン・ラベル・色を決定
    final IconData modeIcon;
    final String modeLabel;
    final Color modeColor;
    if (isTableMode) {
      modeIcon = Icons.table_chart_rounded;
      modeLabel = '表モード';
      modeColor = const Color(0xFF4CAF50);
    } else if (isViewMode) {
      modeIcon = Icons.visibility_rounded;
      modeLabel = '閲覧モード';
      modeColor = const Color(0xFF5E81FF);
    } else {
      modeIcon = Icons.edit_note_rounded;
      modeLabel = '編集モード';
      modeColor = isDarkBar ? Colors.white38 : Colors.black45;
    }

    return Container(
      decoration: BoxDecoration(
        color: barBgColor,
        border: Border(
          top: BorderSide(
            color: isDarkBar
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.12),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkBar ? 0.3 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // クリップボードバー
            if (widget.clipboardNotifier?.value != null)
              ClipboardBottomBar(
                item: widget.clipboardNotifier!.value!,
                onClear: () => widget.clipboardNotifier!.value = null,
              ),
            if (_isAiGenerating)
              const LinearProgressIndicator(
                color: Colors.purpleAccent,
                minHeight: 2,
                backgroundColor: Colors.transparent,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ToolbarButton(
                    icon: Icons.auto_awesome_rounded,
                    label: 'AI生成',
                    color: const Color(0xFF9E7AFF),
                    isLoading: _isAiGenerating,
                    onTap: () {
                      _calcKey.currentState?._showAiGenerateCalcDialog();
                    },
                  ),
                  _ToolbarButton(
                    icon: modeIcon,
                    label: modeLabel,
                    color: modeColor,
                    onTap: () {
                      // タップで順番に切り替え: 編集 → 閲覧 → 表 → 編集
                      if (isTableMode) {
                        _handleUpdate({
                          ..._config.data,
                          'viewMode': false,
                          'tableMode': false,
                        });
                      } else if (isViewMode) {
                        _handleUpdate({
                          ..._config.data,
                          'viewMode': false,
                          'tableMode': true,
                        });
                      } else {
                        _handleUpdate({
                          ..._config.data,
                          'viewMode': true,
                          'tableMode': false,
                        });
                      }
                    },
                    onLongPress: () => _showModePickerSheet(isDarkBar),
                  ),
                  _ToolbarButton(
                    icon: Icons.calculate_rounded,
                    label: '電卓',
                    color: isDarkBar ? Colors.white38 : Colors.black45,
                    onTap: _openCalcSheet,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showModePickerSheet(bool isDark) {
    final isViewMode = _config.data['viewMode'] as bool? ?? false;
    final isTableMode = _config.data['tableMode'] as bool? ?? false;
    final isEditMode = !isViewMode && !isTableMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '表示モードを選択',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (isEditMode
                              ? Colors.white
                              : Colors.white.withOpacity(0.07))
                          .withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  color: isEditMode ? Colors.white : Colors.white54,
                  size: 22,
                ),
              ),
              title: const Text(
                '編集モード',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                '計算式を編集できます',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              trailing: isEditMode
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF5E81FF),
                    )
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _handleUpdate({
                  ..._config.data,
                  'viewMode': false,
                  'tableMode': false,
                });
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (isViewMode
                              ? const Color(0xFF5E81FF)
                              : Colors.white.withOpacity(0.07))
                          .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.visibility_rounded,
                  color: isViewMode ? const Color(0xFF5E81FF) : Colors.white54,
                  size: 22,
                ),
              ),
              title: const Text(
                '閲覧モード',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                '定数・メモ・計算結果を表示します',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              trailing: isViewMode
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF5E81FF),
                    )
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _handleUpdate({
                  ..._config.data,
                  'viewMode': true,
                  'tableMode': false,
                });
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (isTableMode
                              ? const Color(0xFF4CAF50)
                              : Colors.white.withOpacity(0.07))
                          .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.table_chart_rounded,
                  color: isTableMode ? const Color(0xFF4CAF50) : Colors.white54,
                  size: 22,
                ),
              ),
              title: const Text(
                '表モード',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                '値のみをシート形式で表示・編集できます',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              trailing: isTableMode
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF4CAF50),
                    )
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _handleUpdate({
                  ..._config.data,
                  'viewMode': false,
                  'tableMode': true,
                });
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: Color(0xFF7B7FFF),
                  size: 22,
                ),
              ),
              title: const Text(
                'リンクグラフ',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'シート間のリンク関係をグラフで可視化します',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),

              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LinkGraphPage(
                      configs: widget.allConfigs
                          .map((c) => {
                                'id': c.id,
                                'type': c.type,
                                'data': c.data,
                              })
                          .toList(),
                      initialSheetId: _config.id,
                      onOpenSheet: (_) => Navigator.pop(context),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
class _CalcDraggableSheetContent extends StatefulWidget {
  final int existingItemCount;
  final void Function(Map<String, dynamic> item) onAddItem;
  final void Function(List<Map<String, dynamic>> items)? onAddItems;
  final bool isDark;
  final int? bgColor;
  final VoidCallback onClose;
  final String? initialDisplay;
  final Future<void> Function()? onRequestAiCount;
  final void Function(
    void Function(CalcHistoryEntry) onSelect,
    VoidCallback onClear,
  )?
  onRequestHistory;

  const _CalcDraggableSheetContent({
    required this.existingItemCount,
    required this.onAddItem,
    required this.isDark,
    required this.onClose,
    this.bgColor,
    this.initialDisplay,
    this.onRequestAiCount,
    this.onRequestHistory,
    this.onAddItems,
  });

  @override
  State<_CalcDraggableSheetContent> createState() =>
      _CalcDraggableSheetContentState();
}

class _CalcDraggableSheetContentState
    extends State<_CalcDraggableSheetContent> {
  final _dsc = DraggableScrollableController();

  @override
  void dispose() {
    _dsc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _dsc,
      initialChildSize: 0.72,
      minChildSize: 0.55,
      maxChildSize: 0.72,
      expand: true,
      snap: true,
      snapSizes: const [0.55, 0.65, 0.72],
      builder: (ctx, scrollController) {
        final sheetColor = widget.bgColor != null
            ? Color(widget.bgColor!)
            : Colors.black;
        return Material(
          color: sheetColor,
          shadowColor: Colors.black.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              color: widget.isDark ? Colors.black12 : Colors.white12,
              boxShadow: [
                BoxShadow(
                  blurRadius: 1,
                  offset: const Offset(-0, 1),
                  color: Colors.black.withOpacity(widget.isDark ? 0.3 : 0.05),
                ),
              ],
            ),
            child: _CalcBottomSheet(
              scrollController: scrollController,
              sheetController: _dsc,
              existingItemCount: widget.existingItemCount,
              isDark: widget.isDark,
              onAddItem: widget.onAddItem,
              onAddItems: widget.onAddItems,
              onClose: widget.onClose,
              initialDisplay: widget.initialDisplay,
              onRequestAiCount: widget.onRequestAiCount,
              onRequestHistory: widget.onRequestHistory,
            ),
          ),
        );
      },
    );
  }
}

/// HomeScreen から電卓ボトムシートを開く公開ユーティリティ
PersistentBottomSheetController? showHomeCalcSheet({
  required GlobalKey<ScaffoldState> scaffoldKey,
  required void Function(Map<String, dynamic> item) onAddItem,
  void Function(List<Map<String, dynamic>> items)? onAddItems,
  VoidCallback? onClosed,
}) {
  PersistentBottomSheetController? ctrl;
  ctrl = scaffoldKey.currentState?.showBottomSheet(
    backgroundColor: Colors.transparent,
    enableDrag: false,
    (ctx) => _CalcDraggableSheetContent(
      existingItemCount: 0,
      isDark: true,
      onAddItem: onAddItem,
      onAddItems: onAddItems,
      onClose: () => ctrl?.close(),
    ),
  );
  ctrl?.closed.then((_) => onClosed?.call());
  return ctrl;
}

/// ホーム画面でAI生成用プロンプトシートを表示するユーティリティ
Future<({String instruction, bool isModify, Uint8List? imageBytes})?> showHomeAiGenerateSheet(
  BuildContext context,
) {
  return showModalBottomSheet<({String instruction, bool isModify, Uint8List? imageBytes})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _AiPromptSheet(
      title: 'AIで計算式を生成',
      initialText: '',
      showModeSwitcher: false,
    ),
  );
}

/// ホーム画面の常時表示電卓ボトムパネル（スワイプで開閉）
class HomeCalcBottomPanel extends StatefulWidget {
  final void Function(Map<String, dynamic> item) onAddItem;
  final void Function(List<Map<String, dynamic>> items)? onAddItems;
  final void Function(bool isExpanded)? onExpandChanged;

  const HomeCalcBottomPanel({
    super.key,
    required this.onAddItem,
    this.onAddItems,
    this.onExpandChanged,
  });

  @override
  State<HomeCalcBottomPanel> createState() => HomeCalcBottomPanelState();
}

class HomeCalcBottomPanelState extends State<HomeCalcBottomPanel>
    with SingleTickerProviderStateMixin {
  static const double _kHandleHeight = 64.0;
  bool _isExpanded = true;
  bool _isAiCounting = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  // ── 電卓ステート ──
  String _display = '0';
  double? _calcA;
  String _calcOp = '';
  bool _newEntry = true;
  bool _hasResult = false;
  bool _isClearState = true;
  List<double> _termValues = [];
  List<String> _termOps = [];
  String _exprStr = '';
  double _calcLastA = 0;
  double _calcLastB = 0;
  String _calcLastOp = '+';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.value = 1.0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void expand() {
    if (!_isExpanded) {
      setState(() => _isExpanded = true);
      _ctrl.forward();
      widget.onExpandChanged?.call(true);
    }
  }

  void collapse() {
    if (_isExpanded) {
      setState(() => _isExpanded = false);
      _ctrl.reverse();
      widget.onExpandChanged?.call(false);
    }
  }

  void _toggle() {
    if (_isExpanded) {
      collapse();
    } else {
      expand();
    }
  }

  String _fmt(double v) {
    if (v.isInfinite || v.isNaN) return '0';
    if (v == 0) return '0';
    if (v == v.truncateToDouble() && v.abs() < 1e15) return v.toInt().toString();
    if (v.abs() < 1e-15 || v.abs() >= 1e15) return v.toString();
    int intDigits = v.abs() >= 1 ? v.abs().toInt().toString().length : 0;
    int decDigits = (10 - intDigits).clamp(0, 10);
    final s = v.toStringAsFixed(decDigits);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  double _eval(double a, String op, double b) {
    switch (op) {
      case '+': return a + b;
      case '-': return a - b;
      case '×': return a * b;
      case '÷': return b != 0 ? a / b : 0;
      default: return a;
    }
  }

  String _opToDart(String op) {
    switch (op) {
      case '×': return 'x';
      case '÷': return '/';
      default: return op;
    }
  }

  void _onKey(String key) {
    setState(() {
      if (key == 'C' || key == 'AC') {
        if (_display == '0' || key == 'AC') {
          _display = '0';
          _calcA = null;
          _calcOp = '';
          _newEntry = true;
          _hasResult = false;
          _exprStr = '';
          _termValues = [];
          _termOps = [];
          _isClearState = true;
        } else {
          _display = '0';
          _newEntry = true;
          _isClearState = true;
        }
      } else if (key == '⌫') {
        if (!_newEntry && _display.length > 1) {
          _display = _display.substring(0, _display.length - 1);
        } else {
          _display = '0';
          _newEntry = true;
        }
      } else if (key == '+/-') {
        _isClearState = false;
        _display = _fmt(-(double.tryParse(_display) ?? 0));
      } else if (key == '%') {
        _isClearState = false;
        _display = _fmt((double.tryParse(_display) ?? 0) / 100);
      } else if (key == '=') {
        _isClearState = true;
        if (_calcA != null && _calcOp.isNotEmpty) {
          final List<double> allTerms;
          final List<String> effectiveOps;
          if (_newEntry) {
            allTerms = List<double>.from(_termValues);
            effectiveOps = List<String>.from(_termOps)..removeLast();
          } else {
            final b = double.tryParse(_display) ?? 0;
            allTerms = List<double>.from(_termValues)..add(b);
            effectiveOps = List<String>.from(_termOps);
            _calcLastA = _calcA!;
            _calcLastOp = _opToDart(_calcOp);
            _calcLastB = b;
          }
          double result;
          if (allTerms.length == effectiveOps.length + 1 && allTerms.length >= 2) {
            result = allTerms[0];
            for (int i = 0; i < effectiveOps.length; i++) {
              result = _eval(result, effectiveOps[i], allTerms[i + 1]);
            }
          } else {
            result = allTerms.isNotEmpty ? allTerms.last : (_calcA ?? 0);
          }
          final parts = <String>[];
          for (int i = 0; i < allTerms.length; i++) {
            parts.add(_fmt(allTerms[i]));
            if (i < effectiveOps.length) parts.add(effectiveOps[i]);
          }
          final displayParts = parts.map((p) => double.tryParse(p) != null ? _addCommas(p) : p).toList();
          _exprStr = '${displayParts.join(' ')} = ${_addCommas(_fmt(result))}';
          _termValues = allTerms;
          _termOps = effectiveOps;
          _calcA = result;
          _calcOp = '';
          _display = _fmt(result);
          _hasResult = true;
          _newEntry = true;
          CalcHistoryManager.instance.addEntry(parts.join(' '), _fmt(result));
        } else {
          if (_display != '0' || _calcA != null) _hasResult = true;
        }
      } else if (['+', '-', '×', '÷'].contains(key)) {
        _isClearState = true;
        if (!_newEntry || _calcA == null) {
          final cur = double.tryParse(_display) ?? 0;
          if (_termValues.isEmpty) {
            _termValues.add(cur);
          } else if (!_newEntry) {
            _termValues.add(cur);
          }
          _termOps.add(key);
          _calcA = cur;
          if (_termValues.length >= 2) {
            double running = _termValues[0];
            for (int i = 0; i + 1 < _termValues.length; i++) {
              running = _eval(running, _termOps[i], _termValues[i + 1]);
            }
            _display = _fmt(running);
            _calcA = running;
          }
        } else if (_calcOp.isNotEmpty) {
          if (_termOps.isNotEmpty) _termOps[_termOps.length - 1] = key;
          _calcOp = key;
          return;
        } else {
          _termValues = [_calcA!];
          _termOps = [key];
        }
        _calcOp = key;
        _newEntry = true;
        _hasResult = false;
      } else if (key == '.') {
        _isClearState = false;
        if (_newEntry) {
          _display = '0.';
          _newEntry = false;
          _hasResult = false;
        } else if (!_display.contains('.')) {
          _display += '.';
        }
      } else {
        _isClearState = false;
        if (_newEntry || _display == '0') {
          if (_hasResult && _calcOp.isEmpty) {
            _termValues = [];
            _termOps = [];
            _calcA = null;
          }
          _display = key;
          _newEntry = false;
          _hasResult = false;
        } else if (_display.length < 12) {
          _display += key;
        }
      }
    });
  }

  void _addToSheet() {
    if (!_hasResult) return;
    Map<String, dynamic> item;
    if (_termValues.length >= 3 && _termOps.length == _termValues.length - 1) {
      final others = List.generate(
        _termValues.length - 2,
        (i) => {'op': _opToDart(_termOps[i + 1]), 'val': _termValues[i + 2], 'unit': ''},
      );
      item = {
        'name': '計算 1',
        'input': _termValues[0],
        'op': _opToDart(_termOps[0]),
        'operand': _termValues[1],
        'others': others,
        'brackets': [],
      };
    } else {
      item = {
        'name': '計算 1',
        'input': _calcLastA,
        'op': _calcLastOp,
        'operand': _calcLastB,
        'others': [],
        'brackets': [],
      };
    }
    widget.onAddItem(item);
  }

  void _showAiCountDialog() async {
    final ai = GemmaAi();
    setState(() => _isAiCounting = true);
    final count = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => _AiCountPage(onCount: ai.countInImage),
      ),
    );
    if (!mounted) return;
    setState(() {
      _isAiCounting = false;
      if (count != null) {
        _display = count.toString();
        _newEntry = true;
        _hasResult = false;
        _isClearState = false;
        _calcA = null;
        _calcOp = '';
        _termValues = [];
        _termOps = [];
        _exprStr = '';
      }
    });
  }

  void _showHistory() async {
    final entries = await CalcHistoryManager.instance.loadAll();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CalcHistorySheet(
        entries: entries,
        isDark: true,
        onSelect: (entry) {
          Navigator.pop(ctx);
          setState(() {
            _display = entry.result;
            _hasResult = true;
            _isClearState = true;
            _calcOp = '';
            _newEntry = true;

            final parts = entry.expression.trim().split(' ');
            final termVals = <double>[];
            final termOps = <String>[];
            bool valid = parts.length >= 3 && parts.length % 2 == 1;
            if (valid) {
              for (int i = 0; i < parts.length; i++) {
                if (i % 2 == 0) {
                  final v = double.tryParse(parts[i]);
                  if (v == null) { valid = false; break; }
                  termVals.add(v);
                } else {
                  termOps.add(parts[i]);
                }
              }
            }
            if (valid && termVals.length >= 2) {
              _termValues = termVals;
              _termOps = termOps;
              _calcA = double.tryParse(entry.result);
              _calcLastA = termVals[0];
              _calcLastOp = _opToDart(termOps[0]);
              _calcLastB = termVals[1];
            } else {
              _calcA = double.tryParse(entry.result);
              _termValues = _calcA != null ? [_calcA!] : [];
              _termOps = [];
            }
            _exprStr = '${entry.expression.split(' ').map((p) => double.tryParse(p) != null ? _addCommas(p) : p).join(' ')} = ${_addCommas(entry.result)}';
          });
        },
        onClear: () {
          CalcHistoryManager.instance.clearAll();
          Navigator.pop(ctx);
        },
        onAddMultiple: (selectedEntries) {
          Navigator.pop(ctx);
          final items = selectedEntries.map(_historyEntryToItem).toList();
          widget.onAddItems != null
              ? widget.onAddItems!(items)
              : items.forEach(widget.onAddItem);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final topPad = MediaQuery.of(context).padding.top;

    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) {
        final t = _anim.value;
        // 収納時: 64px  →  展開時: 画面全体
        final panelH = _kHandleHeight + (screenH - _kHandleHeight) * t;
        // ハンドル: 展開につれて上部セーフエリア分だけ高くなる
        final handleH = _kHandleHeight + topPad * t;
        final contentH = panelH - handleH;
        return SizedBox(
          height: panelH + 20,
          child: ClipRect(
            child: Column(
              children: [
                _buildHandle(handleH: handleH),
                if (contentH > 0)
                  SizedBox(height: contentH, child: _buildCalcContent()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHandle({required double handleH}) {
 String inProg = '';
    final subtitle = _hasResult ? _exprStr : inProg;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      onVerticalDragUpdate: (d) {
        if (d.delta.dy > 3 && _isExpanded) collapse();
        if (d.delta.dy < -3 && !_isExpanded) expand();
      },
      child: Container(
        height: handleH + 20,
        decoration: const BoxDecoration(

          borderRadius: BorderRadius.all(Radius.circular(30)),
          gradient: LinearGradient(
            colors: [Color.fromARGB(255, 0, 0, 0),Color.fromARGB(255, 68, 172, 241), Color(0xFF7B7FFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isExpanded
            ? Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                  left: 20,
                  right: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
  const Icon(Icons.calculate_rounded, color: Colors.white60, size: 30),
                    const SizedBox(width: 12),
                    const Text(
                      'Calculator',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),

                    IconButton(
                      onPressed: collapse,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      color: Colors.white60,
                      iconSize: 32,
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                  //  const Icon(Icons.calculate_rounded, color: Colors.white60, size: 30),
                    const SizedBox(width: 12),
                   
  subtitle.isNotEmpty?
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  subtitle,
                                    maxLines: 1,
                                  style: TextStyle(
                                    height: 1,
                                    color: Colors.white54,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ):Expanded(
                              child: const Text(
                                                    'Calculator',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 22,
                                                      fontWeight: FontWeight.w600,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                            ),
GestureDetector(
                        onTap: _showHistory,
                        child: Container(
                          margin: const EdgeInsets.only(left:10),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(1000),
                         
                          ),
                          child: const Icon(Icons.history_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white38, size: 28),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCalcContent() {
    String inProg = '';
    if (_termValues.isNotEmpty) {
      final parts = <String>[];
      for (int i = 0; i < _termValues.length; i++) {
        parts.add(_addCommas(_fmt(_termValues[i])));
        if (i < _termOps.length) parts.add(_termOps[i]);
      }
      inProg = parts.join(' ');
    }
    final subtitle = _hasResult ? _exprStr : inProg;

    return Container(
      color: Colors.black,
      child: LayoutBuilder(
          builder: (ctx, constraints) {
          final screenH = MediaQuery.of(ctx).size.height;
          final topPad = MediaQuery.of(ctx).padding.top;
          // 展開時の最大コンテンツ高さをレイアウト計算の基準とする
          final targetContentH = screenH - 64.0 - topPad; // 64.0 is _kHandleHeight

          // viewPadding.bottom は Scaffold/SafeArea に左右されず常にホームインジケーター高さを返す
          final bottomPad = MediaQuery.of(ctx).viewPadding.bottom;
          final screenW = MediaQuery.of(ctx).size.width;
          // innerH = ホームインジケーターを除いた使用可能高さ
          final innerH = targetContentH - bottomPad;
          // kFixed: topPad(8) + actionRow(50) + gap(8) + display(80) + gap(8) + buffer(8) + gridGaps(4*6=24) = 186
          const kFixed = 186.0;
          final gridAvail = innerH - kFixed;
          final buttonH = (gridAvail / 5).clamp(28.0, 72.0);
          final buttonW = (screenW - 20.0 - 18.0) / 4;
          final ratio = buttonW / buttonH;
          final fontSize = (buttonH * 0.42).clamp(14.0, 32.0);

          const keyBg = Color(0x1AFFFFFF);
          const opColor = Color.fromARGB(255, 255, 171, 14);
          const eqColor = Colors.orangeAccent;

          Widget calcKey(String label, {Color? bg, Color? fg}) {
            final lbl = (label == 'C' || label == 'AC')
                ? (_isClearState ? 'AC' : 'C')
                : label;
            return _CalcKeyButton(
              label: lbl,
              bg: bg ?? keyBg,
              fg: fg ?? Colors.white,
              fontSize: fontSize,
              onTap: () => _onKey(lbl),
            );
          }

          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              height: targetContentH,
              child: Padding(
                padding: EdgeInsets.fromLTRB(10, 8, 10, bottomPad + 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                  // ── Action row ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _isAiCounting ? null : _showAiCountDialog,
                        child: AnimatedOpacity(
                          opacity: _isAiCounting ? 0.4 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1000),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.45),
                                width: 0.8,
                              ),
                              gradient: const LinearGradient(
                                colors: [Color.fromARGB(255, 255, 207, 165), Color.fromARGB(255, 163, 182, 252)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                 top: 14, 
                                 bottom: 0,
                                  child: const Icon(Icons.camera_alt_outlined, color: Colors.black, size: 24)),
                                if (_isAiCounting)
                                  const SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                                  ),
                                   Positioned(
                                     top: -0,
                                     child: Text(
                                      'ai',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                                                       ),
                                   )
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _showHistory,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(1000),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.45),
                              width: 0.8,
                            ),
                          ),
                          child: const Icon(Icons.history_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: _hasResult ? 1.0 : 0.35,
                          duration: const Duration(milliseconds: 200),
                          child: GestureDetector(
                            onTap: _hasResult ? _addToSheet : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _hasResult
                                    ? Colors.blueAccent
                                    : Colors.grey.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(40),
                              ),
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'この計算を追加',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ── 表示部 ──
                  SafeArea(
                    child: SizedBox(
                      height: 80,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (subtitle.isNotEmpty)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Text(
                                subtitle,
                                style: TextStyle(
                                  height: 0.9,
                                  color: Colors.white.withOpacity(0.45),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          FittedBox(
                            child: Text(
                              _addCommas(_display),
                              maxLines: 1,
                              style: const TextStyle(
                                height: 1,
                                color: Colors.white,
                                fontSize: 64,
                                fontWeight: FontWeight.w200,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ── ボタングリッド ──
                  SafeArea(
                    child: SizedBox(
                      height: 5* buttonH + 4 * 10,
                      child: GridView.count(
                        padding: EdgeInsets.zero,
                        crossAxisCount: 4,
                        mainAxisSpacing: 5,
                        crossAxisSpacing: 5,
                        childAspectRatio: ratio,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          calcKey('C', bg: Colors.redAccent.withOpacity(0.18), fg: Colors.redAccent),
                          calcKey('+/-'),
                          calcKey('%'),
                          calcKey('÷', bg: opColor.withOpacity(0.18), fg: const Color.fromARGB(255, 255, 255, 255)),
                          calcKey('7'), calcKey('8'), calcKey('9'),
                          calcKey('×', bg: opColor.withOpacity(0.18), fg: const Color.fromARGB(255, 255, 255, 255)),
                          calcKey('4'), calcKey('5'), calcKey('6'),
                          calcKey('-', bg: opColor.withOpacity(0.18), fg: const Color.fromARGB(255, 255, 255, 255)),
                          calcKey('1'), calcKey('2'), calcKey('3'),
                          calcKey('+', bg: opColor.withOpacity(0.18), fg: const Color.fromARGB(255, 255, 255, 255)),
                          calcKey('⌫'),
                          calcKey('0'),
                          calcKey('.'),
                          calcKey('=', bg: eqColor.withOpacity(0.8), fg: Colors.black),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              ))
          );
        },
      ),
    );

  }
}

/// 計算シートを閲覧モードで表示するパブリックウィジェット（HomeScreen のカード展開用）
class CalculatorViewCard extends StatelessWidget {
  final WidgetConfig config;
  final void Function(Map<String, dynamic>) onUpdate;
  final EdgeInsetsGeometry? contentPadding;

  const CalculatorViewCard({
    super.key,
    required this.config,
    required this.onUpdate,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return _CalculatorWidget(
      config: WidgetConfig(
        id: config.id,
        type: config.type,
        data: {...config.data, 'viewMode': true},
      ),
      onUpdate: onUpdate,
      onDuplicate: () {},
      showToolbar: false,
      showHeader: false,
      contentPadding:
          contentPadding ?? const EdgeInsets.fromLTRB(16, 8, 16, 16),
    );
  }
}

// ── 結合ビュー詳細ページ ──────────────────────────────────────────────────────
class MergedDetailPage extends StatefulWidget {
  final WidgetConfig mergedConfig;
  final void Function(Map<String, dynamic>) onMergedUpdate;
  final List<WidgetConfig> sheets;
  final void Function(String sheetId, Map<String, dynamic>) onSheetUpdate;
  final void Function(String sheetId) onSheetDuplicate;
  final List<Map<String, dynamic>> globalConstants;
  final ValueNotifier<Map<String, dynamic>?>? clipboardNotifier;
  final List<WidgetConfig> allConfigs;

  const MergedDetailPage({
    super.key,
    required this.mergedConfig,
    required this.onMergedUpdate,
    required this.sheets,
    required this.onSheetUpdate,
    required this.onSheetDuplicate,
    this.globalConstants = const [],
    this.clipboardNotifier,
    this.allConfigs = const [],
  });

  @override
  State<MergedDetailPage> createState() => _MergedDetailPageState();
}

class _MergedDetailPageState extends State<MergedDetailPage> {
  late String _title;
  late int _bgColor;
  late List<String> _sheetIds;
  late List<WidgetConfig> _localSheets;
  // 0 = 編集, 1 = 閲覧, 2 = 表
  int _globalMode = 0;

  // ── スクロール・シートキー ──
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sheetKeys = {};

  // ── 結合ビュー用電卓オーバーレイ ──
  OverlayEntry? _mergedCalcOverlay;
  bool _mergedCalcOpen = false;
  String? _pendingMergedCalcDisplay;

  @override
  void initState() {
    super.initState();
    _title = widget.mergedConfig.data['title'] as String? ?? '結合ビュー';
    _bgColor = widget.mergedConfig.data['bgColor'] as int? ?? 0xFF0D0D14;
    _sheetIds = (widget.mergedConfig.data['sheetIds'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList();
    _localSheets = List<WidgetConfig>.from(widget.sheets);
    for (final id in _sheetIds) {
      _sheetKeys[id] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _mergedCalcOverlay?.remove();
    _mergedCalcOverlay = null;
    super.dispose();
  }

  GlobalKey _keyForSheet(String id) {
    return _sheetKeys.putIfAbsent(id, () => GlobalKey());
  }

  // ── 結合ビュー用電卓 ──────────────────────────────────────────────────────
  Future<void> _handleMergedCalcAiCountRequest() async {
    _closeMergedCalcSheet();
    final ai = GemmaAi();
    if (!mounted) return;
    final count = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => _AiCountPage(onCount: ai.countInImage),
      ),
    );
    if (!mounted) return;
    if (count != null) {
      _pendingMergedCalcDisplay = count.toString();
    }
    _openMergedCalcSheet();
  }

  void _openMergedCalcSheet() {
    if (_mergedCalcOpen) {
      _closeMergedCalcSheet();
      return;
    }
    setState(() => _mergedCalcOpen = true);
    _mergedCalcOverlay = OverlayEntry(
      builder: (ctx) => _CalcDraggableSheetContent(
        existingItemCount: 0,
        isDark: true,
        initialDisplay: _pendingMergedCalcDisplay,
        onAddItem: (item) {
          _closeMergedCalcSheet();
          Future.microtask(() => _pickSheetAndAdd(item));
        },
        onRequestAiCount: _handleMergedCalcAiCountRequest,
        onRequestHistory: _showMergedHistoryForCalc,
        onClose: _closeMergedCalcSheet,
      ),
    );
    _pendingMergedCalcDisplay = null;
    Overlay.of(context).insert(_mergedCalcOverlay!);
  }

  void _closeMergedCalcSheet() {
    _mergedCalcOverlay?.remove();
    _mergedCalcOverlay = null;
    if (mounted) setState(() => _mergedCalcOpen = false);
  }

  /// 結合ビュー電卓オーバーレイから履歴シートを開く委譲ハンドラ。
  /// OverlayEntry の上に重ねて表示することで電卓の前面に出す。
  void _showMergedHistoryForCalc(
    void Function(CalcHistoryEntry) onSelect,
    VoidCallback onClear,
  ) async {
    final entries = await CalcHistoryManager.instance.loadAll();
    if (!mounted) return;

    OverlayEntry? historyEntry;
    void closeHistory() {
      historyEntry?.remove();
      historyEntry = null;
    }

    historyEntry = OverlayEntry(
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: closeHistory,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              Container(color: Colors.black54),
              Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () {},
                  child: _CalcHistorySheet(
                    entries: entries,
                    isDark: true,
                    onSelect: (entry) {
                      closeHistory();
                      onSelect(entry);
                    },
                    onClear: () {
                      onClear();
                      closeHistory();
                    },
                    onAddMultiple: (selectedEntries) {
                      closeHistory();
                      _closeMergedCalcSheet();
                      final items = selectedEntries.map(_historyEntryToItem).toList();
                      Future.microtask(() => _pickSheetAndAddMultiple(items));
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final entry = historyEntry!;
    if (_mergedCalcOverlay != null) {
      Overlay.of(context).insert(entry, above: _mergedCalcOverlay!);
    } else {
      Overlay.of(context).insert(entry);
    }
  }

  Future<void> _pickSheetAndAdd(Map<String, dynamic> item) async {
    if (!mounted) return;
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '追加するシートを選択',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              for (final id in _sheetIds) ...[
                Builder(
                  builder: (bCtx) {
                    WidgetConfig? sheet;
                    try {
                      sheet = _localSheets.firstWhere((s) => s.id == id);
                    } catch (_) {}
                    final title = sheet?.data['title'] as String? ?? '定型計算';
                    final itemCount =
                        (sheet?.data['items'] as List?)?.length ?? 0;
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5E81FF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.calculate_rounded,
                          color: Color(0xFF5E81FF),
                          size: 18,
                        ),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '$itemCount 件の計算',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                      onTap: () => Navigator.pop(ctx, id),
                    );
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (selectedId == null || !mounted) return;
    final sheetIdx = _localSheets.indexWhere((s) => s.id == selectedId);
    if (sheetIdx == -1) return;
    final sheet = _localSheets[sheetIdx];
    final rawItems = sheet.data['items'] as List<dynamic>? ?? [];
    final newItems = List<dynamic>.from(rawItems)..add(item);
    final rawOrder = sheet.data['displayOrder'] as List<dynamic>?;
    final newOrder = rawOrder != null
        ? (List<dynamic>.from(rawOrder)
            ..add({'type': 'calc', 'calcIdx': newItems.length - 1}))
        : null;
    final newData = {
      ...sheet.data,
      'items': newItems,
      if (newOrder != null) 'displayOrder': newOrder,
    };
    setState(() {
      _localSheets = _localSheets
          .map((s) => s.id == selectedId ? s.copyWith(data: newData) : s)
          .toList();
    });
    widget.onSheetUpdate(selectedId, newData);
  }

  /// 複数アイテムをシート選択ダイアログで選んだ1つのシートに一括追加する
  Future<void> _pickSheetAndAddMultiple(
    List<Map<String, dynamic>> items,
  ) async {
    if (!mounted || items.isEmpty) return;
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '追加するシートを選択 (${items.length}件)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              for (final id in _sheetIds) ...[
                Builder(
                  builder: (bCtx) {
                    WidgetConfig? sheet;
                    try {
                      sheet = _localSheets.firstWhere((s) => s.id == id);
                    } catch (_) {}
                    final title =
                        sheet?.data['title'] as String? ?? '定型計算';
                    final itemCount =
                        (sheet?.data['items'] as List?)?.length ?? 0;
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5E81FF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.calculate_rounded,
                          color: Color(0xFF5E81FF),
                          size: 18,
                        ),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '$itemCount 件の計算',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                      onTap: () => Navigator.pop(ctx, id),
                    );
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (selectedId == null || !mounted) return;
    final sheetIdx = _localSheets.indexWhere((s) => s.id == selectedId);
    if (sheetIdx == -1) return;
    final sheet = _localSheets[sheetIdx];
    var rawItems = List<dynamic>.from(
      sheet.data['items'] as List<dynamic>? ?? [],
    );
    var rawOrder = sheet.data['displayOrder'] as List<dynamic>?;
    var newOrder = rawOrder != null ? List<dynamic>.from(rawOrder) : null;
    for (final item in items) {
      newOrder?.add({'type': 'calc', 'calcIdx': rawItems.length});
      final newItem = Map<String, dynamic>.from(item);
      if (newItem['name'] == null ||
          (newItem['name'] as String).isEmpty ||
          newItem['name'] == '計算') {
        newItem['name'] = '計算 ${rawItems.length + 1}';
      }
      rawItems.add(newItem);
    }
    final newData = {
      ...sheet.data,
      'items': rawItems,
      if (newOrder != null) 'displayOrder': newOrder,
    };
    setState(() {
      _localSheets = _localSheets
          .map((s) => s.id == selectedId ? s.copyWith(data: newData) : s)
          .toList();
    });
    widget.onSheetUpdate(selectedId, newData);
  }

  // ── シートナビゲーション ──────────────────────────────────────────────────
  void _showSheetNavPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'シートへ移動',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              for (int i = 0; i < _sheetIds.length; i++) ...[
                Builder(
                  builder: (bCtx) {
                    final id = _sheetIds[i];
                    WidgetConfig? sheet;
                    try {
                      sheet = _localSheets.firstWhere((s) => s.id == id);
                    } catch (_) {}
                    final title = sheet?.data['title'] as String? ?? '定型計算';
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_downward_rounded,
                        color: Colors.white24,
                        size: 16,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        // ボトムシートのpopアニメーション完了後にスクロール
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToSheet(id);
                        });
                      },
                    );
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToSheet(String sheetId) {
    final key = _sheetKeys[sheetId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
      return;
    }

    // ListView.builder の遅延レンダリングでウィジェットが未構築の場合:
    // 推定位置に先スクロールしてビルドを促してから再試行する
    final idx = _sheetIds.indexOf(sheetId);
    if (idx == -1 || !_scrollController.hasClients) return;

    final maxExtent = _scrollController.position.maxScrollExtent;
    final estimated = _sheetIds.length <= 1
        ? 0.0
        : (idx / (_sheetIds.length - 1)) * maxExtent;

    _scrollController
        .animateTo(
          estimated.clamp(0.0, maxExtent),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeIn,
        )
        .then((_) {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = _sheetKeys[sheetId]?.currentContext;
            if (ctx != null && mounted) {
              Scrollable.ensureVisible(
                ctx,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: 0.0,
              );
            }
          });
        });
  }

  void _removeSheet(String sheetId) {
    setState(() => _sheetIds.remove(sheetId));
    _persistMerged();
  }

  void _persistMerged() {
    widget.onMergedUpdate({
      ...widget.mergedConfig.data,
      'title': _title,
      'sheetIds': _sheetIds,
      'bgColor': _bgColor,
    });
  }

  void _applyModeToAll(int mode) {
    final bool viewMode = mode == 1;
    final bool tableMode = mode == 2;
    setState(() {
      _globalMode = mode;
      _localSheets = _localSheets.map((s) {
        if (_sheetIds.contains(s.id)) {
          return s.copyWith(
            data: {...s.data, 'viewMode': viewMode, 'tableMode': tableMode},
          );
        }
        return s;
      }).toList();
    });
    for (final id in _sheetIds) {
      final cfg = _localSheets.firstWhere(
        (s) => s.id == id,
        orElse: () => WidgetConfig(id: id, type: '', data: {}),
      );
      if (cfg.type.isEmpty) continue;
      widget.onSheetUpdate(id, cfg.data);
    }
  }

  void _showAllModePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '全シートの表示モード',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: Icon(
                Icons.edit_note_rounded,
                color: _globalMode == 0 ? Colors.white : Colors.white54,
              ),
              title: const Text(
                '編集モード',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                '全シートに適用',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              trailing: _globalMode == 0
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF5E81FF),
                    )
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _applyModeToAll(0);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.visibility_rounded,
                color: _globalMode == 1
                    ? const Color(0xFF5E81FF)
                    : Colors.white54,
              ),
              title: const Text(
                '閲覧モード',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                '全シートに適用',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              trailing: _globalMode == 1
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF5E81FF),
                    )
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _applyModeToAll(1);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.table_chart_rounded,
                color: _globalMode == 2
                    ? const Color(0xFF4CAF50)
                    : Colors.white54,
              ),
              title: const Text(
                '表モード',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                '全シートに適用',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              trailing: _globalMode == 2
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF4CAF50),
                    )
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _applyModeToAll(2);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(_bgColor);
    final mergedIsDark = bgColor.computeLuminance() < 0.5;
    final titleTextColor = mergedIsDark ? Colors.white : Colors.black87;
    final iconColor = mergedIsDark ? Colors.white70 : Colors.black54;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: iconColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: () async {
            final ctrl = TextEditingController(text: _title);
            int tempColor = _bgColor;
            final res = await showModalBottomSheet<Map<String, dynamic>>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.black,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (ctx) => StatefulBuilder(
                builder: (context, setSheetState) => Padding(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '結合ビュー名・カラー',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white54,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ビュー名',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: ctrl,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: '例: プロジェクト計算',
                          hintStyle: TextStyle(color: Colors.white24),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '背景カラー（アプバー・背景）',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: _kNoteColorPresets.where((p) => !p.isDark).map((preset) {
                                final isSelected = tempColor == preset.value;
                                return GestureDetector(
                                  onTap: () => setSheetState(
                                    () => tempColor = preset.value,
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Color(preset.value),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blueAccent
                                            : Colors.white24,
                                        width: isSelected ? 2.5 : 1,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check,
                                            size: 18,
                                            color: preset.isDark
                                                ? Colors.white
                                                : Colors.black54,
                                          )
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: _kNoteColorPresets.where((p) => p.isDark).map((preset) {
                                final isSelected = tempColor == preset.value;
                                return GestureDetector(
                                  onTap: () => setSheetState(
                                    () => tempColor = preset.value,
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Color(preset.value),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blueAccent
                                            : Colors.white24,
                                        width: isSelected ? 2.5 : 1,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check,
                                            size: 18,
                                            color: preset.isDark
                                                ? Colors.white
                                                : Colors.black54,
                                          )
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => Navigator.pop(ctx, {
                            'title': ctrl.text,
                            'bgColor': tempColor,
                          }),
                          child: const Text(
                            '保存',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            if (res != null) {
              setState(() {
                if ((res['title'] as String).isNotEmpty) {
                  _title = res['title'] as String;
                }
                _bgColor = res['bgColor'] as int;
              });
              _persistMerged();
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _title,
                  style: TextStyle(
                    color: titleTextColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        actions: const [],
      ),
      body: _sheetIds.isEmpty
          ? Center(
              child: Text(
                'シートがありません',
                style: TextStyle(
                  color: mergedIsDark ? Colors.white38 : Colors.black38,
                ),
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: _mergedCalcOpen
                          ? EdgeInsets.fromLTRB(
                              0,
                              8,
                              0,
                              MediaQuery.of(context).size.height * 0.65,
                            )
                          : const EdgeInsets.fromLTRB(0, 8, 0, 16),
                      itemCount: _sheetIds.length,
                      itemBuilder: (ctx, i) {
                        final id = _sheetIds[i];
                        WidgetConfig? sheetConfig;
                        try {
                          sheetConfig = _localSheets.firstWhere(
                            (s) => s.id == id,
                          );
                        } catch (_) {
                          sheetConfig = null;
                        }
                        if (sheetConfig == null) return const SizedBox.shrink();
                        return Padding(
                          key: _keyForSheet(id),
                          padding: const EdgeInsets.only(bottom: 16,right: 0, left: 0),
                          child: _MergedSheetSection(
                            key: ValueKey(id),
                            config: sheetConfig,
                            onUpdate: (data) {
                              setState(() {
                                _localSheets = _localSheets
                                    .map(
                                      (s) => s.id == id
                                          ? s.copyWith(data: data)
                                          : s,
                                    )
                                    .toList();
                              });
                              widget.onSheetUpdate(id, data);
                            },
                            onRemove: _sheetIds.length > 1
                                ? () => _removeSheet(id)
                                : null,
                            onDuplicate: () => widget.onSheetDuplicate(id),
                            globalConstants: widget.globalConstants,
                            clipboardNotifier: widget.clipboardNotifier,
                            allConfigs: widget.allConfigs.map((c) {
                              try {
                                return _localSheets.firstWhere(
                                  (s) => s.id == c.id,
                                );
                              } catch (_) {
                                return c;
                              }
                            }).toList(),
                            mergedSiblingIds: _sheetIds
                                .where((sid) => sid != id)
                                .toSet(),
                            onSheetUpdate: (sheetId, data) {
                              setState(() {
                                _localSheets = _localSheets
                                    .map(
                                      (s) => s.id == sheetId
                                          ? s.copyWith(data: data)
                                          : s,
                                    )
                                    .toList();
                              });
                              widget.onSheetUpdate(sheetId, data);
                            },
                            onSheetDuplicate: widget.onSheetDuplicate,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _MergedBottomNavBar(
        bgColor: _bgColor,
        globalMode: _globalMode,
        calcOpen: _mergedCalcOpen,
        onModeTap: () => _applyModeToAll((_globalMode + 1) % 3),
        onModeLongPress: _showAllModePicker,
        onSheetNav: _showSheetNavPicker,
        onCalcTap: _openMergedCalcSheet,
        clipboardNotifier: widget.clipboardNotifier,
        onClipboardClear: () => widget.clipboardNotifier?.value = null,
      ),
    );
  }
}

// ── 結合ビュー用ボトムナビゲーションバー ───────────────────────────────────────
class _MergedBottomNavBar extends StatelessWidget {
  final int bgColor;
  final int globalMode;
  final bool calcOpen;
  final VoidCallback onModeTap;
  final VoidCallback onModeLongPress;
  final VoidCallback onSheetNav;
  final VoidCallback onCalcTap;
  final ValueNotifier<Map<String, dynamic>?>? clipboardNotifier;
  final VoidCallback? onClipboardClear;

  const _MergedBottomNavBar({
    required this.bgColor,
    required this.globalMode,
    required this.calcOpen,
    required this.onModeTap,
    required this.onModeLongPress,
    required this.onSheetNav,
    required this.onCalcTap,
    this.clipboardNotifier,
    this.onClipboardClear,
  });

  @override
  Widget build(BuildContext context) {
    final IconData modeIcon;
    final Color modeColor;
    final String modeLabel;
    if (globalMode == 2) {
      modeIcon = Icons.table_chart_rounded;
      modeColor = const Color(0xFF4CAF50);
      modeLabel = '表モード';
    } else if (globalMode == 1) {
      modeIcon = Icons.visibility_rounded;
      modeColor = const Color(0xFF5E81FF);
      modeLabel = '閲覧';
    } else {
      modeIcon = Icons.edit_note_rounded;
      modeColor = const Color(0xFFBF5FFF);
      modeLabel = '編集';
    }

    final navBar = Container(
      decoration: BoxDecoration(
        color: Color(bgColor),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // ── 表示切替 ──
              Expanded(
                child: GestureDetector(
                  onTap: onModeTap,
                  onLongPress: onModeLongPress,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          modeIcon,
                          key: ValueKey(globalMode),
                          color: modeColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          modeLabel,
                          key: ValueKey(modeLabel),
                          style: TextStyle(
                            color: modeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── 区切り ──
              Container(
                width: 1,
                height: 32,
                color: Colors.white.withOpacity(0.08),
              ),

              // ── シートへ移動（中央・強調） ──
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: onSheetNav,
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color.fromARGB(255, 0, 0, 0), Color(0xFF252535)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.format_list_bulleted_rounded,
                            color: Colors.white.withOpacity(0.8),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'シートへ移動',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── 区切り ──
              Container(
                width: 1,
                height: 32,
                color: Colors.white.withOpacity(0.08),
              ),

              // ── 電卓 ──
              Expanded(
                child: GestureDetector(
                  onTap: onCalcTap,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: calcOpen
                              ? const Color(0xFF5E81FF).withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          calcOpen
                              ? Icons.close_rounded
                              : Icons.calculate_rounded,
                          color: calcOpen
                              ? const Color(0xFF5E81FF)
                              : const Color(0xFF5E81FF),
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '電卓',
                        style: TextStyle(
                          color: calcOpen
                              ? const Color(0xFF5E81FF)
                              : const Color(0xFF5E81FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // クリップボードバーがある場合は上に重ねる
    if (clipboardNotifier == null) return navBar;
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: clipboardNotifier!,
      builder: (_, item, __) {
        if (item == null) return navBar;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipboardBottomBar(
              item: item,
              onClear: onClipboardClear ?? () {},
            ),
            navBar,
          ],
        );
      },
    );
  }
}

class _MergedSheetSection extends StatefulWidget {
  final WidgetConfig config;
  final void Function(Map<String, dynamic>) onUpdate;
  final VoidCallback? onRemove;
  final VoidCallback? onDuplicate;
  final List<Map<String, dynamic>> globalConstants;
  final ValueNotifier<Map<String, dynamic>?>? clipboardNotifier;
  final List<WidgetConfig> allConfigs;
  final Set<String> mergedSiblingIds;
  final void Function(String, Map<String, dynamic>)? onSheetUpdate;
  final void Function(String)? onSheetDuplicate;

  const _MergedSheetSection({
    super.key,
    required this.config,
    required this.onUpdate,
    this.onRemove,
    this.onDuplicate,
    this.globalConstants = const [],
    this.clipboardNotifier,
    this.allConfigs = const [],
    this.mergedSiblingIds = const {},
    this.onSheetUpdate,
    this.onSheetDuplicate,
  });

  @override
  State<_MergedSheetSection> createState() => _MergedSheetSectionState();
}

class _MergedSheetSectionState extends State<_MergedSheetSection> {
  final _calcKey = GlobalKey<_CalculatorWidgetState>();
  OverlayEntry? _calcOverlay;
  bool _calcSheetOpen = false;
  bool _isAiGenerating = false;
  String? _pendingCalcDisplay;
  late WidgetConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    widget.clipboardNotifier?.addListener(_onClipboardChanged);
  }

  @override
  void didUpdateWidget(_MergedSheetSection old) {
    super.didUpdateWidget(old);
    if (old.clipboardNotifier != widget.clipboardNotifier) {
      old.clipboardNotifier?.removeListener(_onClipboardChanged);
      widget.clipboardNotifier?.addListener(_onClipboardChanged);
    }
    // 外部からの更新（onSheetUpdate 経由など）でも _config を反映する
    if (old.config != widget.config) {
      setState(() => _config = widget.config);
    }
  }

  void _onClipboardChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.clipboardNotifier?.removeListener(_onClipboardChanged);
    _calcOverlay?.remove();
    _calcOverlay = null;
    super.dispose();
  }

  void _handleUpdate(Map<String, dynamic> data) {
    setState(() => _config = _config.copyWith(data: data));
    widget.onUpdate(data);
  }

  Future<void> _handleCalcAiCountRequest() async {
    _closeCalcSheet();
    final ai = GemmaAi();
    if (!mounted) return;
    final count = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => _AiCountPage(onCount: ai.countInImage),
      ),
    );
    if (!mounted) return;
    if (count != null) {
      _pendingCalcDisplay = count.toString();
    }
    _openCalcSheet();
  }

  void _openCalcSheet() {
    if (_calcSheetOpen) {
      _closeCalcSheet();
      return;
    }
    final state = _calcKey.currentState;
    final currentItems =
        state?._items ?? (_config.data['items'] as List<dynamic>? ?? []);
    final bgColorValue = _config.data['bgColor'] as int?;
    final isDark = bgColorValue != null
        ? _kNoteColorPresets
              .firstWhere(
                (p) => p.value == bgColorValue,
                orElse: () => _kNoteColorPresets.first,
              )
              .isDark
        : true;

    setState(() => _calcSheetOpen = true);
    final pendingDisplay = _pendingCalcDisplay;
    _pendingCalcDisplay = null;
    _calcOverlay = OverlayEntry(
      builder: (ctx) => _CalcDraggableSheetContent(
        existingItemCount: currentItems.length,
        isDark: isDark,
        bgColor: bgColorValue,
        initialDisplay: pendingDisplay,
        onRequestAiCount: _handleCalcAiCountRequest,
        onAddItem: (item) => state?._addItemFromMap(item),
        onAddItems: (items) => state?._addItemsFromMaps(items),
        onClose: _closeCalcSheet,
      ),
    );
    Overlay.of(context).insert(_calcOverlay!);
  }

  void _closeCalcSheet() {
    _calcOverlay?.remove();
    _calcOverlay = null;
    if (mounted) setState(() => _calcSheetOpen = false);
  }

  void _showModePickerSheet(bool isDark) {
    final isViewMode = _config.data['viewMode'] as bool? ?? false;
    final isTableMode = _config.data['tableMode'] as bool? ?? false;
    final isEditMode = !isViewMode && !isTableMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '表示モードを選択',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: Icon(
                Icons.edit_note_rounded,
                color: isEditMode ? Colors.white : Colors.white54,
              ),
              title: const Text(
                '編集モード',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: isEditMode
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF5E81FF),
                    )
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _handleUpdate({
                  ..._config.data,
                  'viewMode': false,
                  'tableMode': false,
                });
              },
            ),
            ListTile(
              leading: Icon(
                Icons.visibility_rounded,
                color: isViewMode ? const Color(0xFF5E81FF) : Colors.white54,
              ),
              title: const Text(
                '閲覧モード',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: isViewMode
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF5E81FF),
                    )
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _handleUpdate({
                  ..._config.data,
                  'viewMode': true,
                  'tableMode': false,
                });
              },
            ),
            ListTile(
              leading: Icon(
                Icons.table_chart_rounded,
                color: isTableMode ? const Color(0xFF4CAF50) : Colors.white54,
              ),
              title: const Text(
                '表モード',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: isTableMode
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF4CAF50),
                    )
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _handleUpdate({
                  ..._config.data,
                  'viewMode': false,
                  'tableMode': true,
                });
              },
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: Color(0xFF7B7FFF),
                  size: 22,
                ),
              ),
              title: const Text(
                'リンクグラフ',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'シート間のリンク関係をグラフで可視化します',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LinkGraphPage(
                      configs: widget.allConfigs
                          .map((c) => {
                                'id': c.id,
                                'type': c.type,
                                'data': c.data,
                              })
                          .toList(),
                      initialSheetId: _config.id,
                      onOpenSheet: (_) => Navigator.pop(context),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isViewMode = _config.data['viewMode'] as bool? ?? false;
    final isTableMode = _config.data['tableMode'] as bool? ?? false;
    final bgColorValue = _config.data['bgColor'] as int?;
    final barBgColor = bgColorValue != null
        ? Color(bgColorValue)
        : const Color(0xFF161625);
    final isDarkBar = barBgColor.computeLuminance() < 0.5;

    final IconData modeIcon;
    final String modeLabel;
    final Color modeColor;
    if (isTableMode) {
      modeIcon = Icons.table_chart_rounded;
      modeLabel = '表モード';
      modeColor = const Color(0xFF4CAF50);
    } else if (isViewMode) {
      modeIcon = Icons.visibility_rounded;
      modeLabel = '閲覧モード';
      modeColor = const Color(0xFF5E81FF);
    } else {
      modeIcon = Icons.edit_note_rounded;
      modeLabel = '編集モード';
      modeColor = isDarkBar ? Colors.white38 : Colors.black45;
    }

    return Container(
      decoration: BoxDecoration(
        color: barBgColor,
        border: Border(
          top: BorderSide(
            color: isDarkBar
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.12),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isAiGenerating)
            const LinearProgressIndicator(
              color: Colors.purpleAccent,
              minHeight: 2,
              backgroundColor: Colors.transparent,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ToolbarButton(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI生成',
                  color: const Color(0xFF9E7AFF),
                  isLoading: _isAiGenerating,
                  showLabel: false,
                  onTap: () =>
                      _calcKey.currentState?._showAiGenerateCalcDialog(),
                ),
                _ToolbarButton(
                  icon: modeIcon,
                  label: modeLabel,
                  color: modeColor,
                  showLabel: false,
                  onTap: () {
                    if (isTableMode) {
                      _handleUpdate({
                        ..._config.data,
                        'viewMode': false,
                        'tableMode': false,
                      });
                    } else if (isViewMode) {
                      _handleUpdate({
                        ..._config.data,
                        'viewMode': false,
                        'tableMode': true,
                      });
                    } else {
                      _handleUpdate({
                        ..._config.data,
                        'viewMode': true,
                        'tableMode': false,
                      });
                    }
                  },
                  onLongPress: () => _showModePickerSheet(isDarkBar),
                ),
                _ToolbarButton(
                  icon: Icons.calculate_rounded,
                  label: '電卓',
                  color: isDarkBar ? Colors.white38 : Colors.black45,
                  showLabel: false,
                  onTap: _openCalcSheet,
                ),
                _ToolbarButton(
                  icon: Icons.add_rounded,
                  label: '行追加',
                  color: isDarkBar ? Colors.white54 : Colors.black54,
                  showLabel: false,
                  onTap: () => _calcKey.currentState?._addItem(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColorValue = _config.data['bgColor'] as int?;
    final cardBg = bgColorValue != null
        ? Color(bgColorValue)
        : const Color(0xFF1A1A26);
    final isDark = cardBg.computeLuminance() < 0.5;
    final titleColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.12);
    final title = _config.data['title'] as String? ?? '定型計算';

    return Container(
      decoration: BoxDecoration(
        color: cardBg.withAlpha(240),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // シートヘッダー
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _calcKey.currentState?._editTitle(),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
                if (_config.type != 'merged')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.link_rounded,
                          color: isDark ? Colors.blueAccent : Colors.blue,
                          size: 20,
                        ),
                        onPressed: () => ProGuard.checkAndRun(
                          context,
                          () => _calcKey.currentState?._showSheetLinkSettingsDialog(),
                        ),
                        tooltip: '値をリンク',
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      const ProBadge(),
                    ],
                  ),
                if (_config.type != 'merged')
                  IconButton(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: isDark ? Colors.blueAccent : Colors.blue,
                      size: 20,
                    ),
                    onPressed: () => _calcKey.currentState?._showActionSheet(),
                    tooltip: 'オプション',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          // 計算ウィジェットまたはネストされた結合シート
          if (_config.type == 'merged')
            _buildNestedMergedCard(context, isDark)
          else
            _CalculatorWidget(
              key: _calcKey,
              config: _config,
              onUpdate: _handleUpdate,
              onDuplicate: () => widget.onDuplicate?.call(),
              showToolbar: false,
              showHeader: false,
              contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              onAiGeneratingChanged: (v) => setState(() => _isAiGenerating = v),
              globalConstants: widget.globalConstants,
              clipboardNotifier: widget.clipboardNotifier,
              allConfigs: widget.allConfigs,
              mergedSiblingIds: widget.mergedSiblingIds,
              onSheetUpdate: widget.onSheetUpdate,
            ),
          // ボトムバー
          if (_config.type != 'merged') _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildNestedMergedCard(BuildContext context, bool isDark) {
    final sheetIds = (_config.data['sheetIds'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList();
    final sheets = sheetIds
        .map((id) {
          try {
            return widget.allConfigs.firstWhere((c) => c.id == id);
          } catch (_) {
            return null;
          }
        })
        .whereType<WidgetConfig>()
        .toList();
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MergedDetailPage(
              mergedConfig: _config,
              onMergedUpdate: (data) => _handleUpdate(data),
              sheets: sheets,
              allConfigs: widget.allConfigs,
              onSheetUpdate: widget.onSheetUpdate ?? (_, __) {},
              clipboardNotifier: widget.clipboardNotifier,
              onSheetDuplicate: widget.onSheetDuplicate ?? (_) {},
              globalConstants: widget.globalConstants,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              Icons.folder_copy_rounded,
              size: 56,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            const SizedBox(height: 16),
            Text(
              '${sheets.length}つのシートが結合されています',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'タップしてさらに展開',
              style: TextStyle(
                color: isDark
                    ? const Color(0xFF5E81FF)
                    : const Color(0xFF5E81FF),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isLoading;
  final bool showLabel;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.onLongPress,
    this.isLoading = false,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      onLongPress: isLoading ? null : onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: color,
                    ),
                  )
                : Icon(icon, color: color, size: 24),
            if (showLabel) ...[  
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color.withOpacity(isLoading ? 0.5 : 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// アプリ内クリップボードの内容を画面下部に表示するバー
class ClipboardBottomBar extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onClear;

  const ClipboardBottomBar({required this.item, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? '計算';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F3C),
        border: Border(
          top: BorderSide(color: Colors.blueAccent.withOpacity(0.5), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.content_paste_rounded,
            color: Colors.blueAccent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'クリップボード',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  name,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white54,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── QR 共有ダイアログ ─────────────────────────────────────────────────────────
class _QrShareDialog extends StatefulWidget {
  final List<String> qrDataList;
  final String title;
  final int itemCount;

  const _QrShareDialog({
    required this.qrDataList,
    required this.title,
    required this.itemCount,
  });

  @override
  State<_QrShareDialog> createState() => _QrShareDialogState();
}

class _QrShareDialogState extends State<_QrShareDialog> {
  int _currentPage = 0;
  bool _saving = false;

  Future<void> _saveCurrentQrAsImage() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (!await Gal.requestAccess()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('写真ライブラリへのアクセスが拒否されました'),
              backgroundColor: Color(0xFF2A2A3A),
            ),
          );
        }
        return;
      }
      final painter = QrPainter(
        data: widget.qrDataList[_currentPage],
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
      );
      // クワイエットゾーン（白余白）を付けてレンダリング
      const double qrSize = 460.0;
      const double quietZone = 30.0; // QR規格推奨: 4モジュール相当
      const double totalSize = qrSize + quietZone * 2;
      final recorder = PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, totalSize, totalSize),
      );
      // 白背景
      canvas.drawRect(
        Rect.fromLTWH(0, 0, totalSize, totalSize),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      // QRコードをパディング分オフセットして描画
      canvas.save();
      canvas.translate(quietZone, quietZone);
      painter.paint(canvas, const Size(qrSize, qrSize));
      canvas.restore();
      final picture = recorder.endRecording();
      final image = await picture.toImage(totalSize.toInt(), totalSize.toInt());
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) throw Exception('画像の生成に失敗しました');
      await Gal.putImageBytes(byteData.buffer.asUint8List());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QRコードを写真に保存しました'),
            backgroundColor: Color(0xFF1A3A2A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: const Color(0xFF2A2A3A),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.qrDataList.length;
    final isMulti = total > 1;
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final qrsize = width < height ? width : height;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Container(
        width: MediaQuery.of(context).size.width - 10,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 0, 0, 0),
          borderRadius: BorderRadius.circular(30),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // タイトルバー
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 8, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.qr_code_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isMulti
                            ? 'QRコードで共有 (${_currentPage + 1}/$total枚目)'
                            : 'QRコードで共有',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white38,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // QRコード
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: qrsize * 0.8,
                    height: qrsize * 0.8,
                    child: QrImageView(
                      data: widget.qrDataList[_currentPage],
                      version: QrVersions.auto,
                      size: qrsize * 0.8,
                      errorCorrectionLevel: QrErrorCorrectLevel.L,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // シート名
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.itemCount}件の計算データ',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (isMulti) ...[
                // 連結QR情報
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.tealAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.link_rounded,
                        color: Colors.tealAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '連結QR: ${_currentPage + 1}/$total枚目',
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '全てのQRコードを順番にスキャンしてください',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                // ページナビゲーションボタン
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: _currentPage > 0
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: _currentPage > 0
                              ? () => setState(() => _currentPage--)
                              : null,
                          child: Text(
                            '← 前へ',
                            style: TextStyle(
                              color: _currentPage > 0
                                  ? Colors.white70
                                  : Colors.white24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: _currentPage < total - 1
                                ? Colors.tealAccent.withValues(alpha: 0.15)
                                : Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: _currentPage < total - 1
                              ? () => setState(() => _currentPage++)
                              : null,
                          child: Text(
                            '次へ →',
                            style: TextStyle(
                              color: _currentPage < total - 1
                                  ? Colors.tealAccent
                                  : Colors.white24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '別の端末でスキャンしてシートを取り込めます',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // 画像として保存ボタン
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.tealAccent,
                      side: BorderSide(
                        color: Colors.tealAccent.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _saving ? null : _saveCurrentQrAsImage,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.tealAccent,
                            ),
                          )
                        : const Icon(Icons.save_alt_rounded, size: 18),
                    label: Text(_saving ? '保存中...' : '画像として保存'),
                  ),
                ),
              ),
              // 閉じるボタン
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '閉じる',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 複数シート QR 共有ダイアログ ──────────────────────────────────────────────
/// [MultiSheetQrDialog] は複数シートの QR データを一覧表示するダイアログです。
/// 各シートは複数チャンクを持つ場合があります。
class MultiSheetQrDialog extends StatefulWidget {
  /// 各シートの情報: title, itemCount, qrDataList (チャンク配列)
  final List<({String title, int itemCount, List<String> qrDataList})> sheets;

  const MultiSheetQrDialog({required this.sheets});

  @override
  State<MultiSheetQrDialog> createState() => _MultiSheetQrDialogState();
}

class _MultiSheetQrDialogState extends State<MultiSheetQrDialog> {
  /// 全シート・全チャンクを一本のフラットリストに展開
  late final List<({int sheetIdx, int chunkIdx})> _allQrs;
  int _currentIndex = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final list = <({int sheetIdx, int chunkIdx})>[];
    for (int si = 0; si < widget.sheets.length; si++) {
      for (int ci = 0; ci < widget.sheets[si].qrDataList.length; ci++) {
        list.add((sheetIdx: si, chunkIdx: ci));
      }
    }
    _allQrs = list;
  }

  ({String title, int itemCount, List<String> qrDataList}) get _sheet =>
      widget.sheets[_allQrs[_currentIndex].sheetIdx];

  String get _currentQrData =>
      _sheet.qrDataList[_allQrs[_currentIndex].chunkIdx];

  void _prev() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  void _next() {
    if (_currentIndex < _allQrs.length - 1) setState(() => _currentIndex++);
  }

  Future<void> _saveCurrentQrAsImage() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (!await Gal.requestAccess()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('写真ライブラリへのアクセスが拒否されました'),
              backgroundColor: Color(0xFF2A2A3A),
            ),
          );
        }
        return;
      }
      final painter = QrPainter(
        data: _currentQrData,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
      );
      const double qrSize = 460.0;
      const double quietZone = 30.0;
      const double totalSize = qrSize + quietZone * 2;
      final recorder = PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, totalSize, totalSize),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, totalSize, totalSize),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      canvas.save();
      canvas.translate(quietZone, quietZone);
      painter.paint(canvas, const Size(qrSize, qrSize));
      canvas.restore();
      final picture = recorder.endRecording();
      final image = await picture.toImage(totalSize.toInt(), totalSize.toInt());
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) throw Exception('画像の生成に失敗しました');
      await Gal.putImageBytes(byteData.buffer.asUint8List());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QRコードを写真に保存しました'),
            backgroundColor: Color(0xFF1A3A2A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: const Color(0xFF2A2A3A),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _allQrs.length;
    final cur = _allQrs[_currentIndex];
    final sheet = _sheet;
    final totalSheets = widget.sheets.length;
    final sheetChunks = sheet.qrDataList.length;

    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final qrSize = (width < height ? width : height) * 0.84;

    // シート内のチャンク番号（シートが複数チャンクを持つ場合のみ表示）
    final chunkLabel =
        sheetChunks > 1 ? '  (${cur.chunkIdx + 1}/$sheetChunks枚目)' : '';
    // シート番号ラベル（複数シートの場合のみ表示）
    final sheetLabel = totalSheets > 1
        ? 'シート ${cur.sheetIdx + 1} / $totalSheets  ·  '
        : '';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Container(
        width: width - 10,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー: シート名
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                children: [
                  Text(
                    sheet.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$sheetLabel${sheet.itemCount}件$chunkLabel',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // QR コード
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Container(
                width: qrSize,
                height: qrSize,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: _currentQrData,
                  version: QrVersions.auto,
                  errorCorrectionLevel: QrErrorCorrectLevel.L,
                ),
              ),
            ),
            // ナビゲーション（常に表示、1枚のみのときは矢印が無効）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _currentIndex > 0 ? _prev : null,
                    icon: Icon(
                      Icons.arrow_back_ios_rounded,
                      size: 22,
                      color: _currentIndex > 0
                          ? Colors.purpleAccent
                          : Colors.white24,
                    ),
                  ),
                  Text(
                    '${_currentIndex + 1} / $total',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: _currentIndex < total - 1 ? _next : null,
                    icon: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 22,
                      color: _currentIndex < total - 1
                          ? Colors.purpleAccent
                          : Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
            // 保存 & 閉じるボタン
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _saveCurrentQrAsImage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9E7AFF), Colors.purpleAccent],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_saving)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            else
                              const Icon(
                                Icons.save_alt_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            const SizedBox(width: 6),
                            const Text(
                              '画像として保存',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      '閉じる',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
