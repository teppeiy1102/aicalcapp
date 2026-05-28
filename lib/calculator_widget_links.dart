part of 'widget_page.dart';

extension CalculatorWidgetLinks on _CalculatorWidgetState {
  void _showSheetLinkSettingsDialog({
    int? initialSrcCalcIdx,
    String? initialSrcField,
    int? initialDestCalcIdx,
    String? initialDestField,
  }) {
    final items = _items;
    if (items.isEmpty) return;

    int? selectedSrcCalcIdx = initialSrcCalcIdx;
    if (selectedSrcCalcIdx == null && items.isNotEmpty) {
      selectedSrcCalcIdx = 0;
      if (initialDestCalcIdx == 0 && items.length > 1) {
        selectedSrcCalcIdx = 1;
      } else if (initialDestCalcIdx == 0 && items.length == 1) {
        selectedSrcCalcIdx = null;
      }
    }
    String selectedSrcField = initialSrcField ?? 'result';
    // 初期表示時: tab0 で最初の式に既存リンク先を事前設定
    Set<String> selectedDests = selectedSrcCalcIdx != null
        ? _calcSelectedDestsForRow(selectedSrcCalcIdx, selectedSrcField)
        : {};
    if (initialDestCalcIdx != null && initialDestField != null) {
      selectedDests.add('${initialDestCalcIdx}_$initialDestField');
    }
    String? selectedSrcSheetId; // null = 現在シート
    // 0=このシート, 1=開放された式, 2=結合シート
    int srcTab = 0;
    // タブごとに最後に選択した (calcIdx, sheetId, field, dests) を記憶
    final Map<int, int?> _lastCalcIdxPerTab = {};
    final Map<int, String?> _lastSheetIdPerTab = {};
    final Map<int, String> _lastFieldPerTab = {};
    final Map<int, Set<String>> _lastDestsPerTab = {};
    // 複数式のリンク設定を蓄積する（一度のダイアログで複数リンク元を設定可能）
    final List<Map<String, dynamic>> _pendingLinks = [];

    void savePending() {
      if (selectedSrcCalcIdx == null) return;
      _pendingLinks.removeWhere(
        (op) =>
            op['sid'] == selectedSrcSheetId &&
            op['calcIdx'] == selectedSrcCalcIdx &&
            op['field'] == selectedSrcField,
      );
      _pendingLinks.add({
        'sid': selectedSrcSheetId,
        'calcIdx': selectedSrcCalcIdx!,
        'field': selectedSrcField,
        'dests': Set<String>.from(selectedDests),
      });
    }

    Set<String> loadPendingOrExisting(String? sid, int? calcIdx, String fld) {
      if (calcIdx == null) return {};
      try {
        final pending = _pendingLinks.firstWhere(
          (op) =>
              op['sid'] == sid &&
              op['calcIdx'] == calcIdx &&
              op['field'] == fld,
        );
        return Set<String>.from(pending['dests'] as Set<String>);
      } catch (_) {
        final existing = sid == null
            ? _calcSelectedDestsForRow(calcIdx, fld)
            : _calcSelectedDestsForExternalRow(sid, calcIdx, fld);
        if (initialDestCalcIdx != null && initialDestField != null) {
          existing.add('${initialDestCalcIdx}_$initialDestField');
        }
        return existing;
      }
    }

    // リンク先シート（null=現在シート、結合ビュー内の兄弟シートID）
    String? destSheetId;
    final siblingConfigs = widget.allConfigs
        .where(
          (c) =>
              widget.mergedSiblingIds.contains(c.id) && c.type == 'calculator',
        )
        .toList();

    List<Map<String, dynamic>> fieldsFor(int idx) {
      final item = items[idx];
      final others = item['others'] as List? ?? [];
      return [
        {
          'key': 'input',
          'label': '項1',
          'op': item['operator'] as String? ?? '+',
        },
        {
          'key': 'operand',
          'label': '項2',
          'op': others.isNotEmpty
              ? ((others[0] as Map)['operator'] as String? ?? '+')
              : null,
        },
        ...List.generate(
          others.length,
          (i) => {
            'key': 'other_$i',
            'label': '項${i + 3}',
            'op': (i + 1 < others.length)
                ? ((others[i + 1] as Map)['operator'] as String? ?? '+')
                : null,
          },
        ),
        {'key': 'result', 'label': '答え'},
      ];
    }

    List<Map<String, dynamic>> fieldsForExternal(String sheetId, int idx) {
      final srcConfig = widget.allConfigs.firstWhere(
        (c) => c.id == sheetId,
        orElse: () => widget.config,
      );
      final srcItems = (srcConfig.data['items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (idx < 0 || idx >= srcItems.length) return [];
      final sItem = srcItems[idx];
      final others = sItem['others'] as List? ?? [];
      return [
        {
          'key': 'input',
          'label': '項1',
          'op': sItem['operator'] as String? ?? '+',
        },
        {
          'key': 'operand',
          'label': '項2',
          'op': others.isNotEmpty
              ? ((others[0] as Map)['operator'] as String? ?? '+')
              : null,
        },
        ...List.generate(
          others.length,
          (i) => {
            'key': 'other_$i',
            'label': '項${i + 3}',
            'op': (i + 1 < others.length)
                ? ((others[i + 1] as Map)['operator'] as String? ?? '+')
                : null,
          },
        ),
        {'key': 'result', 'label': '答え'},
      ];
    }

    String fieldValueStr(int calcIdx, String fieldKey, [String? sheetId]) {
      // 現在シートも外部シートも _resolveExternalValue で統一的に解決
      final targetSheetId = sheetId ?? widget.config.id;
      final v = _resolveExternalValue(targetSheetId, calcIdx, fieldKey);
      final srcConfig = widget.allConfigs.firstWhere(
        (c) => c.id == targetSheetId,
        orElse: () => widget.config,
      );
      final srcItems = (srcConfig.data['items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final precision = calcIdx < srcItems.length
          ? (srcItems[calcIdx]['precision'] as int? ?? 2)
          : 2;
      final String valStr;
      if (v == v.truncateToDouble() && v.abs() < 1e12) {
        valStr = v.toStringAsFixed(0);
      } else {
        valStr = v.toStringAsFixed(precision);
      }
      // 単位を取得して付加
      String unit = '';
      if (calcIdx < srcItems.length) {
        final item = srcItems[calcIdx];
        if (fieldKey == 'input') {
          unit = item['unit1'] as String? ?? '';
        } else if (fieldKey == 'operand') {
          unit = item['unit2'] as String? ?? '';
        } else if (fieldKey == 'result') {
          unit = item['unitResult'] as String? ?? '';
        } else if (fieldKey.startsWith('other_')) {
          final idx = int.tryParse(fieldKey.split('_')[1]) ?? 0;
          final others = item['others'] as List? ?? [];
          if (idx < others.length) {
            unit = (others[idx] as Map)['unit'] as String? ?? '';
          }
        }
      }
      return unit.isNotEmpty ? '$valStr $unit' : valStr;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDs) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),

            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF161622).withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── ヘッダー ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.link_rounded,
                            color: Colors.blueAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '値をリンク',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          splashRadius: 20,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.upload_rounded,
                          size: 20,
                          color: Color.fromARGB(255, 38, 95, 218),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'リンク元',
                          style: TextStyle(
                            color: Color.fromARGB(255, 38, 95, 218),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  // ── リンク元セクション（タブ切り替え） ─────────────────
                  Builder(
                    builder: (_) {
                      final exposedSheets = widget.allConfigs.where((c) {
                        if (c.id == widget.config.id) return false;
                        if (c.type != 'calculator') return false;
                        if (widget.mergedSiblingIds.contains(c.id)) {
                          return false;
                        }
                        final si = c.data['items'] as List? ?? [];
                        return si.any((e) => (e as Map)['exposed'] == true);
                      }).toList();
                      final mergedSheets = widget.allConfigs.where((c) {
                        if (c.id == widget.config.id) return false;
                        if (c.type != 'calculator') return false;
                        return widget.mergedSiblingIds.contains(c.id);
                      }).toList();

                      final tabs = <Map<String, dynamic>>[
                        {
                          'idx': 0,
                          'label': 'このシート',
                          'icon': Icons.upload_rounded,
                          'color': Colors.blueAccent,
                        },
                        if (exposedSheets.isNotEmpty)
                          {
                            'idx': 1,
                            'label': '開放された式',
                            'icon': Icons.public_rounded,
                            'color': Colors.greenAccent,
                          },
                        if (mergedSheets.isNotEmpty)
                          {
                            'idx': 2,
                            'label': '結合シート',
                            'icon': Icons.link_rounded,
                            'color': const Color(0xFF26C6DA),
                          },
                      ];

                      final activeColor =
                          tabs.firstWhere(
                                (t) => t['idx'] == srcTab,
                                orElse: () => tabs.first,
                              )['color']
                              as Color;
                      final bgColor = srcTab == 2
                          ? Colors.cyan.withOpacity(0.04)
                          : srcTab == 1
                          ? Colors.green.withOpacity(0.04)
                          : const Color(0xFF0A1628);

                      return Flexible(
                        flex: 0,
                        child: Container(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // タブバー（複数タブがある場合のみ表示）
                                if (tabs.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      8,
                                    ),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: tabs.map((tab) {
                                          final tIdx = tab['idx'] as int;
                                          final isSel = srcTab == tIdx;
                                          final tColor = tab['color'] as Color;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: GestureDetector(
                                              onTap: () => setDs(() {
                                                // 現在の選択を記憶
                                                _lastCalcIdxPerTab[srcTab] =
                                                    selectedSrcCalcIdx;
                                                _lastSheetIdPerTab[srcTab] =
                                                    selectedSrcSheetId;
                                                _lastFieldPerTab[srcTab] =
                                                    selectedSrcField;
                                                _lastDestsPerTab[srcTab] =
                                                    Set.from(selectedDests);
                                                savePending(); // ペンディングに保存
                                                srcTab = tIdx;
                                                // 新しいタブで以前の選択を復元、なければ最初の式を自動選択
                                                if (_lastCalcIdxPerTab
                                                    .containsKey(tIdx)) {
                                                  selectedSrcCalcIdx =
                                                      _lastCalcIdxPerTab[tIdx];
                                                  selectedSrcSheetId =
                                                      _lastSheetIdPerTab[tIdx];
                                                  selectedSrcField =
                                                      _lastFieldPerTab[tIdx] ??
                                                      'result';
                                                  selectedDests =
                                                      loadPendingOrExisting(
                                                        _lastSheetIdPerTab[tIdx],
                                                        _lastCalcIdxPerTab[tIdx],
                                                        _lastFieldPerTab[tIdx] ??
                                                            'result',
                                                      );
                                                } else if (tIdx == 0) {
                                                  selectedSrcCalcIdx =
                                                      items.isNotEmpty
                                                      ? 0
                                                      : null;
                                                  selectedSrcSheetId = null;
                                                  selectedSrcField = 'result';
                                                  selectedDests =
                                                      loadPendingOrExisting(
                                                        null,
                                                        selectedSrcCalcIdx,
                                                        'result',
                                                      );
                                                } else if (tIdx == 1) {
                                                  // 開放された式：最初の exposed item を選択
                                                  selectedSrcCalcIdx = null;
                                                  selectedSrcSheetId = null;
                                                  selectedSrcField = 'result';
                                                  selectedDests = {};
                                                  for (final cfg
                                                      in exposedSheets) {
                                                    final si =
                                                        (cfg.data['items']
                                                                    as List? ??
                                                                [])
                                                            .asMap()
                                                            .entries
                                                            .where(
                                                              (en) =>
                                                                  (en.value
                                                                      as Map)['exposed'] ==
                                                                  true,
                                                            )
                                                            .toList();
                                                    if (si.isNotEmpty) {
                                                      selectedSrcSheetId =
                                                          cfg.id;
                                                      selectedSrcCalcIdx =
                                                          si.first.key;
                                                      selectedDests =
                                                          loadPendingOrExisting(
                                                            cfg.id,
                                                            si.first.key,
                                                            'result',
                                                          );
                                                      break;
                                                    }
                                                  }
                                                } else if (tIdx == 2) {
                                                  // 結合シート：最初の item を選択
                                                  selectedSrcCalcIdx = null;
                                                  selectedSrcSheetId = null;
                                                  selectedSrcField = 'result';
                                                  selectedDests = {};
                                                  if (mergedSheets.isNotEmpty) {
                                                    final ms =
                                                        mergedSheets.first;
                                                    final si =
                                                        (ms.data['items']
                                                            as List? ??
                                                        []);
                                                    if (si.isNotEmpty) {
                                                      selectedSrcSheetId =
                                                          ms.id;
                                                      selectedSrcCalcIdx = 0;
                                                      selectedDests =
                                                          loadPendingOrExisting(
                                                            ms.id,
                                                            0,
                                                            'result',
                                                          );
                                                    }
                                                  }
                                                }
                                              }),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 150,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isSel
                                                      ? tColor.withOpacity(0.18)
                                                      : Colors.white
                                                            .withOpacity(0.05),
                                                  border: Border.all(
                                                    color: isSel
                                                        ? tColor
                                                        : Colors.white24,
                                                    width: isSel ? 1.5 : 1.0,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(40),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      tab['icon'] as IconData,
                                                      size: 12,
                                                      color: isSel
                                                          ? tColor
                                                          : Colors.white38,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      tab['label'] as String,
                                                      style: TextStyle(
                                                        color: isSel
                                                            ? tColor
                                                            : Colors.white70,
                                                        fontSize: 12,
                                                        fontWeight: isSel
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),

                                Container(
                                  margin: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    0,
                                  ),
                                  width: double.infinity,
                                  constraints: const BoxConstraints(
                                    maxHeight: 200,
                                  ),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    border: Border.all(
                                      color: activeColor.withOpacity(0.4),
                                      //   width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,

                                      children: [
                                        // ── このシート ──
                                        if (srcTab == 0) ...[
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            padding: const EdgeInsets.fromLTRB(
                                              12,
                                              6,
                                              12,
                                              6,
                                            ),
                                            child: Row(
                                              children: (() {
                                                final calcDisplayOrder = _effectiveDisplayOrder
                                                    .where((e) => e['type'] == 'calc')
                                                    .map((e) => e['calcIdx'] as int)
                                                    .toList();
                                                return List.generate(calcDisplayOrder.length, (
                                                  di,
                                                ) {
                                                  final i = calcDisplayOrder[di];
                                                  final calcName =
                                                      items[i]['name']
                                                          as String? ??
                                                      '計算 ${i + 1}';
                                                  final isSel =
                                                      selectedSrcCalcIdx == i &&
                                                      selectedSrcSheetId == null;
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 8,
                                                        ),
                                                    child: GestureDetector(
                                                      onTap: () => setDs(() {
                                                        savePending();
                                                        selectedSrcSheetId = null;
                                                        selectedSrcCalcIdx = i;
                                                        selectedSrcField =
                                                            'result';
                                                        selectedDests =
                                                            loadPendingOrExisting(
                                                              null,
                                                              i,
                                                              'result',
                                                            );
                                                      }),
                                                    child: AnimatedContainer(
                                                      duration: const Duration(
                                                        milliseconds: 150,
                                                      ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 14,
                                                            vertical: 8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: isSel
                                                            ? Colors.blueAccent
                                                                  .withOpacity(
                                                                    0.22,
                                                                  )
                                                            : Colors.white
                                                                  .withOpacity(
                                                                    0.05,
                                                                  ),
                                                        border: Border.all(
                                                          color: isSel
                                                              ? Colors
                                                                    .blueAccent
                                                              : Colors.white24,
                                                          width: isSel
                                                              ? 1.5
                                                              : 1.0,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              30,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        calcName,
                                                        style: TextStyle(
                                                          color: isSel
                                                              ? Colors
                                                                    .blueAccent
                                                              : Colors.white70,
                                                          fontSize: 13,
                                                          fontWeight: isSel
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                    .normal,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                                });
                                              }()),
                                            ),
                                          ),
                                          if (selectedSrcCalcIdx != null &&
                                              selectedSrcSheetId == null) ...[
                                            const Padding(
                                              padding: EdgeInsets.fromLTRB(
                                                12,
                                                0,
                                                12,
                                                4,
                                              ),
                                              child: Text(
                                                '項目を選択',
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    12,
                                                    0,
                                                    12,
                                                    12,
                                                  ),
                                              child: Row(
                                                children: fieldsFor(selectedSrcCalcIdx!).expand((
                                                  sf,
                                                ) {
                                                  final key =
                                                      sf['key'] as String;
                                                  final label =
                                                      sf['label'] as String;
                                                  final op =
                                                      sf['op'] as String?;
                                                  final isSel =
                                                      selectedSrcField == key;
                                                  final valStr = fieldValueStr(
                                                    selectedSrcCalcIdx!,
                                                    key,
                                                  );

                                                  final itemWidget = Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 8,
                                                        ),
                                                    child: GestureDetector(
                                                      onTap: () => setDs(() {
                                                        savePending();
                                                        selectedSrcField = key;
                                                        selectedDests =
                                                            loadPendingOrExisting(
                                                              selectedSrcSheetId,
                                                              selectedSrcCalcIdx,
                                                              key,
                                                            );
                                                      }),
                                                      child: AnimatedContainer(
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 150,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 14,
                                                              vertical: 8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: isSel
                                                              ? Colors
                                                                    .blueAccent
                                                                    .withOpacity(
                                                                      0.22,
                                                                    )
                                                              : Colors.white
                                                                    .withOpacity(
                                                                      0.05,
                                                                    ),
                                                          border: Border.all(
                                                            color: isSel
                                                                ? Colors
                                                                      .blueAccent
                                                                : Colors
                                                                      .white24,
                                                            width: isSel
                                                                ? 1.5
                                                                : 1.0,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              label,
                                                              style: TextStyle(
                                                                color: isSel
                                                                    ? Colors
                                                                          .blueAccent
                                                                    : Colors
                                                                          .white70,
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    isSel
                                                                    ? FontWeight
                                                                          .bold
                                                                    : FontWeight
                                                                          .normal,
                                                              ),
                                                            ),
                                                            //const SizedBox(height: 4),
                                                            Text(
                                                              valStr,
                                                              style: TextStyle(
                                                                color: isSel
                                                                    ? Colors
                                                                          .white
                                                                    : Colors
                                                                          .white70,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                  if (key == 'result') {
                                                    return [
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              right: 8,
                                                            ),
                                                        child: Text(
                                                          '=',
                                                          style: TextStyle(
                                                            color:
                                                                Colors.white54,
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      itemWidget,
                                                    ];
                                                  } else if (op != null) {
                                                    return [
                                                      itemWidget,
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: 8,
                                                            ),
                                                        child: Text(
                                                          op,
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white54,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ),
                                                    ];
                                                  }
                                                  return [itemWidget];
                                                }).toList(),
                                              ),
                                            ),
                                          ],
                                        ],

                                        // ── 開放された式 ──
                                        if (srcTab == 1) ...[
                                          ...exposedSheets.map((cfg) {
                                            final sheetTitle =
                                                cfg.data['title'] as String? ??
                                                cfg.id;
                                            final sheetItems =
                                                (cfg.data['items'] as List? ??
                                                        [])
                                                    .map(
                                                      (e) =>
                                                          Map<
                                                            String,
                                                            dynamic
                                                          >.from(e as Map),
                                                    )
                                                    .toList();
                                            final visibleItems = sheetItems
                                                .asMap()
                                                .entries
                                                .where(
                                                  (en) =>
                                                      en.value['exposed'] ==
                                                      true,
                                                )
                                                .toList();

                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        12,
                                                        4,
                                                        12,
                                                        2,
                                                      ),
                                                  child: Text(
                                                    sheetTitle,
                                                    style: const TextStyle(
                                                      color: Colors.white38,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                                SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        12,
                                                        0,
                                                        12,
                                                        8,
                                                      ),
                                                  child: Row(
                                                    children: visibleItems.map((
                                                      en,
                                                    ) {
                                                      final i = en.key;
                                                      final calcName =
                                                          en.value['name']
                                                              as String? ??
                                                          '計算 ${i + 1}';
                                                      final isSelExt =
                                                          selectedSrcSheetId ==
                                                              cfg.id &&
                                                          selectedSrcCalcIdx ==
                                                              i;
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: 8,
                                                            ),
                                                        child: GestureDetector(
                                                          onTap: () => setDs(() {
                                                            savePending();
                                                            selectedSrcSheetId =
                                                                cfg.id;
                                                            selectedSrcCalcIdx =
                                                                i;
                                                            selectedSrcField =
                                                                'result';
                                                            selectedDests =
                                                                loadPendingOrExisting(
                                                                  cfg.id,
                                                                  i,
                                                                  'result',
                                                                );
                                                          }),
                                                          child: AnimatedContainer(
                                                            duration:
                                                                const Duration(
                                                                  milliseconds:
                                                                      150,
                                                                ),
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      14,
                                                                  vertical: 8,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: isSelExt
                                                                  ? Colors
                                                                        .greenAccent
                                                                        .withOpacity(
                                                                          0.18,
                                                                        )
                                                                  : Colors.white
                                                                        .withOpacity(
                                                                          0.05,
                                                                        ),
                                                              border: Border.all(
                                                                color: isSelExt
                                                                    ? Colors
                                                                          .greenAccent
                                                                    : Colors
                                                                          .white24,
                                                                width: isSelExt
                                                                    ? 1.5
                                                                    : 1.0,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .public_rounded,
                                                                  color:
                                                                      isSelExt
                                                                      ? Colors
                                                                            .greenAccent
                                                                      : Colors
                                                                            .white38,
                                                                  size: 12,
                                                                ),
                                                                const SizedBox(
                                                                  width: 6,
                                                                ),
                                                                Text(
                                                                  calcName,
                                                                  style: TextStyle(
                                                                    color:
                                                                        isSelExt
                                                                        ? Colors
                                                                              .greenAccent
                                                                        : Colors
                                                                              .white70,
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        isSelExt
                                                                        ? FontWeight
                                                                              .bold
                                                                        : FontWeight
                                                                              .normal,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                                if (selectedSrcSheetId !=
                                                        null &&
                                                    selectedSrcCalcIdx !=
                                                        null &&
                                                    cfg.id ==
                                                        selectedSrcSheetId &&
                                                    exposedSheets.any(
                                                      (c) =>
                                                          c.id ==
                                                          selectedSrcSheetId,
                                                    )) ...[
                                                  Divider(
                                                    color: Colors.white12,
                                                  ),
                                                  const Padding(
                                                    padding:
                                                        EdgeInsets.fromLTRB(
                                                          12,
                                                          0,
                                                          12,
                                                          4,
                                                        ),
                                                    child: Text(
                                                      '項目を選択',
                                                      style: TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                          12,
                                                          0,
                                                          12,
                                                          12,
                                                        ),
                                                    child: Row(
                                                      children:
                                                          fieldsForExternal(
                                                            selectedSrcSheetId!,
                                                            selectedSrcCalcIdx!,
                                                          ).expand((sf) {
                                                            final key =
                                                                sf['key']
                                                                    as String;
                                                            final label =
                                                                sf['label']
                                                                    as String;
                                                            final op =
                                                                sf['op']
                                                                    as String?;
                                                            final isSel =
                                                                selectedSrcField ==
                                                                key;
                                                            final valStr =
                                                                fieldValueStr(
                                                                  selectedSrcCalcIdx!,
                                                                  key,
                                                                  selectedSrcSheetId,
                                                                );
                                                            final itemWidget = Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    right: 8,
                                                                  ),
                                                              child: GestureDetector(
                                                                onTap: () => setDs(() {
                                                                  savePending();
                                                                  selectedSrcField =
                                                                      key;
                                                                  selectedDests =
                                                                      loadPendingOrExisting(
                                                                        selectedSrcSheetId,
                                                                        selectedSrcCalcIdx,
                                                                        key,
                                                                      );
                                                                }),
                                                                child: AnimatedContainer(
                                                                  duration:
                                                                      const Duration(
                                                                        milliseconds:
                                                                            150,
                                                                      ),
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            14,
                                                                        vertical:
                                                                            8,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color: isSel
                                                                        ? Colors.greenAccent.withOpacity(
                                                                            0.18,
                                                                          )
                                                                        : Colors.white.withOpacity(
                                                                            0.05,
                                                                          ),
                                                                    border: Border.all(
                                                                      color:
                                                                          isSel
                                                                          ? Colors.greenAccent
                                                                          : Colors.white24,
                                                                      width:
                                                                          isSel
                                                                          ? 1.5
                                                                          : 1.0,
                                                                    ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                  ),
                                                                  child: Column(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      Text(
                                                                        label,
                                                                        style: TextStyle(
                                                                          color:
                                                                              isSel
                                                                              ? Colors.greenAccent
                                                                              : Colors.white70,
                                                                          fontSize:
                                                                              13,
                                                                          fontWeight:
                                                                              isSel
                                                                              ? FontWeight.bold
                                                                              : FontWeight.normal,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            4,
                                                                      ),
                                                                      Text(
                                                                        valStr,
                                                                        style: TextStyle(
                                                                          color:
                                                                              isSel
                                                                              ? Colors.white
                                                                              : Colors.white38,
                                                                          fontSize:
                                                                              11,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                            if (key ==
                                                                'result') {
                                                              return [
                                                                const Padding(
                                                                  padding:
                                                                      EdgeInsets.only(
                                                                        right:
                                                                            8,
                                                                      ),
                                                                  child: Text(
                                                                    '=',
                                                                    style: TextStyle(
                                                                      color: Colors
                                                                          .white54,
                                                                      fontSize:
                                                                          16,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                                itemWidget,
                                                              ];
                                                            } else if (op !=
                                                                null) {
                                                              return [
                                                                itemWidget,
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets.only(
                                                                        right:
                                                                            8,
                                                                      ),
                                                                  child: Text(
                                                                    op,
                                                                    style: const TextStyle(
                                                                      color: Colors
                                                                          .white54,
                                                                      fontSize:
                                                                          16,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ];
                                                            }
                                                            return [itemWidget];
                                                          }).toList(),
                                                    ),
                                                  ),
                                                  Divider(
                                                    color: Colors.white12,
                                                  ),
                                                ],
                                              ],
                                            );
                                          }),
                                        ],

                                        // ── 結合シート ──
                                        if (srcTab == 2) ...[
                                          ...mergedSheets.map((cfg) {
                                            final sheetTitle =
                                                cfg.data['title'] as String? ??
                                                cfg.id;
                                            final sheetItems =
                                                (cfg.data['items'] as List? ??
                                                        [])
                                                    .map(
                                                      (e) =>
                                                          Map<
                                                            String,
                                                            dynamic
                                                          >.from(e as Map),
                                                    )
                                                    .toList();
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        12,
                                                        4,
                                                        12,
                                                        2,
                                                      ),
                                                  child: Text(
                                                    sheetTitle,
                                                    style: const TextStyle(
                                                      color: Colors.white38,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                                SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        12,
                                                        0,
                                                        12,
                                                        8,
                                                      ),
                                                  child: Row(
                                                    children: sheetItems.asMap().entries.map((
                                                      en,
                                                    ) {
                                                      final i = en.key;
                                                      final calcName =
                                                          en.value['name']
                                                              as String? ??
                                                          '計算 ${i + 1}';
                                                      final isSelExt =
                                                          selectedSrcSheetId ==
                                                              cfg.id &&
                                                          selectedSrcCalcIdx ==
                                                              i;
                                                      const chipColor = Color(
                                                        0xFF26C6DA,
                                                      );
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: 8,
                                                            ),
                                                        child: GestureDetector(
                                                          onTap: () => setDs(() {
                                                            savePending();
                                                            selectedSrcSheetId =
                                                                cfg.id;
                                                            selectedSrcCalcIdx =
                                                                i;
                                                            selectedSrcField =
                                                                'result';
                                                            selectedDests =
                                                                loadPendingOrExisting(
                                                                  cfg.id,
                                                                  i,
                                                                  'result',
                                                                );
                                                          }),
                                                          child: AnimatedContainer(
                                                            duration:
                                                                const Duration(
                                                                  milliseconds:
                                                                      150,
                                                                ),
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      14,
                                                                  vertical: 8,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: isSelExt
                                                                  ? chipColor
                                                                        .withOpacity(
                                                                          0.18,
                                                                        )
                                                                  : Colors.white
                                                                        .withOpacity(
                                                                          0.05,
                                                                        ),
                                                              border: Border.all(
                                                                color: isSelExt
                                                                    ? chipColor
                                                                    : Colors
                                                                          .white24,
                                                                width: isSelExt
                                                                    ? 1.5
                                                                    : 1.0,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .link_rounded,
                                                                  color:
                                                                      isSelExt
                                                                      ? chipColor
                                                                      : Colors
                                                                            .white38,
                                                                  size: 12,
                                                                ),
                                                                const SizedBox(
                                                                  width: 6,
                                                                ),
                                                                Text(
                                                                  calcName,
                                                                  style: TextStyle(
                                                                    color:
                                                                        isSelExt
                                                                        ? chipColor
                                                                        : Colors
                                                                              .white70,
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        isSelExt
                                                                        ? FontWeight
                                                                              .bold
                                                                        : FontWeight
                                                                              .normal,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                                if (selectedSrcSheetId !=
                                                        null &&
                                                    selectedSrcCalcIdx !=
                                                        null &&
                                                    selectedSrcSheetId ==
                                                        cfg.id &&
                                                    mergedSheets.any(
                                                      (c) =>
                                                          c.id ==
                                                          selectedSrcSheetId,
                                                    )) ...[
                                                  Divider(
                                                    color: Colors.white12,
                                                  ),
                                                  const Padding(
                                                    padding:
                                                        EdgeInsets.fromLTRB(
                                                          12,
                                                          0,
                                                          12,
                                                          4,
                                                        ),
                                                    child: Text(
                                                      '項目を選択',
                                                      style: TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                          12,
                                                          0,
                                                          12,
                                                          12,
                                                        ),
                                                    child: Row(
                                                      children:
                                                          fieldsForExternal(
                                                            selectedSrcSheetId!,
                                                            selectedSrcCalcIdx!,
                                                          ).expand((sf) {
                                                            final key =
                                                                sf['key']
                                                                    as String;
                                                            final label =
                                                                sf['label']
                                                                    as String;
                                                            final op =
                                                                sf['op']
                                                                    as String?;
                                                            final isSel =
                                                                selectedSrcField ==
                                                                key;
                                                            final valStr =
                                                                fieldValueStr(
                                                                  selectedSrcCalcIdx!,
                                                                  key,
                                                                  selectedSrcSheetId,
                                                                );
                                                            const chipColor =
                                                                Color(
                                                                  0xFF26C6DA,
                                                                );
                                                            final itemWidget = Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    right: 8,
                                                                  ),
                                                              child: GestureDetector(
                                                                onTap: () => setDs(() {
                                                                  savePending();
                                                                  selectedSrcField =
                                                                      key;
                                                                  selectedDests =
                                                                      loadPendingOrExisting(
                                                                        selectedSrcSheetId,
                                                                        selectedSrcCalcIdx,
                                                                        key,
                                                                      );
                                                                }),
                                                                child: AnimatedContainer(
                                                                  duration:
                                                                      const Duration(
                                                                        milliseconds:
                                                                            150,
                                                                      ),
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            14,
                                                                        vertical:
                                                                            8,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color: isSel
                                                                        ? chipColor.withOpacity(
                                                                            0.18,
                                                                          )
                                                                        : Colors.white.withOpacity(
                                                                            0.05,
                                                                          ),
                                                                    border: Border.all(
                                                                      color:
                                                                          isSel
                                                                          ? chipColor
                                                                          : Colors.white24,
                                                                      width:
                                                                          isSel
                                                                          ? 1.5
                                                                          : 1.0,
                                                                    ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                  ),
                                                                  child: Column(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      Text(
                                                                        label,
                                                                        style: TextStyle(
                                                                          color:
                                                                              isSel
                                                                              ? chipColor
                                                                              : Colors.white70,
                                                                          fontSize:
                                                                              13,
                                                                          fontWeight:
                                                                              isSel
                                                                              ? FontWeight.bold
                                                                              : FontWeight.normal,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            4,
                                                                      ),
                                                                      Text(
                                                                        valStr,
                                                                        style: TextStyle(
                                                                          color:
                                                                              isSel
                                                                              ? Colors.white
                                                                              : Colors.white38,
                                                                          fontSize:
                                                                              11,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                            if (key ==
                                                                'result') {
                                                              return [
                                                                const Padding(
                                                                  padding:
                                                                      EdgeInsets.only(
                                                                        right:
                                                                            8,
                                                                      ),
                                                                  child: Text(
                                                                    '=',
                                                                    style: TextStyle(
                                                                      color: Colors
                                                                          .white54,
                                                                      fontSize:
                                                                          16,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                                itemWidget,
                                                              ];
                                                            } else if (op !=
                                                                null) {
                                                              return [
                                                                itemWidget,
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets.only(
                                                                        right:
                                                                            8,
                                                                      ),
                                                                  child: Text(
                                                                    op,
                                                                    style: const TextStyle(
                                                                      color: Colors
                                                                          .white54,
                                                                      fontSize:
                                                                          16,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ];
                                                            }
                                                            return [itemWidget];
                                                          }).toList(),
                                                    ),
                                                  ),

                                                  Divider(
                                                    color: Colors.white12,
                                                  ),
                                                ],
                                              ],
                                            );
                                          }),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  // ── リンク元の「どの式のどの値」ラベル ────────────────
                  if (selectedSrcCalcIdx != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                      child: Builder(
                        builder: (_) {
                          // リンク元のラベルを組み立て
                          String srcName = '';
                          String srcFieldLabel = '';
                          if (selectedSrcSheetId != null) {
                            final srcCfg = widget.allConfigs.firstWhere(
                              (c) => c.id == selectedSrcSheetId,
                              orElse: () => widget.config,
                            );
                            final srcSheetTitle =
                                srcCfg.data['title'] as String? ??
                                selectedSrcSheetId!;
                            final srcItms =
                                (srcCfg.data['items'] as List? ?? [])
                                    .map(
                                      (e) =>
                                          Map<String, dynamic>.from(e as Map),
                                    )
                                    .toList();
                            srcName = selectedSrcCalcIdx! < srcItms.length
                                ? '${srcSheetTitle} / ${srcItms[selectedSrcCalcIdx!]['name'] as String? ?? '計算 ${selectedSrcCalcIdx! + 1}'}'
                                : srcSheetTitle;
                          } else {
                            srcName = selectedSrcCalcIdx! < items.length
                                ? items[selectedSrcCalcIdx!]['name']
                                          as String? ??
                                      '計算 ${selectedSrcCalcIdx! + 1}'
                                : '計算 ${selectedSrcCalcIdx! + 1}';
                          }
                          srcFieldLabel = selectedSrcField == 'result'
                              ? '答え'
                              : selectedSrcField == 'input'
                              ? '項1'
                              : selectedSrcField == 'operand'
                              ? '項2'
                              : selectedSrcField.startsWith('other_')
                              ? '項${(int.tryParse(selectedSrcField.split('_')[1]) ?? 0) + 3}'
                              : selectedSrcField;
                          final srcValStr = fieldValueStr(
                            selectedSrcCalcIdx!,
                            selectedSrcField,
                            selectedSrcSheetId,
                          );
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blueAccent.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.link_rounded,
                                  size: 13,
                                  color: Colors.blueAccent,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '$srcName  $srcFieldLabel  =  $srcValStr',
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 8),
                  // ── リンク先セクション（シアン系） ─────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.download_rounded,
                          size: 14,
                          color: Color(0xFF26C6DA),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'リンク先',
                          style: TextStyle(
                            color: Color(0xFF26C6DA),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '（複数選択可）',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  // ── リンク先シート選択（結合ビューの場合） ─────────
                  if (siblingConfigs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // このシートボタン
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setDs(() => destSheetId = null),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: destSheetId == null
                                        ? const Color(
                                            0xFF26C6DA,
                                          ).withOpacity(0.18)
                                        : Colors.white.withOpacity(0.05),
                                    border: Border.all(
                                      color: destSheetId == null
                                          ? const Color(0xFF26C6DA)
                                          : Colors.white24,
                                      width: destSheetId == null ? 1.5 : 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: Text(
                                    'このシート',
                                    style: TextStyle(
                                      color: destSheetId == null
                                          ? const Color(0xFF26C6DA)
                                          : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: destSheetId == null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // 各兄弟シートボタン
                            ...siblingConfigs.map((sc) {
                              final isSelDest = destSheetId == sc.id;
                              final scTitle =
                                  sc.data['title'] as String? ?? sc.id;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => setDs(() => destSheetId = sc.id),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelDest
                                          ? const Color(
                                              0xFF26C6DA,
                                            ).withOpacity(0.18)
                                          : Colors.white.withOpacity(0.05),
                                      border: Border.all(
                                        color: isSelDest
                                            ? const Color(0xFF26C6DA)
                                            : Colors.white24,
                                        width: isSelDest ? 1.5 : 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(40),
                                    ),
                                    child: Text(
                                      scTitle,
                                      style: TextStyle(
                                        color: isSelDest
                                            ? const Color(0xFF26C6DA)
                                            : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: isSelDest
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color.fromARGB(
                            141,
                            250,
                            250,
                            250,
                          ).withOpacity(0.5),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: selectedSrcCalcIdx == null
                          ? const Center(
                              child: Text(
                                'リンク元の計算式を選択してください',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : Builder(
                              builder: (ctx2) {
                                // 表示するリンク先アイテムを決定
                                final List<Map<String, dynamic>> destItems;
                                if (destSheetId != null) {
                                  final dc = widget.allConfigs.firstWhere(
                                    (c) => c.id == destSheetId,
                                    orElse: () => widget.config,
                                  );
                                  destItems = (dc.data['items'] as List? ?? [])
                                      .map(
                                        (e) =>
                                            Map<String, dynamic>.from(e as Map),
                                      )
                                      .toList();
                                } else {
                                  destItems = _items;
                                }
                                final List<Map<String, dynamic>>
                                destResolvedRows;
                                if (destSheetId != null) {
                                  final dc = widget.allConfigs.firstWhere(
                                    (c) => c.id == destSheetId,
                                    orElse: () => widget.config,
                                  );
                                  final dcConstants =
                                      (dc.data['constants'] as List? ?? [])
                                          .map(
                                            (e) => Map<String, dynamic>.from(
                                              e as Map,
                                            ),
                                          )
                                          .toList();
                                  destResolvedRows = _computeResolvedRows(
                                    destItems,
                                    dcConstants,
                                  );
                                } else {
                                  destResolvedRows = _computeResolvedRows(
                                    items,
                                    _constants,
                                  );
                                }
                                if (destSheetId == null &&
                                    destItems.length <= 1 &&
                                    selectedSrcSheetId == null) {
                                  return const Center(
                                    child: Text(
                                      '他の計算式がありません',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                }
                                // リンク先の表示順: 現在シートは displayOrder に従う
                                final List<int> destCalcOrder;
                                if (destSheetId == null) {
                                  destCalcOrder = _effectiveDisplayOrder
                                      .where((e) => e['type'] == 'calc')
                                      .map((e) => e['calcIdx'] as int)
                                      .toList();
                                } else {
                                  destCalcOrder = List.generate(
                                    destItems.length,
                                    (i) => i,
                                  );
                                }
                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  itemCount: destCalcOrder.length,
                                  itemBuilder: (context, di) {
                                    final i = destCalcOrder[di];
                                    // 同一シート内のリンク元行はスキップ
                                    if (destSheetId == null &&
                                        selectedSrcSheetId == null &&
                                        i == selectedSrcCalcIdx) {
                                      return const SizedBox.shrink();
                                    }
                                    final item = destItems[i];
                                    final rowName =
                                        item['name'] as String? ??
                                        '計算 ${i + 1}';
                                    final itemOthers =
                                        item['others'] as List? ?? [];
                                    // 解決済みの値を取得
                                    final destResolved =
                                        i < destResolvedRows.length
                                        ? destResolvedRows[i]
                                        : <String, dynamic>{};
                                    final resultVal =
                                        destResolved['result'] as double? ??
                                        0.0;
                                    final resolvedOthers =
                                        destResolved['others'] as List? ??
                                        itemOthers;
                                    final destFields = <Map<String, dynamic>>[
                                      {
                                        'key': 'input',
                                        'label': '項1',
                                        'val':
                                            destResolved['input'] as double? ??
                                            (item['input'] as num? ?? 0.0)
                                                .toDouble(),
                                        'op':
                                            item['operator'] as String? ?? '+',
                                      },
                                      {
                                        'key': 'operand',
                                        'label': '項2',
                                        'val':
                                            destResolved['operand']
                                                as double? ??
                                            (item['operand'] as num? ?? 0.0)
                                                .toDouble(),
                                        'op': itemOthers.isNotEmpty
                                            ? ((itemOthers[0]
                                                          as Map)['operator']
                                                      as String? ??
                                                  '+')
                                            : null,
                                      },
                                      ...List.generate(
                                        itemOthers.length,
                                        (j) => {
                                          'key': 'other_$j',
                                          'label': '項${j + 3}',
                                          'val': j < resolvedOthers.length
                                              ? ((resolvedOthers[j]
                                                            as Map)['val']
                                                        as double? ??
                                                    0.0)
                                              : ((itemOthers[j] as Map)['val']
                                                            as num? ??
                                                        0.0)
                                                    .toDouble(),
                                          'op': (j + 1 < itemOthers.length)
                                              ? ((itemOthers[j + 1]
                                                            as Map)['operator']
                                                        as String? ??
                                                    '+')
                                              : null,
                                        },
                                      ),
                                    ];
                                    if (destFields.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    final destPrec =
                                        item['precision'] as int? ?? 2;
                                    String fmtDest(double v) {
                                      if (v == v.truncateToDouble() &&
                                          v.abs() < 1e12) {
                                        return v.toStringAsFixed(0);
                                      }
                                      return v.toStringAsFixed(destPrec);
                                    }

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            10,
                                            12,
                                            4,
                                          ),
                                          child: Text(
                                            rowName,
                                            style: const TextStyle(
                                              color: Color(0xFF26C6DA),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            0,
                                            12,
                                            4,
                                          ),
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              ...destFields.asMap().entries.expand((
                                                en,
                                              ) {
                                                final df = en.value;
                                                final fk = df['key'] as String;
                                                final dk = destSheetId != null
                                                    ? '${destSheetId}__${i}_$fk'
                                                    : '${i}_$fk';
                                                final isSel = selectedDests
                                                    .contains(dk);
                                                String destUnit = '';
                                                if (fk == 'input') {
                                                  destUnit = item['unit1'] as String? ?? '';
                                                } else if (fk == 'operand') {
                                                  destUnit = item['unit2'] as String? ?? '';
                                                } else if (fk.startsWith('other_')) {
                                                  final oIdx = int.tryParse(fk.split('_')[1]) ?? 0;
                                                  final oList = item['others'] as List? ?? [];
                                                  if (oIdx < oList.length) {
                                                    destUnit = (oList[oIdx] as Map)['unit'] as String? ?? '';
                                                  }
                                                }
                                                final valRaw = fmtDest(df['val'] as double? ?? 0.0);
                                                final valStr = destUnit.isNotEmpty ? '$valRaw $destUnit' : valRaw;
                                                final op = df['op'] as String?;

                                                // 既存リンク元ラベルを取得
                                                String existingLinkLabel = '';
                                                String existingLinkLabel2 = '';
                                                Map<String, dynamic>?
                                                existingSrc;
                                                if (fk == 'input' &&
                                                    item['inputLink'] == true) {
                                                  existingSrc =
                                                      item['inputLinkSource']
                                                          as Map<
                                                            String,
                                                            dynamic
                                                          >?;
                                                } else if (fk == 'operand' &&
                                                    item['operandLink'] ==
                                                        true) {
                                                  existingSrc =
                                                      item['operandLinkSource']
                                                          as Map<
                                                            String,
                                                            dynamic
                                                          >?;
                                                } else if (fk.startsWith(
                                                  'other_',
                                                )) {
                                                  final oi =
                                                      int.tryParse(
                                                        fk.split('_')[1],
                                                      ) ??
                                                      0;
                                                  final oth =
                                                      item['others'] as List? ??
                                                      [];
                                                  if (oi < oth.length) {
                                                    final o = oth[oi] as Map;
                                                    if (o['valLink'] == true) {
                                                      existingSrc =
                                                          o['valLinkSource']
                                                              as Map<
                                                                String,
                                                                dynamic
                                                              >?;
                                                    }
                                                  }
                                                }
                                                if (existingSrc != null) {
                                                  final eSid =
                                                      existingSrc['sheetId']
                                                          as String?;
                                                  final eRi =
                                                      existingSrc['rowIdx']
                                                          as int? ??
                                                      0;
                                                  final eTgt =
                                                      existingSrc['target']
                                                          as String? ??
                                                      'result';
                                                  final eTgtLabel =
                                                      eTgt == 'result'
                                                      ? '答え'
                                                      : eTgt == 'input'
                                                      ? '項1'
                                                      : eTgt == 'operand'
                                                      ? '項2'
                                                      : eTgt.startsWith(
                                                          'other_',
                                                        )
                                                      ? '項${(int.tryParse(eTgt.split('_')[1]) ?? 0) + 3}'
                                                      : eTgt;
                                                  if (eSid != null) {
                                                    final eCfg = widget
                                                        .allConfigs
                                                        .firstWhere(
                                                          (c) => c.id == eSid,
                                                          orElse: () =>
                                                              widget.config,
                                                        );
                                                    final eSheetTitle =
                                                        eCfg.data['title']
                                                            as String? ??
                                                        eSid;
                                                    final eItems =
                                                        (eCfg.data['items']
                                                                    as List? ??
                                                                [])
                                                            .map(
                                                              (e) =>
                                                                  Map<
                                                                    String,
                                                                    dynamic
                                                                  >.from(
                                                                    e as Map,
                                                                  ),
                                                            )
                                                            .toList();
                                                    final eRowName =
                                                        eRi < eItems.length
                                                        ? (eItems[eRi]['name']
                                                                  as String? ??
                                                              '計算 ${eRi + 1}')
                                                        : '?';
                                                    existingLinkLabel =
                                                        '$eSheetTitle/$eRowName';
                                                    existingLinkLabel2 =
                                                        '$eTgtLabel';
                                                  } else {
                                                    // 同一シート内リンク
                                                    final eBaseItems =
                                                        destSheetId != null
                                                        ? (widget.allConfigs
                                                                          .firstWhere(
                                                                            (
                                                                              c,
                                                                            ) =>
                                                                                c.id ==
                                                                                destSheetId,
                                                                            orElse: () =>
                                                                                widget.config,
                                                                          )
                                                                          .data['items']
                                                                      as List? ??
                                                                  [])
                                                              .map(
                                                                (e) =>
                                                                    Map<
                                                                      String,
                                                                      dynamic
                                                                    >.from(
                                                                      e as Map,
                                                                    ),
                                                              )
                                                              .toList()
                                                        : items;
                                                    final eRowName =
                                                        eRi < eBaseItems.length
                                                        ? (eBaseItems[eRi]['name']
                                                                  as String? ??
                                                              '計算 ${eRi + 1}')
                                                        : '?';
                                                    existingLinkLabel =
                                                        '$eRowName';
                                                    existingLinkLabel2 =
                                                        '$eTgtLabel';
                                                  }
                                                }

                                                // 選択時に表示するリンク元情報を組み立て
                                                String srcFormulaName = '';
                                                String srcFieldLabel = '';
                                                String srcValDisplay = '';
                                                if (selectedSrcCalcIdx !=
                                                    null) {
                                                  if (selectedSrcSheetId !=
                                                      null) {
                                                    final sCfg = widget
                                                        .allConfigs
                                                        .firstWhere(
                                                          (c) =>
                                                              c.id ==
                                                              selectedSrcSheetId,
                                                          orElse: () =>
                                                              widget.config,
                                                        );
                                                    final sTitle =
                                                        sCfg.data['title']
                                                            as String? ??
                                                        selectedSrcSheetId!;
                                                    final sItms =
                                                        (sCfg.data['items']
                                                                    as List? ??
                                                                [])
                                                            .map(
                                                              (e) =>
                                                                  Map<
                                                                    String,
                                                                    dynamic
                                                                  >.from(
                                                                    e as Map,
                                                                  ),
                                                            )
                                                            .toList();
                                                    final fName =
                                                        selectedSrcCalcIdx! <
                                                            sItms.length
                                                        ? sItms[selectedSrcCalcIdx!]['name']
                                                                  as String? ??
                                                              '計算 ${selectedSrcCalcIdx! + 1}'
                                                        : '計算 ${selectedSrcCalcIdx! + 1}';
                                                    srcFormulaName =
                                                        '$sTitle / $fName';
                                                  } else {
                                                    srcFormulaName =
                                                        selectedSrcCalcIdx! <
                                                            items.length
                                                        ? items[selectedSrcCalcIdx!]['name']
                                                                  as String? ??
                                                              '計算 ${selectedSrcCalcIdx! + 1}'
                                                        : '計算 ${selectedSrcCalcIdx! + 1}';
                                                  }
                                                  srcFieldLabel =
                                                      selectedSrcField ==
                                                          'result'
                                                      ? '答え'
                                                      : selectedSrcField ==
                                                            'input'
                                                      ? '項1'
                                                      : selectedSrcField ==
                                                            'operand'
                                                      ? '項2'
                                                      : selectedSrcField
                                                            .startsWith(
                                                              'other_',
                                                            )
                                                      ? '項${(int.tryParse(selectedSrcField.split('_')[1]) ?? 0) + 3}'
                                                      : selectedSrcField;
                                                  srcValDisplay = fieldValueStr(
                                                    selectedSrcCalcIdx!,
                                                    selectedSrcField,
                                                    selectedSrcSheetId,
                                                  );
                                                }

                                                final itemWidget = GestureDetector(
                                                  onTap: () => setDs(() {
                                                    if (isSel) {
                                                      selectedDests.remove(dk);
                                                    } else {
                                                      selectedDests.add(dk);
                                                    }
                                                  }),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 150,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 8,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isSel
                                                          ? const Color(
                                                              0xFF26C6DA,
                                                            ).withOpacity(0.18)
                                                          : Colors.white
                                                                .withOpacity(
                                                                  0.05,
                                                                ),
                                                      border: Border.all(
                                                        color: isSel
                                                            ? const Color(
                                                                0xFF26C6DA,
                                                              )
                                                            : Colors.white24,
                                                        width: isSel
                                                            ? 1.5
                                                            : 1.0,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            if (isSel)
                                                              const Padding(
                                                                padding:
                                                                    EdgeInsets.only(
                                                                      right: 4,
                                                                    ),
                                                                child: Icon(
                                                                  Icons.check,
                                                                  size: 12,
                                                                  color: Color(
                                                                    0xFF26C6DA,
                                                                  ),
                                                                ),
                                                              ),
                                                            Text(
                                                              df['label']
                                                                  as String,
                                                              style: TextStyle(
                                                                color: isSel
                                                                    ? const Color(
                                                                        0xFF26C6DA,
                                                                      )
                                                                    : Colors
                                                                          .white70,
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    isSel
                                                                    ? FontWeight
                                                                          .bold
                                                                    : FontWeight
                                                                          .normal,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 3,
                                                        ),
                                                        Text(
                                                          valStr,
                                                          style: TextStyle(
                                                            color: isSel
                                                                ? Colors.white
                                                                : Colors
                                                                      .white38,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                        // 選択中：リンク元の式名・項目・値を表示
                                                        if (isSel &&
                                                            srcFormulaName
                                                                .isNotEmpty) ...[
                                                          const SizedBox(
                                                            height: 4,
                                                          ),

                                                          const SizedBox(
                                                            height: 3,
                                                          ),
                                                          Text(
                                                            srcFormulaName,
                                                            style: TextStyle(
                                                              color:
                                                                  const Color(
                                                                    0xFF26C6DA,
                                                                  ).withOpacity(
                                                                    0.85,
                                                                  ),
                                                              fontSize: 9,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          Text(
                                                            '$srcFieldLabel = $srcValDisplay',
                                                            style: TextStyle(
                                                              color:
                                                                  const Color(
                                                                    0xFF26C6DA,
                                                                  ).withOpacity(
                                                                    0.85,
                                                                  ),
                                                              fontSize: 9,
                                                            ),
                                                          ),
                                                          // 未選択で既存リンクあり：リンク元を表示
                                                        ] else if (!isSel &&
                                                            existingLinkLabel
                                                                .isNotEmpty) ...[
                                                          const SizedBox(
                                                            height: 3,
                                                          ),
                                                          Text(
                                                            existingLinkLabel,
                                                            style: TextStyle(
                                                              color:
                                                                  const Color(
                                                                    0xFF26C6DA,
                                                                  ).withOpacity(
                                                                    0.7,
                                                                  ),
                                                              fontSize: 8,
                                                            ),
                                                          ),
                                                          Text(
                                                            existingLinkLabel2,
                                                            style: TextStyle(
                                                              color:
                                                                  const Color(
                                                                    0xFF26C6DA,
                                                                  ).withOpacity(
                                                                    0.7,
                                                                  ),
                                                              fontSize: 8,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                );
                                                if (op != null) {
                                                  return [
                                                    itemWidget,
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 4,
                                                          ),
                                                      child: Text(
                                                        op,
                                                        style: const TextStyle(
                                                          color: Colors.white54,
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ];
                                                }
                                                return [itemWidget];
                                              }),
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                ),
                                                child: Text(
                                                  '=',
                                                  style: TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.02),
                                                  border: Border.all(
                                                    color: Colors.white10,
                                                    width: 1.0,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Text(
                                                      '答え',
                                                      style: TextStyle(
                                                        color: Colors.white38,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      () {
                                                        final unitResult = item['unitResult'] as String? ?? '';
                                                        final resultStr = fmtDest(resultVal);
                                                        return unitResult.isNotEmpty ? '$resultStr $unitResult' : resultStr;
                                                      }(),
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Divider(
                                          color: Colors.white10,
                                          height: 12,
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ── アクションボタン ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            foregroundColor: Colors.white54,
                          ),
                          child: const Text(
                            'キャンセル',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: selectedSrcCalcIdx == null
                              ? null
                              : () {
                                  // 現在の式の選択状態をペンディングに保存
                                  savePending();
                                  Navigator.pop(ctx);
                                  if (_pendingLinks.isEmpty) return;

                                  // 現在シートのアイテムを一度だけ読み込み、
                                  // 全ペンディングを順番に蓄積してから一括適用
                                  var currentItems = _items
                                      .map((e) => Map<String, dynamic>.from(e))
                                      .toList();
                                  final Map<String, List<Map<String, dynamic>>>
                                  sibAcc = {};

                                  for (final op in _pendingLinks) {
                                    final opSid = op['sid'] as String?;
                                    final opIdx = op['calcIdx'] as int;
                                    final opField = op['field'] as String;
                                    final opDests = op['dests'] as Set<String>;

                                    final currentDests = opDests
                                        .where((d) => !d.contains('__'))
                                        .toSet();
                                    final sibDestsMap = <String, Set<String>>{};
                                    for (final d in opDests.where(
                                      (d) => d.contains('__'),
                                    )) {
                                      final sep = d.indexOf('__');
                                      sibDestsMap
                                          .putIfAbsent(
                                            d.substring(0, sep),
                                            () => {},
                                          )
                                          .add(d.substring(sep + 2));
                                    }

                                    // 現在シートへの変更を蓄積
                                    currentItems =
                                        _computeNewItemsWithLinkDests(
                                          currentItems,
                                          opSid,
                                          opIdx,
                                          opField,
                                          currentDests,
                                        );

                                    // 兄弟シートへの変更を蓄積
                                    for (final e in sibDestsMap.entries) {
                                      final sc = widget.allConfigs.firstWhere(
                                        (c) => c.id == e.key,
                                        orElse: () => WidgetConfig(
                                          id: '',
                                          type: '',
                                          data: {},
                                        ),
                                      );
                                      if (sc.id.isEmpty ||
                                          sc.id == widget.config.id) {
                                        continue;
                                      }
                                      final baseSib =
                                          sibAcc[e.key] ??
                                          (sc.data['items'] as List? ?? [])
                                              .map(
                                                (x) =>
                                                    Map<String, dynamic>.from(
                                                      x as Map,
                                                    ),
                                              )
                                              .toList();
                                      sibAcc[e.key] =
                                          _computeSiblingItemsWithLinkDests(
                                            baseSib,
                                            opSid,
                                            opIdx,
                                            opField,
                                            e.value,
                                          );
                                    }
                                  }

                                  // 現在シートを一括適用
                                  widget.onUpdate({
                                    ...widget.config.data,
                                    'items': currentItems,
                                  });
                                  // 兄弟シートを一括適用
                                  for (final e in sibAcc.entries) {
                                    final sc = widget.allConfigs.firstWhere(
                                      (c) => c.id == e.key,
                                      orElse: () => WidgetConfig(
                                        id: '',
                                        type: '',
                                        data: {},
                                      ),
                                    );
                                    if (sc.id.isEmpty ||
                                        sc.id == widget.config.id) {
                                      continue;
                                    }
                                    widget.onSheetUpdate?.call(e.key, {
                                      ...sc.data,
                                      'items': e.value,
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.blueAccent
                                .withOpacity(0.3),
                            disabledForegroundColor: Colors.white38,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'リンクを設定',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 現在シートのアイテムリストにリンク先を適用した新しいリストを返す（副作用なし）
  List<Map<String, dynamic>> _computeNewItemsWithLinkDests(
    List<Map<String, dynamic>> baseItems,
    String? srcSheetId,
    int srcRowIdx,
    String srcField,
    Set<String> selectedDests,
  ) {
    final newItems = baseItems
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final linkSource = srcSheetId != null
        ? {'sheetId': srcSheetId, 'rowIdx': srcRowIdx, 'target': srcField}
        : {'rowIdx': srcRowIdx, 'target': srcField};
    bool wasLinked(Map? src) {
      if (src == null) return false;
      if (srcSheetId != null) {
        return src['sheetId'] == srcSheetId &&
            src['rowIdx'] == srcRowIdx &&
            src['target'] == srcField;
      }
      return src['sheetId'] == null &&
          src['rowIdx'] == srcRowIdx &&
          src['target'] == srcField;
    }

    for (int i = 0; i < newItems.length; i++) {
      if (srcSheetId == null && i == srcRowIdx) continue;
      final item = newItems[i];
      final origItem = Map<String, dynamic>.from(item);

      final inputDest = '${i}_input';
      if (selectedDests.contains(inputDest)) {
        item['inputLink'] = true;
        item['inputLinkSource'] = linkSource;
      } else if (wasLinked(origItem['inputLinkSource'] as Map?)) {
        item['inputLink'] = false;
        item['inputLinkSource'] = null;
      }

      final operandDest = '${i}_operand';
      if (selectedDests.contains(operandDest)) {
        item['operandLink'] = true;
        item['operandLinkSource'] = linkSource;
      } else if (wasLinked(origItem['operandLinkSource'] as Map?)) {
        item['operandLink'] = false;
        item['operandLinkSource'] = null;
      }

      final othersList = ((item['others'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      )).toList();
      final origOthersList = origItem['others'] as List? ?? [];
      for (int j = 0; j < othersList.length; j++) {
        final origO = j < origOthersList.length ? origOthersList[j] as Map : {};
        if (selectedDests.contains('${i}_other_$j')) {
          othersList[j]['valLink'] = true;
          othersList[j]['valLinkSource'] = linkSource;
        } else if (wasLinked(origO['valLinkSource'] as Map?)) {
          othersList[j]['valLink'] = false;
          othersList[j]['valLinkSource'] = null;
        }
      }
      item['others'] = othersList;
    }
    return newItems;
  }

  /// 兄弟シートのアイテムリストにリンク先を適用した新しいリストを返す（副作用なし）
  List<Map<String, dynamic>> _computeSiblingItemsWithLinkDests(
    List<Map<String, dynamic>> sibItems,
    String? srcSheetId,
    int srcRowIdx,
    String srcField,
    Set<String> selectedDests,
  ) {
    final newItems = sibItems.map((e) => Map<String, dynamic>.from(e)).toList();
    final srcId = srcSheetId ?? widget.config.id;
    final linkSource = {
      'sheetId': srcId,
      'rowIdx': srcRowIdx,
      'target': srcField,
    };
    bool wasLinked(Map? src) {
      if (src == null) return false;
      return src['sheetId'] == srcId &&
          src['rowIdx'] == srcRowIdx &&
          src['target'] == srcField;
    }

    for (int i = 0; i < newItems.length; i++) {
      final item = newItems[i];
      final origItem = Map<String, dynamic>.from(item);

      if (selectedDests.contains('${i}_input')) {
        item['inputLink'] = true;
        item['inputLinkSource'] = linkSource;
      } else if (wasLinked(origItem['inputLinkSource'] as Map?)) {
        item['inputLink'] = false;
        item['inputLinkSource'] = null;
      }

      if (selectedDests.contains('${i}_operand')) {
        item['operandLink'] = true;
        item['operandLinkSource'] = linkSource;
      } else if (wasLinked(origItem['operandLinkSource'] as Map?)) {
        item['operandLink'] = false;
        item['operandLinkSource'] = null;
      }

      final othersList = ((item['others'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      )).toList();
      final origOthers = origItem['others'] as List? ?? [];
      for (int j = 0; j < othersList.length; j++) {
        final origO = j < origOthers.length ? origOthers[j] as Map : {};
        if (selectedDests.contains('${i}_other_$j')) {
          othersList[j]['valLink'] = true;
          othersList[j]['valLinkSource'] = linkSource;
        } else if (wasLinked(origO['valLinkSource'] as Map?)) {
          othersList[j]['valLink'] = false;
          othersList[j]['valLinkSource'] = null;
        }
      }
      item['others'] = othersList;
    }
    return newItems;
  }

  /// 兄弟シートのアイテムにリンク先として設定する
  void _applyLinkDestsToSiblingSheet(
    String destSheetId,
    String? srcSheetId,
    int srcRowIdx,
    String srcField,
    Set<String> selectedDests,
  ) {
    final destConfig = widget.allConfigs.firstWhere(
      (c) => c.id == destSheetId,
      orElse: () => widget.config,
    );
    if (destConfig.id == widget.config.id) return;
    final destItems = (destConfig.data['items'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    // リンク元情報（現在シートまたは別シート）
    final linkSource = srcSheetId != null
        ? {'sheetId': srcSheetId, 'rowIdx': srcRowIdx, 'target': srcField}
        : {
            'sheetId': widget.config.id,
            'rowIdx': srcRowIdx,
            'target': srcField,
          };
    bool wasLinked(Map? src) {
      if (src == null) return false;
      final sid = srcSheetId ?? widget.config.id;
      return src['sheetId'] == sid &&
          src['rowIdx'] == srcRowIdx &&
          src['target'] == srcField;
    }

    for (int i = 0; i < destItems.length; i++) {
      final item = destItems[i];
      final origItem = Map<String, dynamic>.from(item);
      final inputDest = '${i}_input';
      if (selectedDests.contains(inputDest)) {
        item['inputLink'] = true;
        item['inputLinkSource'] = linkSource;
      } else if (wasLinked(origItem['inputLinkSource'] as Map?)) {
        item['inputLink'] = false;
        item['inputLinkSource'] = null;
      }
      final operandDest = '${i}_operand';
      if (selectedDests.contains(operandDest)) {
        item['operandLink'] = true;
        item['operandLinkSource'] = linkSource;
      } else if (wasLinked(origItem['operandLinkSource'] as Map?)) {
        item['operandLink'] = false;
        item['operandLinkSource'] = null;
      }
      final othersList = ((item['others'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      )).toList();
      final origOthers = origItem['others'] as List? ?? [];
      for (int j = 0; j < othersList.length; j++) {
        final otherDest = '${i}_other_$j';
        final origO = j < origOthers.length ? origOthers[j] as Map : {};
        if (selectedDests.contains(otherDest)) {
          othersList[j]['valLink'] = true;
          othersList[j]['valLinkSource'] = linkSource;
        } else if (wasLinked(origO['valLinkSource'] as Map?)) {
          othersList[j]['valLink'] = false;
          othersList[j]['valLinkSource'] = null;
        }
      }
      item['others'] = othersList;
    }
    widget.onSheetUpdate?.call(destSheetId, {
      ...destConfig.data,
      'items': destItems,
    });
  }
}
