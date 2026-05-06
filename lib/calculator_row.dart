part of 'widget_page.dart';

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
  final List<Map<String, dynamic>> constants;
  final Function(Map<String, dynamic>) onChanged;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onAdd;
  final VoidCallback onPickBrackets;
  final void Function(List<Map<String, dynamic>>) onAllItemsUpdate;
  final VoidCallback? onInsertBelow;
  final VoidCallback? onInsertMemoBelow;
  final VoidCallback? onToggleName;
  final bool nameVisible;
  final Widget? dragHandle;
  final bool wrapFormula;

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
    this.constants = const [],
    required this.onChanged,
    required this.onDelete,
    required this.onCopy,
    this.onMoveUp,
    this.onMoveDown,
    required this.onAdd,
    required this.onPickBrackets,
    required this.onAllItemsUpdate,
    this.onInsertBelow,
    this.onInsertMemoBelow,
    this.onToggleName,
    this.nameVisible = true,
    this.dragHandle,
    this.wrapFormula = false,
  });

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

  /// 項1を削除：項2が新しい項1に、others[0]が新しい項2に昇格する
  void _removeInput() {
    if (others.isEmpty) return;
    final firstOther = Map<String, dynamic>.from(others.first as Map);
    final newOthers = List<dynamic>.from(others.skip(1));
    final map = _toMap();
    // 項2 → 新しい項1
    map['input'] = operand;
    map['inputLink'] = operandLink;
    map['inputLinkSource'] = operandLinkSource;
    map['inputTransform'] = operandTransform;
    map['inputPowExp'] = operandPowExp;
    map['unit1'] = unit2;
    // others[0] → 新しい項2
    map['op'] = firstOther['op'] ?? '+';
    map['operand'] = (firstOther['val'] as num? ?? 0.0).toDouble();
    map['operandLink'] = firstOther['valLink'] ?? false;
    map['operandLinkSource'] = firstOther['valLinkSource'];
    map['operandTransform'] = firstOther['transform'];
    map['operandPowExp'] = (firstOther['powExp'] as num? ?? 2.0).toDouble();
    map['unit2'] = firstOther['unit'] ?? '';
    map['others'] = newOthers;
    onChanged(map);
  }

  /// 項2を削除：others[0]が新しい項2に昇格する
  void _removeOperand() {
    if (others.isEmpty) return;
    final firstOther = Map<String, dynamic>.from(others.first as Map);
    final newOthers = List<dynamic>.from(others.skip(1));
    final map = _toMap();
    // others[0] → 新しい項2
    map['op'] = firstOther['op'] ?? '+';
    map['operand'] = (firstOther['val'] as num? ?? 0.0).toDouble();
    map['operandLink'] = firstOther['valLink'] ?? false;
    map['operandLinkSource'] = firstOther['valLinkSource'];
    map['operandTransform'] = firstOther['transform'];
    map['operandPowExp'] = (firstOther['powExp'] as num? ?? 2.0).toDouble();
    map['unit2'] = firstOther['unit'] ?? '';
    map['others'] = newOthers;
    onChanged(map);
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
    if (source['type'] == 'constant') {
      final ci = source['constIdx'] as int? ?? 0;
      final name = ci < constants.length ? constants[ci]['name'] as String? ?? '定数' : '定数';
      return '$name（定数）';
    }
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

  /// リンク元の計算行名のみを返す（値ボックス上部ラベル用）
  String _getSourceRowName(Map<String, dynamic>? source) {
    if (source != null && source['type'] == 'constant') {
      final ci = source['constIdx'] as int? ?? 0;
      return ci < constants.length ? constants[ci]['name'] as String? ?? '定数' : '定数';
    }
    if (source == null) {
      if (allItems.isEmpty) return '';
      return (allItems.last as Map)['name'] as String? ??
          '計算 ${allItems.length}';
    }
    final rowIdx = source['rowIdx'] as int? ?? 0;
    if (rowIdx < 0 || rowIdx >= allItems.length) return '';
    return (allItems[rowIdx] as Map)['name'] as String? ?? '計算 ${rowIdx + 1}';
  }

  // ---- リンク先ダイアログ（この行の値を他の行の項目にリンクする） ----
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
    // リンク元候補（この行のフィールド）
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

    // リンク元フィールドの現在値を文字列で返すヘルパー
    String fieldValue(String key) {
      double v;
      if (key == 'input') {
        v = input;
      } else if (key == 'operand') {
        v = operand;
      } else if (key == 'result') {
        v = result;
      } else if (key.startsWith('other_')) {
        final idx = int.tryParse(key.substring(6)) ?? 0;
        if (idx < others.length) {
          v = (others[idx] as Map)['val'] as double? ?? 0.0;
        } else {
          v = 0.0;
        }
      } else {
        v = 0.0;
      }
      if (v == v.truncateToDouble() && v.abs() < 1e12) {
        return v.toStringAsFixed(0);
      }
      return v.toStringAsFixed(precision);
    }

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
            height: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── リンク元セクション（青系） ──────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1628),
                    border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.6),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.upload_rounded,
                              size: 14,
                              color: Colors.blueAccent,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'リンク元',
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '「$name」',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        child: Row(
                          children: srcFields.map((sf) {
                            final key = sf['key'] as String;
                            final label = sf['label'] as String;
                            final sel = selectedSrc == key;
                            final valStr = fieldValue(key);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setDs(() {
                                  selectedSrc = key;
                                  selectedDests = _calcSelectedDests(key);
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? Colors.blueAccent.withOpacity(0.22)
                                        : Colors.white.withOpacity(0.05),
                                    border: Border.all(
                                      color: sel
                                          ? Colors.blueAccent
                                          : Colors.white24,
                                      width: sel ? 1.5 : 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        label,
                                        style: TextStyle(
                                          color: sel
                                              ? Colors.blueAccent
                                              : Colors.white70,
                                          fontSize: 13,
                                          fontWeight: sel
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        valStr,
                                        style: TextStyle(
                                          color: sel
                                              ? Colors.white
                                              : Colors.white38,
                                          fontSize: 11,
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
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ── リンク先セクション（シアン系） ──────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.download_rounded,
                        size: 14,
                        color: Color(0xFF26C6DA),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'リンク先',
                        style: TextStyle(
                          color: Color(0xFF26C6DA),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '（複数選択可）',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    decoration: BoxDecoration(
                     // color: const Color(0xFF071A1A),
                      border: Border.all(
                        color: const Color.fromARGB(141, 250, 250, 250).withOpacity(0.5),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: allItems.length <= 1
                        ? const Center(
                            child: Text(
                              '他の計算式がありません',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: allItems.length,
                            itemBuilder: (context, i) {
                              if (i == myIndex) return const SizedBox.shrink();
                              final item = allItems[i] as Map;
                              final rowName =
                                  item['name'] as String? ?? '計算 ${i + 1}';
                              final itemOthers =
                                  item['others'] as List? ?? [];
                              final destFields = <Map<String, dynamic>>[
                                {
                                  'key': 'input',
                                  'label': '項1',
                                  'val': item['input'] as double? ?? 0.0,
                                },
                                {
                                  'key': 'operand',
                                  'label': '項2',
                                  'val': item['operand'] as double? ?? 0.0,
                                },
                                ...List.generate(
                                  itemOthers.length,
                                  (j) => {
                                    'key': 'other_$j',
                                    'label': '項${j + 3}',
                                    'val': (itemOthers[j] as Map)['val']
                                            as double? ??
                                        0.0,
                                  },
                                ),
                              ];
                              if (destFields.isEmpty) return const SizedBox.shrink();
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(12, 10, 12, 4),
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
                                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: destFields.map((df) {
                                        final fk = df['key'] as String;
                                        final dk = '${i}_$fk';
                                        final isSel = selectedDests.contains(dk);
                                        final valStr = fmtDest(
                                            df['val'] as double? ?? 0.0);
                                        return GestureDetector(
                                          onTap: () => setDs(() {
                                            if (isSel) {
                                              selectedDests.remove(dk);
                                            } else {
                                              selectedDests.add(dk);
                                            }
                                          }),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 150),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isSel
                                                  ? const Color(0xFF26C6DA)
                                                      .withOpacity(0.18)
                                                  : Colors.white
                                                      .withOpacity(0.05),
                                              border: Border.all(
                                                color: isSel
                                                    ? const Color(0xFF26C6DA)
                                                    : Colors.white24,
                                                width: isSel ? 1.5 : 1.0,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (isSel)
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                                right: 4),
                                                        child: Icon(
                                                          Icons.check,
                                                          size: 12,
                                                          color: Color(
                                                              0xFF26C6DA),
                                                        ),
                                                      ),
                                                    Text(
                                                      df['label'] as String,
                                                      style: TextStyle(
                                                        color: isSel
                                                            ? const Color(
                                                                0xFF26C6DA)
                                                            : Colors.white70,
                                                        fontSize: 13,
                                                        fontWeight: isSel
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  valStr,
                                                  style: TextStyle(
                                                    color: isSel
                                                        ? Colors.white
                                                        : Colors.white38,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const Divider(color: Colors.white10, height: 12),
                                ],
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 8),
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
          'リンク設定があります',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text(
          '他の行にリンク中の設定があります。どのように適用しますか？',
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
              'リンクする値以外を適用',
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
                          suffixText: tempLink ? 'リンク中' : null,
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
                // _editInputLinkSection
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
                              'リンク元: ${_getSourceLabel(tempLinkSource)}',
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
                if (constants.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '定数からリンク',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: constants.asMap().entries.map((e) {
                        final ci = e.key;
                        final c = e.value;
                        final name = c['name'] as String? ?? '';
                        final val = (c['value'] as num? ?? 0.0);
                        final isSelected = tempLink &&
                            tempLinkSource != null &&
                            tempLinkSource!['type'] == 'constant' &&
                            tempLinkSource!['constIdx'] == ci;
                        return GestureDetector(
                          onTap: () => setSheetState(() {
                            tempLink = true;
                            tempLinkSource = {'type': 'constant', 'constIdx': ci};
                          }),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.amberAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSelected ? Colors.amberAccent : Colors.white24),
                            ),
                            child: Text('$name = $val', style: TextStyle(color: isSelected ? Colors.amberAccent : Colors.white70, fontSize: 12)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
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
                Row(
                  children: [
                    if (others.isNotEmpty)
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
                          'applyToAll': tempApplyToAll,
                          'delete': false,
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
        _removeInput();
        return;
      }
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
                          suffixText: tempLink ? 'リンク中' : null,
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
                // _editOperandLinkSection
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
                              'リンク元: ${_getSourceLabel(tempLinkSource)}',
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
                if (constants.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '定数からリンク',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: constants.asMap().entries.map((e) {
                        final ci = e.key;
                        final c = e.value;
                        final name = c['name'] as String? ?? '';
                        final val = (c['value'] as num? ?? 0.0);
                        final isSelected = tempLink &&
                            tempLinkSource != null &&
                            tempLinkSource!['type'] == 'constant' &&
                            tempLinkSource!['constIdx'] == ci;
                        return GestureDetector(
                          onTap: () => setSheetState(() {
                            tempLink = true;
                            tempLinkSource = {'type': 'constant', 'constIdx': ci};
                          }),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.amberAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSelected ? Colors.amberAccent : Colors.white24),
                            ),
                            child: Text('$name = $val', style: TextStyle(color: isSelected ? Colors.amberAccent : Colors.white70, fontSize: 12)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
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
                    if (others.isNotEmpty)
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
                          'applyToAll': tempApplyToAll,
                          'delete': false,
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
        _removeOperand();
        return;
      }
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
                          suffixText: tempLink ? 'リンク中' : null,
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
                // _editOtherValLinkSection
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
                              'リンク元: ${_getSourceLabel(tempLinkSource)}',
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
                if (constants.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '定数からリンク',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: constants.asMap().entries.map((e) {
                        final ci = e.key;
                        final c = e.value;
                        final name = c['name'] as String? ?? '';
                        final val = (c['value'] as num? ?? 0.0);
                        final isSelected = tempLink &&
                            tempLinkSource != null &&
                            tempLinkSource!['type'] == 'constant' &&
                            tempLinkSource!['constIdx'] == ci;
                        return GestureDetector(
                          onTap: () => setSheetState(() {
                            tempLink = true;
                            tempLinkSource = {'type': 'constant', 'constIdx': ci};
                          }),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.amberAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSelected ? Colors.amberAccent : Colors.white24),
                            ),
                            child: Text('$name = $val', style: TextStyle(color: isSelected ? Colors.amberAccent : Colors.white70, fontSize: 12)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
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
    if (linkSource['type'] == 'constant') return 2;
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

  Widget _buildToolButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.add_circle_outline_rounded,
            color: Colors.blueAccent.withOpacity(0.6),
            size: 20,
          ),
          tooltip: '項を追加',
          onPressed: onAdd,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 2),
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
            if (onMoveUp != null)
              const PopupMenuItem(
                value: 'move_up',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward_rounded, color: Colors.white70, size: 18),
                    SizedBox(width: 12),
                    Text('上に移動', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            if (onMoveDown != null)
              const PopupMenuItem(
                value: 'move_down',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward_rounded, color: Colors.white70, size: 18),
                    SizedBox(width: 12),
                    Text('下に移動', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            const PopupMenuDivider(height: 1),
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
            const PopupMenuItem(
              value: 'insert_memo_below',
              child: Row(
                children: [
                  Icon(Icons.sticky_note_2_outlined, color: Colors.amber, size: 18),
                  SizedBox(width: 12),
                  Text('メモを追加', style: TextStyle(color: Colors.white, fontSize: 13)),
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
            if (val == 'insert_memo_below') onInsertMemoBelow?.call();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nameVisible || dragHandle != null)
            Padding(
              padding: EdgeInsets.only(bottom: nameVisible ? 12.0 : 4.0),
              child: Row(
                children: [
                  if (dragHandle != null && nameVisible) ...[
                    dragHandle!,
                    const SizedBox(width: 4),
                  ],
                  if (nameVisible) ...[
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
                    _buildToolButtons(context),
                  ] else if (dragHandle != null)
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
          if (wrapFormula)
            Wrap(
              spacing: 8,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
  if (dragHandle != null && !nameVisible) ...[
                    dragHandle!,
                    const SizedBox(width: 4),
                  ],
                // 項1 グループ
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
                  ],
                ),
                // 演算子
                GestureDetector(
                  onTapDown: (details) => _pickOp(context, details.globalPosition),
                  onLongPress: others.isNotEmpty ? () => _removeOperand() : null,
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
                // 項2 グループ
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
                  ],
                ),
                // 追加の項
                ...others.asMap().entries.map((e) {
                  final idx = e.key;
                  final other = e.value as Map;
                  final otherOp = other['op'] as String? ?? '+';
                  final otherVal = (other['val'] as num? ?? 0.0).toDouble();
                  final otherUnit = other['unit'] as String? ?? '';
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
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
                      const SizedBox(width: 8),
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
                // = と答え
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '=',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black26,
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildValueBox(
                      value: result.toStringAsFixed(precision),
                      unit: unitResult,
                      fontSize: 18,
                      onTapDown: (details) => _editResultProperties(context, details.globalPosition),
                    ),
                  ],
                ),
                if (!nameVisible) _buildToolButtons(context),
              ],
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
if (dragHandle != null && !nameVisible) ...[
                    dragHandle!,
                    const SizedBox(width: 4),
                  ],
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
                    onLongPress: others.isNotEmpty ? () => _removeOperand() : null,
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

                  if (!nameVisible) ...[
                    const SizedBox(width: 12),
                    _buildToolButtons(context),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

