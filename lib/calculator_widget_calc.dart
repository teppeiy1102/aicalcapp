part of 'widget_page.dart';

extension _CalculatorWidgetStateCalc on _CalculatorWidgetState {
  // ── 電卓ロジック ──
  void _onCalcKey(String key) {
    // ignore: invalid_use_of_protected_member
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
          // 表示用（カンマ付き）
          final exprDisplayParts = exprParts.map((p) {
            final v = double.tryParse(p);
            return v != null ? _addCommas(p) : p;
          }).toList();
          _calcExprStr = '${exprDisplayParts.join(' ')} = ${_addCommas(_fmtCalc(result))}';
          _calcTermValues = allTerms;
          _calcTermOps = effectiveOps;
          _calcA = result;
          _calcOp = '';
          _calcDisplay = _fmtCalc(result);
          _calcHasResult = true;
          _calcNewEntry = true;
          // 履歴に保存（カンマなし）
          CalcHistoryManager.instance.addEntry(
            exprParts.join(' '),
            _fmtCalc(result),
          );
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
          // 複数項がある場合、そこまでの計算結果を表示
          if (_calcTermValues.length >= 2) {
            double runningResult = _calcTermValues[0];
            for (int i = 0; i + 1 < _calcTermValues.length; i++) {
              runningResult = _evalCalcSimple(
                runningResult,
                _calcTermOps[i],
                _calcTermValues[i + 1],
              );
            }
            _calcDisplay = _fmtCalc(runningResult);
            _calcA = runningResult;
          }
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
    // 浮動小数点誤差を除去するため、有効数字10桁で丸める
    int intDigits = v.abs() >= 1 ? v.abs().toInt().toString().length : 0;
    int decDigits = (10 - intDigits).clamp(0, 10);
    String s = v.toStringAsFixed(decDigits);
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

    final newCalcIdx = newItems.length;
    newItems.add(newItem);
    final order = List<Map<String, dynamic>>.from(_effectiveDisplayOrder);
    order.add({'type': 'calc', 'calcIdx': newCalcIdx});
    widget.onUpdate({
      ...widget.config.data,
      'items': newItems,
      'displayOrder': order,
    });
    // ignore: invalid_use_of_protected_member
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
        final double subtitleFontSize = (20.0 * scale).clamp(12.0, 20.0);

        final textColor = isDark ? Colors.white : Colors.black;
        final keyBg = isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.07);
        final opColor = isDark ? Colors.blueAccent : Colors.black;
        final eqColor = isDark ? Colors.orangeAccent : Colors.black;

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
            ipParts.add(_addCommas(_fmtCalc(_calcTermValues[i])));
            if (i < _calcTermOps.length) ipParts.add(_calcTermOps[i]);
          }
          inProgressExpr = ipParts.join(' ');
        }
        final String subtitle = _calcHasResult ? _calcExprStr : inProgressExpr;

        Widget content = SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 46),
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(
                            isDark ? 0.25 : 0.12,
                          ),
                          border: Border.all(
                            color: Colors.tealAccent.withOpacity(0.45),
                            width: 0.8,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.tealAccent,
                              size: 16,
                            ),
                            if (_isAiCounting)
                              SizedBox(
                                width: (36.0 * scale).clamp(26.0, 36.0),
                                height: (36.0 * scale).clamp(26.0, 36.0),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.tealAccent,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 履歴ボタン
                  GestureDetector(
                    onTap: _showCalcHistory,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.06),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.2)
                              : Colors.black.withOpacity(0.15),
                          width: 0.8,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        color: isDark ? Colors.white70 : Colors.black54,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 「この計算を追加」ボタン
                  Expanded(
                    child: AnimatedOpacity(
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
                    ),
                  ),
                ],
              ),
              // 表示部
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                height: 80,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.0)
                      : Colors.black.withOpacity(0.0),
                  borderRadius: BorderRadius.circular(0),
                ),
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
                                _addCommas(_calcDisplay),
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
                          ),
                        ],
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
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
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
                      calcKey(
                        '=',
                        bg: eqColor.withOpacity(0.8),
                        fg: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
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
}
