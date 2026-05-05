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
          decoration: BoxDecoration(
            color: widget.bg,
            borderRadius: BorderRadius.circular(1000),
          ),
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
  bool _isAiCounting = false;
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
            padding: const EdgeInsets.only(left: 4, right: 14, top: 12, bottom: 10),
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
                        color: Colors.white.withOpacity(0.85),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.45),
                          width: 0.8,
                        ),
                        shape: BoxShape.circle
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.black,
                            size: 22,
                          ),
                          if (_isAiCounting)
                            const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.tealAccent,
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

