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
  final VoidCallback? onCut;
  final VoidCallback? onPaste;
  final bool hasClipboard;
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
  /// 表モードのカスタム列ラベル (key: 'input'/'operand'/'other_N'/'result', value: label)
  final Map<String, String>? termLabels;
  /// 他のシートに開放中かどうか
  final bool exposed;
  /// 開放状態をトグルするコールバック
  final VoidCallback? onToggleExpose;

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
    this.onCut,
    this.onPaste,
    this.hasClipboard = false,
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
    this.wrapFormula = true,
    this.termLabels,
    this.exposed = false,
    this.onToggleExpose,
  });

  /// termLabels 優先、なければデフォルト
  String _termLabel(String key) {
    final custom = termLabels?[key];
    if (custom != null && custom.isNotEmpty) return custom;
    if (key == 'input') return '項1';
    if (key == 'operand') return '項2';
    if (key == 'result') return '答え';
    if (key.startsWith('other_')) {
      final i = int.tryParse(key.split('_')[1]) ?? 0;
      return '項${i + 3}';
    }
    return key;
  }

  void _showMiniCalcSheet(
    BuildContext context,
    void Function(double) onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:Colors.black,
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
      backgroundColor: Colors.black,
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
        backgroundColor: Colors.black,
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
      fieldLabel = _termLabel('result');
    } else if (target == 'input') {
      fieldLabel = _termLabel('input');
    } else if (target == 'operand') {
      fieldLabel = _termLabel('operand');
    } else if (target.startsWith('other_')) {
      final idx = int.tryParse(target.split('_')[1]) ?? 0;
      fieldLabel = _termLabel('other_$idx');
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
        backgroundColor: Colors.black,
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
      backgroundColor: Colors.black,
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
      case 'sin':
        return math.sin(v);
      case 'cos':
        return math.cos(v);
      case 'tan':
        return math.tan(v);
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
      case 'sin':
        return Colors.blueAccent;
      case 'cos':
        return Colors.orangeAccent;
      case 'tan':
        return Colors.yellowAccent;
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
      case 'sin':
        return 'sin($valStr)';
      case 'cos':
        return 'cos($valStr)';
      case 'tan':
        return 'tan($valStr)';
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
      case 'sin':
        return Text('sin(', style: ts(13));
      case 'cos':
        return Text('cos(', style: ts(13));
      case 'tan':
        return Text('tan(', style: ts(13));
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
      case 'sin':
      case 'cos':
      case 'tan':
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
      backgroundColor: Colors.black,
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
                        '${_termLabel('input')}の設定',
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
                        readOnly: tempLink,
                        decoration: InputDecoration(
                          hintText: '0.0',
                          hintStyle: const TextStyle(color: Colors.white24),
                          suffix: tempLink
                              ? GestureDetector(
                                  onTap: () => setSheetState(() => tempLink = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                                    ),
                                    child: const Text(
                                      'リンク中',
                                      style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                )
                              : null,
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
                if (tempLink || tempLinkSource != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: (tempLink ? Colors.blueAccent : Colors.orangeAccent).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (tempLink ? Colors.blueAccent : Colors.orangeAccent).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            tempLink ? Icons.link : Icons.link_off,
                            size: 14,
                            color: tempLink ? Colors.blueAccent : Colors.orangeAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tempLink
                                  ? 'リンク元: ${_getSourceLabel(tempLinkSource)}'
                                  : '元リンク: ${_getSourceLabel(tempLinkSource)}',
                              style: TextStyle(
                                color: tempLink ? Colors.blueAccent : Colors.orangeAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (tempLink)
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
                            )
                          else
                            GestureDetector(
                              onTap: () => setSheetState(() => tempLink = true),
                              child: const Text(
                                'リンクに戻す',
                                style: TextStyle(
                                  color: Colors.blueAccent,
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
                        ['sin', 'sin'],
                        ['cos', 'cos'],
                        ['tan', 'tan'],
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
      backgroundColor: Colors.black,
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
                        '${_termLabel('operand')}の設定',
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
                        readOnly: tempLink,
                        decoration: InputDecoration(
                          hintText: '0.0',
                          hintStyle: const TextStyle(color: Colors.white24),
                          suffix: tempLink
                              ? GestureDetector(
                                  onTap: () => setSheetState(() => tempLink = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                                    ),
                                    child: const Text(
                                      'リンク中',
                                      style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                )
                              : null,
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
                if (tempLink || tempLinkSource != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: (tempLink ? Colors.blueAccent : Colors.orangeAccent).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (tempLink ? Colors.blueAccent : Colors.orangeAccent).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            tempLink ? Icons.link : Icons.link_off,
                            size: 14,
                            color: tempLink ? Colors.blueAccent : Colors.orangeAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tempLink
                                  ? 'リンク元: ${_getSourceLabel(tempLinkSource)}'
                                  : '元リンク: ${_getSourceLabel(tempLinkSource)}',
                              style: TextStyle(
                                color: tempLink ? Colors.blueAccent : Colors.orangeAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (tempLink)
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
                            )
                          else
                            GestureDetector(
                              onTap: () => setSheetState(() => tempLink = true),
                              child: const Text(
                                'リンクに戻す',
                                style: TextStyle(
                                  color: Colors.blueAccent,
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
                        ['sin', 'sin'],
                        ['cos', 'cos'],
                        ['tan', 'tan'],
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
      color:Colors.black,
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
      backgroundColor:Colors.black,
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
                        '${_termLabel('other_$idx')}の設定',
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
                        readOnly: tempLink,
                        decoration: InputDecoration(
                          hintText: '0.0',
                          hintStyle: const TextStyle(color: Colors.white24),
                          suffix: tempLink
                              ? GestureDetector(
                                  onTap: () => setSheetState(() => tempLink = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                                    ),
                                    child: const Text(
                                      'リンク中',
                                      style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                )
                              : null,
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
                if (tempLink || tempLinkSource != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: (tempLink ? Colors.blueAccent : Colors.orangeAccent).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (tempLink ? Colors.blueAccent : Colors.orangeAccent).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            tempLink ? Icons.link : Icons.link_off,
                            size: 14,
                            color: tempLink ? Colors.blueAccent : Colors.orangeAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tempLink
                                  ? 'リンク元: ${_getSourceLabel(tempLinkSource)}'
                                  : '元リンク: ${_getSourceLabel(tempLinkSource)}',
                              style: TextStyle(
                                color: tempLink ? Colors.blueAccent : Colors.orangeAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (tempLink)
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
                            )
                          else
                            GestureDetector(
                              onTap: () => setSheetState(() => tempLink = true),
                              child: const Text(
                                'リンクに戻す',
                                style: TextStyle(
                                  color: Colors.blueAccent,
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
                        ['sin', 'sin'],
                        ['cos', 'cos'],
                        ['tan', 'tan'],
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

    // ── 計算式の詳細を構築 ──────────────────────────────────────────────────
    String fmtV(double v, int prec) {
      if (v.isNaN || v.isInfinite) return '0';
      if (v == v.truncateToDouble() && v.abs() < 1e12) return v.toInt().toString();
      return v.toStringAsFixed(prec);
    }
    String termStr(double rawV, String? transform, double powExp, int prec) {
      final s = fmtV(rawV, prec);
      if (transform == null) return s;
      switch (transform) {
        case 'sqrt': return '√$s';
        case 'pow':
          final e = powExp == powExp.truncateToDouble() ? powExp.toInt().toString() : fmtV(powExp, 1);
          return '$s^$e';
        case 'nroot':
          final e = powExp == powExp.truncateToDouble() ? powExp.toInt().toString() : fmtV(powExp, 1);
          return '${e}√$s';
        case 'abs': return '|$s|';
        case 'floor': return '⌊$s⌋';
        case 'ceil': return '⌈$s⌉';
        case 'round': return '≈$s';
        case 'log10': return 'log($s)';
        case 'reciprocal': return '1/$s';
        case 'sin': return 'sin($s)';
        case 'cos': return 'cos($s)';
        case 'tan': return 'tan($s)';
        default: return s;
      }
    }
    // リンク値を解決するヘルパー
    double resolveLinkedVal(double rawVal, bool isLink, Map<String, dynamic>? source) {
      if (!isLink) return rawVal;
      if (source == null) {
        return allResults.isNotEmpty ? allResults.last : rawVal;
      }
      if (source['type'] == 'constant') {
        final constIdx = source['constIdx'] as int? ?? 0;
        if (constIdx >= 0 && constIdx < constants.length) {
          return (constants[constIdx]['value'] as num? ?? 0.0).toDouble();
        }
        return rawVal;
      }
      final rowIdx = source['rowIdx'] as int? ?? 0;
      final target = source['target'] as String? ?? 'result';
      if (rowIdx < 0 || rowIdx >= allItems.length) return rawVal;
      if (target == 'result' && rowIdx < allResults.length) return allResults[rowIdx];
      if (target == 'input') return (allItems[rowIdx] as Map)['input'] as double? ?? rawVal;
      if (target == 'operand') return (allItems[rowIdx] as Map)['operand'] as double? ?? rawVal;
      if (target.startsWith('other_')) {
        final idx = int.tryParse(target.split('_')[1]) ?? 0;
        final oList = (allItems[rowIdx] as Map)['others'] as List? ?? [];
        if (idx < oList.length) return (oList[idx] as Map)['val'] as double? ?? rawVal;
      }
      return rawVal;
    }

    final resolvedInput = resolveLinkedVal(input, inputLink, inputLinkSource);
    final resolvedOperand = resolveLinkedVal(operand, operandLink, operandLinkSource);

    final formulaParts = <_FormulaLine>[];
    formulaParts.add(_FormulaLine(
      label: _termLabel('input'),
      value: termStr(resolvedInput, inputTransform, inputPowExp, precision),
      unit: unit1,
      op: null,
      isLink: inputLink,
      linkLabel: inputLink ? _getSourceRowName(inputLinkSource) : '',
    ));
    formulaParts.add(_FormulaLine(
      label: _termLabel('operand'),
      value: termStr(resolvedOperand, operandTransform, operandPowExp, precision),
      unit: unit2,
      op: op,
      isLink: operandLink,
      linkLabel: operandLink ? _getSourceRowName(operandLinkSource) : '',
    ));
    for (int i = 0; i < others.length; i++) {
      final o = others[i] as Map;
      final oVal = (o['val'] as num? ?? 0.0).toDouble();
      final oLink = o['valLink'] as bool? ?? false;
      final oSource = o['valLinkSource'] as Map<String, dynamic>?;
      final resolvedOVal = resolveLinkedVal(oVal, oLink, oSource);
      final oOp = o['op'] as String? ?? '+';
      final oTransform = o['transform'] as String?;
      final oPowExp = (o['powExp'] as num? ?? 2.0).toDouble();
      final oUnit = o['unit'] as String? ?? '';
      formulaParts.add(_FormulaLine(
        label: _termLabel('other_$i'),
        value: termStr(resolvedOVal, oTransform, oPowExp, precision),
        unit: oUnit,
        op: oOp,
        isLink: oLink,
        linkLabel: oLink ? _getSourceRowName(oSource) : '',
      ));
    }
    final resultStr = fmtV(result, precision);
    // ───────────────────────────────────────────────────────────────────────

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:Colors.black,
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
                    Expanded(
                      child: Text(
                        name.isNotEmpty ? name : '答えの設定',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
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
                // ── 計算式の詳細 ──────────────────────────────────────────
                const Text(
                  '計算式の詳細',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      ...formulaParts.asMap().entries.map((entry) {
                        final line = entry.value;
                        final isLast = entry.key == formulaParts.length - 1;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 演算子列
                              SizedBox(
                                width: 28,
                                child: line.op != null
                                    ? Text(
                                        line.op!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.orangeAccent,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      )
                                    : const SizedBox(),
                              ),
                              const SizedBox(width: 8),
                              // ラベル列
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (line.isLink && line.linkLabel.isNotEmpty)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.link_rounded,
                                            size: 9,
                                            color: Colors.blueAccent,
                                          ),
                                          const SizedBox(width: 2),
                                          Flexible(
                                            child: Text(
                                              line.linkLabel,
                                              style: const TextStyle(
                                                color: Colors.blueAccent,
                                                fontSize: 9,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    Text(
                                      line.label,
                                      style: TextStyle(
                                        color: line.isLink
                                            ? Colors.blueAccent.withOpacity(0.7)
                                            : Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 値列
                              Expanded(
                                flex: 4,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (line.isLink)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Icon(
                                          Icons.link_rounded,
                                          size: 12,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    Flexible(
                                      child: Text(
                                        line.value +
                                            (line.unit.isNotEmpty
                                                ? ' ${line.unit}'
                                                : ''),
                                        textAlign: TextAlign.right,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: line.isLink
                                              ? Colors.blueAccent.withOpacity(0.9)
                                              : Colors.white70,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      // 答え行
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(14)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 28,
                              child: Text(
                                '=',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '答え',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                resultStr +
                                    (unitResult.isNotEmpty
                                        ? ' $unitResult'
                                        : ''),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // ── 小数点以下の桁数 ──────────────────────────────────────
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
          color:Colors.black,
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
                  Icon(Icons.copy_rounded, color: Colors.blueAccent, size: 18),
                  SizedBox(width: 12),
                  Text('コピー', style: TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'cut',
              child: Row(
                children: [
                  Icon(Icons.content_cut_rounded, color: Colors.orangeAccent, size: 18),
                  SizedBox(width: 12),
                  Text('移動（切り取り）', style: TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
            if (hasClipboard)
              const PopupMenuItem(
                value: 'paste',
                child: Row(
                  children: [
                    Icon(Icons.content_paste_rounded, color: Colors.greenAccent, size: 18),
                    SizedBox(width: 12),
                    Text('コピーした計算を追加', style: TextStyle(color: Colors.white, fontSize: 13)),
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
            const PopupMenuDivider(height: 1),
            PopupMenuItem(
              value: 'expose',
              child: Row(
                children: [
                  Icon(
                    exposed ? Icons.public_off_rounded : Icons.public_rounded,
                    color: exposed ? Colors.orangeAccent : Colors.greenAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    exposed ? '他シートへの開放を解除' : '他のシートに開放する',
                    style: TextStyle(
                      color: exposed ? Colors.orangeAccent : Colors.greenAccent,
                      fontSize: 13,
                    ),
                  ),
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
            if (val == 'cut') onCut?.call();
            if (val == 'paste') onPaste?.call();
            if (val == 'brackets') onPickBrackets();
            if (val == 'move_up') onMoveUp?.call();
            if (val == 'move_down') onMoveDown?.call();
            if (val == 'toggle_name') onToggleName?.call();
            if (val == 'insert_below') onInsertBelow?.call();
            if (val == 'insert_memo_below') onInsertMemoBelow?.call();
            if (val == 'expose') onToggleExpose?.call();
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
                        child: Row(
                          children: [
                            if (exposed)
                              const Padding(
                                padding: EdgeInsets.only(right: 5),
                                child: Icon(
                                  Icons.public_rounded,
                                  color: Colors.greenAccent,
                                  size: 13,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                name.isEmpty ? '名称未設定' : name,
                                style: TextStyle(
                                  color: isDark ? Colors.white.withOpacity(0.9) : Colors.black,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
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

// ── 計算式詳細の行データ ───────────────────────────────────────────────────────
class _FormulaLine {
  final String label;
  final String value;
  final String unit;
  final String? op;
  final bool isLink;
  final String linkLabel;

  const _FormulaLine({
    required this.label,
    required this.value,
    required this.unit,
    required this.op,
    this.isLink = false,
    this.linkLabel = '',
  });
}

