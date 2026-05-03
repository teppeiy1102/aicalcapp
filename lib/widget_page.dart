library widget_page;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ai_service.dart';

part 'calculator_widget.dart';

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

  const _CalcBottomSheet({
    required this.existingItemCount,
    required this.onAddItem,
    this.isDark = true,
  });

  @override
  State<_CalcBottomSheet> createState() => _CalcBottomSheetState();
}

class _CalcBottomSheetState extends State<_CalcBottomSheet> {
  String _display = '0';
  double? _calcA;
  String _calcOp = '';
  double _calcLastA = 0;
  double _calcLastB = 0;
  String _calcLastOp = '+';
  bool _newEntry = true;
  bool _hasResult = false;
  String _exprStr = '';
  bool _isClearState = true;
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
    if (mounted) Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final keyBg = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.07);
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

    Widget calcKey(String label, {Color? bg, Color? fg}) {
      final lbl = (label == 'C' || label == 'AC')
          ? (_isClearState ? 'AC' : 'C')
          : label;
      return _CalcKeyButton(
        label: lbl,
        bg: bg ?? keyBg,
        fg: fg ?? textColor,
        fontSize: 30,
        onTap: () => _onKey(lbl),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '電卓',
                  style: TextStyle(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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
          const SizedBox(height: 6),
          // ボタングリッド
          GridView.count(
            padding: EdgeInsets.zero,
            crossAxisCount: 4,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              calcKey('C', bg: Colors.redAccent.withOpacity(0.18), fg: Colors.redAccent),
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
          const SizedBox(height: 12),
          // AIカウントボタン
          if (_isAiCounting)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: LinearProgressIndicator(
                color: Colors.tealAccent,
                minHeight: 2,
                backgroundColor: Colors.transparent,
              ),
            ),
          GestureDetector(
            onTap: _isAiCounting ? null : _showAiCountDialog,
            child: AnimatedOpacity(
              opacity: _isAiCounting ? 0.5 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.tealAccent.withOpacity(0.35),
                    width: 0.8,
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.tealAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isAiCounting ? 'AIカウント中...' : 'AIカウント',
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
  bool _isAiGenerating = false;

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

  void _openCalcSheet() {
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CalcBottomSheet(
        existingItemCount: currentItems.length,
        isDark: isDark,
        onAddItem: (item) {
          state?._addItemFromMap(item);
        },
      ),
    );
  }

  Color _toolbarIconColor(bool isActive) =>
      isActive ? Colors.blueAccent : Colors.white54;

  @override
  Widget build(BuildContext context) {
    final title = _config.data['title'] as String? ?? '定型計算';
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D14).withOpacity(0.7),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
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
                    const Color(0xFF5E81FF).withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: _CalculatorWidget(
                key: _calcKey,
                config: _config,
                onUpdate: _handleUpdate,
                onDuplicate: widget.onDuplicate,
                showToolbar: false,
                showHeader: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton(
          onPressed: () => _calcKey.currentState?._addItem(),
          backgroundColor: const Color(0xFF5E81FF),
          foregroundColor: Colors.white,
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161625),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
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
                    onTap: () {
                      _calcKey.currentState?._showAiGenerateCalcDialog();
                    },
                  ),
                  _ToolbarButton(
                    icon: isViewMode ? Icons.edit_note_rounded : Icons.visibility_rounded,
                    label: isViewMode ? '編集モード' : '閲覧モード',
                    color: isViewMode ? const Color(0xFF5E81FF) : Colors.white38,
                    onTap: () => _handleUpdate(
                      {..._config.data, 'viewMode': !isViewMode},
                    ),
                  ),
                  _ToolbarButton(
                    icon: Icons.calculate_rounded,
                    label: '電卓',
                    color: Colors.white38,
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
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.8),
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
