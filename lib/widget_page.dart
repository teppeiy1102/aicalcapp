library widget_page;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ai_service.dart';

part 'calc_input_widgets.dart';
part 'calculator_widget.dart';
part 'calculator_row.dart';
part 'memo_ai_widgets.dart';

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
  _NoteColorPreset(0xFF1A1A2E, isDark: true),
  _NoteColorPreset(0xFF16213E, isDark: true),
  _NoteColorPreset(0xFF0F3460, isDark: true),
  _NoteColorPreset(0xFF1B1B2F, isDark: true),
  _NoteColorPreset(0xFF2C2C54, isDark: true),
  _NoteColorPreset(0xFF222831, isDark: true),
  _NoteColorPreset(0xFF2D4A22, isDark: true),
  _NoteColorPreset(0xFF4A1942, isDark: true),
  _NoteColorPreset(0xFF3D1C02, isDark: true),
  _NoteColorPreset(0xFFF5F5F5, isDark: false),
  _NoteColorPreset(0xFFE8F4FD, isDark: false),
  _NoteColorPreset(0xFFFFF3E0, isDark: false),
  _NoteColorPreset(0xFFE8F5E9, isDark: false),
  _NoteColorPreset(0xFFFCE4EC, isDark: false),
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

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
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
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                final text = _ctrl.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(
                  context,
                  (instruction: text, isModify: _isModify),
                );
              },
              child: const Text('生成', style: TextStyle(fontSize: 16)),
            ),
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
  final bool isDark;
  final VoidCallback onClose;
  final ScrollController? scrollController;
  final DraggableScrollableController? sheetController;
  final String? initialDisplay;
  final Future<void> Function()? onRequestAiCount;

  const _CalcBottomSheet({
    required this.existingItemCount,
    required this.onAddItem,
    required this.onClose,
    this.isDark = true,
    this.scrollController,
    this.sheetController,
    this.initialDisplay,
    this.onRequestAiCount,
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
    if (v == v.truncateToDouble() && v.abs() < 1e15) return v.toInt().toString();
    if (v.abs() < 1e-15 || v.abs() >= 1e15) return v.toString();
    String s = v.toStringAsFixed(15);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  double _evalSimple(double a, String op, double b) {
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
          _display = '0'; _calcA = null; _calcOp = ''; _newEntry = true;
          _hasResult = false; _exprStr = ''; _termValues = []; _termOps = [];
          _isClearState = true;
        } else {
          _display = '0'; _newEntry = true; _isClearState = true;
        }
      } else if (key == '⌫') {
        if (!_newEntry && _display.length > 1) {
          _display = _display.substring(0, _display.length - 1);
        } else {
          _display = '0'; _newEntry = true;
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
          _exprStr = '${parts.join(' ')} = ${_fmt(result)}';
          _termValues = allTerms;
          _termOps = effectiveOps;
          _calcA = result; _calcOp = ''; _display = _fmt(result);
          _hasResult = true; _newEntry = true;
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
        } else if (_calcOp.isNotEmpty) {
          if (_termOps.isNotEmpty) _termOps[_termOps.length - 1] = key;
          _calcOp = key;
          return;
        } else {
          _termValues = [_calcA!];
          _termOps = [key];
        }
        _calcOp = key; _newEntry = true; _hasResult = false;
      } else if (key == '.') {
        _isClearState = false;
        if (_newEntry) {
          _display = '0.'; _newEntry = false; _hasResult = false;
        } else if (!_display.contains('.')) {
          _display += '.';
        }
      } else {
        _isClearState = false;
        if (_newEntry || _display == '0') {
          if (_hasResult && _calcOp.isEmpty) {
            _termValues = []; _termOps = []; _calcA = null;
          }
          _display = key; _newEntry = false; _hasResult = false;
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
      final others = List.generate(_termValues.length - 2, (i) => {
        'op': _opToDart(_termOps[i + 1]),
        'val': _termValues[i + 2],
        'unit': '',
      });
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
    final textColor = isDark ? Colors.white : Colors.black87;
    final keyBg = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.white.withOpacity(1);
    final opColor = isDark ? Colors.blueAccent : Colors.black87;
    final eqColor = isDark ? Colors.orangeAccent : Colors.black87;

    String inProg = '';
    if (_termValues.isNotEmpty) {
      final parts = <String>[];
      for (int i = 0; i < _termValues.length; i++) {
        parts.add(_fmt(_termValues[i]));
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
    final extent = (dsc != null && dsc.isAttached) ? dsc.size : 0.65;
    final sheetH = extent * screenH;

    // 固定 UI 要素の高さ（グリッド外）
    const kFixedH = 242.0; // ハンドル12 + ヘッダー40 + gap4 + 追加ボタン40 + 表示部80 + gap6 + pad上8 + pad下16
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
            // 「追加」ボタン
            AnimatedOpacity(
              opacity: _hasResult ? 1.0 : 0.35,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: _hasResult ? _addResult : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
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
            // 表示部
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // AIカウントアイコンボタン（横長）
                  GestureDetector(
                    onTap: _isAiCounting ? null : _showAiCountDialog,
                    child: AnimatedOpacity(
                      opacity: _isAiCounting ? 0.4 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(1),
                          borderRadius: BorderRadius.circular(1000),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.45),
                            width: 0.8,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.black,
                              size: 24,
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
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
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
                            _display,
                            maxLines: 1,
                            style: TextStyle(
                              height: 1,
                              color: textColor,
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
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
            GridView.count(
              padding: EdgeInsets.zero,
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: ratio,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                calcKey('C',
                    bg: Colors.redAccent.withOpacity(0.18),
                    fg: Colors.redAccent),
                calcKey('+/-', bg: keyBg),
                calcKey('%', bg: keyBg),
                calcKey('÷', bg: opColor.withOpacity(0.18), fg: opColor),
                calcKey('7'), calcKey('8'), calcKey('9'),
                calcKey('×', bg: opColor.withOpacity(0.18), fg: opColor),
                calcKey('4'), calcKey('5'), calcKey('6'),
                calcKey('-', bg: opColor.withOpacity(0.18), fg: opColor),
                calcKey('1'), calcKey('2'), calcKey('3'),
                calcKey('+', bg: opColor.withOpacity(0.18), fg: opColor),
                calcKey('⌫', bg: keyBg),
                calcKey('0'), calcKey('.'),
                calcKey('=', bg: eqColor.withOpacity(0.8), fg: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── ウィジェット詳細ページ ────────────────────────────────────────────────────
class WidgetDetailPage extends StatefulWidget {
  final WidgetConfig initialConfig;
  final void Function(Map<String, dynamic> data) onUpdate;
  final VoidCallback onDuplicate;

  const WidgetDetailPage({
    super.key,
    required this.initialConfig,
    required this.onUpdate,
    required this.onDuplicate,
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
    _calcSheetOverlay = OverlayEntry(
      builder: (ctx) => _CalcDraggableSheetContent(
        existingItemCount: currentItems.length,
        isDark: isDark,
        bgColor: bgColorValue,
        initialDisplay: _pendingCalcDisplay,
        onRequestAiCount: _handleCalcAiCountRequest,
        onAddItem: (item) {
          state?._addItemFromMap(item);
        },
        onClose: _closeCalcSheet,
      ),
    );
    _pendingCalcDisplay = null;
    Overlay.of(context).insert(_calcSheetOverlay!);
  }

  @override
  void dispose() {
    _calcSheetOverlay?.remove();
    _calcSheetOverlay = null;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _config.data['title'] as String? ?? '定型計算';
    final bgColorValue = _config.data['bgColor'] as int?;
    final scaffoldBgColor = bgColorValue != null ? Color(bgColorValue) : const Color(0xFF0D0D14);
    final isDark = scaffoldBgColor.computeLuminance() < 0.5;
    final fgColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
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
                  onAiGeneratingChanged: (v) => setState(() => _isAiGenerating = v),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
    final barBgColor = bgColorValue != null ? Color(bgColorValue) : const Color(0xFF161625);
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
                        _handleUpdate({..._config.data, 'viewMode': false, 'tableMode': false});
                      } else if (isViewMode) {
                        _handleUpdate({..._config.data, 'viewMode': false, 'tableMode': true});
                      } else {
                        _handleUpdate({..._config.data, 'viewMode': true, 'tableMode': false});
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
      backgroundColor: const Color(0xFF1A1A2E),
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
                    child: Text('表示モードを選択', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isEditMode ? Colors.white : Colors.white.withOpacity(0.07)).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.edit_note_rounded, color: isEditMode ? Colors.white : Colors.white54, size: 22),
              ),
              title: const Text('編集モード', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('計算式を編集できます', style: TextStyle(color: Colors.white38, fontSize: 12)),
              trailing: isEditMode ? const Icon(Icons.check_circle_rounded, color: Color(0xFF5E81FF)) : null,
              onTap: () {
                Navigator.pop(ctx);
                _handleUpdate({..._config.data, 'viewMode': false, 'tableMode': false});
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isViewMode ? const Color(0xFF5E81FF) : Colors.white.withOpacity(0.07)).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.visibility_rounded, color: isViewMode ? const Color(0xFF5E81FF) : Colors.white54, size: 22),
              ),
              title: const Text('閲覧モード', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('定数・メモ・計算結果を表示します', style: TextStyle(color: Colors.white38, fontSize: 12)),
              trailing: isViewMode ? const Icon(Icons.check_circle_rounded, color: Color(0xFF5E81FF)) : null,
              onTap: () {
                Navigator.pop(ctx);
                _handleUpdate({..._config.data, 'viewMode': true, 'tableMode': false});
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isTableMode ? const Color(0xFF4CAF50) : Colors.white.withOpacity(0.07)).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.table_chart_rounded, color: isTableMode ? const Color(0xFF4CAF50) : Colors.white54, size: 22),
              ),
              title: const Text('表モード', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('値のみをシート形式で表示・編集できます', style: TextStyle(color: Colors.white38, fontSize: 12)),
              trailing: isTableMode ? const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50)) : null,
              onTap: () {
                Navigator.pop(ctx);
                _handleUpdate({..._config.data, 'viewMode': false, 'tableMode': true});
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── 電卓ドラッガブルシート（DraggableScrollableController ライフサイクル管理） ──
class _CalcDraggableSheetContent extends StatefulWidget {
  final int existingItemCount;
  final void Function(Map<String, dynamic> item) onAddItem;
  final bool isDark;
  final int? bgColor;
  final VoidCallback onClose;
  final String? initialDisplay;
  final Future<void> Function()? onRequestAiCount;

  const _CalcDraggableSheetContent({
    required this.existingItemCount,
    required this.onAddItem,
    required this.isDark,
    required this.onClose,
    this.bgColor,
    this.initialDisplay,
    this.onRequestAiCount,
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
      initialChildSize: 0.65,
      minChildSize: 0.55,
      maxChildSize: 0.72,
      expand: true,
      snap: true,
      snapSizes: const [0.55, 0.65,0.72],
      builder: (ctx, scrollController) {
        final sheetColor = widget.bgColor != null
            ? Color(widget.bgColor!)
            : const Color(0xFF1A1A2E);
        return Material(
          color: sheetColor,
          shadowColor: Colors.black.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
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
              onClose: widget.onClose,
              initialDisplay: widget.initialDisplay,
              onRequestAiCount: widget.onRequestAiCount,
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
      onClose: () => ctrl?.close(),
    ),
  );
  ctrl?.closed.then((_) => onClosed?.call());
  return ctrl;
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
      contentPadding: contentPadding ?? const EdgeInsets.fromLTRB(16, 8, 16, 16),
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

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.onLongPress,
    this.isLoading = false,
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
        ),
      ),
    );
  }
}
