part of 'widget_page.dart';

extension _CalculatorWidgetStateView on _CalculatorWidgetState {
  // ── 閲覧モード用の定数セクション（読み取り専用） ──────────────────────────
  Widget _buildViewModeConstantsSection(
    List<Map<String, dynamic>> constants,
    bool isDark,
  ) {
    final fgColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black45;
    return Container(
      margin: const EdgeInsets.only(bottom: 5, top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        // color: Colors.amberAccent.withOpacity(isDark ? 0.07 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: subColor.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.push_pin_outlined,
                size: 12,
                color: Colors.amber,
              ),
              const SizedBox(width: 5),
              Text(
                AppLocalizations.of(context)!.constant,
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'ZenOldMincho',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 5,
            children: constants.map((c) {
              final name = c['name'] as String? ?? '';
              final value = (c['value'] as num? ?? 0.0).toDouble();
              final valStr =
                  value == value.truncateToDouble() && value.abs() < 1e12
                  ? _addCommas(value.toInt().toString())
                  : _addCommas(value
                        .toStringAsFixed(4)
                        .replaceAll(RegExp(r'0+$'), '')
                        .replaceAll(RegExp(r'\.$'), ''));
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: subColor,
                        fontSize: 11,
                        fontFamily: 'ZenOldMincho',
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '=',
                      style: TextStyle(
                        color: subColor,
                        fontSize: 11,
                        fontFamily: 'ZenOldMincho',
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      valStr,
                      style: TextStyle(
                        color: fgColor,
                        fontSize: 12,
                        //fontWeight: FontWeight.bold,
                        fontFamily: 'ZenOldMincho',
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── 閲覧モード用ウィジェット ──
  Widget _buildViewModeWidget() {
    final items = _items;
    final constants = _constants;
    final standaloneItems = _standaloneItems;
    final displayOrder = _effectiveDisplayOrder;
    final title = widget.config.data['title'] as String? ?? AppLocalizations.of(context)!.standardCalc;
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
    // Pass 1: 暫定計算（リンクなし）
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

    // Pass 2: 反復収束によりチェーンリンクを正しく解決
    final List<double> finalResults = List<double>.from(provisionalResults);
    var resolvedRows = <Map<String, dynamic>>[];

    double resolveLink(
      Map<String, dynamic>? source,
      bool isLink,
      double fallback,
    ) {
      if (!isLink) return fallback;
      if (source == null) {
        return finalResults.isNotEmpty ? finalResults.last : fallback;
      }
      if (source['sheetId'] != null) {
        return _resolveExternalValue(
          source['sheetId'] as String,
          source['rowIdx'] as int? ?? 0,
          source['target'] as String? ?? 'result',
        );
      }
      if (source['type'] == 'constant') {
        final constIdx = source['constIdx'] as int? ?? 0;
        if (constIdx >= 0 && constIdx < constants.length) {
          return (constants[constIdx]['value'] as num? ?? 0.0).toDouble();
        }
        return fallback;
      }
      if (source['type'] == 'logic') {
        final logicId = source['logicId'] as String?;
        if (logicId != null) {
          final logicItems = widget.config.data['logicItems'] as List? ?? [];
          Map<String, dynamic>? logic;
          for (final l in logicItems) {
            if (l is Map && l['id'] == logicId) {
              logic = Map<String, dynamic>.from(l);
              break;
            }
          }
          if (logic != null) {
            final isTrue = _CalculatorWidgetState._evalLogicItem(logic, resolveLink);
            final trueVal = (source['trueVal'] as num? ?? 1.0).toDouble();
            final falseVal = (source['falseVal'] as num? ?? 0.0).toDouble();
            return isTrue ? trueVal : falseVal;
          }
        }
        return fallback;
      }
      final int sRowIdx = source['rowIdx'] as int? ?? 0;
      final String sTarget = source['target'] as String? ?? 'result';
      if (sRowIdx < 0 || sRowIdx >= items.length) return fallback;
      final sItem = items[sRowIdx];
      if (sTarget == 'result') return finalResults[sRowIdx];
      if (sTarget == 'input') return (sItem['input'] as num? ?? 0.0).toDouble();
      if (sTarget == 'operand') {
        return (sItem['operand'] as num? ?? 0.0).toDouble();
      }
      if (sTarget.startsWith('other_')) {
        final idx = int.tryParse(sTarget.split('_')[1]) ?? 0;
        final sOthers = sItem['others'] as List? ?? [];
        if (idx < sOthers.length) {
          return (sOthers[idx]['val'] as num? ?? 0.0).toDouble();
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
      if (v == v.truncateToDouble() && v.abs() < 1e12) {
        return _addCommas(v.toInt().toString());
      }
      return _addCommas(v.toStringAsFixed(precision));
    }

    List<InlineSpan> buildFormulaSpans(
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
      final double operandPow = (item['operandPowExp'] as num? ?? 2.0)
          .toDouble();

      bool hasStart(int idx) => bks.any((b) => (b as Map)['start'] == idx);
      bool hasEnd(int idx) => bks.any((b) => (b as Map)['end'] == idx);

      final valStyle = TextStyle(
        color: isDark ? Colors.white60 : Colors.black54,
        fontSize: 14,
        fontFamily: 'ZenOldMincho',
        height: 1.5,
      );
      final unitStyle = TextStyle(
        color: isDark ? Colors.white38 : Colors.black45,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.5,
      );

      List<InlineSpan> termSpans(double v, String u, String? transform, double powExp) {
        final s = fmtNum(v, precision);
        final mapped = _CalculatorRow._transformExprStr('###VAL###', transform, powExp);
        final parts = mapped.split('###VAL###');
        final prefix = parts[0];
        final suffix = parts.length > 1 ? parts[1] : '';

        final spans = <InlineSpan>[];
        if (prefix.isNotEmpty) spans.add(TextSpan(text: prefix, style: valStyle));
        spans.add(TextSpan(text: s, style: valStyle));
        if (u.isNotEmpty) spans.add(TextSpan(text: ' $u', style: unitStyle));
        if (suffix.isNotEmpty) spans.add(TextSpan(text: suffix, style: valStyle));
        return spans;
      }

      // 各項をトークンリストで組み立て
      final termCount = others.length + 2;
      final terms = <List<InlineSpan>>[];
      terms.add(termSpans(iv, u1, inputTr, inputPow));
      terms.add(termSpans(ov, u2, operandTr, operandPow));
      for (final o in others) {
        final m = o as Map;
        final oVal = (m['val'] as num? ?? 0.0).toDouble();
        final oUnit = m['unit'] as String? ?? '';
        final String? oTr = m['transform'] as String?;
        final double oPow = (m['powExp'] as num? ?? 2.0).toDouble();
        terms.add(termSpans(oVal, oUnit, oTr, oPow));
      }

      final ops = <String>[opStr];
      for (final o in others) {
        ops.add((o as Map)['op'] as String? ?? '+');
      }

      final spans = <InlineSpan>[];
      for (int idx = 0; idx < termCount; idx++) {
        if (hasStart(idx)) spans.add(TextSpan(text: '( ', style: valStyle));
        spans.addAll(terms[idx]);
        if (hasEnd(idx)) spans.add(TextSpan(text: ' )', style: valStyle));
        if (idx < ops.length) {
          spans.add(TextSpan(text: '  ${ops[idx]}  ', style: valStyle));
        }
      }
      return spans;
    }

    final bgColor = bgColorValue != null
        ? Color(bgColorValue)
        : (isDark ? const Color(0xFF1A1A22) : const Color(0xFFFAFAFA));

    return Container(
      margin: EdgeInsets.only(bottom: 0),
      padding:
          widget.contentPadding ??
          const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.03),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 50),
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
                        color: isDark ? Colors.white70 : Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'ZenOldMincho',
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded, size: 20),
                    onPressed: () => widget.onUpdate({
                      ...widget.config.data,
                      'viewMode': false,
                    }),
                    color: isDark ? Colors.white24 : Colors.black26,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Divider(
                color: isDark ? Colors.white10 : Colors.black12,
                thickness: 0.5,
              ),
              const SizedBox(height: 24),
            ],
        
            if (constants.isNotEmpty) ...[
              _buildViewModeConstantsSection(constants, isDark),
              const SizedBox(height: 16),
            ],
        
            if (items.isEmpty && standaloneItems.isEmpty && _logicItems.isEmpty)
              Center(
                child: Text(
                  AppLocalizations.of(context)!.noContent,
                  style: TextStyle(
                    color: isDark ? Colors.white12 : Colors.black12,
                    fontFamily: 'ZenOldMincho',
                  ),
                ),
              )
            else
              ...() {
                final memos = _memos;
                final widgets = <Widget>[];
                for (
                  int orderIdx = 0;
                  orderIdx < displayOrder.length;
                  orderIdx++
                ) {
                  final entry = displayOrder[orderIdx];
                  final isFirst = orderIdx == 0;
        
                  if (entry['type'] == 'standalone') {
                    final itemId = entry['itemId'] as String? ?? '';
                    final sm = standaloneItems.firstWhere(
                      (e) => e['id'] == itemId,
                      orElse: () => <String, dynamic>{},
                    );
                    if (sm.isEmpty) continue;
                    final text = sm['text'] as String? ?? '';
                    if (text.isEmpty) continue;
                    if (!isFirst) {
                      widgets.add(
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 6),
                          child: Divider(
                            color: isDark
                                ? Colors.white.withOpacity(0.03)
                                : Colors.black.withOpacity(0.03),
                            thickness: 0.5,
                          ),
                        ),
                      );
                    }
                    widgets.add(
                      Padding(
                        padding: const EdgeInsets.only(left: 10, bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.sticky_note_2_outlined,
                              size: 13,
                              color: isDark
                                  ? Colors.tealAccent.withOpacity(0.6)
                                  : Colors.teal.shade700.withOpacity(0.7),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                text,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.55)
                                      : Colors.black.withOpacity(0.55),
                                  fontSize: 13,
                                  fontFamily: 'ZenOldMincho',
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    continue;
                  }
        
                  if (entry['type'] == 'logic') {
                    final itemId = entry['itemId'] as String? ?? '';
                    final logicItem = _logicItems.firstWhere(
                      (e) => e['id'] == itemId,
                      orElse: () => <String, dynamic>{},
                    );
                    if (logicItem.isEmpty) continue;
                    if (!isFirst) {
                      widgets.add(
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 6),
                          child: Divider(
                            color: isDark
                                ? Colors.white.withOpacity(0.03)
                                : Colors.black.withOpacity(0.03),
                            thickness: 0.5,
                          ),
                        ),
                      );
                    }
                    final exprStr = _CalculatorWidgetState._buildLogicExprString(
                      logicItem,
                      resolveLink,
                    );
                    final isTrue = _CalculatorWidgetState._evalLogicItem(
                      logicItem,
                      resolveLink,
                    );
                    final logicName = logicItem['name'] as String? ?? '';
                    widgets.add(
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 10,
                          bottom: 4,
                          right: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.rule_rounded,
                              size: 13,
                              color: isDark
                                  ? Colors.deepPurpleAccent.withOpacity(0.7)
                                  : Colors.deepPurple.withOpacity(0.6),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (logicName.isNotEmpty)
                                    Text(
                                      logicName,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.45)
                                            : Colors.black45,
                                        fontSize: 11,
                                        fontFamily: 'ZenOldMincho',
                                      ),
                                    ),
                                  Text(
                                    exprStr,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.55)
                                          : Colors.black.withOpacity(0.55),
                                      fontSize: 12,
                                      fontFamily: 'ZenOldMincho',
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isTrue
                                    ? Colors.greenAccent.withOpacity(
                                        isDark ? 0.15 : 0.12,
                                      )
                                    : Colors.redAccent.withOpacity(
                                        isDark ? 0.15 : 0.10,
                                      ),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: isTrue
                                      ? Colors.greenAccent.withOpacity(0.4)
                                      : Colors.redAccent.withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                isTrue ? AppLocalizations.of(context)!.trueLabel : AppLocalizations.of(context)!.falseLabel,
                                style: TextStyle(
                                  color: isTrue
                                      ? (isDark
                                            ? Colors.greenAccent
                                            : Colors.green.shade700)
                                      : (isDark
                                            ? Colors.redAccent
                                            : Colors.red.shade700),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'ZenOldMincho',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    continue;
                  }
        
                  // type == 'calc'
                  final ci = entry['calcIdx'] as int? ?? 0;
                  if (ci < 0 || ci >= items.length || ci >= resolvedRows.length) {
                    continue;
                  }
        
                  final item = items[ci];
                  final resolved = resolvedRows[ci];
                  final precision = item['precision'] as int? ?? 2;
                  final name = item['name'] as String? ?? '';
                  final result = finalResults[ci];
                  final unitResult = item['unitResult'] as String? ?? '';
                  final formulaSpans = buildFormulaSpans(item, resolved, precision);
                  
                  final resultValStyle = TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'ZenOldMincho',
                    letterSpacing: -0.5,
                  );
                  final resultUnitStyle = TextStyle(
                    color: isDark ? Colors.white38 : Colors.black45,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  );

                  if (!isFirst) {
                    widgets.add(
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 6),
                        child: Divider(
                          color: isDark
                              ? Colors.white.withOpacity(0.03)
                              : Colors.black.withOpacity(0.03),
                          thickness: 0.5,
                        ),
                      ),
                    );
                  }
        
                  widgets.add(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 10),
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
                                ...formulaSpans,
                                TextSpan(
                                  text: '  =  ',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white24
                                        : Colors.black12,
                                    fontSize: 16,
                                  ),
                                ),
                                TextSpan(
                                  text: fmtNum(result, precision),
                                  style: resultValStyle,
                                ),
                                if (unitResult.isNotEmpty)
                                  TextSpan(
                                    text: ' $unitResult',
                                    style: resultUnitStyle,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
        
                  // この計算行に紐付いたメモを表示（閲覧モードは読み取り専用）
                  for (final memo in memos) {
                    if ((memo['afterCalcIdx'] as int? ?? -1) == ci) {
                      final text = memo['text'] as String? ?? '';
                      if (text.isNotEmpty) {
                        widgets.add(
                          Padding(
                            padding: const EdgeInsets.only(left: 10, bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.sticky_note_2_outlined,
                                  size: 13,
                                  color: isDark
                                      ? Colors.amber.withOpacity(0.5)
                                      : Colors.amber.shade700.withOpacity(0.6),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.45)
                                          : Colors.black.withOpacity(0.45),
                                      fontSize: 12,
                                      fontFamily: 'ZenOldMincho',
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    }
                  }
                }
                return widgets;
              }(),
            if (_showCalc) ...[
              const SizedBox(height: 12),
              _buildInlineCalc(isDark),
            ],
          ],
        ),
      ),
    );
  }
}
