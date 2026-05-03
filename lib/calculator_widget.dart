part of 'widget_page.dart';

// ── 電卓キーボタン（押し込みアニメーション付き） ──
class _CalcKeyButton extends StatefulWidget {
  final String label;
  final Color bg;
  final Color fg;
  final double fontSize;
  final VoidCallback onTap;

  const _CalcKeyButton({
    required this.label,
    required this.bg,
    required this.fg,
    required this.fontSize,
    required this.onTap,
  });

  @override
  State<_CalcKeyButton> createState() => _CalcKeyButtonState();
}

class _CalcKeyButtonState extends State<_CalcKeyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeIn,
        reverseCurve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) => _ctrl.forward();
  void _handleTapUp(TapUpDetails _) {
    _ctrl.reverse();
    widget.onTap();
  }

  void _handleTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(color: widget.bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.fg,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w100,
            ),
          ),
        ),
      ),
    );
  }
}

// ---- 数値入力用ミニ計算機シート ----
class _MiniCalcSheet extends StatefulWidget {
  final void Function(double) onResult;
  const _MiniCalcSheet({required this.onResult});

  @override
  State<_MiniCalcSheet> createState() => _MiniCalcSheetState();
}

class _MiniCalcSheetState extends State<_MiniCalcSheet> {
  String _display = '0';
  double? _calcA;
  String _calcOp = '';
  bool _newEntry = true;
  bool _hasResult = false;
  bool _isClearState = true;
  String _exprStr = '';
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
            // 演算子直後に = → 最後の演算子をキャンセルして直前の値を結果とする
            allTerms = List<double>.from(_termValues);
            effectiveOps = List<String>.from(_termOps)..removeLast();
          } else {
            final b = double.tryParse(_display) ?? 0;
            allTerms = List<double>.from(_termValues)..add(b);
            effectiveOps = List<String>.from(_termOps);
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

  @override
  Widget build(BuildContext context) {
    final keyBg = Colors.white.withOpacity(0.1);
    const opColor = Colors.blueAccent;
    const eqColor = Colors.orangeAccent;
    const textColor = Colors.white;

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

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
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
                  '計算機',
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
          AnimatedOpacity(
            opacity: _hasResult ? 1.0 : 0.35,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: _hasResult
                  ? () {
                      widget.onResult(double.tryParse(_display) ?? 0.0);
                      Navigator.pop(context);
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _hasResult
                      ? Colors.blueAccent
                      : Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'この値を入力',
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
          Container(
            height: 90,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        height: 1,
                        color: textColor.withOpacity(0.45),
                        fontSize: 16,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                FittedBox(
                  child: Text(
                    _display,
                    maxLines: 1,
                    style: const TextStyle(
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---- 定型計算ウィジェット ----
class _CalculatorWidget extends StatefulWidget {
  final WidgetConfig config;
  final void Function(Map<String, dynamic>) onUpdate;
  final VoidCallback onDuplicate;
  final bool showToolbar;
  final bool showHeader;
  final EdgeInsetsGeometry? contentPadding;

  const _CalculatorWidget({
    super.key,
    required this.config,
    required this.onUpdate,
    required this.onDuplicate,
    this.showToolbar = true,
    this.showHeader = true,
    this.contentPadding,
  });

  @override
  State<_CalculatorWidget> createState() => _CalculatorWidgetState();
}

class _CalculatorWidgetState extends State<_CalculatorWidget> {
  bool get _isExpanded => widget.config.data['isExpanded'] as bool? ?? true;

  void _toggleExpanded() {
    widget.onUpdate({...widget.config.data, 'isExpanded': !_isExpanded});
  }

  // ── 電卓パネル state ──
  bool _showCalc = false;
  String _calcDisplay = '0';
  double? _calcA;
  String _calcOp = '';
  double _calcLastA = 0;
  double _calcLastB = 0;
  String _calcLastOp = '+';
  bool _calcNewEntry = true;
  bool _calcHasResult = false;
  String _calcExprStr = '';
  bool _isClearState = true; // クリアボタンの状態管理
  bool _isAiGenerating = false; // AI生成中フラグ
  bool _isAiCounting = false; // AIカウント中フラグ
  bool get _viewMode =>
      widget.config.data['viewMode'] as bool? ?? false; // 閲覧モード
  // 多項追跡: 入力された全ての項の値と演算子を保持
  List<double> _calcTermValues = []; // [t0, t1, t2, ...]
  List<String> _calcTermOps = []; // [op01, op12, ...] ※表示形式 (+,-,×,÷)

  // item: { name: String, input: double, op: String, operand: double }
  List<Map<String, dynamic>> get _items {
    final raw = widget.config.data['items'] as List<dynamic>? ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _addItem() {
    final newItems = List<Map<String, dynamic>>.from(_items);
    newItems.add({
      'name': '計算 ${newItems.length + 1}',
      'input': 0.0,
      'op': '+',
      'operand': 0.0,
      'others': [],
      'brackets': [],
    });
    widget.onUpdate({...widget.config.data, 'items': newItems});
  }

  void _addItemFromMap(Map<String, dynamic> item) {
    final newItems = List<Map<String, dynamic>>.from(_items);
    newItems.add(item);
    widget.onUpdate({...widget.config.data, 'items': newItems});
  }

  void _insertItemAfter(int index) {
    final newItems = List<Map<String, dynamic>>.from(_items);
    newItems.insert(index + 1, {
      'name': '計算 ${newItems.length + 1}',
      'input': 0.0,
      'op': '+',
      'operand': 0.0,
      'others': [],
      'brackets': [],
    });
    widget.onUpdate({...widget.config.data, 'items': newItems});
  }

  void _toggleNameVisible(int index) {
    final newItems = List<Map<String, dynamic>>.from(_items);
    final item = Map<String, dynamic>.from(newItems[index]);
    item['nameVisible'] = !(item['nameVisible'] as bool? ?? true);
    newItems[index] = item;
    widget.onUpdate({...widget.config.data, 'items': newItems});
  }

  void _toggleAllNamesVisible() {
    final items = _items;
    final allVisible =
        items.every((item) => item['nameVisible'] as bool? ?? true);
    final newItems = items.map((item) {
      final updated = Map<String, dynamic>.from(item);
      updated['nameVisible'] = !allVisible;
      return updated;
    }).toList();
    widget.onUpdate({...widget.config.data, 'items': newItems});
  }

  static List<Map<String, dynamic>> get _sampleItems => [
    {
      'name': '計算 1',
      'input': 0.0,
      'op': '+',
      'operand': 0.0,
      'others': <dynamic>[],
      'brackets': <dynamic>[],
      'precision': 2,
    },
  ];

  void _addTerm(int index) {
    final newItems = List<Map<String, dynamic>>.from(_items);
    final item = Map<String, dynamic>.from(newItems[index]);
    final others = List<Map<String, dynamic>>.from(
      item['others'] as List? ?? [],
    );
    others.add({'op': '+', 'val': 0.0, 'unit': ''});
    item['others'] = others;
    newItems[index] = item;
    widget.onUpdate({...widget.config.data, 'items': newItems});
  }

  /// rowIdx を持つ全リンク参照を remap 関数で付け替える。
  /// remap が null を返した場合はそのリンクを解除する。
  List<Map<String, dynamic>> _remapLinkIndices(
    List<Map<String, dynamic>> items,
    int? Function(int) remap,
  ) {
    return items.map((item) {
      final updated = Map<String, dynamic>.from(item);

      // inputLinkSource
      if (updated['inputLink'] == true) {
        final src = updated['inputLinkSource'] as Map<String, dynamic>?;
        if (src != null) {
          final newIdx = remap(src['rowIdx'] as int? ?? 0);
          if (newIdx == null) {
            updated['inputLink'] = false;
            updated['inputLinkSource'] = null;
          } else {
            updated['inputLinkSource'] = {...src, 'rowIdx': newIdx};
          }
        }
      }

      // operandLinkSource
      if (updated['operandLink'] == true) {
        final src = updated['operandLinkSource'] as Map<String, dynamic>?;
        if (src != null) {
          final newIdx = remap(src['rowIdx'] as int? ?? 0);
          if (newIdx == null) {
            updated['operandLink'] = false;
            updated['operandLinkSource'] = null;
          } else {
            updated['operandLinkSource'] = {...src, 'rowIdx': newIdx};
          }
        }
      }

      // others の valLinkSource
      final others = List<Map<String, dynamic>>.from(
        updated['others'] as List? ?? [],
      );
      updated['others'] = others.map((other) {
        final o = Map<String, dynamic>.from(other);
        if (o['valLink'] == true) {
          final src = o['valLinkSource'] as Map<String, dynamic>?;
          if (src != null) {
            final newIdx = remap(src['rowIdx'] as int? ?? 0);
            if (newIdx == null) {
              o['valLink'] = false;
              o['valLinkSource'] = null;
            } else {
              o['valLinkSource'] = {...src, 'rowIdx': newIdx};
            }
          }
        }
        return o;
      }).toList();

      return updated;
    }).toList();
  }

  void _removeItem(int index) {
    var newItems = List<Map<String, dynamic>>.from(_items);
    newItems.removeAt(index);
    // 削除した行を参照していたリンクを解除し、以降のインデックスを繰り上げ
    newItems = _remapLinkIndices(newItems, (oldIdx) {
      if (oldIdx == index) return null;
      if (oldIdx > index) return oldIdx - 1;
      return oldIdx;
    });
    // 全て削除したらサンプルを追加
    if (newItems.isEmpty) {
      newItems = List<Map<String, dynamic>>.from(_sampleItems);
    }
    widget.onUpdate({...widget.config.data, 'items': newItems});
  }

  void _duplicateItem(int index) {
    var newItems = List<Map<String, dynamic>>.from(_items);
    final copy = Map<String, dynamic>.from(newItems[index]);
    copy['name'] = '${copy['name'] ?? ''} (コピー)';
    newItems.insert(index + 1, copy);
    // index より後の行がひとつ後ろにずれる
    newItems = _remapLinkIndices(newItems, (oldIdx) {
      if (oldIdx > index) return oldIdx + 1;
      return oldIdx;
    });
    widget.onUpdate({...widget.config.data, 'items': newItems});
  }

  void _moveItem(int from, int to) {
    if (to < 0 || to >= _items.length) return;
    var newItems = List<Map<String, dynamic>>.from(_items);
    final item = newItems.removeAt(from);
    newItems.insert(to, item);
    // 移動に伴うインデックス変化を全リンクに反映
    newItems = _remapLinkIndices(newItems, (oldIdx) {
      if (oldIdx == from) return to;
      if (from < to) {
        // from+1..to の行がひとつ前に詰まる
        if (oldIdx > from && oldIdx <= to) return oldIdx - 1;
      } else {
        // to..from-1 の行がひとつ後ろにずれる
        if (oldIdx >= to && oldIdx < from) return oldIdx + 1;
      }
      return oldIdx;
    });
    widget.onUpdate({...widget.config.data, 'items': newItems});
  }

  void _updateItem(int index, Map<String, dynamic> newItem) {
    var newItems = List<Map<String, dynamic>>.from(_items);

    // 一括適用フラグがある場合
    if (newItem.containsKey('_applyToAllKey')) {
      final key = newItem['_applyToAllKey'] as String;
      final skipLinked = newItem['_skipLinked'] == true;

      newItems = newItems.map((item) {
        final updated = Map<String, dynamic>.from(item);

        // 連動中の行をスキップ
        if (skipLinked) {
          if (key == 'input' && item['inputLink'] == true) return item;
          if (key == 'operand' && item['operandLink'] == true) return item;
          if (key.startsWith('other_')) {
            final parts = key.split('_');
            final otherIdx = int.parse(parts[1]);
            final othersList = item['others'] as List? ?? [];
            if (otherIdx < othersList.length &&
                (othersList[otherIdx] as Map)['valLink'] == true)
              return item;
          }
        }

        if (key.startsWith('other_')) {
          final parts = key.split('_');
          final otherIdx = int.parse(parts[1]);
          final field = parts[2]; // val, op
          final others = List<Map<String, dynamic>>.from(
            updated['others'] as List? ?? [],
          );
          if (otherIdx < others.length) {
            others[otherIdx][field] = newItem['others'][otherIdx][field];
            updated['others'] = others;
          }
        } else if (key == 'result') {
          updated['unitResult'] = newItem['unitResult'];
          updated['precision'] = newItem['precision'];
        } else if (key == 'details') {
          // すべての設定をコピー（名前以外）
          updated['precision'] = newItem['precision'];
          updated['unit1'] = newItem['unit1'];
          updated['unit2'] = newItem['unit2'];
          updated['unitResult'] = newItem['unitResult'];
          final others = List<Map<String, dynamic>>.from(
            updated['others'] as List? ?? [],
          );
          final newOthers = newItem['others'] as List;
          for (int i = 0; i < others.length && i < newOthers.length; i++) {
            others[i]['unit'] = newOthers[i]['unit'];
          }
          updated['others'] = others;
        } else {
          updated[key] = newItem[key];
          // 連動情報も一括コピー
          if (key == 'input') {
            updated['inputLink'] = newItem['inputLink'];
            updated['inputLinkSource'] = newItem['inputLinkSource'];
            updated['inputTransform'] = newItem['inputTransform'];
            updated['inputPowExp'] = newItem['inputPowExp'];
          } else if (key == 'operand') {
            updated['operandLink'] = newItem['operandLink'];
            updated['operandLinkSource'] = newItem['operandLinkSource'];
            updated['operandTransform'] = newItem['operandTransform'];
            updated['operandPowExp'] = newItem['operandPowExp'];
          }
        }
        return updated;
      }).toList();
    } else {
      newItems[index] = newItem;
    }

    widget.onUpdate({...widget.config.data, 'items': newItems});
  }

  void _editTitle() async {
    final currentTitle = widget.config.data['title'] as String? ?? '定型計算';
    final currentColor = widget.config.data['bgColor'] as int?;
    final ctrl = TextEditingController(text: currentTitle);
    int selectedColor = currentColor ?? _kNoteColorPresets.first.value;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
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
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ウィジェット名・カラー',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
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
                  const SizedBox(height: 16),
                  const Text(
                    'ウィジェット名',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: '例: 財務計算',
                      hintStyle: TextStyle(color: Colors.white24),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '背景カラー',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _kNoteColorPresets.map((preset) {
                        final isSelected = selectedColor == preset.value;
                        return GestureDetector(
                          onTap: () =>
                              setSheetState(() => selectedColor = preset.value),
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
                        'bgColor': selectedColor,
                      }),
                      child: const Text('保存', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      widget.onUpdate({
        ...widget.config.data,
        'title': result['title'],
        'bgColor': result['bgColor'],
      });
    }
  }

  void _showActionSheet() {
    final items = _items;
    final allNamesVisible =
        items.every((item) => item['nameVisible'] as bool? ?? true);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.calculate_outlined,
                    color: Colors.white54,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.config.data['title'] as String? ?? '定型計算',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: Icon(
                allNamesVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white70,
              ),
              title: Text(
                allNamesVisible
                    ? 'すべての計算名を非表示'
                    : 'すべての計算名を表示',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _toggleAllNamesVisible();
              },
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.white70),
              title: const Text(
                'ウィジェット名・カラーを編集',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _editTitle();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined, color: Colors.white70),
              title: const Text(
                'このシートを複製する',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                widget.onDuplicate();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.table_chart_outlined,
                color: Colors.white70,
              ),
              title: const Text(
                'CSV形式でコピーする',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _copyAsCsv();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _copyAsCsv() {
    final items = _items;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('コピーするデータがありません'),
          backgroundColor: Color(0xFF2A2A3A),
        ),
      );
      return;
    }

    // ---- パス1: 暫定計算（連動なし）----
    final List<double> provisionalResults = List.filled(items.length, 0.0);
    for (int pi = 0; pi < items.length; pi++) {
      final pItem = items[pi];
      final pInput = (pItem['input'] as num? ?? 0.0).toDouble();
      final pOperand = (pItem['operand'] as num? ?? 0.0).toDouble();
      final pOthers = (pItem['others'] as List? ?? []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        m['val'] = (m['val'] as num? ?? 0.0).toDouble();
        return m;
      }).toList();
      final r = _calculate(
        _CalculatorRow._applyTermTransform(
          pInput,
          pItem['inputTransform'] as String?,
          (pItem['inputPowExp'] as num? ?? 2.0).toDouble(),
        ),
        pItem['op'] as String? ?? '+',
        _CalculatorRow._applyTermTransform(
          pOperand,
          pItem['operandTransform'] as String?,
          (pItem['operandPowExp'] as num? ?? 2.0).toDouble(),
        ),
        pOthers,
        pItem['brackets'] as List? ?? [],
      );
      provisionalResults[pi] = r;
    }

    // ---- パス2: 反復収束によりチェーン連動を正しく解決 ----
    // finalResults をあらかじめ暫定値で初期化しておくことで
    // 前方参照（移動後に順序逆転したチェーン）でも正しい値が伝播する
    final List<double> finalResults = List<double>.from(provisionalResults);
    var resolvedRows = <Map<String, dynamic>>[];

    // ---- リンク解決ヘルパー ----
    double resolveLink(
      Map<String, dynamic>? source,
      bool isLink,
      double fallback,
    ) {
      if (!isLink) return fallback;
      if (source == null) {
        return finalResults.isNotEmpty ? finalResults.last : fallback;
      }
      final int sRowIdx = source['rowIdx'] as int? ?? 0;
      final String sTarget = source['target'] as String? ?? 'result';
      if (sRowIdx < 0 || sRowIdx >= items.length) return fallback;
      final sItem = items[sRowIdx];
      if (sTarget == 'result') return finalResults[sRowIdx];
      if (sTarget == 'input') return (sItem['input'] as num? ?? 0.0).toDouble();
      if (sTarget == 'operand')
        return (sItem['operand'] as num? ?? 0.0).toDouble();
      if (sTarget.startsWith('other_')) {
        final idx = int.tryParse(sTarget.split('_')[1]) ?? 0;
        final sOthers = sItem['others'] as List? ?? [];
        if (idx < sOthers.length) {
          return (sOthers[idx]['val'] as num? ?? 0.0).toDouble();
        }
      }
      return fallback;
    }

    // 最大 items.length 回の反復で任意のチェーン深さを収束させる
    for (int pass = 0; pass < items.length; pass++) {
      resolvedRows = [];
      bool anyChange = false;

      for (int i = 0; i < items.length; i++) {
        final item = items[i];

        final double inputValue = resolveLink(
          item['inputLinkSource'] as Map<String, dynamic>?,
          item['inputLink'] == true,
          (item['input'] as num? ?? 0.0).toDouble(),
        );
        final double operandValue = resolveLink(
          item['operandLinkSource'] as Map<String, dynamic>?,
          item['operandLink'] == true,
          (item['operand'] as num? ?? 0.0).toDouble(),
        );
        final othersValue = List.from(item['others'] as List? ?? []).map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          map['val'] = resolveLink(
            map['valLinkSource'] as Map<String, dynamic>?,
            map['valLink'] == true,
            (map['val'] as num? ?? 0.0).toDouble(),
          );
          return map;
        }).toList();

        final inputTransform = item['inputTransform'] as String?;
        final inputPowExp = (item['inputPowExp'] as num? ?? 2.0).toDouble();
        final operandTransform = item['operandTransform'] as String?;
        final operandPowExp = (item['operandPowExp'] as num? ?? 2.0).toDouble();

        final inputForCalc = _CalculatorRow._applyTermTransform(
          inputValue,
          inputTransform,
          inputPowExp,
        );
        final operandForCalc = _CalculatorRow._applyTermTransform(
          operandValue,
          operandTransform,
          operandPowExp,
        );
        final othersForCalc = othersValue.map((e) {
          final m = Map<String, dynamic>.from(e);
          final t = m['transform'] as String?;
          final exp = (m['powExp'] as num? ?? 2.0).toDouble();
          m['val'] = _CalculatorRow._applyTermTransform(
            (m['val'] as double),
            t,
            exp,
          );
          return m;
        }).toList();

        final res = _calculate(
          inputForCalc,
          item['op'] as String? ?? '+',
          operandForCalc,
          othersForCalc,
          item['brackets'] as List? ?? [],
        );
        if ((res - finalResults[i]).abs() > 1e-10) anyChange = true;
        finalResults[i] = res;
        resolvedRows.add({
          'input': inputValue,
          'operand': operandValue,
          'others': othersValue,
        });
      }
      if (!anyChange) break;
    }

    // ---- CSV 文字列組み立て ----
    String escapeCsv(String s) {
      if (s.contains(',') || s.contains('"') || s.contains('\n')) {
        return '"${s.replaceAll('"', '""')}"';
      }
      return s;
    }

    String fmtNum(double v, int precision) {
      if (v == v.truncateToDouble() && v.abs() < 1e12)
        return v.toInt().toString();
      return v.toStringAsFixed(precision);
    }

    final title = widget.config.data['title'] as String? ?? '定型計算';
    final buf = StringBuffer();
    buf.writeln(escapeCsv(title));
    buf.writeln('名前,計算式,結果');

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final resolved = resolvedRows[i];
      final name = item['name'] as String? ?? '';
      final precision = item['precision'] as int? ?? 2;
      final unitResult = item['unitResult'] as String? ?? '';
      final result = finalResults[i];
      final resultStr = '${fmtNum(result, precision)}$unitResult';

      final double input = resolved['input'] as double;
      final double operand = resolved['operand'] as double;
      final op = item['op'] as String? ?? '+';
      final unit1 = item['unit1'] as String? ?? '';
      final unit2 = item['unit2'] as String? ?? '';
      final others = resolved['others'] as List;
      var formula =
          '${fmtNum(input, precision)}$unit1 $op ${fmtNum(operand, precision)}$unit2';
      for (final o in others) {
        final m = o as Map;
        formula +=
            ' ${m['op'] ?? '+'} ${fmtNum((m['val'] as num? ?? 0.0).toDouble(), precision)}${m['unit'] ?? ''}';
      }

      buf.writeln(
        '${escapeCsv(name)},${escapeCsv(formula)},${escapeCsv(resultStr)}',
      );
    }

    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSVをクリップボードにコピーしました'),
        backgroundColor: Color(0xFF2A2A3A),
      ),
    );
  }

  void _applyToAllOther(int idx, String key) {
    final curItems = _items;
    if (curItems.isEmpty) return;
    final firstOthers = curItems.first['others'] as List? ?? [];
    if (firstOthers.length <= idx) return;
    final valueToApply = (firstOthers[idx] as Map)[key];

    final newItems = curItems.map((item) {
      final newItem = Map<String, dynamic>.from(item);
      final itemOthers = List<Map<String, dynamic>>.from(
        newItem['others'] as List? ?? [],
      );
      if (itemOthers.length > idx) {
        final newOther = Map<String, dynamic>.from(itemOthers[idx]);
        newOther[key] = valueToApply;
        itemOthers[idx] = newOther;
      }
      newItem['others'] = itemOthers;
      return newItem;
    }).toList();
    widget.onUpdate({...widget.config.data, 'items': newItems});
  }

  double _evaluateTokens(List<dynamic> tokens) {
    if (tokens.isEmpty) return 0.0;

    double extractVal(dynamic t) =>
        (t is Map ? (t['val'] ?? 0.0) : (t ?? 0.0)).toDouble();

    // 第1パス: 高優先度の演算子（x, /, %）を先に評価
    final List<dynamic> work = List.from(tokens);
    int i = 1;
    while (i < work.length) {
      final op = work[i] as String;
      if (op == 'x' || op == '/' || op == '%') {
        final result = _calculateSingle(
          extractVal(work[i - 1]),
          op,
          extractVal(work[i + 1]),
        );
        work.replaceRange(i - 1, i + 2, [
          {'val': result},
        ]);
      } else {
        i += 2;
      }
    }

    // 第2パス: 低優先度の演算子（+, -）を評価
    double res = extractVal(work[0]);
    for (int j = 1; j < work.length; j += 2) {
      res = _calculateSingle(res, work[j] as String, extractVal(work[j + 1]));
    }
    return res;
  }

  double _calculate(
    double input,
    String op,
    double operand,
    List<dynamic>? others,
    List<dynamic>? brackets,
  ) {
    // トークンリストの構築: [{val: 1.0, termIdx: 0}, "+", {val: 2.0, termIdx: 1}, ...]
    List<dynamic> tokens = [
      {'val': input, 'termIdx': 0},
      op,
      {'val': operand, 'termIdx': 1},
    ];
    if (others != null) {
      for (int i = 0; i < others.length; i++) {
        final map = others[i] as Map;
        tokens.add(map['op'] as String? ?? '+');
        tokens.add({
          'val': (map['val'] as num? ?? 0.0).toDouble(),
          'termIdx': i + 2,
        });
      }
    }

    if (brackets == null || brackets.isEmpty) {
      return _evaluateTokens(tokens);
    }

    final List<dynamic> currentTokens = List<dynamic>.from(tokens);
    final List<Map<String, int>> bList = brackets.map<Map<String, int>>((e) {
      final m = e as Map;
      return <String, int>{
        'start': (m['start'] as num).toInt(),
        'end': (m['end'] as num).toInt(),
      };
    }).toList();

    // ネストに対応するため、範囲が狭い順（内側）に処理
    bList.sort((Map<String, int> a, Map<String, int> b) {
      final int aSpan = a['end']! - a['start']!;
      final int bSpan = b['end']! - b['start']!;
      return aSpan.compareTo(bSpan);
    });

    for (final Map<String, int> b in bList) {
      final int start = b['start']!;
      final int end = b['end']!;

      int firstIdx = -1;
      int lastIdx = -1;
      for (int i = 0; i < currentTokens.length; i++) {
        final t = currentTokens[i];
        if (t is Map && t.containsKey('termIdx')) {
          final int tidx = (t['termIdx'] as num).toInt();
          if (tidx <= start) firstIdx = i;
          if (tidx <= end) lastIdx = i;
        }
      }

      if (firstIdx != -1 && lastIdx != -1 && firstIdx < lastIdx) {
        final List<dynamic> sub = currentTokens.sublist(firstIdx, lastIdx + 1);
        final double res = _evaluateTokens(sub);
        final Map firstMap = currentTokens[firstIdx] as Map;
        currentTokens.replaceRange(
          firstIdx,
          lastIdx + 1,
          <Map<String, dynamic>>[
            <String, dynamic>{
              'val': res,
              'termIdx': (firstMap['termIdx'] as num).toInt(),
            },
          ],
        );
      }
    }

    return _evaluateTokens(currentTokens);
  }

  double _calculateSingle(double input, String op, double operand) {
    switch (op) {
      case '+':
        return input + operand;
      case '-':
        return input - operand;
      case 'x':
        return input * operand;
      case '/':
        return operand != 0 ? input / operand : 0;
      case '%':
        return operand != 0 ? input % operand : 0;
      default:
        return input;
    }
  }

  // _applyTermTransform moved to _CalculatorRow as a static method

  // ── 電卓ロジック ──
  void _onCalcKey(String key) {
    setState(() {
      if (key == 'C' || key == 'AC') {
        if (_calcDisplay == '0' || key == 'AC') {
          // すでに 0 の場合、または AC が押された場合は全クリア
          _calcDisplay = '0';
          _calcA = null;
          _calcOp = '';
          _calcNewEntry = true;
          _calcHasResult = false;
          _calcExprStr = '';
          _calcTermValues = [];
          _calcTermOps = [];
          _isClearState = true;
        } else {
          // それ以外の場合は現在の入力のみクリア (C)
          _calcDisplay = '0';
          _calcNewEntry = true;
          _isClearState = true;
        }
      } else if (key == '⌫') {
        if (!_calcNewEntry && _calcDisplay.length > 1) {
          _calcDisplay = _calcDisplay.substring(0, _calcDisplay.length - 1);
        } else {
          _calcDisplay = '0';
          _calcNewEntry = true;
        }
      } else if (key == '+/-') {
        _isClearState = false;
        final v = double.tryParse(_calcDisplay) ?? 0;
        _calcDisplay = _fmtCalc(-v);
      } else if (key == '%') {
        _isClearState = false;
        final v = double.tryParse(_calcDisplay) ?? 0;
        _calcDisplay = _fmtCalc(v / 100);
      } else if (key == '=') {
        _isClearState = true;
        if (_calcA != null && _calcOp.isNotEmpty) {
          final List<double> allTerms;
          final List<String> effectiveOps;
          if (_calcNewEntry) {
            // 演算子直後に = → 最後の演算子をキャンセルして直前の値を結果とする
            allTerms = List<double>.from(_calcTermValues);
            effectiveOps = List<String>.from(_calcTermOps)..removeLast();
          } else {
            final b = double.tryParse(_calcDisplay) ?? 0;
            allTerms = List<double>.from(_calcTermValues)..add(b);
            effectiveOps = List<String>.from(_calcTermOps);
            _calcLastA = _calcA!;
            _calcLastOp = _opToDart(_calcOp);
            _calcLastB = b;
          }
          // 全項で左から右へ計算
          double result;
          if (allTerms.length == effectiveOps.length + 1 &&
              allTerms.length >= 2) {
            result = allTerms[0];
            for (int i = 0; i < effectiveOps.length; i++) {
              result = _evalCalcSimple(
                result,
                effectiveOps[i],
                allTerms[i + 1],
              );
            }
          } else {
            result = allTerms.isNotEmpty ? allTerms.last : (_calcA ?? 0);
          }
          // 式文字列を全項から構築
          final exprParts = <String>[];
          for (int i = 0; i < allTerms.length; i++) {
            exprParts.add(_fmtCalc(allTerms[i]));
            if (i < effectiveOps.length) exprParts.add(effectiveOps[i]);
          }
          _calcExprStr = '${exprParts.join(' ')} = ${_fmtCalc(result)}';
          _calcTermValues = allTerms;
          _calcTermOps = effectiveOps;
          _calcA = result;
          _calcOp = '';
          _calcDisplay = _fmtCalc(result);
          _calcHasResult = true;
          _calcNewEntry = true;
        } else {
          // 演算子なしで = を押した場合、何か意味のある入力があるときのみ結果扱い
          // （追加直後のリセット状態 = '0' / _calcA==null のときは無視）
          if (_calcDisplay != '0' || _calcA != null) {
            _calcHasResult = true;
          }
        }
      } else if (['+', '-', '×', '÷'].contains(key)) {
        _isClearState = true;
        if (!_calcNewEntry || _calcA == null) {
          // 新しい値を入力後に演算子を押した場合（または初回）
          final currentVal = double.tryParse(_calcDisplay) ?? 0;
          if (_calcTermValues.isEmpty) {
            _calcTermValues.add(currentVal); // 最初の項
          } else if (!_calcNewEntry) {
            _calcTermValues.add(currentVal); // 続く項
          }
          _calcTermOps.add(key);
          _calcA = currentVal;
        } else if (_calcOp.isNotEmpty) {
          // 演算子を押し直した場合（直前の演算子を置換）
          if (_calcTermOps.isNotEmpty) {
            _calcTermOps[_calcTermOps.length - 1] = key;
          }
          _calcOp = key;
          return;
        } else {
          // = の後に演算子を押した場合（結果から連続計算）
          _calcTermValues = [_calcA!];
          _calcTermOps = [key];
        }
        _calcOp = key;
        _calcNewEntry = true;
        _calcHasResult = false;
      } else if (key == '.') {
        _isClearState = false;
        if (_calcNewEntry) {
          _calcDisplay = '0.';
          _calcNewEntry = false;
          _calcHasResult = false;
        } else if (!_calcDisplay.contains('.')) {
          _calcDisplay += '.';
        }
      } else {
        // digit
        _isClearState = false;
        if (_calcNewEntry || _calcDisplay == '0') {
          // 結果表示中にオペレータなしで新しい数字を押した場合は新規計算
          if (_calcHasResult && _calcOp.isEmpty) {
            _calcTermValues = [];
            _calcTermOps = [];
            _calcA = null;
          }
          _calcDisplay = key;
          _calcNewEntry = false;
          _calcHasResult = false;
        } else if (_calcDisplay.length < 12) {
          _calcDisplay += key;
        }
      }
    });
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

  double _evalCalcSimple(double a, String op, double b) {
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

  String _fmtCalc(double v) {
    if (v.isInfinite || v.isNaN) return '0';
    if (v == 0) return '0';
    if (v == v.truncateToDouble() && v.abs() < 1e15) {
      return v.toInt().toString();
    }
    // 非常に小さい値（1e-15未満）や非常に大きい値（1e15以上）は指数表記
    if (v.abs() < 1e-15 || v.abs() >= 1e15) {
      return v.toString();
    }
    // それ以外は固定小数点表示（最大15桁）
    String s = v.toStringAsFixed(15);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  void _addCalcResult() {
    if (!_calcHasResult) return;
    final newItems = List<Map<String, dynamic>>.from(_items);
    final name = '計算 ${newItems.length + 1}';

    Map<String, dynamic> newItem;
    if (_calcTermValues.length >= 3 &&
        _calcTermOps.length == _calcTermValues.length - 1) {
      // 3項以上: others に追加分の項を格納
      final others = List.generate(_calcTermValues.length - 2, (i) {
        return {
          'op': _opToDart(_calcTermOps[i + 1]),
          'val': _calcTermValues[i + 2],
          'unit': '',
        };
      });
      newItem = {
        'name': name,
        'input': _calcTermValues[0],
        'op': _opToDart(_calcTermOps[0]),
        'operand': _calcTermValues[1],
        'others': others,
        'brackets': [],
      };
    } else {
      // 2項まで: 従来通り
      newItem = {
        'name': name,
        'input': _calcLastA,
        'op': _calcLastOp,
        'operand': _calcLastB,
        'others': [],
        'brackets': [],
      };
    }

    newItems.add(newItem);
    widget.onUpdate({...widget.config.data, 'items': newItems});
    setState(() {
      _calcHasResult = false;
      _calcDisplay = '0';
      _calcA = null;
      _calcOp = '';
      _calcNewEntry = true;
      _calcExprStr = '';
      _calcTermValues = [];
      _calcTermOps = [];
    });
  }

  Widget _buildInlineCalc(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // タブレット対応: 最大幅 360px でキャップし中央寄せ
        const double kMaxCalcWidth = 360.0;
        final double calcWidth = constraints.maxWidth.clamp(0.0, kMaxCalcWidth);
        final double scale = calcWidth / kMaxCalcWidth;
        final double keyFontSize = (32.0 * scale).clamp(18.0, 32.0);
        final double displayFontSize = (52.0 * scale).clamp(28.0, 52.0);
        final double subtitleFontSize = (20.0 * scale).clamp(12.0, 20.0);

        final textColor = isDark ? Colors.white : Colors.black87;
        final keyBg = isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.07);
        final opColor = isDark ? Colors.blueAccent : Colors.black87;
        final eqColor = isDark ? Colors.orangeAccent : Colors.black87;

        Widget calcKey(String label, {Color? bg, Color? fg}) {
          final actualLabel = (label == 'C' || label == 'AC')
              ? (_isClearState ? 'AC' : 'C')
              : label;
          return _CalcKeyButton(
            label: actualLabel,
            bg: bg ?? keyBg,
            fg: fg ?? textColor,
            fontSize: keyFontSize,
            onTap: () => _onCalcKey(actualLabel),
          );
        }

        // 計算途中の式を全項から構築: "1 + 2 +" のように表示
        String inProgressExpr = '';
        if (_calcTermValues.isNotEmpty) {
          final ipParts = <String>[];
          for (int i = 0; i < _calcTermValues.length; i++) {
            ipParts.add(_fmtCalc(_calcTermValues[i]));
            if (i < _calcTermOps.length) ipParts.add(_calcTermOps[i]);
          }
          inProgressExpr = ipParts.join(' ');
        }
        final String subtitle = _calcHasResult ? _calcExprStr : inProgressExpr;

        Widget content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 16),
            AnimatedOpacity(
              opacity: _calcHasResult ? 1.0 : 0.35,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: _calcHasResult ? _addCalcResult : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _calcHasResult
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
            ), // 表示部
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.0)
                    : Colors.black.withOpacity(0.0),
                borderRadius: BorderRadius.circular(0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (subtitle.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            height: 0.9,
                            color: textColor.withOpacity(0.45),
                            fontSize: subtitleFontSize,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    child: FittedBox(
                      child: Text(
                        _calcDisplay,
                        maxLines: 1,
                        style: TextStyle(
                          height: 1,
                          color: textColor,
                          fontSize: displayFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ボタングリッド
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.00)
                    : Colors.black.withOpacity(0.00),
                borderRadius: BorderRadius.circular(0),
              ),
              child: GridView.count(
                padding: EdgeInsets.zero,
                crossAxisCount: 4,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                childAspectRatio: 1,
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
            const SizedBox(height: 20),

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
                    color: Colors.teal.withOpacity(isDark ? 0.25 : 0.12),
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
                      Icon(
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
            const SizedBox(height: 4),

          ],
        );

        // タブレット: 最大幅でキャップして中央配置
        if (constraints.maxWidth > kMaxCalcWidth) {
          return Center(
            child: SizedBox(width: kMaxCalcWidth, child: content),
          );
        }
        return content;
      },
    );
  }

  // ── 閲覧モード用ウィジェット ──
  Widget _buildViewModeWidget() {
    final items = _items;
    final title = widget.config.data['title'] as String? ?? '定型計算';
    final bgColorValue = widget.config.data['bgColor'] as int?;
    final isDark = bgColorValue != null
        ? _kNoteColorPresets
              .firstWhere(
                (p) => p.value == bgColorValue,
                orElse: () => _kNoteColorPresets.first,
              )
              .isDark
        : true;

    // 結果計算（buildと同一ロジック）
    // Pass 1: 暫定計算（連動なし）
    final List<double> provisionalResults = List.filled(items.length, 0.0);
    for (int pi = 0; pi < items.length; pi++) {
      final pItem = items[pi];
      final pInput = (pItem['input'] as num? ?? 0.0).toDouble();
      final pOperand = (pItem['operand'] as num? ?? 0.0).toDouble();
      final pOthers = (pItem['others'] as List? ?? []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        m['val'] = (m['val'] as num? ?? 0.0).toDouble();
        return m;
      }).toList();
      final r = _calculate(
        _CalculatorRow._applyTermTransform(
          pInput,
          pItem['inputTransform'] as String?,
          (pItem['inputPowExp'] as num? ?? 2.0).toDouble(),
        ),
        pItem['op'] as String? ?? '+',
        _CalculatorRow._applyTermTransform(
          pOperand,
          pItem['operandTransform'] as String?,
          (pItem['operandPowExp'] as num? ?? 2.0).toDouble(),
        ),
        pOthers,
        pItem['brackets'] as List? ?? [],
      );
      provisionalResults[pi] = r;
    }

    // Pass 2: 反復収束によりチェーン連動を正しく解決
    final List<double> finalResults = List<double>.from(provisionalResults);
    var resolvedRows = <Map<String, dynamic>>[];

    double resolveLink(
      Map<String, dynamic>? source,
      bool isLink,
      double fallback,
    ) {
      if (!isLink) return fallback;
      if (source == null)
        return finalResults.isNotEmpty ? finalResults.last : fallback;
      final int sRowIdx = source['rowIdx'] as int? ?? 0;
      final String sTarget = source['target'] as String? ?? 'result';
      if (sRowIdx < 0 || sRowIdx >= items.length) return fallback;
      final sItem = items[sRowIdx];
      if (sTarget == 'result') return finalResults[sRowIdx];
      if (sTarget == 'input') return (sItem['input'] as num? ?? 0.0).toDouble();
      if (sTarget == 'operand')
        return (sItem['operand'] as num? ?? 0.0).toDouble();
      if (sTarget.startsWith('other_')) {
        final idx = int.tryParse(sTarget.split('_')[1]) ?? 0;
        final sOthers = sItem['others'] as List? ?? [];
        if (idx < sOthers.length)
          return (sOthers[idx]['val'] as num? ?? 0.0).toDouble();
      }
      return fallback;
    }

    for (int pass = 0; pass < items.length; pass++) {
      resolvedRows = [];
      bool anyChange = false;

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final double inputValue = resolveLink(
          item['inputLinkSource'] as Map<String, dynamic>?,
          item['inputLink'] == true,
          (item['input'] as num? ?? 0.0).toDouble(),
        );
        final double operandValue = resolveLink(
          item['operandLinkSource'] as Map<String, dynamic>?,
          item['operandLink'] == true,
          (item['operand'] as num? ?? 0.0).toDouble(),
        );
        final othersValue = List.from(item['others'] as List? ?? []).map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          map['val'] = resolveLink(
            map['valLinkSource'] as Map<String, dynamic>?,
            map['valLink'] == true,
            (map['val'] as num? ?? 0.0).toDouble(),
          );
          return map;
        }).toList();

        final res = _calculate(
          _CalculatorRow._applyTermTransform(
            inputValue,
            item['inputTransform'] as String?,
            (item['inputPowExp'] as num? ?? 2.0).toDouble(),
          ),
          item['op'] as String? ?? '+',
          _CalculatorRow._applyTermTransform(
            operandValue,
            item['operandTransform'] as String?,
            (item['operandPowExp'] as num? ?? 2.0).toDouble(),
          ),
          othersValue.map((e) {
            final m = Map<String, dynamic>.from(e);
            m['val'] = _CalculatorRow._applyTermTransform(
              (m['val'] as double),
              m['transform'] as String?,
              (m['powExp'] as num? ?? 2.0).toDouble(),
            );
            return m;
          }).toList(),
          item['brackets'] as List? ?? [],
        );
        if ((res - finalResults[i]).abs() > 1e-10) anyChange = true;
        finalResults[i] = res;
        resolvedRows.add({
          'input': inputValue,
          'operand': operandValue,
          'others': othersValue,
        });
      }
      if (!anyChange) break;
    }

    // 数値フォーマット
    String fmtNum(double v, int precision) {
      if (v.isNaN || v.isInfinite) return '0';
      if (v == v.truncateToDouble() && v.abs() < 1e12)
        return v.toInt().toString();
      return v.toStringAsFixed(precision);
    }

    // 計算式文字列を組み立て（括弧・トランスフォーム対応）
    String buildFormula(
      Map<String, dynamic> item,
      Map<String, dynamic> resolved,
      int precision,
    ) {
      final double iv = resolved['input'] as double;
      final double ov = resolved['operand'] as double;
      final String u1 = item['unit1'] as String? ?? '';
      final String u2 = item['unit2'] as String? ?? '';
      final String opStr = item['op'] as String? ?? '+';
      final others = resolved['others'] as List;
      final List<dynamic> bks = item['brackets'] as List? ?? [];

      // トランスフォーム情報
      final String? inputTr = item['inputTransform'] as String?;
      final double inputPow = (item['inputPowExp'] as num? ?? 2.0).toDouble();
      final String? operandTr = item['operandTransform'] as String?;
      final double operandPow = (item['operandPowExp'] as num? ?? 2.0).toDouble();

      bool hasStart(int idx) => bks.any((b) => (b as Map)['start'] == idx);
      bool hasEnd(int idx) => bks.any((b) => (b as Map)['end'] == idx);

      String termStr(double v, String u, String? transform, double powExp) {
        final s = fmtNum(v, precision);
        final base = u.isNotEmpty ? '$s $u' : s;
        return _CalculatorRow._transformExprStr(base, transform, powExp);
      }

      // 各項をトークンリストで組み立て
      final termCount = others.length + 2;
      final terms = <String>[];
      terms.add(termStr(iv, u1, inputTr, inputPow));
      terms.add(termStr(ov, u2, operandTr, operandPow));
      for (final o in others) {
        final m = o as Map;
        final oVal = (m['val'] as num? ?? 0.0).toDouble();
        final oUnit = m['unit'] as String? ?? '';
        final String? oTr = m['transform'] as String?;
        final double oPow = (m['powExp'] as num? ?? 2.0).toDouble();
        terms.add(termStr(oVal, oUnit, oTr, oPow));
      }

      final ops = <String>[opStr];
      for (final o in others) {
        ops.add((o as Map)['op'] as String? ?? '+');
      }

      final buf = StringBuffer();
      for (int idx = 0; idx < termCount; idx++) {
        if (hasStart(idx)) buf.write('( ');
        buf.write(terms[idx]);
        if (hasEnd(idx)) buf.write(' )');
        if (idx < ops.length) {
          buf.write('  ${ops[idx]}  ');
        }
      }
      return buf.toString();
    }

    final paperColor = isDark ? const Color(0xFF1A1A22) : const Color(0xFFFAFAFA);

    return Container(
      padding: widget.contentPadding ?? const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: paperColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'ZenOldMincho',
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                  onPressed: () => widget.onUpdate({...widget.config.data, 'viewMode': false}),
                  color: isDark ? Colors.white24 : Colors.black26,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: isDark ? Colors.white10 : Colors.black12, thickness: 0.5),
            const SizedBox(height: 24),
          ],
          
          if (items.isEmpty)
            Center(
              child: Text(
                '内容がありません',
                style: TextStyle(
                  color: isDark ? Colors.white12 : Colors.black12,
                  fontFamily: 'ZenOldMincho',
                ),
              ),
            )
          else
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final resolved = resolvedRows[i];
              final precision = item['precision'] as int? ?? 2;
              final name = item['name'] as String? ?? '';
              final result = finalResults[i];
              final unitResult = item['unitResult'] as String? ?? '';
              final formula = buildFormula(item, resolved, precision);
              final resultStr =
                  '${fmtNum(result, precision)}${unitResult.isNotEmpty ? ' $unitResult' : ''}';

              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black45,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'ZenOldMincho',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: formula,
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: 14,
                              fontFamily: 'ZenOldMincho',
                              height: 1.5,
                            ),
                          ),
                          TextSpan(
                            text: ' = ',
                            style: TextStyle(
                              color: isDark ? Colors.white24 : Colors.black12,
                              fontSize: 16,
                            ),
                          ),
                          TextSpan(
                            text: resultStr,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'ZenOldMincho',
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < items.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Divider(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), thickness: 0.5),
                      ),
                  ],
                ),
              );
            }),
          if (_showCalc) ...[
            const SizedBox(height: 12),
            _buildInlineCalc(isDark),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_viewMode) return _buildViewModeWidget();
    final items = _items;
    final bgColorValue = widget.config.data['bgColor'] as int?;
    final bgColor = bgColorValue != null
        ? Color(bgColorValue)
        : Colors.white.withOpacity(0.95);
    final isDark = bgColorValue != null
        ? _kNoteColorPresets
              .firstWhere(
                (p) => p.value == bgColorValue,
                orElse: () => _kNoteColorPresets.first,
              )
              .isDark
        : false;
    final headerTextColor = isDark ? Colors.white : Colors.black;
    final headerIconColor = isDark ? Colors.white70 : Colors.black54;
    return Container(
      padding: widget.contentPadding ??
          const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ヘッダー（折りたたみ可能）
              if (widget.showHeader)
                GestureDetector(
                  onTap: _toggleExpanded,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        color: headerIconColor,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.calculate_outlined,
                        color: headerTextColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.config.data['title'] as String? ?? '定型計算',
                          style: TextStyle(
                            color: headerTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => widget.onUpdate(
                            {...widget.config.data, 'viewMode': true}),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.visibility_outlined,
                            color: headerIconColor,
                            size: 20,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      GestureDetector(
                        onTap: _showActionSheet,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.more_vert,
                            color: headerIconColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.showHeader ? _isExpanded : true) ...[
                // const SizedBox(height: 20),

                // 「計算式がありません」または行リスト
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        '計算式がありません',
                        style: TextStyle(color: Colors.white24, fontSize: 12),
                      ),
                    ),
                  )
                else
                  ...(() {
                    // Pass 1: 暫定計算（連動なし）
                    final List<double> provisionalResults = List.filled(
                      items.length,
                      0.0,
                    );
                    for (int pi = 0; pi < items.length; pi++) {
                      final pItem = items[pi];
                      final pInput = (pItem['input'] as num? ?? 0.0)
                          .toDouble();
                      final pOperand = (pItem['operand'] as num? ?? 0.0)
                          .toDouble();
                      final pOthers = (pItem['others'] as List? ?? []).map((
                        e,
                      ) {
                        final m = Map<String, dynamic>.from(e as Map);
                        m['val'] = (m['val'] as num? ?? 0.0).toDouble();
                        return m;
                      }).toList();
                      final r = _calculate(
                        _CalculatorRow._applyTermTransform(
                          pInput,
                          pItem['inputTransform'] as String?,
                          (pItem['inputPowExp'] as num? ?? 2.0).toDouble(),
                        ),
                        pItem['op'] as String? ?? '+',
                        _CalculatorRow._applyTermTransform(
                          pOperand,
                          pItem['operandTransform'] as String?,
                          (pItem['operandPowExp'] as num? ?? 2.0).toDouble(),
                        ),
                        pOthers,
                        pItem['brackets'] as List? ?? [],
                      );
                      provisionalResults[pi] = r;
                    }

                    // Pass 2: 反復収束によりチェーン連動を正しく解決
                    final List<double> finalResults =
                        List<double>.from(provisionalResults);
                    var resolvedRows = <Map<String, dynamic>>[];

                    double resolveLink(
                      Map<String, dynamic>? source,
                      bool isLink,
                      double fallback,
                    ) {
                      if (!isLink) return fallback;
                      if (source == null) {
                        return finalResults.isNotEmpty
                            ? finalResults.last
                            : fallback;
                      }
                      final int sRowIdx = source['rowIdx'] as int? ?? 0;
                      final String sTarget =
                          source['target'] as String? ?? 'result';
                      if (sRowIdx < 0 || sRowIdx >= items.length)
                        return fallback;

                      final sItem = items[sRowIdx];
                      if (sTarget == 'result') {
                        return finalResults[sRowIdx];
                      }
                      if (sTarget == 'input') {
                        return (sItem['input'] as num? ?? 0.0).toDouble();
                      }
                      if (sTarget == 'operand') {
                        return (sItem['operand'] as num? ?? 0.0).toDouble();
                      }
                      if (sTarget.startsWith('other_')) {
                        final idx = int.tryParse(sTarget.split('_')[1]) ?? 0;
                        final sOthers = sItem['others'] as List? ?? [];
                        if (idx < sOthers.length) {
                          return (sOthers[idx]['val'] as num? ?? 0.0)
                              .toDouble();
                        }
                      }
                      return fallback;
                    }

                    for (int pass = 0; pass < items.length; pass++) {
                      resolvedRows = [];
                      bool anyChange = false;

                      for (int i = 0; i < items.length; i++) {
                        final item = items[i];

                        final double inputValue = resolveLink(
                          item['inputLinkSource'],
                          item['inputLink'] == true,
                          (item['input'] as num? ?? 0.0).toDouble(),
                        );
                        final double operandValue = resolveLink(
                          item['operandLinkSource'],
                          item['operandLink'] == true,
                          (item['operand'] as num? ?? 0.0).toDouble(),
                        );
                        final othersValue =
                            List.from(item['others'] as List? ?? []).map((e) {
                              final map = Map<String, dynamic>.from(e as Map);
                              map['val'] = resolveLink(
                                map['valLinkSource'],
                                map['valLink'] == true,
                                (map['val'] as num? ?? 0.0).toDouble(),
                              );
                              return map;
                            }).toList();

                        // 変換（指数/平方根）を計算用に適用（表示値は変換前を保持）
                        final inputTransform =
                            item['inputTransform'] as String?;
                        final inputPowExp =
                            (item['inputPowExp'] as num? ?? 2.0).toDouble();
                        final operandTransform =
                            item['operandTransform'] as String?;
                        final operandPowExp =
                            (item['operandPowExp'] as num? ?? 2.0).toDouble();
                        final inputForCalc = _CalculatorRow._applyTermTransform(
                          inputValue,
                          inputTransform,
                          inputPowExp,
                        );
                        final operandForCalc =
                            _CalculatorRow._applyTermTransform(
                              operandValue,
                              operandTransform,
                              operandPowExp,
                            );
                        final othersForCalc = othersValue.map((e) {
                          final m = Map<String, dynamic>.from(e);
                          final t = m['transform'] as String?;
                          final exp =
                              (m['powExp'] as num? ?? 2.0).toDouble();
                          m['val'] = _CalculatorRow._applyTermTransform(
                            (m['val'] as double),
                            t,
                            exp,
                          );
                          return m;
                        }).toList();

                        final res = _calculate(
                          inputForCalc,
                          item['op'] as String? ?? '+',
                          operandForCalc,
                          othersForCalc,
                          item['brackets'] as List? ?? [],
                        );
                        if ((res - finalResults[i]).abs() > 1e-10)
                          anyChange = true;
                        finalResults[i] = res;
                        resolvedRows.add({
                          'input': inputValue,
                          'operand': operandValue,
                          'others': othersValue,
                          'result': res,
                        });
                      }
                      if (!anyChange) break;
                    }

                    return (() {
                      final rows = <Widget>[];
                      items.asMap().entries.forEach((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        final resolved = resolvedRows[i];
                        if (i > 0) {
                          rows.add(Divider(
                            color: isDark
                                ? Colors.white.withOpacity(0.07)
                                : Colors.black.withOpacity(0.08),
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ));
                        }
                        rows.add(_CalculatorRow(
                          name: item['name'] as String? ?? '',
                          myIndex: i,
                          isFirst: i == 0,
                          input: resolved['input'],
                          inputLink: item['inputLink'] as bool? ?? false,
                          inputLinkSource:
                              item['inputLinkSource'] as Map<String, dynamic>?,
                          inputTransform: item['inputTransform'] as String?,
                          inputPowExp: (item['inputPowExp'] as num? ?? 2.0)
                              .toDouble(),
                          op: item['op'] as String? ?? '+',
                          operand: resolved['operand'],
                          operandLink: item['operandLink'] as bool? ?? false,
                          operandLinkSource:
                              item['operandLinkSource'] as Map<String, dynamic>?,
                          operandTransform: item['operandTransform'] as String?,
                          operandPowExp: (item['operandPowExp'] as num? ?? 2.0)
                              .toDouble(),
                          others: resolved['others'],
                          result: resolved['result'],
                          precision: item['precision'] as int? ?? 2,
                          unit1: item['unit1'] as String? ?? '',
                          unit2: item['unit2'] as String? ?? '',
                          unitResult: item['unitResult'] as String? ?? '',
                          isDark: isDark,
                          brackets: item['brackets'] as List? ?? [],
                          allItems: items,
                          allResults: finalResults,
                          onChanged: (newItem) => _updateItem(i, newItem),
                          onDelete: () => _removeItem(i),
                          onCopy: () => _duplicateItem(i),
                          onMoveUp: i > 0 ? () => _moveItem(i, i - 1) : null,
                          onMoveDown: i < items.length - 1
                              ? () => _moveItem(i, i + 1)
                              : null,
                          onAdd: () => _addTerm(i),
                          onPickBrackets: () => _pickBracketsFor(i),
                          onAllItemsUpdate: (newItems) => widget.onUpdate(
                            {...widget.config.data, 'items': newItems},
                          ),
                          nameVisible: item['nameVisible'] as bool? ?? true,
                          onInsertBelow: () => _insertItemAfter(i),
                          onToggleName: () => _toggleNameVisible(i),
                        ));
                      });
                      return rows;
                    })();
                  })(),
                const SizedBox(height: 12),
                // 下部ツールバー（showToolbar=true のときのみ表示）
                if (widget.showToolbar) ...[
                  if (_isAiGenerating)
                    const LinearProgressIndicator(
                      color: Colors.purpleAccent,
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                    ),
                  Divider(color: Colors.white.withOpacity(0.3), height: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(
                          Icons.auto_awesome_outlined,
                          color: Colors.purpleAccent.withOpacity(0.7),
                          size: 18,
                        ),
                        label: Text(
                          'AI生成',
                          style: TextStyle(
                            color: Colors.purpleAccent.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        onPressed: _showAiGenerateCalcDialog,
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: isDark ? Colors.white54 : Colors.black45,
                          size: 18,
                        ),
                        label: Text(
                          '追加',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () => _addItem(),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(
                          Icons.calculate,
                          color: _showCalc
                              ? Colors.blueAccent
                              : (isDark ? Colors.white54 : Colors.black45),
                          size: 18,
                        ),
                        label: Text(
                          '電卓',
                          style: TextStyle(
                            color: _showCalc
                                ? Colors.blueAccent
                                : (isDark ? Colors.white54 : Colors.black45),
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () => setState(() => _showCalc = !_showCalc),
                      ),
                    ],
                  ),
                  if (_showCalc) ...[_buildInlineCalc(isDark)],
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showAiGenerateCalcDialog() async {
    final ai = GemmaAi();
    if (!ai.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AIが初期化されていません。'),
          backgroundColor: Color(0xFF2A2A3A),
        ),
      );
      return;
    }

    final result =
        await showModalBottomSheet<({String instruction, bool isModify})>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => const _AiPromptSheet(
            title: 'AIで計算式を生成',
            initialText: '',
            showModeSwitcher: false,
          ),
        );

    if (result == null || result.instruction.isEmpty) return;
    if (!mounted) return;

    final instruction = result.instruction;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('計算式を生成中...'),
        duration: Duration(seconds: 2),
      ),
    );

    setState(() => _isAiGenerating = true);

    final prompt =
        """
User wants to generate a calculator expression for: "$instruction".
Return a JSON array containing EXACTLY ONE item. 

[CRITICAL INSTRUCTIONS]
1. Combine all calculation steps into the 'others' list of a single item. If no extra steps are needed, 'others' should be an empty list [].
2. For variables the user needs to input (e.g., "base", "height"), set "input" or "val" to 0.0 and put the label in "unit".
3. For mathematical constants required by the formula (e.g., "2" in triangle area, "3.14" in circle), set the specific numerical value in "input", "operand", or "val".
4. [IMPORTANT] Be mathematically precise. Only use division or constants (like /2) if the specific formula requires it (e.g., Triangle has /2, Square DOES NOT have /2).
5. Use "brackets" to specify priority calculations (parentheses). Index 0 is "input", index 1 is "operand", index 2 is "others[0]", index 3 is "others[1]", and so on.
6. Ensure the formula is mathematically correct.

Structure:
{
  "name": "Calculation name",
  "input": 0.0,
  "unit1": "label for first value",
  "op": "+", (one of: +, -, x, /, %)
  "operand": 0.0,
  "unit2": "label for second value",
  "others": [
    { "op": "/", "val": 2.0, "unit": "" }
  ],
  "brackets": [
    { "start": 0, "end": 1 }
  ],
  "unitResult": "label for result",
  "precision": 2
}

Example: "三角形の面積" (base x height / 2)
[{
  "name": "三角形の面積",
  "input": 0.0,
  "unit1": "底辺",
  "op": "x",
  "operand": 0.0,
  "unit2": "高さ",
  "others": [{ "op": "/", "val": 2.0, "unit": "定数" }],
  "brackets": [],
  "unitResult": "面積",
  "precision": 2
}]

Example: "台形の面積" ( (upper + lower) * height / 2 )
[{
  "name": "台形の面積",
  "input": 0.0,
  "unit1": "上底",
  "op": "+",
  "operand": 0.0,
  "unit2": "下底",
  "others": [
    { "op": "x", "val": 0.0, "unit": "高さ" },
    { "op": "/", "val": 2.0, "unit": "定数" }
  ],
  "brackets": [
    { "start": 0, "end": 1 }
  ],
  "unitResult": "面積",
  "precision": 2
}]

Example: "正方形の面積" (side x side)
[{
  "name": "正方形の面積",
  "input": 0.0,
  "unit1": "一辺",
  "op": "x",
  "operand": 0.0,
  "unit2": "一辺",
  "others": [],
  "brackets": [],
  "unitResult": "面積",
  "precision": 2
}]

Return ONLY the JSON array. Do not include any explanations.
""";

    try {
      final res = await ai.query(
        prompt,
        systemPrompt:
            "You are a calculator generator AI. Return a JSON array with EXACTLY ONE item.",
      );
      final jsonStart = res.indexOf('[');
      final jsonEnd = res.lastIndexOf(']');
      if (jsonStart != -1 && jsonEnd != -1) {
        final jsonStr = res.substring(jsonStart, jsonEnd + 1);
        final list = jsonDecode(jsonStr) as List<dynamic>;
        final newItems = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        final currentItems = result.isModify
            ? <Map<String, dynamic>>[]
            : List<Map<String, dynamic>>.from(_items);

        // 強制的に1つだけに絞る（もしAIが複数返してきた場合）
        if (newItems.isNotEmpty) {
          currentItems.add(newItems.first);
        }

        widget.onUpdate({...widget.config.data, 'items': currentItems});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('生成失敗: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isAiGenerating = false);
      }
    }
  }

  /// 画像をAIに送り、指示に従って数をカウントして電卓に反映する
  void _showAiCountDialog() async {
    // ローカルGemma・xAI両方対応
    final ai = GemmaAi();
    final bool isLocal = ai.currentModel == AiModel.local;
    if (isLocal && !ai.isInitialized) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ローカルAIが初期化されていません。'),
          backgroundColor: Color(0xFF2A2A3A),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isAiCounting = true);

    final count = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => _AiCountPage(onCount: ai.countInImage),
      ),
    );

    if (!mounted) return;
    setState(() => _isAiCounting = false);

    if (count != null) {
      setState(() {
        _calcDisplay = count.toString();
        _calcNewEntry = true;
        _calcHasResult = false;
        _isClearState = false;
        _calcA = null;
        _calcOp = '';
        _calcTermValues = [];
        _calcTermOps = [];
        _calcExprStr = '';
      });
    }
  }

  void _pickBracketsFor(int rowIndex) async {
    final items = _items;
    if (rowIndex >= items.length) return;
    final item = items[rowIndex];
    final others = item['others'] as List? ?? [];
    final int termCount = others.length + 2;
    final List<dynamic> localBrackets = List.from(
      item['brackets'] as List? ?? [],
    );

    int startIdx = 0;
    int endIdx = 1;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text(
              '優先計算（ ）の範囲指定',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '開始項目',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                DropdownButton<int>(
                  value: startIdx,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A2E),
                  items: List.generate(
                    termCount - 1,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(
                        '項${i + 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  onChanged: (v) => setDialogState(() {
                    startIdx = v!;
                    if (endIdx <= startIdx) endIdx = startIdx + 1;
                  }),
                ),
                const SizedBox(height: 16),
                const Text(
                  '終了項目',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                DropdownButton<int>(
                  value: endIdx,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A2E),
                  items: List.generate(
                    termCount,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(
                        '項${i + 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ).where((item) => item.value! > startIdx).toList(),
                  onChanged: (v) => setDialogState(() => endIdx = v!),
                ),
                if (localBrackets.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '現在の指定',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const Divider(color: Colors.white24),
                  ...localBrackets.asMap().entries.map((e) {
                    final b = e.value as Map;
                    return Row(
                      children: [
                        Text(
                          '項${(b['start'] as num).toInt() + 1} 〜 項${(b['end'] as num).toInt() + 1}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              localBrackets.removeAt(e.key);
                            });
                            // 親の状態も即時更新して計算結果を反映
                            final newItems = List<Map<String, dynamic>>.from(
                              _items.asMap().entries.map((en) {
                                if (en.key == rowIndex) {
                                  return <String, dynamic>{
                                    ...en.value,
                                    'brackets': List.from(localBrackets),
                                  };
                                }
                                return en.value;
                              }),
                            );
                            setState(() {
                              widget.onUpdate({
                                ...widget.config.data,
                                'items': newItems,
                              });
                            });
                          },
                        ),
                      ],
                    );
                  }),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () {
                  if (startIdx >= endIdx) return;
                  setDialogState(() {
                    localBrackets.add({'start': startIdx, 'end': endIdx});
                  });
                  final newItems = List<Map<String, dynamic>>.from(
                    _items.asMap().entries.map((en) {
                      if (en.key == rowIndex) {
                        return <String, dynamic>{
                          ...en.value,
                          'brackets': List.from(localBrackets),
                        };
                      }
                      return en.value;
                    }),
                  );
                  setState(() {
                    widget.onUpdate({...widget.config.data, 'items': newItems});
                  });
                  Navigator.pop(ctx);
                },
                child: const Text(
                  '追加',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CalculatorRow extends StatelessWidget {
  final String name;
  final int myIndex;
  final bool isFirst;
  final double input;
  final bool inputLink;
  final Map<String, dynamic>? inputLinkSource;
  final String? inputTransform;
  final double inputPowExp;
  final String op;
  final double operand;
  final bool operandLink;
  final Map<String, dynamic>? operandLinkSource;
  final String? operandTransform;
  final double operandPowExp;
  final List<dynamic> others;
  final List<dynamic>? brackets;
  final double result;
  final int precision;
  final String unit1;
  final String unit2;
  final String unitResult;
  final bool isDark;
  final List<dynamic> allItems;
  final List<double> allResults;
  final Function(Map<String, dynamic>) onChanged;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onAdd;
  final VoidCallback onPickBrackets;
  final void Function(List<Map<String, dynamic>>) onAllItemsUpdate;
  final VoidCallback? onInsertBelow;
  final VoidCallback? onToggleName;
  final bool nameVisible;

  const _CalculatorRow({
    required this.name,
    required this.myIndex,
    this.isFirst = false,
    required this.input,
    this.inputLink = false,
    this.inputLinkSource,
    this.inputTransform,
    this.inputPowExp = 2.0,
    required this.op,
    required this.operand,
    this.operandLink = false,
    this.operandLinkSource,
    this.operandTransform,
    this.operandPowExp = 2.0,
    required this.others,
    this.brackets,
    required this.result,
    required this.precision,
    required this.unit1,
    required this.unit2,
    required this.unitResult,
    this.isDark = false,
    required this.allItems,
    required this.allResults,
    required this.onChanged,
    required this.onDelete,
    required this.onCopy,
    this.onMoveUp,
    this.onMoveDown,
    required this.onAdd,
    required this.onPickBrackets,
    required this.onAllItemsUpdate,
    this.onInsertBelow,
    this.onToggleName,
    this.nameVisible = true,
  });

  static const Map<String, double> commonConstants = {
    'π (円周率)': math.pi,
    'e (ネイピア数)': math.e,
    'φ (黄金比)': 1.618033988749895,
    'c (光速)': 299792458,
    'G (万有引力定数)': 6.67430e-11,
    'g (重力加速度)': 9.80665,
    'h (プランク定数)': 6.62607015e-34,
    'Na (アボガドロ定数)': 6.02214076e23,
    'R (気体定数)': 8.314462618,
    'k (ボルツマン定数)': 1.380649e-23,
  };

  void _showMiniCalcSheet(
    BuildContext context,
    void Function(double) onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MiniCalcSheet(onResult: onSelected),
    );
  }

  void _showConstantPicker(
    BuildContext context,
    void Function(double) onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '定数を選択',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: commonConstants.entries
                      .map(
                        (e) => InkWell(
                          onTap: () {
                            onSelected(e.value);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  e.key,
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  e.value.toString().contains('e')
                                      ? e.value
                                            .toStringAsExponential(3)
                                            .replaceFirst('e', ' × 10^')
                                      : (e.value.toString().length > 10
                                            ? e.value.toStringAsFixed(4)
                                            : e.value.toString()),
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static const Map<String, List<String>> unitCategories = {
    'よく使う': ['円', '個', '%', '人', '回', '点', '枚', '台', '件', '組', 'セット', '箱'],
    '通貨/金融': ['円', '\$', '€', '£', '元', '₩', '¥', 'BTC', 'ETH', 'pts', '株'],
    '割合/数': ['%', '‰', '倍', '割', '分', 'ppm', 'ppb', 'doz', '対', '本'],
    '時間': [
      'hrs',
      'min',
      'sec',
      'ms',
      '日',
      '月',
      '年',
      '週',
      '世紀',
      '期',
      '営業日',
      'h',
    ],
    '重さ': ['kg', 'g', 'mg', 't', 'lb', 'oz', 'カラット', '貫', '斤', '匁'],
    '長さ': [
      'm',
      'cm',
      'mm',
      'km',
      'inch',
      'ft',
      'yd',
      'mile',
      '光年',
      '海里',
      '尺',
      '寸',
      '里',
    ],
    '容量': [
      'L',
      'ml',
      'cc',
      'm³',
      'tsp',
      'tbsp',
      'cup',
      'gal',
      'バレル',
      '升',
      '斗',
      '合',
    ],
    '面積': ['m²', 'cm²', 'km²', 'ha', 'a', '坪', '畳', 'エーカー', '反', '畝'],
    '温度/気圧': ['℃', '℉', 'K', 'Pa', 'bar', 'hPa', 'atm', 'mmHg', 'psi'],
    '速度/電力': [
      'km/h',
      'm/s',
      'knot',
      'mach',
      'W',
      'kW',
      'V',
      'A',
      'Hz',
      'dB',
      'cal',
      'kcal',
      'J',
    ],
  };

  Map<String, dynamic> _toMap() {
    return {
      'name': name,
      'input': input,
      'inputLink': inputLink,
      'inputLinkSource': inputLinkSource,
      'inputTransform': inputTransform,
      'inputPowExp': inputPowExp,
      'op': op,
      'operand': operand,
      'operandLink': operandLink,
      'operandLinkSource': operandLinkSource,
      'operandTransform': operandTransform,
      'operandPowExp': operandPowExp,
      'others': others,
      'brackets': brackets,
      'precision': precision,
      'unit1': unit1,
      'unit2': unit2,
      'unitResult': unitResult,
    };
  }

  void _updateWith({
    double? newInput,
    String? newUnit1,
    bool? newInputLink,
    Map<String, dynamic>? newInputLinkSource,
    bool updateInputTransform = false,
    String? newInputTransform,
    double? newInputPowExp,
    String? newOp,
    double? newOperand,
    String? newUnit2,
    bool? newOperandLink,
    Map<String, dynamic>? newOperandLinkSource,
    bool updateOperandTransform = false,
    String? newOperandTransform,
    double? newOperandPowExp,
    List<dynamic>? newOthers,
    List<dynamic>? newBrackets,
    String? applyToAllKey,
    bool skipLinked = false,
  }) {
    final map = _toMap();
    map['input'] = newInput ?? input;
    map['unit1'] = newUnit1 ?? unit1;
    map['inputLink'] = newInputLink ?? inputLink;
    map['inputLinkSource'] = newInputLinkSource ?? inputLinkSource;
    if (updateInputTransform) {
      map['inputTransform'] = newInputTransform;
      map['inputPowExp'] = newInputPowExp ?? inputPowExp;
    }
    map['op'] = newOp ?? op;
    map['operand'] = newOperand ?? operand;
    map['unit2'] = newUnit2 ?? unit2;
    map['operandLink'] = newOperandLink ?? operandLink;
    map['operandLinkSource'] = newOperandLinkSource ?? operandLinkSource;
    if (updateOperandTransform) {
      map['operandTransform'] = newOperandTransform;
      map['operandPowExp'] = newOperandPowExp ?? operandPowExp;
    }
    map['others'] = newOthers ?? others;
    map['brackets'] = newBrackets ?? brackets;

    if (applyToAllKey != null) {
      map['_applyToAllKey'] = applyToAllKey;
      if (skipLinked) map['_skipLinked'] = true;
    }
    onChanged(map);
  }

  void _updateOther(
    int idx, {
    String? oOp,
    double? oVal,
    bool? oValLink,
    Map<String, dynamic>? oValLinkSource,
    String? oUnit,
    bool updateTransform = false,
    String? oTransform,
    double? oPowExp,
    String? applyToAllOtherField,
    bool skipLinked = false,
  }) {
    final list = List<Map<String, dynamic>>.from(
      others.map((e) => Map<String, dynamic>.from(e as Map)),
    );
    if (oOp != null) list[idx]['op'] = oOp;
    if (oVal != null) list[idx]['val'] = oVal;
    if (oValLink != null) list[idx]['valLink'] = oValLink;
    if (oValLinkSource != null) list[idx]['valLinkSource'] = oValLinkSource;
    if (oUnit != null) list[idx]['unit'] = oUnit;
    if (updateTransform) {
      list[idx]['transform'] = oTransform;
      list[idx]['powExp'] = oPowExp ?? 2.0;
    }

    if (applyToAllOtherField != null) {
      final val = (applyToAllOtherField == 'val')
          ? list[idx]['val']
          : list[idx]['op'];
      onChanged({
        ..._toMap(),
        'others': list,
        '_applyToAllKey': 'other_${idx}_$applyToAllOtherField',
        'other_${idx}_$applyToAllOtherField': val,
        if (skipLinked) '_skipLinked': true,
      });
    } else {
      _updateWith(newOthers: list);
    }
  }

  void _removeOther(int idx) {
    final list = List<Map<String, dynamic>>.from(
      others.map((e) => Map<String, dynamic>.from(e as Map)),
    );
    list.removeAt(idx);
    _updateWith(newOthers: list);
  }

  void _editDetails(BuildContext context) async {
    final nameCtrl = TextEditingController(text: name);
    final unit1Ctrl = TextEditingController(text: unit1);
    final unit2Ctrl = TextEditingController(text: unit2);
    final unitResCtrl = TextEditingController(text: unitResult);
    final othersUnitsCtrls = others.map((e) {
      return TextEditingController(text: (e as Map)['unit'] as String? ?? '');
    }).toList();
    final suggestedUnits = _collectUsedUnits();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
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
                      '項目設定',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
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
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('計算の名前'),
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: '例: 消費税計算',
                          hintStyle: TextStyle(color: Colors.white24),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildUnitSection(
                        context,
                        '項1の単位',
                        unit1Ctrl,
                        setDialogState,
                        suggestedUnits: suggestedUnits,
                      ),
                      const SizedBox(height: 16),
                      _buildUnitSection(
                        context,
                        '項2の単位',
                        unit2Ctrl,
                        setDialogState,
                        suggestedUnits: suggestedUnits,
                      ),
                      const SizedBox(height: 16),
                      for (int i = 0; i < others.length; i++) ...[
                        _buildUnitSection(
                          context,
                          '項${i + 3}の単位',
                          othersUnitsCtrls[i],
                          setDialogState,
                          suggestedUnits: suggestedUnits,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildUnitSection(
                        context,
                        '答えの単位',
                        unitResCtrl,
                        setDialogState,
                        suggestedUnits: suggestedUnits,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
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
                  onPressed: () {
                    final map = {
                      'name': nameCtrl.text,
                      'input': input,
                      'inputLink': inputLink,
                      'inputLinkSource': inputLinkSource,
                      'op': op,
                      'operand': operand,
                      'operandLink': operandLink,
                      'operandLinkSource': operandLinkSource,
                      'others': others.asMap().entries.map((entry) {
                        final map = Map<String, dynamic>.from(
                          entry.value as Map,
                        );
                        map['unit'] = othersUnitsCtrls[entry.key].text;
                        return map;
                      }).toList(),
                      'brackets': brackets,
                      'precision': precision,
                      'unit1': unit1Ctrl.text,
                      'unit2': unit2Ctrl.text,
                      'unitResult': unitResCtrl.text,
                    };
                    onChanged(map);
                    Navigator.pop(ctx);
                  },
                  child: const Text('保存', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }

  List<String> _collectUsedUnits() {
    final Set<String> units = {};
    for (final rawItem in allItems) {
      final item = rawItem as Map;
      final u1 = item['unit1'] as String? ?? '';
      final u2 = item['unit2'] as String? ?? '';
      final ur = item['unitResult'] as String? ?? '';
      if (u1.isNotEmpty) units.add(u1);
      if (u2.isNotEmpty) units.add(u2);
      if (ur.isNotEmpty) units.add(ur);
      for (final o in item['others'] as List? ?? []) {
        final u = (o as Map)['unit'] as String? ?? '';
        if (u.isNotEmpty) units.add(u);
      }
    }
    return units.toList();
  }

  void _showUnitSuggestionPopup(
    BuildContext context,
    List<String> units,
    void Function(String) onSelected,
  ) {
    showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          '使用中の単位を選択',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        children: units
            .map(
              (u) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, u),
                child: Text(
                  u,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
            )
            .toList(),
      ),
    ).then((selected) {
      if (selected != null) onSelected(selected);
    });
  }

  Widget _buildUnitSection(
    BuildContext context,
    String label,
    TextEditingController ctrl,
    StateSetter setDialogState, {
    List<String> suggestedUnits = const [],
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFieldLabel(label),
            TextButton.icon(
              onPressed: () => _showGenreUnitPicker(context, (u) {
                setDialogState(() => ctrl.text = u);
              }),
              icon: const Icon(Icons.category_outlined, size: 14),
              label: const Text('カテゴリーから選択', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: Colors.blueAccent,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '自由に文字を入力',
                  hintStyle: TextStyle(color: Colors.white24),
                ),
              ),
            ),
            if (suggestedUnits.length == 1) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () =>
                    setDialogState(() => ctrl.text = suggestedUnits[0]),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    suggestedUnits[0],
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ] else if (suggestedUnits.length > 1) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () =>
                    _showUnitSuggestionPopup(context, suggestedUnits, (u) {
                      setDialogState(() => ctrl.text = u);
                    }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        suggestedUnits[0],
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 13,
                        ),
                      ),
                      const Icon(
                        Icons.expand_more,
                        size: 14,
                        color: Colors.blueAccent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _getSourceLabel(Map<String, dynamic>? source) {
    if (source == null) return '直前の残高（答え）';
    final rowIdx = source['rowIdx'] as int? ?? 0;
    final target = source['target'] as String? ?? 'result';

    final rowName = (rowIdx < allItems.length)
        ? (allItems[rowIdx] as Map)['name'] as String? ?? '計算 ${rowIdx + 1}'
        : '計算 ${rowIdx + 1}';

    String fieldLabel = '';
    if (target == 'result') {
      fieldLabel = '答え';
    } else if (target == 'input') {
      fieldLabel = '項1';
    } else if (target == 'operand') {
      fieldLabel = '項2';
    } else if (target.startsWith('other_')) {
      final idx = int.tryParse(target.split('_')[1]) ?? 0;
      fieldLabel = '項${idx + 3}';
    }

    return '$rowName の $fieldLabel';
  }

  /// 連動元の計算行名のみを返す（値ボックス上部ラベル用）
  String _getSourceRowName(Map<String, dynamic>? source) {
    if (source == null) {
      if (allItems.isEmpty) return '';
      return (allItems.last as Map)['name'] as String? ??
          '計算 ${allItems.length}';
    }
    final rowIdx = source['rowIdx'] as int? ?? 0;
    if (rowIdx < 0 || rowIdx >= allItems.length) return '';
    return (allItems[rowIdx] as Map)['name'] as String? ?? '計算 ${rowIdx + 1}';
  }

  // ---- 連動先ダイアログ（この行の値を他の行の項目にリンクする） ----
  Set<String> _calcSelectedDests(String srcField) {
    final Set<String> dests = {};
    for (int i = 0; i < allItems.length; i++) {
      if (i == myIndex) continue;
      final item = allItems[i] as Map;
      bool _linkedToMe(Map? src) =>
          src != null && src['rowIdx'] == myIndex && src['target'] == srcField;
      if (item['inputLink'] == true &&
          _linkedToMe(item['inputLinkSource'] as Map?))
        dests.add('${i}_input');
      if (item['operandLink'] == true &&
          _linkedToMe(item['operandLinkSource'] as Map?))
        dests.add('${i}_operand');
      final othersList = item['others'] as List? ?? [];
      for (int j = 0; j < othersList.length; j++) {
        final o = othersList[j] as Map;
        if (o['valLink'] == true && _linkedToMe(o['valLinkSource'] as Map?))
          dests.add('${i}_other_$j');
      }
    }
    return dests;
  }

  void _applyLinkDestinations(String sourceField, Set<String> selectedDests) {
    final newItems = allItems
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    for (int i = 0; i < newItems.length; i++) {
      if (i == myIndex) continue;
      final item = newItems[i];
      final origItem = allItems[i] as Map;
      bool wasLinked(Map? src) =>
          src != null && src['rowIdx'] == myIndex && src['target'] == sourceField;

      // input
      final inputDest = '${i}_input';
      final inputWas =
          origItem['inputLink'] == true && wasLinked(origItem['inputLinkSource'] as Map?);
      if (selectedDests.contains(inputDest)) {
        item['inputLink'] = true;
        item['inputLinkSource'] = {'rowIdx': myIndex, 'target': sourceField};
      } else if (inputWas) {
        item['inputLink'] = false;
        item['inputLinkSource'] = null;
      }

      // operand
      final operandDest = '${i}_operand';
      final operandWas =
          origItem['operandLink'] == true && wasLinked(origItem['operandLinkSource'] as Map?);
      if (selectedDests.contains(operandDest)) {
        item['operandLink'] = true;
        item['operandLinkSource'] = {'rowIdx': myIndex, 'target': sourceField};
      } else if (operandWas) {
        item['operandLink'] = false;
        item['operandLinkSource'] = null;
      }

      // others
      final othersList = ((item['others'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)))
          .toList();
      final origOthersList = origItem['others'] as List? ?? [];
      for (int j = 0; j < othersList.length; j++) {
        final otherDest = '${i}_other_$j';
        final origO = j < origOthersList.length ? origOthersList[j] as Map : {};
        final otherWas =
            origO['valLink'] == true && wasLinked(origO['valLinkSource'] as Map?);
        if (selectedDests.contains(otherDest)) {
          othersList[j]['valLink'] = true;
          othersList[j]['valLinkSource'] = {'rowIdx': myIndex, 'target': sourceField};
        } else if (otherWas) {
          othersList[j]['valLink'] = false;
          othersList[j]['valLinkSource'] = null;
        }
      }
      item['others'] = othersList;
    }
    onAllItemsUpdate(newItems);
  }

  void _showSetLinkDestDialog(BuildContext context) {
    // 連動元候補（この行のフィールド）
    final List<Map<String, dynamic>> srcFields = [
      ...const [
        {'key': 'input', 'label': '項1'},
        {'key': 'operand', 'label': '項2'},
      ],
      ...List.generate(
        others.length,
        (i) => {'key': 'other_$i', 'label': '項${i + 3}'},
      ),
      const {'key': 'result', 'label': '答え'},
    ];

    String selectedSrc = 'result';
    Set<String> selectedDests = _calcSelectedDests(selectedSrc);

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDs) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text(
            '値をリンクする',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Text(
                    '連動元の値',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: srcFields.map((sf) {
                      final key = sf['key'] as String;
                      final label = sf['label'] as String;
                      final sel = selectedSrc == key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: sel,
                          selectedColor: Colors.blueAccent.withOpacity(0.3),
                          backgroundColor: Colors.white.withOpacity(0.05),
                          labelStyle: TextStyle(
                            color: sel ? Colors.blueAccent : Colors.white70,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setDs(() {
                            selectedSrc = key;
                            selectedDests = _calcSelectedDests(key);
                          }),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(color: Colors.white12, height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: const Text(
                    '連動先（複数選択可）',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: allItems.length <= 1
                      ? const Center(
                          child: Text(
                            '他の計算式がありません',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        )
                      : ListView.builder(
                          itemCount: allItems.length,
                          itemBuilder: (context, i) {
                            if (i == myIndex) return const SizedBox.shrink();
                            final item = allItems[i] as Map;
                            final rowName =
                                item['name'] as String? ?? '計算 ${i + 1}';
                            final destFields = <Map<String, dynamic>>[
                              ...const [
                                {'key': 'input', 'label': '項1'},
                                {'key': 'operand', 'label': '項2'},
                              ],
                              ...List.generate(
                                (item['others'] as List? ?? []).length,
                                (j) => {'key': 'other_$j', 'label': '項${j + 3}'},
                              ),
                            ];
                            if (destFields.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                                  child: Text(
                                    rowName,
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: destFields.map((df) {
                                      final fk = df['key'] as String;
                                      final dk = '${i}_$fk';
                                      final isSel = selectedDests.contains(dk);
                                      return FilterChip(
                                        label: Text(df['label'] as String),
                                        selected: isSel,
                                        selectedColor:
                                            Colors.blueAccent.withOpacity(0.25),
                                        checkmarkColor: Colors.blueAccent,
                                        backgroundColor:
                                            Colors.white.withOpacity(0.05),
                                        labelStyle: TextStyle(
                                          color: isSel
                                              ? Colors.blueAccent
                                              : Colors.white70,
                                          fontSize: 12,
                                        ),
                                        onSelected: (v) => setDs(() {
                                          if (v) {
                                            selectedDests.add(dk);
                                          } else {
                                            selectedDests.remove(dk);
                                          }
                                        }),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const Divider(color: Colors.white10, height: 16),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'キャンセル',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _applyLinkDestinations(selectedSrc, selectedDests);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('設定する'),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasLinkedRowsForKey(String key, {int otherIdx = 0}) {
    for (int i = 0; i < allItems.length; i++) {
      if (i == myIndex) continue;
      final item = allItems[i] as Map;
      if (key == 'input' && item['inputLink'] == true) return true;
      if (key == 'operand' && item['operandLink'] == true) return true;
      if (key == 'other') {
        final othersList = item['others'] as List? ?? [];
        if (otherIdx < othersList.length &&
            (othersList[otherIdx] as Map)['valLink'] == true)
          return true;
      }
    }
    return false;
  }

  Future<String?> _confirmOverwriteLinks(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          '連動設定があります',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text(
          '他の行に連動中の設定があります。どのように適用しますか？',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'skipLinked'),
            child: const Text(
              '連動する値以外を適用',
              style: TextStyle(color: Colors.blueAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'overwrite'),
            child: const Text(
              '上書きして適用',
              style: TextStyle(color: Colors.orangeAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showGenreUnitPicker(BuildContext context, Function(String) onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DefaultTabController(
        length: unitCategories.length,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '単位をカテゴリーから選択',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TabBar(
              isScrollable: true,
              indicatorColor: Colors.blueAccent,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.white38,
              tabs: unitCategories.keys.map((k) => Tab(text: k)).toList(),
            ),
            Expanded(
              child: TabBarView(
                children: unitCategories.values.map((units) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: units.length,
                    itemBuilder: (context, idx) {
                      final u = units[idx];
                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelected(u);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            u,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 変換計算 ──
  static double _applyTermTransform(
    double v,
    String? transform,
    double powExp,
  ) {
    switch (transform) {
      case 'sqrt':
        return math.sqrt(v < 0 ? 0 : v);
      case 'pow':
        return math.pow(v, powExp).toDouble();
      case 'nroot':
        return powExp != 0
            ? math.pow(v < 0 ? 0 : v, 1.0 / powExp).toDouble()
            : 0;
      case 'abs':
        return v.abs();
      case 'floor':
        return v.floorToDouble();
      case 'ceil':
        return v.ceilToDouble();
      case 'round':
        return v.roundToDouble();
      case 'log10':
        return v > 0 ? math.log(v) / math.ln10 : 0;
      case 'reciprocal':
        return v != 0 ? 1.0 / v : 0;
      default:
        return v;
    }
  }

  // ── 変換ラベル色 ──
  static Color _transformColor(String? t) {
    switch (t) {
      case 'sqrt':
        return Colors.greenAccent;
      case 'pow':
        return Colors.purpleAccent;
      case 'nroot':
        return const Color(0xFF69F0AE); // light green
      case 'abs':
        return Colors.redAccent;
      case 'floor':
        return Colors.teal;
      case 'ceil':
        return Colors.cyan;
      case 'round':
        return Colors.lightBlueAccent;
      case 'log10':
        return Colors.green; // orange-ish
      case 'reciprocal':
        return Colors.pinkAccent;
      default:
        return Colors.white70;
    }
  }

  // ── 式文字列（プレビュー用） ──
  static String _transformExprStr(String valStr, String? t, double powExp) {
    String expStr(double e) {
      if (e == e.truncateToDouble()) return e.toInt().toString();
      return e
          .toStringAsFixed(4)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }

    switch (t) {
      case 'sqrt':
        return '√($valStr)';
      case 'pow':
        return '($valStr)^${expStr(powExp)}';
      case 'nroot':
        return '${expStr(powExp)}√($valStr)';
      case 'abs':
        return '|$valStr|';
      case 'floor':
        return '⌊$valStr⌋';
      case 'ceil':
        return '⌈$valStr⌉';
      case 'round':
        return 'round($valStr)';
      case 'log10':
        return 'log10($valStr)';
      case 'reciprocal':
        return '1/($valStr)';
      default:
        return valStr;
    }
  }

  // ── 変換プレフィックスWidget ──
  Widget? _buildTransformPrefix(String? t, double powExp) {
    Color c = _transformColor(t);
    TextStyle ts(double fs) =>
        TextStyle(color: c, fontSize: fs, fontWeight: FontWeight.w400);
    String expStr(double e) {
      if (e == e.truncateToDouble()) return e.toInt().toString();
      return e
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }

    switch (t) {
      case 'sqrt':
        return Text('√', style: ts(20));
      case 'nroot':
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Transform.translate(
              offset: const Offset(0, -4),
              child: Text(
                expStr(powExp),
                style: TextStyle(
                  color: c,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text('√', style: ts(20)),
          ],
        );
      case 'abs':
        return Text('|', style: ts(20));
      case 'floor':
        return Text('⌊', style: ts(20));
      case 'ceil':
        return Text('⌈', style: ts(20));
      case 'round':
        return Text('round(', style: ts(13));
      case 'log10':
        return RichText(
          text: TextSpan(
            children: [
              TextSpan(text: 'log', style: ts(13)),
              WidgetSpan(
                child: Transform.translate(
                  offset: const Offset(0, 4),
                  child: Text('10', style: TextStyle(color: c, fontSize: 9)),
                ),
              ),
              TextSpan(text: '(', style: ts(13)),
            ],
          ),
        );
      case 'reciprocal':
        return Text('1/(', style: ts(13));
      default:
        return null;
    }
  }

  // ── 変換サフィックスWidget ──
  Widget? _buildTransformSuffix(String? t, double powExp) {
    Color c = _transformColor(t);
    TextStyle ts(double fs) =>
        TextStyle(color: c, fontSize: fs, fontWeight: FontWeight.w400);
    String expStr(double e) {
      if (e == e.truncateToDouble()) return e.toInt().toString();
      return e
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }

    switch (t) {
      case 'pow':
        return Transform.translate(
          offset: const Offset(2, -8),
          child: Text(
            expStr(powExp),
            style: TextStyle(
              color: c,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case 'abs':
        return Text('|', style: ts(20));
      case 'floor':
        return Text('⌋', style: ts(20));
      case 'ceil':
        return Text('⌉', style: ts(20));
      case 'round':
      case 'log10':
      case 'reciprocal':
        return Text(')', style: ts(13));
      default:
        return null;
    }
  }

  void _editInput(BuildContext context) async {
    final _inputText = input.toString();
    final ctrl = TextEditingController(text: _inputText)
      ..selection = TextSelection(baseOffset: 0, extentOffset: _inputText.length);
    final unitCtrl = TextEditingController(text: unit1);
    bool tempLink = inputLink;
    Map<String, dynamic>? tempLinkSource = inputLinkSource;
    String? tempTransform = inputTransform;
    double tempPowExp = inputPowExp;
    bool tempApplyToAll = false;
    final suggestedUnits = _collectUsedUnits();
    final powExpCtrl = TextEditingController(
      text: inputPowExp == inputPowExp.truncateToDouble()
          ? inputPowExp.toInt().toString()
          : inputPowExp.toString(),
    );

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          child: Padding(
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
                        '項1の設定',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
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
                const SizedBox(height: 16),
                const Text(
                  '数値',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                        autofocus: true,
                        enabled: !tempLink,
                        decoration: InputDecoration(
                          hintText: '0.0',
                          hintStyle: const TextStyle(color: Colors.white24),
                          suffixText: tempLink ? '連動中' : null,
                          suffixStyle: const TextStyle(
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    ),
                    if (!tempLink) ...[
                      IconButton(
                        icon: const Icon(
                          Icons.calculate_outlined,
                          color: Colors.blueAccent,
                        ),
                        tooltip: '計算機',
                        onPressed: () => _showMiniCalcSheet(context, (v) {
                          setSheetState(() {
                            if (v == v.truncateToDouble() && v.abs() < 1e15) {
                              ctrl.text = v.toInt().toString();
                            } else {
                              ctrl.text = v.toStringAsFixed(15)
                                  .replaceAll(RegExp(r'0+$'), '')
                                  .replaceAll(RegExp(r'\.$'), '');
                            }
                          });
                        }),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.backspace_outlined,
                          color: Colors.white54,
                        ),
                        onPressed: () => setSheetState(() => ctrl.clear()),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _buildUnitSection(
                  context,
                  '単位',
                  unitCtrl,
                  setSheetState,
                  suggestedUnits: suggestedUnits,
                ),

                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text(
                    '数値を他の全ての行に適用',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  value: tempApplyToAll,
                  onChanged: (v) =>
                      setSheetState(() => tempApplyToAll = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Colors.blueAccent,
                  dense: true,
                ),
                if (tempLink)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blueAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link,
                            size: 14,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '連動元: ${_getSourceLabel(tempLinkSource)}',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setSheetState(() {
                              tempLink = false;
                              tempLinkSource = null;
                            }),
                            child: const Text(
                              '解除',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Divider(color: Colors.white12),
                const SizedBox(height: 4),
                const Text(
                  '変換（オプション）',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      for (final entry in <List<String?>>[
                        ['なし', null],
                        ['√ 平方根', 'sqrt'],
                        ['x^n 指数', 'pow'],
                        ['n乗根', 'nroot'],
                        ['|x| 絶対値', 'abs'],
                        ['⌊x⌋ 切捨', 'floor'],
                        ['⌈x⌉ 切上', 'ceil'],
                        ['round 四捨五入', 'round'],
                        ['log10 対数', 'log10'],
                        ['1/x 逆数', 'reciprocal'],
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(entry[0]!),
                            selected: tempTransform == entry[1],
                            selectedColor: entry[1] == null
                                ? null
                                : _CalculatorRow._transformColor(
                                    entry[1],
                                  ).withOpacity(0.2),
                            labelStyle: TextStyle(
                              color:
                                  tempTransform == entry[1] && entry[1] != null
                                  ? _CalculatorRow._transformColor(entry[1])
                                  : Colors.white70,
                              fontSize: 12,
                            ),
                            onSelected: (_) =>
                                setSheetState(() => tempTransform = entry[1]),
                          ),
                        ),
                    ],
                  ),
                ),
                if (tempTransform == 'pow' || tempTransform == 'nroot') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        tempTransform == 'pow' ? '何乗するか（n）：' : '何乗根か（n）：',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: powExpCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: '2',
                            hintStyle: TextStyle(color: Colors.white24),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (v) {
                            tempPowExp = double.tryParse(v) ?? tempPowExp;
                            setSheetState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                if (tempTransform != null) ...[
                  const SizedBox(height: 10),
                  Builder(
                    builder: (_) {
                      final v = double.tryParse(ctrl.text) ?? 0.0;
                      final res = _applyTermTransform(
                        v,
                        tempTransform,
                        tempPowExp,
                      );
                      String fmtPreview(double x) {
                        if (x.isInfinite || x.isNaN) return 'エラー';
                        if (x == x.truncateToDouble() && x.abs() < 1e12)
                          return x.toInt().toString();
                        final s = x.toStringAsFixed(10);
                        return s
                            .replaceAll(RegExp(r'0+$'), '')
                            .replaceAll(RegExp(r'\.$'), '');
                      }

                      final exprStr = _CalculatorRow._transformExprStr(
                        ctrl.text,
                        tempTransform,
                        tempPowExp,
                      );
                      final color = _CalculatorRow._transformColor(
                        tempTransform,
                      );
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withOpacity(0.25)),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Text(
                                exprStr,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '=',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                fmtPreview(res),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 8),

                const SizedBox(height: 16),
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
                      'val': ctrl.text,
                      'unit': unitCtrl.text,
                      'link': tempLink,
                      'source': tempLinkSource,
                      'transform': tempTransform,
                      'powExp': tempPowExp,
                      'applyToAll': tempApplyToAll,
                    }),
                    child: const Text('保存', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null) {
      final val = double.tryParse(result['val'] as String) ?? 0.0;
      bool skipLinked = false;
      if (result['applyToAll'] == true && _hasLinkedRowsForKey('input')) {
        final choice = await _confirmOverwriteLinks(context);
        if (choice == null) return;
        skipLinked = (choice == 'skipLinked');
      }

      _updateWith(
        newInput: val,
        newUnit1: result['unit'] as String,
        newInputLink: result['link'] as bool,
        newInputLinkSource: result['source'] as Map<String, dynamic>?,
        updateInputTransform: true,
        newInputTransform: result['transform'] as String?,
        newInputPowExp: (result['powExp'] as double?) ?? 2.0,
        applyToAllKey: result['applyToAll'] as bool ? 'input' : null,
        skipLinked: skipLinked,
      );
    }
  }

  void _editOperand(BuildContext context) async {
    final _operandText = operand.toString();
    final ctrl = TextEditingController(text: _operandText)
      ..selection = TextSelection(baseOffset: 0, extentOffset: _operandText.length);
    final unitCtrl = TextEditingController(text: unit2);
    bool tempLink = operandLink;
    Map<String, dynamic>? tempLinkSource = operandLinkSource;
    String? tempTransform = operandTransform;
    double tempPowExp = operandPowExp;
    bool tempApplyToAll = false;
    final suggestedUnits = _collectUsedUnits();
    final powExpCtrl = TextEditingController(
      text: operandPowExp == operandPowExp.truncateToDouble()
          ? operandPowExp.toInt().toString()
          : operandPowExp.toString(),
    );

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          child: Padding(
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
                        '項2の設定',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
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
                const SizedBox(height: 16),
                const Text(
                  '数値',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                        autofocus: true,
                        enabled: !tempLink,
                        decoration: InputDecoration(
                          hintText: '0.0',
                          hintStyle: const TextStyle(color: Colors.white24),
                          suffixText: tempLink ? '連動中' : null,
                          suffixStyle: const TextStyle(
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    ),
                    if (!tempLink) ...[
                      IconButton(
                        icon: const Icon(
                          Icons.calculate_outlined,
                          color: Colors.blueAccent,
                        ),
                        tooltip: '計算機',
                        onPressed: () => _showMiniCalcSheet(context, (v) {
                          setSheetState(() {
                            if (v == v.truncateToDouble() && v.abs() < 1e15) {
                              ctrl.text = v.toInt().toString();
                            } else {
                              ctrl.text = v.toStringAsFixed(15)
                                  .replaceAll(RegExp(r'0+$'), '')
                                  .replaceAll(RegExp(r'\.$'), '');
                            }
                          });
                        }),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.backspace_outlined,
                          color: Colors.white54,
                        ),
                        onPressed: () => setSheetState(() => ctrl.clear()),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _buildUnitSection(
                  context,
                  '単位',
                  unitCtrl,
                  setSheetState,
                  suggestedUnits: suggestedUnits,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text(
                    '数値を他の全ての行に適用',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  value: tempApplyToAll,
                  onChanged: (v) =>
                      setSheetState(() => tempApplyToAll = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Colors.blueAccent,
                  dense: true,
                ),
                if (tempLink)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blueAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link,
                            size: 14,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '連動元: ${_getSourceLabel(tempLinkSource)}',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setSheetState(() {
                              tempLink = false;
                              tempLinkSource = null;
                            }),
                            child: const Text(
                              '解除',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Divider(color: Colors.white12),
                const SizedBox(height: 4),
                const Text(
                  '変換（オプション）',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      for (final entry in <List<String?>>[
                        ['なし', null],
                        ['√ 平方根', 'sqrt'],
                        ['x^n 指数', 'pow'],
                        ['n乗根', 'nroot'],
                        ['|x| 絶対値', 'abs'],
                        ['⌊x⌋ 切捨', 'floor'],
                        ['⌈x⌉ 切上', 'ceil'],
                        ['round 四捨五入', 'round'],
                        ['log10 対数', 'log10'],
                        ['1/x 逆数', 'reciprocal'],
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(entry[0]!),
                            selected: tempTransform == entry[1],
                            selectedColor: entry[1] == null
                                ? null
                                : _CalculatorRow._transformColor(
                                    entry[1],
                                  ).withOpacity(0.2),
                            labelStyle: TextStyle(
                              color:
                                  tempTransform == entry[1] && entry[1] != null
                                  ? _CalculatorRow._transformColor(entry[1])
                                  : Colors.white70,
                              fontSize: 12,
                            ),
                            onSelected: (_) =>
                                setSheetState(() => tempTransform = entry[1]),
                          ),
                        ),
                    ],
                  ),
                ),
                if (tempTransform == 'pow' || tempTransform == 'nroot') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        tempTransform == 'pow' ? '何乗するか（n）：' : '何乗根か（n）：',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: powExpCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: '2',
                            hintStyle: TextStyle(color: Colors.white24),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (v) {
                            tempPowExp = double.tryParse(v) ?? tempPowExp;
                            setSheetState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                if (tempTransform != null) ...[
                  const SizedBox(height: 10),
                  Builder(
                    builder: (_) {
                      final v = double.tryParse(ctrl.text) ?? 0.0;
                      final res = _applyTermTransform(
                        v,
                        tempTransform,
                        tempPowExp,
                      );
                      String fmtPreview(double x) {
                        if (x.isInfinite || x.isNaN) return 'エラー';
                        if (x == x.truncateToDouble() && x.abs() < 1e12)
                          return x.toInt().toString();
                        final s = x.toStringAsFixed(10);
                        return s
                            .replaceAll(RegExp(r'0+$'), '')
                            .replaceAll(RegExp(r'\.$'), '');
                      }

                      final exprStr = _CalculatorRow._transformExprStr(
                        ctrl.text,
                        tempTransform,
                        tempPowExp,
                      );
                      final color = _CalculatorRow._transformColor(
                        tempTransform,
                      );
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withOpacity(0.25)),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Text(
                                exprStr,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '=',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                fmtPreview(res),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 16),
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
                      'val': ctrl.text,
                      'unit': unitCtrl.text,
                      'link': tempLink,
                      'source': tempLinkSource,
                      'transform': tempTransform,
                      'powExp': tempPowExp,
                      'applyToAll': tempApplyToAll,
                    }),
                    child: const Text('保存', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null) {
      final val = double.tryParse(result['val'] as String) ?? 0.0;
      bool skipLinked = false;
      if (result['applyToAll'] == true && _hasLinkedRowsForKey('operand')) {
        final choice = await _confirmOverwriteLinks(context);
        if (choice == null) return;
        skipLinked = (choice == 'skipLinked');
      }

      _updateWith(
        newOperand: val,
        newUnit2: result['unit'] as String,
        newOperandLink: result['link'] as bool,
        newOperandLinkSource: result['source'] as Map<String, dynamic>?,
        updateOperandTransform: true,
        newOperandTransform: result['transform'] as String?,
        newOperandPowExp: (result['powExp'] as double?) ?? 2.0,
        applyToAllKey: result['applyToAll'] as bool ? 'operand' : null,
        skipLinked: skipLinked,
      );
    }
  }

  void _pickOp(BuildContext context, Offset globalPos, {int? otherIdx}) async {
    const ops = ['+', '-', 'x', '/', '%'];

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(globalPos, globalPos),
      Offset.zero & overlay.size,
    );

    final String? selectedOp = await showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: ops
          .map(
            (o) => PopupMenuItem<String>(
              value: o,
              child: Center(
                child: Text(
                  o,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );

    if (selectedOp != null) {
      if (otherIdx == null) {
        _updateWith(newOp: selectedOp);
      } else {
        _updateOther(otherIdx, oOp: selectedOp);
      }
    }
  }

  void _editOtherVal(BuildContext context, int idx) async {
    final currentOther = others[idx] as Map;
    final currentVal = currentOther['val'] as double? ?? 0.0;
    final currentUnit = currentOther['unit'] as String? ?? '';
    final currentLink = currentOther['valLink'] as bool? ?? false;
    final currentSource =
        currentOther['valLinkSource'] as Map<String, dynamic>?;
    final currentTransform = currentOther['transform'] as String?;
    final currentPowExp = ((currentOther['powExp'] as num? ?? 2.0).toDouble());
    final _otherValText = currentVal.toString();
    final ctrl = TextEditingController(text: _otherValText)
      ..selection = TextSelection(baseOffset: 0, extentOffset: _otherValText.length);
    final unitCtrl = TextEditingController(text: currentUnit);
    bool tempLink = currentLink;
    Map<String, dynamic>? tempLinkSource = currentSource;
    String? tempTransform = currentTransform;
    double tempPowExp = currentPowExp;
    bool tempApplyToAll = false;
    final suggestedUnits = _collectUsedUnits();
    final powExpCtrl = TextEditingController(
      text: currentPowExp == currentPowExp.truncateToDouble()
          ? currentPowExp.toInt().toString()
          : currentPowExp.toString(),
    );

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          child: Padding(
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
                        '項${idx + 3}の設定',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
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
                const SizedBox(height: 16),
                const Text(
                  '数値',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                        autofocus: true,
                        enabled: !tempLink,
                        decoration: InputDecoration(
                          hintText: '0.0',
                          hintStyle: const TextStyle(color: Colors.white24),
                          suffixText: tempLink ? '連動中' : null,
                          suffixStyle: const TextStyle(
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    ),
                    if (!tempLink) ...[
                      IconButton(
                        icon: const Icon(
                          Icons.calculate_outlined,
                          color: Colors.blueAccent,
                        ),
                        tooltip: '計算機',
                        onPressed: () => _showMiniCalcSheet(context, (v) {
                          setSheetState(() {
                            if (v == v.truncateToDouble() && v.abs() < 1e15) {
                              ctrl.text = v.toInt().toString();
                            } else {
                              ctrl.text = v.toStringAsFixed(15)
                                  .replaceAll(RegExp(r'0+$'), '')
                                  .replaceAll(RegExp(r'\.$'), '');
                            }
                          });
                        }),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.backspace_outlined,
                          color: Colors.white54,
                        ),
                        onPressed: () => setSheetState(() => ctrl.clear()),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _buildUnitSection(
                  context,
                  '単位',
                  unitCtrl,
                  setSheetState,
                  suggestedUnits: suggestedUnits,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text(
                    '数値を他の全ての行に適用',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  value: tempApplyToAll,
                  onChanged: (v) =>
                      setSheetState(() => tempApplyToAll = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Colors.blueAccent,
                  dense: true,
                ),
                if (tempLink)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blueAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link,
                            size: 14,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '連動元: ${_getSourceLabel(tempLinkSource)}',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setSheetState(() {
                              tempLink = false;
                              tempLinkSource = null;
                            }),
                            child: const Text(
                              '解除',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Divider(color: Colors.white12),
                const SizedBox(height: 4),
                const Text(
                  '変換（オプション）',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      for (final entry in <List<String?>>[
                        ['なし', null],
                        ['√ 平方根', 'sqrt'],
                        ['x^n 指数', 'pow'],
                        ['n乗根', 'nroot'],
                        ['|x| 絶対値', 'abs'],
                        ['⌊x⌋ 切捨', 'floor'],
                        ['⌈x⌉ 切上', 'ceil'],
                        ['round 四捨五入', 'round'],
                        ['log10 対数', 'log10'],
                        ['1/x 逆数', 'reciprocal'],
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(entry[0]!),
                            selected: tempTransform == entry[1],
                            selectedColor: entry[1] == null
                                ? null
                                : _CalculatorRow._transformColor(
                                    entry[1],
                                  ).withOpacity(0.2),
                            labelStyle: TextStyle(
                              color:
                                  tempTransform == entry[1] && entry[1] != null
                                  ? _CalculatorRow._transformColor(entry[1])
                                  : Colors.white70,
                              fontSize: 12,
                            ),
                            onSelected: (_) =>
                                setSheetState(() => tempTransform = entry[1]),
                          ),
                        ),
                    ],
                  ),
                ),
                if (tempTransform == 'pow' || tempTransform == 'nroot') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        tempTransform == 'pow' ? '何乗するか（n）：' : '何乗根か（n）：',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: powExpCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: '2',
                            hintStyle: TextStyle(color: Colors.white24),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (v) {
                            tempPowExp = double.tryParse(v) ?? tempPowExp;
                            setSheetState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                if (tempTransform != null) ...[
                  const SizedBox(height: 10),
                  Builder(
                    builder: (_) {
                      final v = double.tryParse(ctrl.text) ?? 0.0;
                      final res = _applyTermTransform(
                        v,
                        tempTransform,
                        tempPowExp,
                      );
                      String fmtPreview(double x) {
                        if (x.isInfinite || x.isNaN) return 'エラー';
                        if (x == x.truncateToDouble() && x.abs() < 1e12)
                          return x.toInt().toString();
                        final s = x.toStringAsFixed(10);
                        return s
                            .replaceAll(RegExp(r'0+$'), '')
                            .replaceAll(RegExp(r'\.$'), '');
                      }

                      final exprStr = _CalculatorRow._transformExprStr(
                        ctrl.text,
                        tempTransform,
                        tempPowExp,
                      );
                      final color = _CalculatorRow._transformColor(
                        tempTransform,
                      );
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withOpacity(0.25)),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Text(
                                exprStr,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '=',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                fmtPreview(res),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, {'delete': true}),
                      child: const Text(
                        '項を削除',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 140,
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
                          'val': ctrl.text,
                          'unit': unitCtrl.text,
                          'link': tempLink,
                          'source': tempLinkSource,
                          'transform': tempTransform,
                          'powExp': tempPowExp,
                          'delete': false,
                          'applyToAll': tempApplyToAll,
                        }),
                        child: const Text('保存', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null) {
      if (result['delete'] == true) {
        _removeOther(idx);
        return;
      }
      final val = double.tryParse(result['val'] as String) ?? 0.0;
      bool skipLinked = false;
      if (result['applyToAll'] == true &&
          _hasLinkedRowsForKey('other', otherIdx: idx)) {
        final choice = await _confirmOverwriteLinks(context);
        if (choice == null) return;
        skipLinked = (choice == 'skipLinked');
      }

      _updateOther(
        idx,
        oVal: val,
        oUnit: result['unit'] as String,
        oValLink: result['link'] as bool,
        oValLinkSource: result['source'] as Map<String, dynamic>?,
        updateTransform: true,
        oTransform: result['transform'] as String?,
        oPowExp: (result['powExp'] as double?) ?? 2.0,
        applyToAllOtherField: result['applyToAll'] as bool ? 'val' : null,
        skipLinked: skipLinked,
      );
    }
  }

  void _editResultProperties(BuildContext context, Offset globalPos) async {
    int tempPrecision = precision;
    final unitResCtrl = TextEditingController(text: unitResult);
    final suggestedUnits = _collectUsedUnits();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '答えの設定',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
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
                const SizedBox(height: 20),
                const Text(
                  '小数点以下の桁数',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(9, (i) {
                      final selected = tempPrecision == i;
                        return GestureDetector(
                          onTap: () => setSheetState(() => tempPrecision = i),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.blueAccent
                                  : Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? Colors.blueAccent
                                    : Colors.white24,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$i',
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                const SizedBox(height: 20),
                _buildUnitSection(
                  context,
                  '答えの単位',
                  unitResCtrl,
                  setSheetState,
                  suggestedUnits: suggestedUnits,
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
                    onPressed: () {
                      onChanged({
                        ..._toMap(),
                        'precision': tempPrecision,
                        'unitResult': unitResCtrl.text,
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('保存', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // _showUnitEditSheet is now merged into _editResultProperties

  int _getLinkedPrecision(Map<String, dynamic>? linkSource) {
    if (linkSource == null) {
      return allItems.isNotEmpty
          ? (allItems.last as Map)['precision'] as int? ?? 2
          : 2;
    }
    final srcIdx = linkSource['rowIdx'] as int? ?? 0;
    if (srcIdx < 0 || srcIdx >= allItems.length) return 2;
    return (allItems[srcIdx] as Map)['precision'] as int? ?? 2;
  }

  Widget _buildValueBox({
    required String value,
    required String unit,
    bool isLink = false,
    String? linkLabel,
    VoidCallback? onTap,
    Function(TapDownDetails)? onTapDown,
    double fontSize = 15,
  }) {
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLink ? Colors.blueAccent.withOpacity(0.4) : Colors.white.withOpacity(0.08),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (isLink)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.link_rounded, size: 14, color: Colors.blueAccent),
            ),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          if (unit.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                unit,
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black45,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );

    final Widget content = (isLink && linkLabel != null && linkLabel.isNotEmpty)
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  linkLabel,
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              box,
            ],
          )
        : box;

    if (onTapDown != null) {
      return GestureDetector(
        onTapDown: onTapDown,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    return content;
  }

  Widget _buildBracket(String b) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: Text(
        b,
        style: TextStyle(
          color: Colors.blue.withOpacity(0.8),
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  bool _hasStart(int idx) =>
      (brackets ?? []).any((b) => (b as Map)['start'] == idx);
  bool _hasEnd(int idx) =>
      (brackets ?? []).any((b) => (b as Map)['end'] == idx);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nameVisible)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _editDetails(context),
                      child: Text(
                        name.isEmpty ? '名称未設定' : name,
                        style: TextStyle(
                          color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 項1
                if (_hasStart(0)) _buildBracket('('),
                if (_buildTransformPrefix(inputTransform, inputPowExp) != null)
                  _buildTransformPrefix(inputTransform, inputPowExp)!,
                _buildValueBox(
                  value: inputLink
                      ? input.toStringAsFixed(_getLinkedPrecision(inputLinkSource))
                      : input.toString(),
                  unit: unit1,
                  isLink: inputLink,
                  linkLabel: inputLink ? _getSourceRowName(inputLinkSource) : null,
                  onTap: () => _editInput(context),
                ),
                if (_buildTransformSuffix(inputTransform, inputPowExp) != null)
                  _buildTransformSuffix(inputTransform, inputPowExp)!,
                if (_hasEnd(0)) _buildBracket(')'),
                
                const SizedBox(width: 12),
                
                // 演算子
                GestureDetector(
                  onTapDown: (details) => _pickOp(context, details.globalPosition),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
                    ),
                    child: Text(
                      op,
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // 項2
                if (_hasStart(1)) _buildBracket('('),
                if (_buildTransformPrefix(operandTransform, operandPowExp) != null)
                  _buildTransformPrefix(operandTransform, operandPowExp)!,
                _buildValueBox(
                  value: operandLink
                      ? operand.toStringAsFixed(_getLinkedPrecision(operandLinkSource))
                      : operand.toString(),
                  unit: unit2,
                  isLink: operandLink,
                  linkLabel: operandLink ? _getSourceRowName(operandLinkSource) : null,
                  onTap: () => _editOperand(context),
                ),
                if (_buildTransformSuffix(operandTransform, operandPowExp) != null)
                  _buildTransformSuffix(operandTransform, operandPowExp)!,
                if (_hasEnd(1)) _buildBracket(')'),

                // 追加の項
                ...others.asMap().entries.map((e) {
                  final idx = e.key;
                  final other = e.value as Map;
                  final otherOp = other['op'] as String? ?? '+';
                  final otherVal = (other['val'] as num? ?? 0.0).toDouble();
                  final otherUnit = other['unit'] as String? ?? '';

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTapDown: (details) => _pickOp(context, details.globalPosition, otherIdx: idx),
                        onLongPress: () => _removeOther(idx),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withOpacity(0.08),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
                          ),
                          child: Text(
                            otherOp,
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_hasStart(idx + 2)) _buildBracket('('),
                      if (_buildTransformPrefix(other['transform'] as String?, (other['powExp'] as num? ?? 2.0).toDouble()) != null)
                        _buildTransformPrefix(other['transform'] as String?, (other['powExp'] as num? ?? 2.0).toDouble())!,
                      _buildValueBox(
                        value: (other['valLink'] as bool? ?? false)
                            ? otherVal.toStringAsFixed(_getLinkedPrecision(other['valLinkSource'] as Map<String, dynamic>?))
                            : otherVal.toString(),
                        unit: otherUnit,
                        isLink: other['valLink'] as bool? ?? false,
                        linkLabel: (other['valLink'] as bool? ?? false)
                            ? _getSourceRowName(other['valLinkSource'] as Map<String, dynamic>?)
                            : null,
                        onTap: () => _editOtherVal(context, idx),
                      ),
                      if (_buildTransformSuffix(other['transform'] as String?, (other['powExp'] as num? ?? 2.0).toDouble()) != null)
                        _buildTransformSuffix(other['transform'] as String?, (other['powExp'] as num? ?? 2.0).toDouble())!,
                      if (_hasEnd(idx + 2)) _buildBracket(')'),
                    ],
                  );
                }),

                const SizedBox(width: 16),
                Text(
                  '=',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black26,
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(width: 16),

                // 答え
                _buildValueBox(
                  value: result.toStringAsFixed(precision),
                  unit: unitResult,
                  fontSize: 18,
                  onTapDown: (details) => _editResultProperties(context, details.globalPosition),
                ),

                const SizedBox(width: 12),
                
                // ツールボタン
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.blueAccent.withOpacity(0.6),
                        size: 22,
                      ),
                      tooltip: '項を追加',
                      onPressed: onAdd,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: isDark ? Colors.white24 : Colors.black26,
                        size: 20,
                      ),
                      color: const Color(0xFF1A1A2E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'toggle_name',
                          child: Row(
                            children: [
                              Icon(nameVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white70, size: 18),
                              const SizedBox(width: 12),
                              Text(nameVisible ? '名称を隠す' : '名称を出す', style: const TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'insert_below',
                          child: Row(
                            children: [
                              Icon(Icons.playlist_add_rounded, color: Colors.white70, size: 18),
                              SizedBox(width: 12),
                              Text('下に計算を追加', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(height: 1),
                        const PopupMenuItem(
                          value: 'copy',
                          child: Row(
                            children: [
                              Icon(Icons.copy_all_rounded, color: Colors.blueAccent, size: 18),
                              SizedBox(width: 12),
                              Text('複製', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'brackets',
                          child: Row(
                            children: [
                              Icon(Icons.code_rounded, color: Colors.blueAccent, size: 18),
                              SizedBox(width: 12),
                              Text('優先順位 ( )', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'link_dest',
                          child: Row(
                            children: [
                              Icon(Icons.link_rounded, color: Colors.blueAccent, size: 18),
                              SizedBox(width: 12),
                              Text('リンク設定', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(height: 1),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                              SizedBox(width: 12),
                              Text('削除', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (val) {
                        if (val == 'delete') onDelete();
                        if (val == 'copy') onCopy();
                        if (val == 'brackets') onPickBrackets();
                        if (val == 'link_dest') _showSetLinkDestDialog(context);
                        if (val == 'move_up') onMoveUp?.call();
                        if (val == 'move_down') onMoveDown?.call();
                        if (val == 'toggle_name') onToggleName?.call();
                        if (val == 'insert_below') onInsertBelow?.call();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── AIカウント専用ページ ──
class _AiCountPage extends StatefulWidget {
  final Future<int?> Function(Uint8List imageBytes, String instruction) onCount;

  const _AiCountPage({required this.onCount});

  @override
  State<_AiCountPage> createState() => _AiCountPageState();
}

class _AiCountPageState extends State<_AiCountPage> {
  Uint8List? _imageBytes;
  bool _isCounting = false;
  int? _lastCount;
  final _instructionCtrl = TextEditingController();
  final _picker = ImagePicker();

  @override
  void dispose() {
    _instructionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final Permission perm =
        source == ImageSource.camera ? Permission.camera : Permission.photos;
    final status = await perm.request();
    if (!mounted) return;
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'カメラのアクセス許可が必要です。'
                : '写真へのアクセス許可が必要です。',
          ),
          action: SnackBarAction(
            label: '設定を開く',
            onPressed: openAppSettings,
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _lastCount = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像の取得に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _runCount() async {
    final instruction = _instructionCtrl.text.trim();
    if (instruction.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('何を数えるか入力してください。')),
      );
      return;
    }
    if (_imageBytes == null) return;

    setState(() => _isCounting = true);
    try {
      final count = await widget.onCount(_imageBytes!, instruction);
      if (!mounted) return;
      setState(() => _lastCount = count);
      if (count == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('数字を読み取れませんでした。別の指示を試してください。'),
            backgroundColor: Colors.deepOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCounting = false);
    }
  }

  void _showSourcePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.camera_alt, color: Colors.tealAccent),
              title: const Text(
                'カメラで撮影',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Colors.tealAccent),
              title: const Text(
                'ギャラリーから選択',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: const Row(
          children: [
            Icon(Icons.camera_alt_outlined, color: Colors.tealAccent, size: 18),
            SizedBox(width: 8),
            Text(
              'AIカウント',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        actions: [
          if (_lastCount != null)
            TextButton.icon(
              onPressed: () => Navigator.pop(context, _lastCount),
              icon: const Icon(
                Icons.check_circle,
                color: Colors.tealAccent,
                size: 18,
              ),
              label: Text(
                '${_lastCount} を反映',
                style: const TextStyle(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 画像エリア
          Expanded(
            child: _imageBytes == null
                ? _buildPickerArea()
                : _buildImageArea(),
          ),
          // 指示入力バー（画像選択後に表示）
          if (_imageBytes != null) _buildInstructionBar(),
        ],
      ),
    );
  }

  Widget _buildPickerArea() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_search,
            color: Colors.white24,
            size: 72,
          ),
          const SizedBox(height: 20),
          const Text(
            '画像を選択してください',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSourceButton(
                icon: Icons.camera_alt,
                label: 'カメラ',
                onTap: () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(width: 20),
              _buildSourceButton(
                icon: Icons.photo_library,
                label: 'ギャラリー',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.tealAccent.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.tealAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.tealAccent, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 画像表示
        Image.memory(_imageBytes!, fit: BoxFit.contain),

        // カウント結果バッジ
        if (_lastCount != null)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Text(
                  '${_lastCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),

        // カウント中オーバーレイ
        if (_isCounting)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.tealAccent),
                  SizedBox(height: 16),
                  Text(
                    'AIが解析中...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

        // 写真変更ボタン
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _isCounting ? null : _showSourcePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, color: Colors.white70, size: 14),
                  SizedBox(width: 4),
                  Text(
                    '写真を変更',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionBar() {
    return Container(
      color: const Color(0xFF0D0D1A),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _instructionCtrl,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.send,
                onSubmitted: _isCounting ? null : (_) => _runCount(),
                decoration: InputDecoration(
                  hintText: '何を数えますか？（例: 人の数）',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.07),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isCounting ? null : _runCount,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isCounting
                      ? Colors.teal.withOpacity(0.3)
                      : Colors.teal,
                  shape: BoxShape.circle,
                ),
                child: _isCounting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 22,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}