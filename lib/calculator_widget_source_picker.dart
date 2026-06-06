part of 'widget_page.dart';

extension CalculatorWidgetSourcePicker on _CalculatorWidgetState {
  Future<Map<String, dynamic>?> _showLinkSourcePicker({
    int? excludeRowIdx,
  }) async {
    final exposedSheets = widget.allConfigs
        .where((c) => c.id != widget.config.id && c.type == 'calculator')
        .toList();

    final mergedSheets = widget.allConfigs.where((c) {
      if (c.id == widget.config.id) return false;
      if (c.type != 'calculator') return false;
      return widget.mergedSiblingIds.contains(c.id);
    }).toList();

    int currentTab = 0; // 0=このシート, 1=開放された式, 2=結合シート, 3=定数
    String? selectedSheetId;
    int? selectedRowIdx;
    String? selectedField;
    int? selectedConstIdx; // 定数タブ用
    bool selectedConstIsGlobal = false; // true=グローバル定数, false=シート定数

    return showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Widget buildFieldChip(
              String fieldKey,
              String label,
              String? sheetId,
              int calcIdx,
              String unit,
            ) {
              bool isSel =
                  selectedSheetId == sheetId &&
                  selectedRowIdx == calcIdx &&
                  selectedField == fieldKey;

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
              String valStr = '';
              if (v == v.truncateToDouble() && v.abs() < 1e12) {
                valStr = v.toStringAsFixed(0);
              } else {
                valStr = v.toStringAsFixed(precision);
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedSheetId = sheetId;
                    selectedRowIdx = calcIdx;
                    selectedField = fieldKey;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSel ? Colors.blueAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel ? Colors.blueAccent : Colors.white24,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: isSel ? Colors.white70 : Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            valStr,
                            style: TextStyle(
                              color: isSel ? Colors.white : Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (unit.isNotEmpty) ...[
                            const SizedBox(width: 2),
                            Text(
                              unit,
                              style: TextStyle(
                                color: isSel ? Colors.white70 : Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            Widget buildFormulaRow(
              String? sheetId,
              int idx,
              String op,
              List<Map<String, dynamic>> others,
              Map<String, dynamic> item,
            ) {
              final opStyle = const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              );
              return Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    buildFieldChip(
                      'input',
                      '項1',
                      sheetId,
                      idx,
                      item['unit1'] as String? ?? '',
                    ),
                    Text(op, style: opStyle),
                    buildFieldChip(
                      'operand',
                      '項2',
                      sheetId,
                      idx,
                      item['unit2'] as String? ?? '',
                    ),
                    for (int oi = 0; oi < others.length; oi++) ...[
                      Text(others[oi]['op'] as String? ?? '+', style: opStyle),
                      buildFieldChip(
                        'other_$oi',
                        '項${oi + 3}',
                        sheetId,
                        idx,
                        others[oi]['unit'] as String? ?? '',
                      ),
                    ],
                    const Text(
                      '=',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    buildFieldChip(
                      'result',
                      '答え',
                      sheetId,
                      idx,
                      item['unitResult'] as String? ?? '',
                    ),
                  ],
                ),
              );
            }

            Widget buildSheetList(List<dynamic> sheets, bool isMerged) {
              // 開放された式が1件以上あるシートのみ対象にする
              final visibleSheets = sheets.where((sheet) {
                final allItems = (sheet.data['items'] as List<dynamic>? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
                final exposedEntries = allItems
                    .asMap()
                    .entries
                    .where((e) => isMerged || e.value['exposed'] == true)
                    .toList();
                return exposedEntries.isNotEmpty;
              }).toList();

              if (visibleSheets.isEmpty) {
                return const Center(
                  child: Text(
                    'リンク可能なシートがありません',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: visibleSheets.length,
                itemBuilder: (context, i) {
                  final sheet = visibleSheets[i];
                  final allItems = (sheet.data['items'] as List<dynamic>? ?? [])
                      .map((e) => Map<String, dynamic>.from(e as Map))
                      .toList();
                  final exposedEntries = allItems
                      .asMap()
                      .entries
                      .where((e) => isMerged || e.value['exposed'] == true)
                      .toList();
                  final title = sheet.data['title'] as String? ?? '名称未設定シート';

                  return ExpansionTile(
                    title: Text(
                      title,
                      style: const TextStyle(color: Colors.white),
                    ),
                    iconColor: Colors.white54,
                    collapsedIconColor: Colors.white54,
                    children: exposedEntries.map((e) {
                      final idx = e.key;
                      final item = e.value;
                      final rowName =
                          item['name'] as String? ?? '計算 ${idx + 1}';
                      final op = item['op'] as String? ?? '+';
                      final others = (item['others'] as List? ?? [])
                          .map((o) => Map<String, dynamic>.from(o as Map))
                          .toList();
                      final isSelRow =
                          selectedSheetId == sheet.id && selectedRowIdx == idx;
                      return SizedBox(
                        width: double.infinity,
                        child: Container(
                          margin: const EdgeInsets.only(
                            bottom: 8,
                            left: 8,
                            right: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(
                              isSelRow ? 0.1 : 0.05,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelRow
                                  ? Colors.blueAccent
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  rowName,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              buildFormulaRow(sheet.id, idx, op, others, item),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            }

            Widget buildCurrentSheet() {
              final items = _items;
              if (items.isEmpty) {
                return const Center(
                  child: Text(
                    '計算式がありません',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: items.length,
                itemBuilder: (context, idx) {
                  if (idx == excludeRowIdx) return const SizedBox.shrink();
                  final item = items[idx];
                  final rowName = item['name'] as String? ?? '計算 ${idx + 1}';
                  final op = item['op'] as String? ?? '+';
                  final others = (item['others'] as List? ?? [])
                      .map((o) => Map<String, dynamic>.from(o as Map))
                      .toList();
                  final isSelRow =
                      selectedSheetId == null && selectedRowIdx == idx;
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(isSelRow ? 0.1 : 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelRow
                            ? Colors.blueAccent
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            rowName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        buildFormulaRow(null, idx, op, others, item),
                      ],
                    ),
                  );
                },
              );
            }

            // 定数タブ: シート定数 + グローバル定数一覧
            Widget buildConstantsTab() {
              final localConsts = _constants;
              final globalConsts = widget.globalConstants;
              if (localConsts.isEmpty && globalConsts.isEmpty) {
                return const Center(
                  child: Text(
                    'リンク可能な定数がありません',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              Widget buildConstItem(
                int i,
                Map<String, dynamic> c,
                bool isGlobal,
              ) {
                final name = c['name'] as String? ?? '定数 ${i + 1}';
                final value = (c['value'] as num? ?? 0.0).toDouble();
                final valStr =
                    value == value.truncateToDouble() && value.abs() < 1e12
                    ? value.toStringAsFixed(0)
                    : value.toString();
                final isSel =
                    selectedConstIdx == i &&
                    selectedConstIsGlobal == isGlobal;
                return GestureDetector(
                  onTap: () => setState(() {
                    selectedConstIdx = i;
                    selectedConstIsGlobal = isGlobal;
                    selectedRowIdx = null;
                    selectedField = null;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(isSel ? 0.1 : 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSel
                            ? Colors.blueAccent
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          valStr,
                          style: TextStyle(
                            color: isSel ? Colors.white : Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  if (localConsts.isNotEmpty) ...
                    [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6, top: 4),
                        child: Text(
                          'シート定数',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      ...localConsts.asMap().entries.map(
                        (e) => buildConstItem(e.key, e.value, false),
                      ),
                    ],
                  if (globalConsts.isNotEmpty) ...
                    [
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: 6,
                          top: localConsts.isNotEmpty ? 12 : 4,
                        ),
                        child: const Text(
                          'グローバル定数',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      ...globalConsts.asMap().entries.map(
                        (e) => buildConstItem(e.key, e.value, true),
                      ),
                    ],
                ],
              );
            }

            return Dialog(
              insetPadding: const EdgeInsets.all(20),
              backgroundColor: const Color(0xFF161622),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'リンク元を選択',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => setState(() => currentTab = 0),
                            child: Text(
                              'このシート',
                              style: TextStyle(
                                color: currentTab == 0
                                    ? Colors.blueAccent
                                    : Colors.white54,
                              ),
                            ),
                          ),
                          if (exposedSheets.isNotEmpty) ...[
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => setState(() => currentTab = 1),
                              child: Text(
                                '開放された式',
                                style: TextStyle(
                                  color: currentTab == 1
                                      ? Colors.blueAccent
                                      : Colors.white54,
                                ),
                              ),
                            ),
                          ],
                          if (mergedSheets.isNotEmpty) ...[
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => setState(() => currentTab = 2),
                              child: Text(
                                '結合シート',
                                style: TextStyle(
                                  color: currentTab == 2
                                      ? Colors.blueAccent
                                      : Colors.white54,
                                ),
                              ),
                            ),
                          ],
                          if (_constants.isNotEmpty || widget.globalConstants.isNotEmpty) ...[
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => setState(() => currentTab = 3),
                              child: Text(
                                '定数',
                                style: TextStyle(
                                  color: currentTab == 3
                                      ? Colors.blueAccent
                                      : Colors.white54,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: currentTab == 0
                          ? buildCurrentSheet()
                          : currentTab == 1
                          ? buildSheetList(exposedSheets, false)
                          : currentTab == 2
                          ? buildSheetList(mergedSheets, true)
                          : buildConstantsTab(),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'キャンセル',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: (selectedRowIdx == null &&
                                    selectedConstIdx == null)
                                ? null
                                : () {
                                    if (selectedConstIdx != null) {
                                      if (selectedConstIsGlobal) {
                                        final name = widget
                                                .globalConstants[selectedConstIdx!]
                                                ['name'] as String? ??
                                            '';
                                        Navigator.of(context).pop({
                                          'type': 'globalConstant',
                                          'constName': name,
                                          'constIdx': selectedConstIdx,
                                        });
                                      } else {
                                        Navigator.of(context).pop({
                                          'type': 'constant',
                                          'constIdx': selectedConstIdx,
                                        });
                                      }
                                    } else {
                                      Navigator.of(context).pop({
                                        'type': 'calc',
                                        'sheetId':
                                            selectedSheetId ?? widget.config.id,
                                        'rowIdx': selectedRowIdx,
                                        'target': selectedField,
                                      });
                                    }
                                  },
                            child: const Text('決定'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
