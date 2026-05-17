part of 'widget_page.dart';

extension _CalculatorWidgetStateTable on _CalculatorWidgetState {
  Widget _buildTableModeWidget() {
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
    final bgColor = bgColorValue != null
        ? Color(bgColorValue)
        : (isDark ? const Color(0xFF1A1A22) : const Color(0xFFFAFAFA));

    // ── 結果計算 ──────────────────────────────────────────────────────────
    final List<double> provisionalResults = List.filled(items.length, 0.0);
    for (int pi = 0; pi < items.length; pi++) {
      final pItem = items[pi];
      final pOthers = (pItem['others'] as List? ?? []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        m['val'] = (m['val'] as num? ?? 0.0).toDouble();
        return m;
      }).toList();
      provisionalResults[pi] = _calculate(
        _CalculatorRow._applyTermTransform(
          (pItem['input'] as num? ?? 0.0).toDouble(),
          pItem['inputTransform'] as String?,
          (pItem['inputPowExp'] as num? ?? 2.0).toDouble(),
        ),
        pItem['op'] as String? ?? '+',
        _CalculatorRow._applyTermTransform(
          (pItem['operand'] as num? ?? 0.0).toDouble(),
          pItem['operandTransform'] as String?,
          (pItem['operandPowExp'] as num? ?? 2.0).toDouble(),
        ),
        pOthers,
        pItem['brackets'] as List? ?? [],
      );
    }
    final List<double> finalResults = List<double>.from(provisionalResults);
    // リンク解決後の各行の実際の値を保持（セル表示用）
    final resolvedRows = List<Map<String, dynamic>>.generate(
      items.length,
      (i) => <String, dynamic>{
        'input': (items[i]['input'] as num? ?? 0.0).toDouble(),
        'operand': (items[i]['operand'] as num? ?? 0.0).toDouble(),
        'others': List<Map<String, dynamic>>.from(
          (items[i]['others'] as List? ?? []).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        ),
      },
    );
    for (int pass = 0; pass < items.length; pass++) {
      bool anyChange = false;
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
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
            final consts = _constants;
            if (constIdx >= 0 && constIdx < consts.length) {
              return (consts[constIdx]['value'] as num? ?? 0.0).toDouble();
            }
            return fallback;
          }
          final int sRowIdx = source['rowIdx'] as int? ?? 0;
          final String sTarget = source['target'] as String? ?? 'result';
          if (sRowIdx < 0 || sRowIdx >= items.length) return fallback;
          if (sTarget == 'result') return finalResults[sRowIdx];
          if (sTarget == 'input') {
            return (items[sRowIdx]['input'] as num? ?? 0.0).toDouble();
          }
          if (sTarget == 'operand') {
            return (items[sRowIdx]['operand'] as num? ?? 0.0).toDouble();
          }
          if (sTarget.startsWith('other_')) {
            final idx = int.tryParse(sTarget.split('_')[1]) ?? 0;
            final sOthers = items[sRowIdx]['others'] as List? ?? [];
            if (idx < sOthers.length) {
              return (sOthers[idx]['val'] as num? ?? 0.0).toDouble();
            }
          }
          return fallback;
        }

        final inputValue = resolveLink(
          item['inputLinkSource'] as Map<String, dynamic>?,
          item['inputLink'] == true,
          (item['input'] as num? ?? 0.0).toDouble(),
        );
        final operandValue = resolveLink(
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
        resolvedRows[i] = {
          'input': inputValue,
          'operand': operandValue,
          'others': othersValue,
        };
      }
      if (!anyChange) break;
    }

    String fmtNum(double v, int precision) {
      if (v.isNaN || v.isInfinite) return '0';
      if (v == v.truncateToDouble() && v.abs() < 1e12) {
        return v.toInt().toString();
      }
      return v.toStringAsFixed(precision);
    }

    // 変換オプション付きの値表示文字列
    String termWithTransform(
      double rawV,
      String? transform,
      double powExp,
      int precision,
    ) {
      final s = fmtNum(rawV, precision);
      if (transform == null) return s;
      switch (transform) {
        case 'sqrt':
          return '√$s';
        case 'pow':
          final expStr = powExp == powExp.truncateToDouble()
              ? powExp.toInt().toString()
              : fmtNum(powExp, 1);
          return '$s^$expStr';
        case 'nroot':
          final expStr = powExp == powExp.truncateToDouble()
              ? powExp.toInt().toString()
              : fmtNum(powExp, 1);
          return '$expStr√$s';
        case 'abs':
          return '|$s|';
        case 'floor':
          return '⌊$s⌋';
        case 'ceil':
          return '⌈$s⌉';
        case 'round':
          return '≈$s';
        case 'log10':
          return 'log($s)';
        case 'reciprocal':
          return '1/$s';
        case 'sin':
          return 'sin($s)';
        case 'cos':
          return 'cos($s)';
        case 'tan':
          return 'tan($s)';
        default:
          return s;
      }
    }

    // ── カラム定義を生成 ──────────────────────────────────────────────────
    // 行 = 計算式、列 = 名前 | 項1 | 項2 | 項3... | 答え
    final maxOthers = items.fold(
      0,
      (int acc, item) => math.max(acc, (item['others'] as List? ?? []).length),
    );
    final allColumnKeys = <String>['name', 'input', 'operand'];
    for (int i = 0; i < maxOthers; i++) {
      allColumnKeys.add('other_$i');
    }
    allColumnKeys.add('result');

    final rawColConfig =
        widget.config.data['tableColumnConfig'] as List<dynamic>? ?? [];
    final colConfigMap = <String, Map<String, dynamic>>{
      for (final c in rawColConfig.whereType<Map>())
        c['key'] as String: Map<String, dynamic>.from(c),
    };

    String defaultLabel(String key) {
      if (key == 'name') return '名前';
      if (key == 'input') return '項1';
      if (key == 'operand') return '項2';
      if (key == 'result') return '答え';
      final i = int.tryParse(key.split('_')[1]) ?? 0;
      return '項${i + 3}';
    }

    final columns = allColumnKeys
        .map(
          (key) => <String, dynamic>{
            'key': key,
            'label':
                colConfigMap[key]?['label'] as String? ?? defaultLabel(key),
            'visible': colConfigMap[key]?['visible'] as bool? ?? true,
          },
        )
        .toList();

    final visibleColumns = columns.where((c) => c['visible'] as bool).toList();

    // ── スタイル ──────────────────────────────────────────────────────────
    final fgColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.09)
        : Colors.black.withOpacity(0.10);
    final headerBg = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.04);

    double colWidth(String key) => key == 'name' ? 150.0 : 96.0;

    // セルの表示文字列（リンク解決済み値・変換オプション表示対応）
    String cellValue(String key, int rowIdx) {
      final item = items[rowIdx];
      final resolved = resolvedRows[rowIdx];
      final precision = item['precision'] as int? ?? 2;
      final unit1 = item['unit1'] as String? ?? '';
      final unit2 = item['unit2'] as String? ?? '';
      final unitResult = item['unitResult'] as String? ?? '';
      if (key == 'name') return item['name'] as String? ?? '';
      if (key == 'input') {
        final v = resolved['input'] as double;
        final transform = item['inputTransform'] as String?;
        final powExp = (item['inputPowExp'] as num? ?? 2.0).toDouble();
        return termWithTransform(v, transform, powExp, precision) +
            (unit1.isNotEmpty ? ' $unit1' : '');
      }
      if (key == 'operand') {
        final v = resolved['operand'] as double;
        final transform = item['operandTransform'] as String?;
        final powExp = (item['operandPowExp'] as num? ?? 2.0).toDouble();
        return termWithTransform(v, transform, powExp, precision) +
            (unit2.isNotEmpty ? ' $unit2' : '');
      }
      if (key == 'result') {
        return fmtNum(finalResults[rowIdx], precision) +
            (unitResult.isNotEmpty ? ' $unitResult' : '');
      }
      if (key.startsWith('other_')) {
        final i = int.tryParse(key.split('_')[1]) ?? 0;
        final resolvedOthers = resolved['others'] as List;
        final rawOthers = item['others'] as List? ?? [];
        if (i < resolvedOthers.length) {
          final o = resolvedOthers[i] as Map;
          final v = (o['val'] as num? ?? 0.0).toDouble();
          final unit = i < rawOthers.length
              ? (rawOthers[i] as Map)['unit'] as String? ?? ''
              : '';
          final transform = i < rawOthers.length
              ? (rawOthers[i] as Map)['transform'] as String?
              : null;
          final powExp = i < rawOthers.length
              ? ((rawOthers[i] as Map)['powExp'] as num? ?? 2.0).toDouble()
              : 2.0;
          return termWithTransform(v, transform, powExp, precision) +
              (unit.isNotEmpty ? ' $unit' : '');
        }
        return '-';
      }
      return '';
    }

    // 答えセルをタップしたときに計算式をアラートで表示
    void showResultFormula(int rowIdx) {
      final item = items[rowIdx];
      final resolved = resolvedRows[rowIdx];
      final precision = item['precision'] as int? ?? 2;
      final unit1 = item['unit1'] as String? ?? '';
      final unit2 = item['unit2'] as String? ?? '';
      final unitResult = item['unitResult'] as String? ?? '';
      final inputTransform = item['inputTransform'] as String?;
      final inputPowExp = (item['inputPowExp'] as num? ?? 2.0).toDouble();
      final operandTransform = item['operandTransform'] as String?;
      final operandPowExp = (item['operandPowExp'] as num? ?? 2.0).toDouble();
      final op = item['op'] as String? ?? '+';
      final resolvedOthers = resolved['others'] as List;
      final rawOthers = item['others'] as List? ?? [];

      // 列ラベルを取得（カスタム設定があればそれを使用）
      String colLabel(String colKey) {
        final col = columns.firstWhere(
          (c) => c['key'] == colKey,
          orElse: () => <String, dynamic>{'label': colKey},
        );
        return col['label'] as String;
      }

      final inputRaw = resolved['input'] as double;
      final operandRaw = resolved['operand'] as double;

      // 式の各パーツを構築
      final parts = <String>[];
      parts.add(
        '${colLabel('input')}: ${termWithTransform(inputRaw, inputTransform, inputPowExp, precision)}${unit1.isNotEmpty ? ' $unit1' : ''}',
      );
      parts.add(
        '  $op ${colLabel('operand')}: ${termWithTransform(operandRaw, operandTransform, operandPowExp, precision)}${unit2.isNotEmpty ? ' $unit2' : ''}',
      );
      for (int i = 0; i < resolvedOthers.length; i++) {
        final o = resolvedOthers[i] as Map;
        final rawO = i < rawOthers.length
            ? rawOthers[i] as Map
            : <String, dynamic>{};
        final oVal = (o['val'] as num? ?? 0.0).toDouble();
        final oOp = rawO['op'] as String? ?? '+';
        final oTransform = rawO['transform'] as String?;
        final oPowExp = (rawO['powExp'] as num? ?? 2.0).toDouble();
        final oUnit = rawO['unit'] as String? ?? '';
        parts.add(
          '  $oOp ${colLabel('other_$i')}: ${termWithTransform(oVal, oTransform, oPowExp, precision)}${oUnit.isNotEmpty ? ' $oUnit' : ''}',
        );
      }
      parts.add(
        '= ${fmtNum(finalResults[rowIdx], precision)}${unitResult.isNotEmpty ? ' $unitResult' : ''}',
      );

      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            item['name'] as String? ?? '答えの計算式',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'ZenOldMincho',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            parts.join('\n'),
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'ZenOldMincho',
              fontSize: 15,
              height: 1.9,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                '閉じる',
                style: TextStyle(color: Color(0xFF5E81FF)),
              ),
            ),
          ],
        ),
      );
    }

    bool isResultCol(String key) => key == 'result';

    return Container(
      padding:
          widget.contentPadding ??
          const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.03),
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
                      color: isDark ? Colors.white70 : Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'ZenOldMincho',
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.view_column_rounded, size: 20),
                  tooltip: '列の設定',
                  onPressed: () =>
                      _showTableColumnSettingsSheet(columns, isDark),
                  color: isDark ? Colors.white38 : Colors.black38,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                  onPressed: () => widget.onUpdate({
                    ...widget.config.data,
                    'viewMode': false,
                    'tableMode': false,
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
            const SizedBox(height: 12),
          ],
          if (visibleColumns.isEmpty || items.isEmpty)
            Center(
              child: Text(
                items.isEmpty ? '計算式がありません' : '表示する列がありません',
                style: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black26,
                  fontFamily: 'ZenOldMincho',
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── ヘッダー行 ──────────────────────────────────────────
                  Row(
                    children: visibleColumns.map((col) {
                      final key = col['key'] as String;
                      final label = col['label'] as String;
                      final w = colWidth(key);
                      final isLast = col == visibleColumns.last;
                      final isEditable = key != 'result' && key != 'name';
                      final isNameCol = key == 'name';
                      return GestureDetector(
                        onTap: isNameCol
                            ? () => _showColumnVisibilityDialog(columns, isDark)
                            : (isEditable
                                  ? () => _showTableColumnLabelEdit(
                                      key,
                                      label,
                                      columns,
                                    )
                                  : null),
                        child: Container(
                          width: w,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: headerBg,
                            border: Border(
                              bottom: BorderSide(color: borderColor),
                              right: isLast
                                  ? BorderSide.none
                                  : BorderSide(color: borderColor),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: subColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'ZenOldMincho',
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              if (isNameCol) ...[
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.view_column_rounded,
                                  size: 8,
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.black12,
                                ),
                              ] else if (isEditable) ...[
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.edit_rounded,
                                  size: 8,
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.black12,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  // ── データ行 ────────────────────────────────────────────
                  ...() {
                    // displayOrder に従った表示順で calc エントリを列挙
                    final displayedCalcIndices = _effectiveDisplayOrder
                        .where((e) => e['type'] == 'calc')
                        .map((e) => e['calcIdx'] as int)
                        .where((i) => i >= 0 && i < items.length)
                        .toList();
                    return displayedCalcIndices.asMap().entries.map((entry) {
                      final displayPos = entry.key;
                      final rowIdx = entry.value;
                      final isLastRow =
                          displayPos == displayedCalcIndices.length - 1;
                      return Row(
                        children: visibleColumns.map((col) {
                          final key = col['key'] as String;
                          final w = colWidth(key);
                          final isLastCol = col == visibleColumns.last;
                          final val = cellValue(key, rowIdx);
                          final isRes = isResultCol(key);
                          final editable = !isRes;
                          return GestureDetector(
                            onTap: isRes
                                ? () => _showTableItemEditSheet(
                                    rowIdx,
                                    'result',
                                    '答え',
                                  )
                                : (editable
                                      ? () => _showTableItemEditSheet(
                                          rowIdx,
                                          key,
                                          col['label'] as String,
                                        )
                                      : null),
                            child: Container(
                              width: w,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isRes
                                    ? (isDark
                                          ? Colors.white.withOpacity(0.03)
                                          : Colors.black.withOpacity(0.02))
                                    : Colors.transparent,
                                border: Border(
                                  bottom: isLastRow
                                      ? BorderSide.none
                                      : BorderSide(color: borderColor),
                                  right: isLastCol
                                      ? BorderSide.none
                                      : BorderSide(color: borderColor),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      val,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isRes
                                            ? fgColor
                                            : (isDark
                                                  ? Colors.white70
                                                  : Colors.black),
                                        fontSize: isRes ? 16 : 15,
                                        fontWeight: isRes
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        fontFamily: 'ZenOldMincho',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    }).toList();
                  }(),
                ],
              ),
            ),
          if (_constants.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildConstantsSection(_constants, isDark),
          ],
          // 論理式行をテーブル下部にメモ風で表示
          ...() {
            final logicItems = _logicItems;
            if (logicItems.isEmpty) return <Widget>[];
            return [
              const SizedBox(height: 12),
              Divider(color: isDark ? Colors.white10 : Colors.black12),
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4, bottom: 2),
                child: Text(
                  '論理式',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...logicItems.map((logicItem) {
                final exprStr = _CalculatorWidgetState._buildLogicExprString(logicItem);
                final isTrue = _CalculatorWidgetState._evalLogicItem(logicItem);
                final logicName = logicItem['name'] as String? ?? '';
                final itemId = logicItem['id'] as String? ?? '';
                return GestureDetector(
                  onTap: () {
                    showDialog<Map<String, dynamic>?>(
                      context: context,
                      builder: (ctx) =>
                          _LogicItemEditDialog(initial: logicItem),
                    ).then((result) {
                      if (result == null || !mounted) return;
                      _updateLogicItem(itemId, result);
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(8, 3, 8, 3),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.deepPurpleAccent.withOpacity(0.07)
                          : Colors.deepPurple.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark
                            ? Colors.deepPurpleAccent.withOpacity(0.22)
                            : Colors.deepPurple.withOpacity(0.16),
                      ),
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
                          child: Text(
                            logicName.isNotEmpty
                                ? '$logicName: $exprStr'
                                : exprStr,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.black.withOpacity(0.65),
                              fontSize: 12,
                              fontFamily: 'ZenOldMincho',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                                ? Colors.greenAccent.withOpacity(0.15)
                                : Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isTrue
                                  ? Colors.greenAccent.withOpacity(0.4)
                                  : Colors.redAccent.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            isTrue ? '真' : '偽',
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
              }),
            ];
          }(),
        ],
      ),
    );
  }

  /// 列ヘッダーのラベルをインラインで編集するシート（表モード専用）
  void _showTableColumnLabelEdit(
    String columnKey,
    String currentLabel,
    List<Map<String, dynamic>> allColumns,
  ) {
    showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ColumnLabelEditSheet(
        columnKey: columnKey,
        currentLabel: currentLabel,
        allColumns: allColumns,
      ),
    ).then((newColConfig) {
      if (newColConfig == null || !mounted) return;
      widget.onUpdate({
        ...widget.config.data,
        'tableColumnConfig': newColConfig,
      });
    });
  }

  /// セルをタップしたときに値/名前を編集するシート（編集モードと同じ詳細シートを使用）
  void _showTableItemEditSheet(
    int rowIdx,
    String columnKey,
    String columnLabel,
  ) {
    final items = _items;
    if (rowIdx < 0 || rowIdx >= items.length) return;
    final item = items[rowIdx];
    final constants = _constants;
    final bgColorValue = widget.config.data['bgColor'] as int?;
    final isDark = bgColorValue != null
        ? _kNoteColorPresets
              .firstWhere(
                (p) => p.value == bgColorValue,
                orElse: () => _kNoteColorPresets.first,
              )
              .isDark
        : true;

    // リンク解決済みの結果を計算（編集モードと同様に finalResults を使用）
    final resolvedRowsForEdit = _computeResolvedRows(items, constants);
    final finalResultsForEdit = resolvedRowsForEdit
        .map((r) => (r['result'] as num? ?? 0.0).toDouble())
        .toList();
    final resolvedForRow = rowIdx < resolvedRowsForEdit.length
        ? resolvedRowsForEdit[rowIdx]
        : <String, dynamic>{};

    void onItemChanged(Map<String, dynamic> newItem) {
      final latestItems = _items;
      if (rowIdx >= latestItems.length) return;
      final newItems = List<Map<String, dynamic>>.from(latestItems);
      newItems[rowIdx] = newItem;
      widget.onUpdate({...widget.config.data, 'items': newItems});
    }

    final row = _CalculatorRow(
      name: item['name'] as String? ?? '',
      myIndex: rowIdx,
      input: (resolvedForRow['input'] as num? ?? (item['input'] as num? ?? 0.0))
          .toDouble(),
      inputLink: item['inputLink'] as bool? ?? false,
      inputLinkSource: item['inputLinkSource'] as Map<String, dynamic>?,
      inputTransform: item['inputTransform'] as String?,
      inputPowExp: (item['inputPowExp'] as num? ?? 2.0).toDouble(),
      op: item['op'] as String? ?? '+',
      operand:
          (resolvedForRow['operand'] as num? ??
                  (item['operand'] as num? ?? 0.0))
              .toDouble(),
      operandLink: item['operandLink'] as bool? ?? false,
      operandLinkSource: item['operandLinkSource'] as Map<String, dynamic>?,
      operandTransform: item['operandTransform'] as String?,
      operandPowExp: (item['operandPowExp'] as num? ?? 2.0).toDouble(),
      others: List.from(
        resolvedForRow['others'] as List? ?? item['others'] as List? ?? [],
      ),
      result: rowIdx < finalResultsForEdit.length
          ? finalResultsForEdit[rowIdx]
          : 0.0,
      precision: item['precision'] as int? ?? 2,
      unit1: item['unit1'] as String? ?? '',
      unit2: item['unit2'] as String? ?? '',
      unitResult: item['unitResult'] as String? ?? '',
      isDark: isDark,
      brackets: item['brackets'] as List? ?? [],
      allItems: items,
      allResults: finalResultsForEdit,
      constants: constants,
      onChanged: onItemChanged,
      onDelete: () {},
      onCopy: () {},
      onCut: null,
      onPaste: null,
      hasClipboard: false,
      onAdd: () {},
      onPickBrackets: () {},
      onAllItemsUpdate: (newItems) =>
          widget.onUpdate({...widget.config.data, 'items': newItems}),
      termLabels: _effectiveTermLabels.isNotEmpty ? _effectiveTermLabels : null,
      onLinkSettingsPressed: (mode, fieldKey) {
        if (mode == 'source') {
          _showSheetLinkSettingsDialog(
            initialSrcCalcIdx: rowIdx,
            initialSrcField: fieldKey,
          );
        } else {
          _showSheetLinkSettingsDialog(
            initialDestCalcIdx: rowIdx,
            initialDestField: fieldKey,
          );
        }
      },
    );

    if (columnKey == 'result') {
      row._editResultProperties(context, Offset.zero);
    } else if (columnKey == 'name') {
      row._editDetails(context);
    } else if (columnKey == 'input') {
      row._editInput(context);
    } else if (columnKey == 'operand') {
      row._editOperand(context);
    } else if (columnKey.startsWith('other_')) {
      final i = int.tryParse(columnKey.split('_')[1]) ?? 0;
      row._editOtherVal(context, i);
    }
  }

  /// 列の表示・非表示と列名を設定するシート
  void _showTableColumnSettingsSheet(
    List<Map<String, dynamic>> columns,
    bool isDark,
  ) {
    showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ColumnSettingsSheet(columns: columns),
    ).then((newColConfig) {
      if (newColConfig == null || !mounted) return;
      widget.onUpdate({
        ...widget.config.data,
        'tableColumnConfig': newColConfig,
      });
    });
  }

  /// 表の左上「名前」ヘッダータップ時：列の表示/非表示をアラートで切り替える
  void _showColumnVisibilityDialog(
    List<Map<String, dynamic>> columns,
    bool isDark,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ColumnVisibilityDialog(
        columns: columns,
        onSave: (newConfig) {
          if (mounted) {
            widget.onUpdate({
              ...widget.config.data,
              'tableColumnConfig': newConfig,
            });
          }
        },
      ),
    );
  }
}
