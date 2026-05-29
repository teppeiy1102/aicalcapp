part of 'widget_page.dart';

// ---- 定型計算ウィジェット ----
class _CalculatorWidget extends StatefulWidget {
  final WidgetConfig config;
  final void Function(Map<String, dynamic>) onUpdate;
  final VoidCallback onDuplicate;
  final bool showToolbar;
  final bool showHeader;
  final EdgeInsetsGeometry? contentPadding;

  /// AI生成中フラグが変化したときに通知するコールバック
  final void Function(bool isGenerating)? onAiGeneratingChanged;

  /// ホームのSettings画面で管理するユーザー定義定数
  final List<Map<String, dynamic>> globalConstants;

  /// アプリ内クリップボード（シートをまたいで共有）
  final ValueNotifier<Map<String, dynamic>?>? clipboardNotifier;

  /// 全シートの設定（シート間リンク用）
  final List<WidgetConfig> allConfigs;

  /// 結合ビュー内の兄弟シートID（開放不要でリンク元参照可）
  final Set<String> mergedSiblingIds;

  /// 結合ビュー内の別シートデータ更新コールバック（シート間リンク用）
  final void Function(String sheetId, Map<String, dynamic> data)? onSheetUpdate;

  const _CalculatorWidget({
    super.key,
    required this.config,
    required this.onUpdate,
    required this.onDuplicate,
    this.showToolbar = true,
    this.showHeader = true,
    this.contentPadding,
    this.onAiGeneratingChanged,
    this.globalConstants = const [],
    this.clipboardNotifier,
    this.allConfigs = const [],
    this.mergedSiblingIds = const {},
    this.onSheetUpdate,
  });

  @override
  State<_CalculatorWidget> createState() => _CalculatorWidgetState();
}

class _CalculatorWidgetState extends State<_CalculatorWidget> {
  bool get _isExpanded => widget.config.data['isExpanded'] as bool? ?? true;

  void _toggleExpanded() {
    widget.onUpdate({...widget.config.data, 'isExpanded': !_isExpanded});
  }

  @override
  void initState() {
    super.initState();
    widget.clipboardNotifier?.addListener(_onClipboardChanged);
  }

  @override
  void didUpdateWidget(_CalculatorWidget old) {
    super.didUpdateWidget(old);
    if (old.clipboardNotifier != widget.clipboardNotifier) {
      old.clipboardNotifier?.removeListener(_onClipboardChanged);
      widget.clipboardNotifier?.addListener(_onClipboardChanged);
    }
  }

  @override
  void dispose() {
    widget.clipboardNotifier?.removeListener(_onClipboardChanged);
    super.dispose();
  }

  void _onClipboardChanged() {
    if (mounted) setState(() {});
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
  String get _displayMode {
    final tableMode = widget.config.data['tableMode'] as bool? ?? false;
    if (tableMode) return 'table';
    final viewMode = widget.config.data['viewMode'] as bool? ?? false;
    if (viewMode) return 'view';
    return 'edit';
  }

  bool get _wrapFormula =>
      widget.config.data['wrapFormula'] as bool? ?? true; // 折り返し表示モード
  // 多項追跡: 入力された全ての項の値と演算子を保持
  List<double> _calcTermValues = []; // [t0, t1, t2, ...]
  List<String> _calcTermOps = []; // [op01, op12, ...] ※表示形式 (+,-,×,÷)

  // item: { name: String, input: double, op: String, operand: double }
  List<Map<String, dynamic>> get _items {
    final raw = widget.config.data['items'] as List<dynamic>? ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // 定数リスト: [{ 'id': String, 'name': String, 'value': double }]
  List<Map<String, dynamic>> get _constants {
    final raw = widget.config.data['constants'] as List<dynamic>? ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // スタンドアロンメモ: [{ 'id': String, 'text': String }]
  List<Map<String, dynamic>> get _standaloneItems {
    final raw = widget.config.data['standaloneItems'] as List<dynamic>? ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // 論理式: [{ 'id': String, 'name': String, 'conditions': List, 'chainOps': List }]
  List<Map<String, dynamic>> get _logicItems {
    final raw = widget.config.data['logicItems'] as List<dynamic>? ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// tableColumnConfig から項名マップを返す
  Map<String, String> get _effectiveTermLabels {
    final rawColConfig =
        widget.config.data['tableColumnConfig'] as List<dynamic>? ?? [];
    return {
      for (final c in rawColConfig.whereType<Map>())
        if ((c['label'] as String? ?? '').isNotEmpty)
          c['key'] as String: c['label'] as String,
    };
  }

  /// 実効表示順を返す。
  /// data['displayOrder'] が未設定のときは items 順のデフォルトを返す。
  /// 形式: [{'type':'calc','calcIdx':int} | {'type':'standalone','itemId':String} | {'type':'logic','itemId':String}]
  List<Map<String, dynamic>> get _effectiveDisplayOrder {
    final items = _items;
    final raw = widget.config.data['displayOrder'] as List<dynamic>?;
    final logicItemsList =
        widget.config.data['logicItems'] as List<dynamic>? ?? [];

    if (raw == null) {
      final order = List.generate(
          items.length, (i) => {'type': 'calc', 'calcIdx': i});
      // displayOrder未設定の場合も論理式を末尾に追加
      for (final l in logicItemsList) {
        final id = (l as Map)['id'] as String? ?? '';
        if (id.isNotEmpty) order.add({'type': 'logic', 'itemId': id});
      }
      return order;
    }
    final order = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    // 未登録のcalc があれば末尾に追加（整合性保持）
    final presentIdxs = order
        .where((e) => e['type'] == 'calc')
        .map((e) => e['calcIdx'] as int)
        .toSet();
    for (int i = 0; i < items.length; i++) {
      if (!presentIdxs.contains(i)) {
        order.add({'type': 'calc', 'calcIdx': i});
      }
    }
    // 未登録の論理式があれば末尾に追加（整合性保持）
    final presentLogicIds = order
        .where((e) => e['type'] == 'logic')
        .map((e) => e['itemId'] as String? ?? '')
        .toSet();
    for (final l in logicItemsList) {
      final id = (l as Map)['id'] as String? ?? '';
      if (id.isNotEmpty && !presentLogicIds.contains(id)) {
        order.add({'type': 'logic', 'itemId': id});
      }
    }
    return order;
  }

  void _addItem() {
    final newItems = List<Map<String, dynamic>>.from(_items);
    final newCalcIdx = newItems.length;
    newItems.add({
      'name': '計算 ${newItems.length + 1}',
      'input': 0.0,
      'op': '+',
      'operand': 0.0,
      'others': [],
      'brackets': [],
    });
    final order = List<Map<String, dynamic>>.from(_effectiveDisplayOrder);
    order.add({'type': 'calc', 'calcIdx': newCalcIdx});
    widget.onUpdate({
      ...widget.config.data,
      'items': newItems,
      'displayOrder': order,
    });
  }

  void _addItemFromMap(Map<String, dynamic> item) {
    final newItems = List<Map<String, dynamic>>.from(_items);
    final newCalcIdx = newItems.length;
    newItems.add(item);
    final order = List<Map<String, dynamic>>.from(_effectiveDisplayOrder);
    order.add({'type': 'calc', 'calcIdx': newCalcIdx});
    widget.onUpdate({
      ...widget.config.data,
      'items': newItems,
      'displayOrder': order,
    });
  }

  void _addItemsFromMaps(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return;
    final newItems = List<Map<String, dynamic>>.from(_items);
    final order = List<Map<String, dynamic>>.from(_effectiveDisplayOrder);
    for (final item in items) {
      final newCalcIdx = newItems.length;
      newItems.add(item);
      order.add({'type': 'calc', 'calcIdx': newCalcIdx});
    }
    widget.onUpdate({
      ...widget.config.data,
      'items': newItems,
      'displayOrder': order,
    });
  }

  void _insertItemAfter(int calcIdx) {
    final newItems = List<Map<String, dynamic>>.from(_items);
    final newCalcIdx = newItems.length;
    newItems.add({
      'name': '計算 ${newItems.length + 1}',
      'input': 0.0,
      'op': '+',
      'operand': 0.0,
      'others': [],
      'brackets': [],
    });
    // displayOrder 内で calcIdx のエントリの直後に新アイテムを挿入
    final order = List<Map<String, dynamic>>.from(_effectiveDisplayOrder);
    int insertPos = order.length;
    for (int i = 0; i < order.length; i++) {
      if (order[i]['type'] == 'calc' && order[i]['calcIdx'] == calcIdx) {
        insertPos = i + 1;
      }
    }
    order.insert(insertPos, {'type': 'calc', 'calcIdx': newCalcIdx});
    widget.onUpdate({
      ...widget.config.data,
      'items': newItems,
      'displayOrder': order,
      'memos': _memos,
    });
  }

  // ── メモ管理 ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _memos {
    final raw = widget.config.data['memos'] as List<dynamic>? ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  List<Map<String, dynamic>> _remapMemoIndices(
    List<Map<String, dynamic>> memos,
    int? Function(int) remap,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final memo in memos) {
      final oldIdx = memo['afterCalcIdx'] as int? ?? 0;
      final newIdx = remap(oldIdx);
      if (newIdx != null) {
        result.add({...memo, 'afterCalcIdx': newIdx});
      }
    }
    return result;
  }

  void _insertMemoAfter(int calcIdx, BuildContext context) {
    // PopupMenu の dismiss アニメーション（約300ms）完了後にダイアログを表示する
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      showDialog<String?>(
        context: this.context,
        builder: (ctx) =>
            _MemoEditDialog(initialText: '', title: 'メモを追加', saveLabel: '追加'),
      ).then((result) {
        if (result == null || !mounted) return;
        final newMemos = List<Map<String, dynamic>>.from(_memos);
        newMemos.add({'afterCalcIdx': calcIdx, 'text': result});
        widget.onUpdate({...widget.config.data, 'memos': newMemos});
      });
    });
  }

  void _updateMemo(int memoIdx, String text) {
    final newMemos = List<Map<String, dynamic>>.from(_memos);
    if (memoIdx < 0 || memoIdx >= newMemos.length) return;
    newMemos[memoIdx] = {...newMemos[memoIdx], 'text': text};
    widget.onUpdate({...widget.config.data, 'memos': newMemos});
  }

  void _deleteMemo(int memoIdx) {
    final newMemos = List<Map<String, dynamic>>.from(_memos);
    if (memoIdx < 0 || memoIdx >= newMemos.length) return;
    newMemos.removeAt(memoIdx);
    widget.onUpdate({...widget.config.data, 'memos': newMemos});
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
    final allVisible = items.every(
      (item) => item['nameVisible'] as bool? ?? true,
    );
    final newItems = items.map((item) {
      final updated = Map<String, dynamic>.from(item);
      updated['nameVisible'] = !allVisible;
      return updated;
    }).toList();
    widget.onUpdate({...widget.config.data, 'items': newItems});
  }

  // ── 定数管理 ────────────────────────────────────────────────────────────────
  void _addConstant() {
    final consts = List<Map<String, dynamic>>.from(_constants);
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    consts.add({'id': newId, 'name': '定数${consts.length + 1}', 'value': 0.0});
    widget.onUpdate({...widget.config.data, 'constants': consts});
  }

  void _updateConstant(int idx, Map<String, dynamic> data) {
    final consts = List<Map<String, dynamic>>.from(_constants);
    if (idx < 0 || idx >= consts.length) return;
    consts[idx] = data;
    widget.onUpdate({...widget.config.data, 'constants': consts});
  }

  void _deleteConstant(int idx) {
    final consts = List<Map<String, dynamic>>.from(_constants);
    if (idx < 0 || idx >= consts.length) return;
    consts.removeAt(idx);
    widget.onUpdate({...widget.config.data, 'constants': consts});
  }

  // ── スタンドアロンメモ管理 ──────────────────────────────────────────────────
  void _addStandaloneMemo() {
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      showDialog<String?>(
        context: context,
        builder: (ctx) =>
            _MemoEditDialog(initialText: '', title: 'メモを追加', saveLabel: '追加'),
      ).then((result) {
        if (result == null || !mounted) return;
        final newId = DateTime.now().millisecondsSinceEpoch.toString();
        final newItems = List<Map<String, dynamic>>.from(_standaloneItems);
        newItems.add({'id': newId, 'text': result});
        final order = List<Map<String, dynamic>>.from(_effectiveDisplayOrder);
        order.add({'type': 'standalone', 'itemId': newId});
        widget.onUpdate({
          ...widget.config.data,
          'standaloneItems': newItems,
          'displayOrder': order,
        });
      });
    });
  }

  void _updateStandaloneMemo(String id, String text) {
    final items = List<Map<String, dynamic>>.from(_standaloneItems);
    final idx = items.indexWhere((e) => e['id'] == id);
    if (idx < 0) return;
    items[idx] = {...items[idx], 'text': text};
    widget.onUpdate({...widget.config.data, 'standaloneItems': items});
  }

  void _deleteStandaloneMemo(String id) {
    final items = List<Map<String, dynamic>>.from(_standaloneItems);
    items.removeWhere((e) => e['id'] == id);
    final order = List<Map<String, dynamic>>.from(_effectiveDisplayOrder);
    order.removeWhere((e) => e['type'] == 'standalone' && e['itemId'] == id);
    widget.onUpdate({
      ...widget.config.data,
      'standaloneItems': items,
      'displayOrder': order,
    });
  }

  // ── 論理式管理 ───────────────────────────────────────────────────────────
  void _addLogicItem() {
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      showDialog<Map<String, dynamic>?>(
        context: context,
        builder: (ctx) => _LogicItemEditDialog(
          initial: null,
          onPickLinkSource: () => _showLinkSourcePicker(excludeRowIdx: null),
          getSourceRowName: (source) {
            if (source == null) return 'リンク';
            final sheetId = source['sheetId'] as String?;
            final rowIdx = source['rowIdx'] as int? ?? 0;
            final target = source['target'] as String? ?? 'result';
            final effectiveId = sheetId ?? widget.config.id;
            final srcConfig = widget.allConfigs.firstWhere(
              (c) => c.id == effectiveId,
              orElse: () => widget.config,
            );
            final srcItems = (srcConfig.data['items'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            if (rowIdx < 0 || rowIdx >= srcItems.length) return 'リンク';
            final item = srcItems[rowIdx];
            final rowName = item['name'] as String? ?? '計算 ${rowIdx + 1}';
            String targetLabel;
            if (target == 'input') {
              targetLabel = '項1';
            } else if (target == 'operand') {
              targetLabel = '項2';
            } else if (target.startsWith('other_')) {
              final oi = int.tryParse(target.split('_')[1]) ?? 0;
              targetLabel = '項${oi + 3}';
            } else {
              targetLabel = '答え';
            }
            final v = _resolveExternalValue(effectiveId, rowIdx, target);
            final precision = item['precision'] as int? ?? 2;
            final valStr = (v == v.truncateToDouble() && v.abs() < 1e12)
                ? v.toStringAsFixed(0)
                : v.toStringAsFixed(precision);
            return '$rowName / $targetLabel: $valStr';
          },
        ),
      ).then((result) {
        if (result == null || !mounted) return;
        final newId = DateTime.now().millisecondsSinceEpoch.toString();
        final newItems = List<Map<String, dynamic>>.from(_logicItems);
        newItems.add({'id': newId, ...result});
        final order = List<Map<String, dynamic>>.from(_effectiveDisplayOrder);
        order.add({'type': 'logic', 'itemId': newId});
        widget.onUpdate({
          ...widget.config.data,
          'logicItems': newItems,
          'displayOrder': order,
        });
      });
    });
  }

  void _onAddLogicItem(Map<String, dynamic> newItem) {
    final newItems = List<Map<String, dynamic>>.from(_logicItems);
    newItems.add(newItem);
    final order = List<Map<String, dynamic>>.from(_effectiveDisplayOrder);
    order.add({'type': 'logic', 'itemId': newItem['id']});
    widget.onUpdate({
      ...widget.config.data,
      'logicItems': newItems,
      'displayOrder': order,
    });
  }

  void _updateLogicItem(String id, Map<String, dynamic> data) {
    final items = List<Map<String, dynamic>>.from(_logicItems);
    final idx = items.indexWhere((e) => e['id'] == id);
    if (idx < 0) return;
    items[idx] = {'id': id, ...data};
    widget.onUpdate({...widget.config.data, 'logicItems': items});
  }

  void _deleteLogicItem(String id) {
    final items = List<Map<String, dynamic>>.from(_logicItems);
    items.removeWhere((e) => e['id'] == id);
    final order = List<Map<String, dynamic>>.from(_effectiveDisplayOrder);
    order.removeWhere((e) => e['type'] == 'logic' && e['itemId'] == id);
    widget.onUpdate({
      ...widget.config.data,
      'logicItems': items,
      'displayOrder': order,
    });
  }

  /// 論理式アイテム全体を評価して真/偽を返す
  static bool _evalLogicItem(
    Map<String, dynamic> item, [
    double Function(Map<String, dynamic>?, bool, double)? resolver,
  ]) {
    final conditions = item['conditions'] as List? ?? [];
    final chainOps = item['chainOps'] as List? ?? [];
    if (conditions.isEmpty) return false;
    bool result = _evalCondition(
      Map<String, dynamic>.from(conditions[0] as Map),
      resolver,
    );
    for (int i = 1; i < conditions.length; i++) {
      final condResult = _evalCondition(
        Map<String, dynamic>.from(conditions[i] as Map),
        resolver,
      );
      final op = (i - 1 < chainOps.length ? chainOps[i - 1] : 'AND') as String;
      if (op == 'OR') {
        result = result || condResult;
      } else if (op == 'XOR') {
        result = result ^ condResult;
      } else {
        result = result && condResult;
      }
    }
    return result;
  }

  static bool _evalCondition(
    Map<String, dynamic> cond, [
    double Function(Map<String, dynamic>?, bool, double)? resolver,
  ]) {
    final lhsVal = resolver != null
        ? resolver(
            cond['lhsLinkSource'] as Map<String, dynamic>?,
            cond['lhsLink'] == true,
            (cond['lhsVal'] as num? ?? 0.0).toDouble(),
          )
        : (cond['lhsVal'] as num? ?? 0.0).toDouble();
    final rhsVal = resolver != null
        ? resolver(
            cond['rhsLinkSource'] as Map<String, dynamic>?,
            cond['rhsLink'] == true,
            (cond['rhsVal'] as num? ?? 0.0).toDouble(),
          )
        : (cond['rhsVal'] as num? ?? 0.0).toDouble();
    final op = cond['op'] as String? ?? '==';
    if (op == '==') return (lhsVal - rhsVal).abs() < 1e-10;
    if (op == '!=') return (lhsVal - rhsVal).abs() >= 1e-10;
    if (op == '>') return lhsVal > rhsVal;
    if (op == '>=') return lhsVal >= rhsVal;
    if (op == '<') return lhsVal < rhsVal;
    if (op == '<=') return lhsVal <= rhsVal;
    if (op == 'between') {
      final rhs2 = resolver != null
          ? resolver(
              cond['rhsLinkSource2'] as Map<String, dynamic>?,
              cond['rhsLink2'] == true,
              (cond['rhsVal2'] as num? ?? 0.0).toDouble(),
            )
          : (cond['rhsVal2'] as num? ?? 0.0).toDouble();
      return lhsVal >= rhsVal && lhsVal <= rhs2;
    }
    if (op == 'not_between') {
      final rhs2 = resolver != null
          ? resolver(
              cond['rhsLinkSource2'] as Map<String, dynamic>?,
              cond['rhsLink2'] == true,
              (cond['rhsVal2'] as num? ?? 0.0).toDouble(),
            )
          : (cond['rhsVal2'] as num? ?? 0.0).toDouble();
      return lhsVal < rhsVal || lhsVal > rhs2;
    }
    if (op == 'divisible') {
      if (rhsVal == 0) return false;
      return (lhsVal % rhsVal).abs() < 1e-10;
    }
    return false;
  }

  /// 論理式全体の式文字列を生成する
  static String _buildLogicExprString(
    Map<String, dynamic> item, [
    double Function(Map<String, dynamic>?, bool, double)? resolver,
  ]) {
    final conditions = item['conditions'] as List? ?? [];
    final chainOps = item['chainOps'] as List? ?? [];
    if (conditions.isEmpty) return '(条件なし)';
    final parts = <String>[];
    for (int i = 0; i < conditions.length; i++) {
      parts.add(
        _buildConditionString(
          Map<String, dynamic>.from(conditions[i] as Map),
          resolver,
        ),
      );
      if (i < chainOps.length) {
        final cop = chainOps[i] as String? ?? 'AND';
        parts.add(cop == 'OR' ? 'または' : cop == 'XOR' ? 'どちらか一方' : 'かつ');
      }
    }
    return parts.join(' ');
  }

  static String _buildConditionString(
    Map<String, dynamic> cond, [
    double Function(Map<String, dynamic>?, bool, double)? resolver,
  ]) {
    final lhsLink = cond['lhsLink'] == true;
    final lhsLinkSource = cond['lhsLinkSource'] as Map<String, dynamic>?;
    final lhsValStored = (cond['lhsVal'] as num? ?? 0.0).toDouble();
    final lhsLabel = cond['lhsLabel'] as String? ?? '';
    final rhsLink = cond['rhsLink'] == true;
    final rhsLinkSource = cond['rhsLinkSource'] as Map<String, dynamic>?;
    final lhsVal = (lhsLink && resolver != null)
        ? resolver(lhsLinkSource, true, lhsValStored)
        : lhsValStored;
    final rhsValStored = (cond['rhsVal'] as num? ?? 0.0).toDouble();
    final rhsLabel = cond['rhsLabel'] as String? ?? '';
    final rhsVal = (rhsLink && resolver != null)
        ? resolver(rhsLinkSource, true, rhsValStored)
        : rhsValStored;
    final op = cond['op'] as String? ?? '==';

    String fmtN(double v) {
      if (v == v.truncateToDouble() && v.abs() < 1e12) {
        return v.toInt().toString();
      }
      return v
          .toStringAsFixed(4)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }

    final lhs = (lhsLink && resolver != null)
        ? fmtN(lhsVal)
        : lhsLabel.isNotEmpty
        ? lhsLabel
        : fmtN(lhsVal);
    final rhs = (rhsLink && resolver != null)
        ? fmtN(rhsVal)
        : rhsLabel.isNotEmpty
        ? rhsLabel
        : fmtN(rhsVal);
    if (op == 'between' || op == 'not_between') {
      final rhsLink2 = cond['rhsLink2'] == true;
      final rhsLinkSource2 = cond['rhsLinkSource2'] as Map<String, dynamic>?;
      final rhs2Label = cond['rhsLabel2'] as String? ?? '';
      final rhs2ValStored = (cond['rhsVal2'] as num? ?? 0.0).toDouble();
      final rhs2Val = (rhsLink2 && resolver != null)
          ? resolver(rhsLinkSource2, true, rhs2ValStored)
          : rhs2ValStored;
      final rhs2 = (rhsLink2 && resolver != null)
          ? fmtN(rhs2Val)
          : rhs2Label.isNotEmpty
          ? rhs2Label
          : fmtN(rhs2Val);
      if (op == 'between') return '$rhs ≤ $lhs ≤ $rhs2';
      return '$lhs < $rhs または $lhs > $rhs2';
    }
    if (op == 'divisible') return '$lhs が $rhs の倍数';
    final opStr =
        const {
          '==': '=',
          '!=': '≠',
          '>': '>',
          '>=': '≥',
          '<': '<',
          '<=': '≤',
        }[op] ??
        op;
    return '$lhs $opStr $rhs';
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

  void _removeItem(int calcIdx) {
    var newItems = List<Map<String, dynamic>>.from(_items);
    newItems.removeAt(calcIdx);
    // 削除した行を参照していたリンクを解除し、以降のインデックスを繰り上げ
    newItems = _remapLinkIndices(newItems, (oldIdx) {
      if (oldIdx == calcIdx) return null;
      if (oldIdx > calcIdx) return oldIdx - 1;
      return oldIdx;
    });
    // displayOrder から削除エントリを消し、後続の calcIdx を繰り上げ
    var order = List<Map<String, dynamic>>.from(_effectiveDisplayOrder);
    order.removeWhere((e) => e['type'] == 'calc' && e['calcIdx'] == calcIdx);
    order = order.map((e) {
      if (e['type'] == 'calc') {
        final ci = e['calcIdx'] as int;
        if (ci > calcIdx) return {...e, 'calcIdx': ci - 1};
      }
      return e;
    }).toList();
    // 全て削除したらサンプルを追加
    if (newItems.isEmpty) {
      newItems = List<Map<String, dynamic>>.from(_sampleItems);
      order = [
        {'type': 'calc', 'calcIdx': 0},
      ];
    }
    // 削除した計算のメモも削除し、以降のインデックスを繰り上げ
    final newMemos = _remapMemoIndices(_memos, (old) {
      if (old == calcIdx) return null;
      if (old > calcIdx) return old - 1;
      return old;
    });
    widget.onUpdate({
      ...widget.config.data,
      'items': newItems,
      'displayOrder': order,
      'memos': newMemos,
    });
  }

  void _duplicateItem(int calcIdx) {
    // クリップボードにコピー（即複製しない）
    final items = _items;
    if (calcIdx < 0 || calcIdx >= items.length) return;
    final copy = Map<String, dynamic>.from(items[calcIdx]);
    widget.clipboardNotifier?.value = copy;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${copy['name'] ?? '計算'}」をコピーしました'),
          backgroundColor: const Color.fromARGB(255, 70, 196, 255),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _cutItem(int calcIdx) {
    final items = _items;
    if (calcIdx < 0 || calcIdx >= items.length) return;
    final copy = Map<String, dynamic>.from(items[calcIdx]);
    widget.clipboardNotifier?.value = copy;
    _removeItem(calcIdx);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${copy['name'] ?? '計算'}」を切り取りました'),
          backgroundColor: const Color.fromARGB(255, 206, 255, 70),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 連動設定をすべて解除したコピーを返す
  Map<String, dynamic> _unlinkItem(Map<String, dynamic> item) {
    final copy = Map<String, dynamic>.from(item);
    copy['inputLink'] = false;
    copy['inputLinkSource'] = null;
    copy['operandLink'] = false;
    copy['operandLinkSource'] = null;
    if (copy['others'] is List) {
      copy['others'] = (copy['others'] as List).map((o) {
        final oCopy = Map<String, dynamic>.from(o as Map<String, dynamic>);
        oCopy['valLink'] = false;
        oCopy['valLinkSource'] = null;
        return oCopy;
      }).toList();
    }
    return copy;
  }

  void _pasteFromClipboard(int insertAfterCalcIdx) {
    final clipData = widget.clipboardNotifier?.value;
    if (clipData == null) return;
    final pasteItem = _unlinkItem(Map<String, dynamic>.from(clipData));
    final newItems = List<Map<String, dynamic>>.from(_items);
    final newCalcIdx = newItems.length;
    newItems.add(pasteItem);
    final order = List<Map<String, dynamic>>.from(_effectiveDisplayOrder);
    int insertPos = order.length;
    for (int i = 0; i < order.length; i++) {
      if (order[i]['type'] == 'calc' &&
          order[i]['calcIdx'] == insertAfterCalcIdx) {
        insertPos = i + 1;
        break;
      }
    }
    order.insert(insertPos, {'type': 'calc', 'calcIdx': newCalcIdx});
    widget.onUpdate({
      ...widget.config.data,
      'items': newItems,
      'displayOrder': order,
      'memos': _memos,
    });
  }

  /// 表示順上の from 位置を to 位置へ移動する（displayOrder のみ更新）
  void _moveItem(int from, int to) {
    final order = List<Map<String, dynamic>>.from(_effectiveDisplayOrder);
    if (from < 0 || to < 0 || from >= order.length || to >= order.length) {
      return;
    }
    final entry = order.removeAt(from);
    order.insert(to, entry);
    widget.onUpdate({...widget.config.data, 'displayOrder': order});
  }

  void _updateItem(int index, Map<String, dynamic> newItem) {
    var newItems = List<Map<String, dynamic>>.from(_items);

    // 一括適用フラグがある場合
    if (newItem.containsKey('_applyToAllKey')) {
      final key = newItem['_applyToAllKey'] as String;
      final skipLinked = newItem['_skipLinked'] == true;

      newItems = newItems.map((item) {
        final updated = Map<String, dynamic>.from(item);

        // リンク中の行をスキップ
        if (skipLinked) {
          if (key == 'input' && item['inputLink'] == true) return item;
          if (key == 'operand' && item['operandLink'] == true) return item;
          if (key.startsWith('other_')) {
            final parts = key.split('_');
            final otherIdx = int.parse(parts[1]);
            final othersList = item['others'] as List? ?? [];
            if (otherIdx < othersList.length &&
                (othersList[otherIdx] as Map)['valLink'] == true) {
              return item;
            }
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
          // リンク情報も一括コピー
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
      backgroundColor: Colors.black,
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

  // ── 定数セクションWidget ──────────────────────────────────────────────────
  Widget _buildConstantsSection(
    List<Map<String, dynamic>> constants,
    bool isDark,
  ) {
    final fgColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black45;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amberAccent.withOpacity(isDark ? 0.07 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amberAccent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.push_pin_outlined,
                size: 14,
                color: Colors.amberAccent,
              ),
              const SizedBox(width: 6),
              Text(
                '定数',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _addConstant,
                child: const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: Colors.amberAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: constants.asMap().entries.map((entry) {
              final idx = entry.key;
              final c = entry.value;
              final name = c['name'] as String? ?? '';
              final value = (c['value'] as num? ?? 0.0).toDouble();
              final valStr =
                  value == value.truncateToDouble() && value.abs() < 1e12
                  ? value.toInt().toString()
                  : value
                        .toStringAsFixed(4)
                        .replaceAll(RegExp(r'0+$'), '')
                        .replaceAll(RegExp(r'\.$'), '');
              return GestureDetector(
                onTap: () => _editConstant(idx),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amberAccent.withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: TextStyle(color: subColor, fontSize: 12),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '=',
                        style: TextStyle(color: subColor, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        valStr,
                        style: TextStyle(
                          color: fgColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _editConstant(int idx) async {
    final consts = _constants;
    if (idx < 0 || idx >= consts.length) return;
    final c = consts[idx];
    final nameCtrl = TextEditingController(text: c['name'] as String? ?? '');
    final valCtrl = TextEditingController(
      text: (c['value'] as num? ?? 0.0).toString(),
    );

    // 物理・数学定数プリセット
    const physicalConstants = [
      {'label': 'π', 'value': 3.14159265358979},
      {'label': 'e', 'value': 2.71828182845905},
      {'label': 'g', 'value': 9.80665},
      {'label': 'φ', 'value': 1.61803398874989},
      {'label': 'c', 'value': 299792458.0},
    ];

    var _valSelected = false;
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          if (!_valSelected) {
            _valSelected = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              valCtrl.selection = TextSelection(
                baseOffset: 0,
                extentOffset: valCtrl.text.length,
              );
            });
          }
          return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '定数の設定',
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
                '名前',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '例: 税率',
                  hintStyle: TextStyle(color: Colors.white24),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '値',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: valCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                      decoration: const InputDecoration(
                        hintText: '0.0',
                        hintStyle: TextStyle(color: Colors.white24),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.all(Radius.circular(16)),

                      ),
                    ),
                  ),),
                  const SizedBox(width: 8),
                 
                  IconButton(
                    icon: const Icon(
                      Icons.backspace_outlined,
                      color: Colors.white54,
                    ),
                    onPressed: () => setSheetState(() => valCtrl.clear()),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 物理・数学定数プリセットボタン
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...physicalConstants.map((preset) {
                      final label = preset['label'] as String;
                      final value = preset['value'] as double;
                      return GestureDetector(
                        onTap: () => setSheetState(() {
                          valCtrl.text = value.toString();
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.amberAccent.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'ZenOldMincho',
                            ),
                          ),
                        ),
                      );
                    }),
                    // ユーザー定義定数プリセット
                    ...widget.globalConstants.map((uc) {
                      final name = uc['name'] as String? ?? '';
                      final value = (uc['value'] as num? ?? 0.0).toDouble();
                      return GestureDetector(
                        onTap: () => setSheetState(() {
                          valCtrl.text =
                              value == value.truncateToDouble() &&
                                  value.abs() < 1e15
                              ? value.toInt().toString()
                              : value.toString();
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5E81FF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF5E81FF).withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Color(0xFF5E81FF),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
 Container(
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(1),
    shape: BoxShape.circle,
    border: Border.all(color: Colors.white)),
   child: IconButton(
                      icon: const Icon(
                        Icons.calculate_outlined,
                        color: Colors.black,
                      ),
                      tooltip: '電卓',
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.black,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          builder: (calcCtx) => _MiniCalcSheet(
                            onResult: (v) {
                              setSheetState(() {
                                if (v == v.truncateToDouble() && v.abs() < 1e15) {
                                  valCtrl.text = v.toInt().toString();
                                } else {
                                  valCtrl.text = v
                                      .toStringAsFixed(15)
                                      .replaceAll(RegExp(r'0+$'), '')
                                      .replaceAll(RegExp(r'\.$'), '');
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
 ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, {'delete': true}),
                    child: const Text(
                      '削除',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 120,
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
                        'name': nameCtrl.text,
                        'value': valCtrl.text,
                      }),
                      child: const Text('保存', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        },
      ),
    );
    if (result == null) return;
    if (result['delete'] == true) {
      _deleteConstant(idx);
    } else {
      _updateConstant(idx, {
        ...consts[idx],
        'name': result['name'] as String,
        'value': double.tryParse(result['value'] as String) ?? 0.0,
      });
    }
  }

  void _showActionSheet() {
    final items = _items;
    final allNamesVisible = items.every(
      (item) => item['nameVisible'] as bool? ?? true,
    );
    final wrapFormula = _wrapFormula;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 14),
            ListTile(
              leading: const Icon(
                Icons.push_pin_outlined,
                color: Colors.amberAccent,
              ),
              title: const Text('定数を追加', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _addConstant();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.sticky_note_2_outlined,
                color: Colors.tealAccent,
              ),
              title: const Text('メモを追加', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _addStandaloneMemo();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.rule_rounded,
                color: Colors.deepPurpleAccent,
              ),
              title: const Text(
                '論理式を追加',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                '比較・AND/OR条件の真偽判定',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _addLogicItem();
              },
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
                allNamesVisible ? 'すべての計算名を非表示' : 'すべての計算名を表示',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _toggleAllNamesVisible();
              },
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: Icon(
                wrapFormula
                    ? Icons.wrap_text_rounded
                    : Icons.format_list_bulleted_rounded,
                color: wrapFormula ? Colors.blueAccent : Colors.white70,
              ),
              title: Text(
                wrapFormula ? '一行で表示する' : '折り返して表示する',
                style: const TextStyle(color: Colors.white),
              ),
              trailing: wrapFormula
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.blueAccent,
                      size: 18,
                    )
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                widget.onUpdate({
                  ...widget.config.data,
                  'wrapFormula': !wrapFormula,
                });
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
            ListTile(
              leading: const Icon(Icons.qr_code_rounded, color: Colors.white70),
              title: const Text(
                'QRコードで共有する',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                ProGuard.checkAndRun(context, _shareAsCsvQr);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── シートレベルのリンク設定ダイアログ ────────────────────────────────────

  // ignore: unused_element
  Set<String> _calcSelectedDestsForRow(int srcRowIdx, String srcField) {
    final items = _items;
    final Set<String> dests = {};
    for (int i = 0; i < items.length; i++) {
      if (i == srcRowIdx) continue;
      final item = items[i];
      bool linkedToMe(Map? src) =>
          src != null &&
          src['rowIdx'] == srcRowIdx &&
          src['target'] == srcField;
      if (item['inputLink'] == true &&
          linkedToMe(item['inputLinkSource'] as Map?)) {
        dests.add('${i}_input');
      }
      if (item['operandLink'] == true &&
          linkedToMe(item['operandLinkSource'] as Map?)) {
        dests.add('${i}_operand');
      }
      final othersList = item['others'] as List? ?? [];
      for (int j = 0; j < othersList.length; j++) {
        final o = othersList[j] as Map;
        if (o['valLink'] == true && linkedToMe(o['valLinkSource'] as Map?)) {
          dests.add('${i}_other_$j');
        }
      }
    }
    return dests;
  }

  // ---- 他シート開放 --------------------------------------------------------

  void _toggleExposed(int calcIdx) {
    final newItems = List<Map<String, dynamic>>.from(_items);
    if (calcIdx < 0 || calcIdx >= newItems.length) return;
    final current = newItems[calcIdx]['exposed'] as bool? ?? false;
    newItems[calcIdx] = {...newItems[calcIdx], 'exposed': !current};
    widget.onUpdate({...widget.config.data, 'items': newItems});
  }

  /// 別シートの指定行・フィールドの値を返す（シート内リンクを多パスで解決）
  double _resolveExternalValue(
    String sheetId,
    int rowIdx,
    String target, [
    Set<String>? _visiting,
  ]) {
    final visiting = _visiting ?? {};
    // 循環参照ガード（visited set で検出）
    if (visiting.contains(sheetId)) return 0.0;
    final nextVisiting = <String>{...visiting, sheetId};
    final List<Map<String, dynamic>> srcItems;
    final List<Map<String, dynamic>> srcConstants;
    if (sheetId == widget.config.id) {
      // 現在シート自体への参照 → 現在シートのアイテムを直接使用
      srcItems = _items;
      srcConstants = _constants;
    } else {
      final srcConfig = widget.allConfigs.firstWhere(
        (c) => c.id == sheetId,
        orElse: () => WidgetConfig(id: '', type: '', data: {}),
      );
      if (srcConfig.id.isEmpty) return 0.0;
      srcItems = (srcConfig.data['items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      srcConstants = (srcConfig.data['constants'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (rowIdx < 0 || rowIdx >= srcItems.length) return 0.0;

    // Pass 1: 暫定計算（リンクなし）
    final extResults = List<double>.filled(srcItems.length, 0.0);
    for (int pi = 0; pi < srcItems.length; pi++) {
      final it = srcItems[pi];
      extResults[pi] = _calculate(
        _CalculatorRow._applyTermTransform(
          (it['input'] as num? ?? 0.0).toDouble(),
          it['inputTransform'] as String?,
          (it['inputPowExp'] as num? ?? 2.0).toDouble(),
        ),
        it['op'] as String? ?? '+',
        _CalculatorRow._applyTermTransform(
          (it['operand'] as num? ?? 0.0).toDouble(),
          it['operandTransform'] as String?,
          (it['operandPowExp'] as num? ?? 2.0).toDouble(),
        ),
        (it['others'] as List? ?? []).map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          m['val'] = (m['val'] as num? ?? 0.0).toDouble();
          return m;
        }).toList(),
        it['brackets'] as List? ?? [],
      );
    }

    // シート内リンクを解決する補助関数（循環参照ガード付き）
    double resolveInExt(
      Map<String, dynamic>? src,
      bool isLink,
      double fallback,
    ) {
      if (!isLink) return fallback;
      if (src == null) {
        return extResults.isNotEmpty ? extResults.last : fallback;
      }
      final xSheetId = src['sheetId'] as String?;
      if (xSheetId != null) {
        return _resolveExternalValue(
          xSheetId,
          src['rowIdx'] as int? ?? 0,
          src['target'] as String? ?? 'result',
          nextVisiting,
        );
      }
      if (src['type'] == 'constant') {
        final ci = src['constIdx'] as int? ?? 0;
        // まずソースシートの定数、なければグローバル定数を参照
        final allConsts = [...srcConstants, ...widget.globalConstants];
        if (ci >= 0 && ci < allConsts.length) {
          return (allConsts[ci]['value'] as num? ?? 0.0).toDouble();
        }
        return fallback;
      }
      final sRowIdx = src['rowIdx'] as int? ?? 0;
      final sTarget = src['target'] as String? ?? 'result';
      if (sRowIdx < 0 || sRowIdx >= srcItems.length) return fallback;
      final si = srcItems[sRowIdx];
      if (sTarget == 'result') return extResults[sRowIdx];
      if (sTarget == 'input') return (si['input'] as num? ?? 0.0).toDouble();
      if (sTarget == 'operand') {
        return (si['operand'] as num? ?? 0.0).toDouble();
      }
      if (sTarget.startsWith('other_')) {
        final idx = int.tryParse(sTarget.split('_')[1]) ?? 0;
        final sOthers = si['others'] as List? ?? [];
        if (idx < sOthers.length) {
          return ((sOthers[idx] as Map)['val'] as num? ?? 0.0).toDouble();
        }
      }
      return fallback;
    }

    // Pass 2: 反復収束（シート内リンクを解決）
    for (int pass = 0; pass < srcItems.length; pass++) {
      bool anyChange = false;
      for (int i = 0; i < srcItems.length; i++) {
        final item = srcItems[i];
        final inp = resolveInExt(
          item['inputLinkSource'] as Map<String, dynamic>?,
          item['inputLink'] == true,
          (item['input'] as num? ?? 0.0).toDouble(),
        );
        final ope = resolveInExt(
          item['operandLinkSource'] as Map<String, dynamic>?,
          item['operandLink'] == true,
          (item['operand'] as num? ?? 0.0).toDouble(),
        );
        final others = (item['others'] as List? ?? []).map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          m['val'] = resolveInExt(
            m['valLinkSource'] as Map<String, dynamic>?,
            m['valLink'] == true,
            (m['val'] as num? ?? 0.0).toDouble(),
          );
          return m;
        }).toList();
        final res = _calculate(
          _CalculatorRow._applyTermTransform(
            inp,
            item['inputTransform'] as String?,
            (item['inputPowExp'] as num? ?? 2.0).toDouble(),
          ),
          item['op'] as String? ?? '+',
          _CalculatorRow._applyTermTransform(
            ope,
            item['operandTransform'] as String?,
            (item['operandPowExp'] as num? ?? 2.0).toDouble(),
          ),
          others.map((e) {
            final m = Map<String, dynamic>.from(e);
            m['val'] = _CalculatorRow._applyTermTransform(
              m['val'] as double,
              m['transform'] as String?,
              (m['powExp'] as num? ?? 2.0).toDouble(),
            );
            return m;
          }).toList(),
          item['brackets'] as List? ?? [],
        );
        if ((res - extResults[i]).abs() > 1e-10) anyChange = true;
        extResults[i] = res;
      }
      if (!anyChange) break;
    }

    // 対象フィールドの解決済み値を返す
    final sItem = srcItems[rowIdx];
    if (target == 'result') return extResults[rowIdx];
    if (target == 'input') {
      return resolveInExt(
        sItem['inputLinkSource'] as Map<String, dynamic>?,
        sItem['inputLink'] == true,
        (sItem['input'] as num? ?? 0.0).toDouble(),
      );
    }
    if (target == 'operand') {
      return resolveInExt(
        sItem['operandLinkSource'] as Map<String, dynamic>?,
        sItem['operandLink'] == true,
        (sItem['operand'] as num? ?? 0.0).toDouble(),
      );
    }
    if (target.startsWith('other_')) {
      final idx = int.tryParse(target.split('_')[1]) ?? 0;
      final sOthers = sItem['others'] as List? ?? [];
      if (idx < sOthers.length) {
        final o = sOthers[idx] as Map;
        return resolveInExt(
          o['valLinkSource'] as Map<String, dynamic>?,
          o['valLink'] == true,
          (o['val'] as num? ?? 0.0).toDouble(),
        );
      }
      return 0.0;
    }
    return 0.0;
  }

  /// 指定したアイテムリストについてリンクを多パスで解決し、
  /// 各行の {input, operand, others, result} を返す
  List<Map<String, dynamic>> _computeResolvedRows(
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> constants,
  ) {
    if (items.isEmpty) return [];

    // Pass 1: 暫定計算（リンクなし）
    final List<double> finalResults = List.filled(items.length, 0.0);
    for (int pi = 0; pi < items.length; pi++) {
      final it = items[pi];
      finalResults[pi] = _calculate(
        _CalculatorRow._applyTermTransform(
          (it['input'] as num? ?? 0.0).toDouble(),
          it['inputTransform'] as String?,
          (it['inputPowExp'] as num? ?? 2.0).toDouble(),
        ),
        it['op'] as String? ?? '+',
        _CalculatorRow._applyTermTransform(
          (it['operand'] as num? ?? 0.0).toDouble(),
          it['operandTransform'] as String?,
          (it['operandPowExp'] as num? ?? 2.0).toDouble(),
        ),
        (it['others'] as List? ?? []).map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          m['val'] = (m['val'] as num? ?? 0.0).toDouble();
          return m;
        }).toList(),
        it['brackets'] as List? ?? [],
      );
    }

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
      if (source['type'] == 'logic') {
        final logicId = source['logicId'] as String?;
        if (logicId != null) {
          Map<String, dynamic>? logic;
          for (final l in _logicItems) {
            if (l['id'] == logicId) {
              logic = l;
              break;
            }
          }
          if (logic != null) {
            final isTrue = _evalLogicItem(logic, resolveLink);
            final trueVal = (source['trueLink'] as bool? ?? false)
                ? resolveLink(source['trueLinkSource'] as Map<String, dynamic>?, true, 1.0)
                : (source['trueVal'] as num? ?? 1.0).toDouble();
            final falseVal = (source['falseLink'] as bool? ?? false)
                ? resolveLink(source['falseLinkSource'] as Map<String, dynamic>?, true, 0.0)
                : (source['falseVal'] as num? ?? 0.0).toDouble();
            return isTrue ? trueVal : falseVal;
          }
        }
        return fallback;
      }
      if (source['type'] == 'constant') {
        final ci = source['constIdx'] as int? ?? 0;
        if (ci >= 0 && ci < constants.length) {
          return (constants[ci]['value'] as num? ?? 0.0).toDouble();
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
          return ((sOthers[idx] as Map)['val'] as num? ?? 0.0).toDouble();
        }
      }
      return fallback;
    }

    // Pass 2: 反復収束
    var resolvedRows = <Map<String, dynamic>>[];
    for (int pass = 0; pass < items.length; pass++) {
      resolvedRows = [];
      bool anyChange = false;
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final inputVal = resolveLink(
          item['inputLinkSource'] as Map<String, dynamic>?,
          item['inputLink'] == true,
          (item['input'] as num? ?? 0.0).toDouble(),
        );
        final operandVal = resolveLink(
          item['operandLinkSource'] as Map<String, dynamic>?,
          item['operandLink'] == true,
          (item['operand'] as num? ?? 0.0).toDouble(),
        );
        final othersVal = List.from(item['others'] as List? ?? []).map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          m['val'] = resolveLink(
            m['valLinkSource'] as Map<String, dynamic>?,
            m['valLink'] == true,
            (m['val'] as num? ?? 0.0).toDouble(),
          );
          return m;
        }).toList();
        final res = _calculate(
          _CalculatorRow._applyTermTransform(
            inputVal,
            item['inputTransform'] as String?,
            (item['inputPowExp'] as num? ?? 2.0).toDouble(),
          ),
          item['op'] as String? ?? '+',
          _CalculatorRow._applyTermTransform(
            operandVal,
            item['operandTransform'] as String?,
            (item['operandPowExp'] as num? ?? 2.0).toDouble(),
          ),
          othersVal.map((e) {
            final m = Map<String, dynamic>.from(e);
            m['val'] = _CalculatorRow._applyTermTransform(
              m['val'] as double,
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
          'input': inputVal,
          'operand': operandVal,
          'others': othersVal,
          'result': res,
        });
      }
      if (!anyChange) break;
    }
    return resolvedRows;
  }

  /// 別シートの行/フィールドが現在シートのどの欄にリンクされているか返す
  Set<String> _calcSelectedDestsForExternalRow(
    String sheetId,
    int srcRowIdx,
    String srcField,
  ) {
    final items = _items;
    final Set<String> dests = {};
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      bool linkedToSrc(Map? src) =>
          src != null &&
          src['sheetId'] == sheetId &&
          src['rowIdx'] == srcRowIdx &&
          src['target'] == srcField;
      if (item['inputLink'] == true &&
          linkedToSrc(item['inputLinkSource'] as Map?)) {
        dests.add('${i}_input');
      }
      if (item['operandLink'] == true &&
          linkedToSrc(item['operandLinkSource'] as Map?)) {
        dests.add('${i}_operand');
      }
      final othersList = item['others'] as List? ?? [];
      for (int j = 0; j < othersList.length; j++) {
        final o = othersList[j] as Map;
        if (o['valLink'] == true && linkedToSrc(o['valLinkSource'] as Map?)) {
          dests.add('${i}_other_$j');
        }
      }
    }
    return dests;
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

    final csvText = _buildCsvString(items);
    Clipboard.setData(ClipboardData(text: csvText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSVをクリップボードにコピーしました'),
        backgroundColor: Color(0xFF2A2A3A),
      ),
    );
  }

  /// CSV 文字列を構築する（連動値を正しく解決し、計算式に = 結果 を含める）
  String _buildCsvString(List<Map<String, dynamic>> items) {
    final resolvedRows = _computeResolvedRows(items, _constants);

    String escapeCsv(String s) {
      if (s.contains(',') || s.contains('"') || s.contains('\n')) {
        return '"${s.replaceAll('"', '""')}"';
      }
      return s;
    }

    String fmtNum(double v, int precision) {
      if (v == v.truncateToDouble() && v.abs() < 1e12) {
        return v.toInt().toString();
      }
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
      final result = (resolved['result'] as num? ?? 0.0).toDouble();
      final resultStr = '${fmtNum(result, precision)}$unitResult';

      final double input = (resolved['input'] as num? ?? 0.0).toDouble();
      final double operand = (resolved['operand'] as num? ?? 0.0).toDouble();
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
      formula += ' = $resultStr';

      buf.writeln(
        '${escapeCsv(name)},${escapeCsv(formula)},${escapeCsv(resultStr)}',
      );
    }

    // ── メモセクション ────────────────────────────────────────────────────
    final memos = _memos;
    if (memos.isNotEmpty) {
      buf.writeln();
      buf.writeln('--- メモ ---');
      for (final memo in memos) {
        final text = memo['text'] as String? ?? '';
        if (text.isNotEmpty) buf.writeln(escapeCsv(text));
      }
    }

    // ── 論理式セクション ──────────────────────────────────────────────────
    final logicItems = _logicItems;
    if (logicItems.isNotEmpty) {
      buf.writeln();
      buf.writeln('--- 論理式 ---');
      buf.writeln('名前,式,結果');
      for (final logicItem in logicItems) {
        final lName = logicItem['name'] as String? ?? '';
        final lExpr = _buildLogicExprString(logicItem);
        final lResult = _evalLogicItem(logicItem) ? '真' : '偽';
        buf.writeln(
          '${escapeCsv(lName)},${escapeCsv(lExpr)},${escapeCsv(lResult)}',
        );
      }
    }

    // ── 定数セクション ────────────────────────────────────────────────────
    final constants = _constants;
    if (constants.isNotEmpty) {
      buf.writeln();
      buf.writeln('--- 定数 ---');
      buf.writeln('名前,値');
      for (final c in constants) {
        final cName = c['name'] as String? ?? '';
        final cValue = (c['value'] as num? ?? 0.0).toDouble();
        buf.writeln('${escapeCsv(cName)},${fmtNum(cValue, 6)}');
      }
    }

    return buf.toString();
  }

  /// QR コードを表示して CSV/シートデータを共有する
  void _shareAsCsvQr() {
    final items = _items;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('共有するデータがありません'),
          backgroundColor: Color(0xFF2A2A3A),
        ),
      );
      return;
    }

    // NaN / Infinity を安全な値に変換するヘルパー
    double safeDouble(num? v) {
      final d = (v ?? 0.0).toDouble();
      if (d.isNaN || d.isInfinite) return 0.0;
      return d;
    }

    final resolvedRows = _computeResolvedRows(items, _constants);
    final title = widget.config.data['title'] as String? ?? '定型計算';

    final qrItems = List.generate(items.length, (i) {
      final item = items[i];
      final resolved = resolvedRows[i];
      final precision = item['precision'] as int? ?? 2;
      return {
        'n': (item['name'] as String? ?? ''),
        'i': safeDouble(resolved['input'] as num?),
        'op': (item['op'] as String? ?? '+'),
        'o': safeDouble(resolved['operand'] as num?),
        'oth': (resolved['others'] as List).map((e) {
          final m = e as Map;
          return {
            'op': (m['op'] as String? ?? '+'),
            'v': safeDouble(m['val'] as num?),
            'u': (m['unit'] as String? ?? ''),
          };
        }).toList(),
        'p': precision,
        'u1': (item['unit1'] as String? ?? ''),
        'u2': (item['unit2'] as String? ?? ''),
        'ur': (item['unitResult'] as String? ?? ''),
      };
    });

    // メモをコンパクト形式で含める
    final memos = _memos;
    final qrMemos = memos.isNotEmpty
        ? memos
              .map(
                (m) => {
                  'txt': m['text'] as String? ?? '',
                  'aci': m['afterCalcIdx'] as int? ?? -1,
                },
              )
              .toList()
        : null;

    // スタンドアロンメモをコンパクト形式で含める
    final standaloneItems = _standaloneItems;
    final qrSItems = standaloneItems.isNotEmpty
        ? standaloneItems.map((s) => s['text'] as String? ?? '').toList()
        : null;

    // 論理式リストを先に取得（表示順の構築に必要）
    final logicItems = _logicItems;

    // 表示順をコンパクト形式で含める（スタンドアロンメモまたは論理式がある場合）
    List<Map<String, dynamic>>? qrDOrder;
    if (standaloneItems.isNotEmpty || logicItems.isNotEmpty) {
      final displayOrder = _effectiveDisplayOrder;
      // standaloneItems の itemId → 配列インデックスのマップを作成
      final sItemIdToIdx = <String, int>{};
      for (int si = 0; si < standaloneItems.length; si++) {
        final id = standaloneItems[si]['id'] as String? ?? '';
        sItemIdToIdx[id] = si;
      }
      // logicItems の itemId → 配列インデックスのマップを作成
      final lItemIdToIdx = <String, int>{};
      for (int li = 0; li < logicItems.length; li++) {
        final id = logicItems[li]['id'] as String? ?? '';
        lItemIdToIdx[id] = li;
      }
      qrDOrder = displayOrder
          .map((e) {
            if (e['type'] == 'calc') {
              return {'c': e['calcIdx'] as int};
            } else if (e['type'] == 'logic') {
              final id = e['itemId'] as String? ?? '';
              final idx = lItemIdToIdx[id];
              if (idx == null) return null;
              return {'li': idx};
            } else {
              final id = e['itemId'] as String? ?? '';
              final idx = sItemIdToIdx[id];
              if (idx == null) return null;
              return {'s': idx};
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    // 論理式をコンパクト形式で含める
    final qrLogicItems = logicItems.isNotEmpty
        ? logicItems.map((l) {
            final conditions = (l['conditions'] as List? ?? [])
                .map((c) => Map<String, dynamic>.from(c as Map))
                .toList();
            final chainOps = (l['chainOps'] as List? ?? [])
                .map((e) => e as String)
                .toList();
            return {
              'id': l['id'] as String? ?? '',
              'n': l['name'] as String? ?? '',
              'conds': conditions
                  .map(
                    (c) => {
                      'lv': safeDouble(c['lhsVal'] as num?),
                      'll': c['lhsLabel'] as String? ?? '',
                      'op': c['op'] as String? ?? '==',
                      'rv': safeDouble(c['rhsVal'] as num?),
                      'rl': c['rhsLabel'] as String? ?? '',
                      'rv2': safeDouble(c['rhsVal2'] as num?),
                      'rl2': c['rhsLabel2'] as String? ?? '',
                      if (c['lhsLink'] == true) 'lhl': true,
                      if (c['lhsLinkSource'] != null) 'lhls': c['lhsLinkSource'],
                      if (c['rhsLink'] == true) 'rhl': true,
                      if (c['rhsLinkSource'] != null) 'rhls': c['rhsLinkSource'],
                      if (c['rhsLink2'] == true) 'rhl2': true,
                      if (c['rhsLinkSource2'] != null) 'rhls2': c['rhsLinkSource2'],
                    },
                  )
                  .toList(),
              'cops': chainOps,
            };
          }).toList()
        : null;

    // シート固有定数をコンパクト形式で含める
    final constants = _constants;
    final qrConsts = constants.isNotEmpty
        ? constants
              .map(
                (c) => {
                  'n': c['name'] as String? ?? '',
                  'v': safeDouble(c['value'] as num?),
                },
              )
              .toList()
        : null;

    List<String> qrDataList;
    try {
      qrDataList = _buildQrChunks(
        title: title,
        qrItems: qrItems,
        qrMemos: qrMemos,
        qrSItems: qrSItems,
        qrDOrder: qrDOrder,
        qrConsts: qrConsts,
        qrLogicItems: qrLogicItems,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('データのエンコードに失敗しました'),
          backgroundColor: Color(0xFF2A2A3A),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _QrShareDialog(
        qrDataList: qrDataList,
        title: title,
        itemCount: items.length,
      ),
    );
  }

  /// QRデータを1000文字以内のチャンクに分割して返す。
  /// 1枚に収まる場合はそのまま1要素のリストを返す。
  List<String> _buildQrChunks({
    required String title,
    required List<Map<String, dynamic>> qrItems,
    List<Map<String, dynamic>>? qrMemos,
    List<String>? qrSItems,
    List<Map<String, dynamic>>? qrDOrder,
    List<Map<String, dynamic>>? qrConsts,
    List<Map<String, dynamic>>? qrLogicItems,
  }) {
    final singlePayload = <String, dynamic>{
      'v': 1,
      't': title,
      'items': qrItems,
      if (qrMemos != null && qrMemos.isNotEmpty) 'memos': qrMemos,
      if (qrSItems != null && qrSItems.isNotEmpty) 'sitems': qrSItems,
      if (qrDOrder != null && qrDOrder.isNotEmpty) 'dorder': qrDOrder,
      if (qrConsts != null && qrConsts.isNotEmpty) 'consts': qrConsts,
      if (qrLogicItems != null && qrLogicItems.isNotEmpty)
        'logics': qrLogicItems,
    };
    // まずシングルQRで試す
    final singleQr = json.encode(singlePayload);
    if (singleQr.length <= 350) {
      return [singleQr];
    }

    // アイテム配列をJSON文字列化してチャンク分割
    // メモ・定数はチャンク外（先頭チャンクのみに付与）
    final itemsJson = json.encode(qrItems);
    // ヘッダーオーバーヘッド({"v":1,"m":1,"tot":99,"idx":0,"t":"...","d":""})を考慮して
    // 1チャンクあたり最大900文字のデータとする
    const dataChunkSize = 300;

    final dataChunks = <String>[];
    var i = 0;
    while (i < itemsJson.length) {
      final end = (i + dataChunkSize).clamp(0, itemsJson.length);
      dataChunks.add(itemsJson.substring(i, end));
      i = end;
    }

    final total = dataChunks.length;
    return List.generate(total, (idx) {
      final envelope = <String, dynamic>{
        'v': 1,
        'm': 1, // 連結モード
        'tot': total, // 総枚数
        'idx': idx, // 0始まりのインデックス
        'd': dataChunks[idx],
      };
      // タイトル・メモ・定数・論理式は最初のチャンクにのみ含める
      if (idx == 0) {
        envelope['t'] = title;
        if (qrMemos != null && qrMemos.isNotEmpty) envelope['memos'] = qrMemos;
        if (qrSItems != null && qrSItems.isNotEmpty)
          envelope['sitems'] = qrSItems;
        if (qrDOrder != null && qrDOrder.isNotEmpty)
          envelope['dorder'] = qrDOrder;
        if (qrConsts != null && qrConsts.isNotEmpty)
          envelope['consts'] = qrConsts;
        if (qrLogicItems != null && qrLogicItems.isNotEmpty)
          envelope['logics'] = qrLogicItems;
      }
      return json.encode(envelope);
    });
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

  @override
  Widget build(BuildContext context) {
    if (_displayMode == 'view') return _buildViewModeWidget();
    if (_displayMode == 'table') return _buildTableModeWidget();
    final items = _items;
    final constants = _constants;
    final standaloneItems = _standaloneItems;
    final logicItems = _logicItems;
    final displayOrder = _effectiveDisplayOrder;
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
      margin: EdgeInsets.only(bottom: 0),
      constraints: BoxConstraints(
        // minHeight: MediaQuery.of(context).size.height-230,
      ),
      decoration: BoxDecoration(
        color: bgColor.withAlpha(200),
        borderRadius: BorderRadius.circular(0),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.25)
                : Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19.5),
        child: CustomPaint(
          painter: _PaperPainter(isDark: isDark),
          child: Padding(
            padding:
                widget.contentPadding ??
                const EdgeInsets.only(top: 16, bottom: 50, left: 1, right: 16),
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
                                widget.config.data['title'] as String? ??
                                    '定型計算',
                                style: TextStyle(
                                  color: headerTextColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => widget.onUpdate({
                                ...widget.config.data,
                                'viewMode': true,
                              }),
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
                      // 定数セクション
                      if (constants.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildConstantsSection(constants, isDark),
                      ],

                      // 「計算式がありません」または行リスト
                      if (items.isEmpty &&
                          displayOrder.every((e) => e['type'] == 'calc'))
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              '計算式がありません',
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      else
                        ...(() {
                          // Pass 1: 暫定計算（リンクなし）
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
                            final pOthers = (pItem['others'] as List? ?? [])
                                .map((e) {
                                  final m = Map<String, dynamic>.from(e as Map);
                                  m['val'] = (m['val'] as num? ?? 0.0)
                                      .toDouble();
                                  return m;
                                })
                                .toList();
                            final r = _calculate(
                              _CalculatorRow._applyTermTransform(
                                pInput,
                                pItem['inputTransform'] as String?,
                                (pItem['inputPowExp'] as num? ?? 2.0)
                                    .toDouble(),
                              ),
                              pItem['op'] as String? ?? '+',
                              _CalculatorRow._applyTermTransform(
                                pOperand,
                                pItem['operandTransform'] as String?,
                                (pItem['operandPowExp'] as num? ?? 2.0)
                                    .toDouble(),
                              ),
                              pOthers,
                              pItem['brackets'] as List? ?? [],
                            );
                            provisionalResults[pi] = r;
                          }

                          // Pass 2: 反復収束によりチェーンリンクを正しく解決
                          final List<double> finalResults = List<double>.from(
                            provisionalResults,
                          );
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
                            // クロスシートリンク
                            if (source['sheetId'] != null) {
                              return _resolveExternalValue(
                                source['sheetId'] as String,
                                source['rowIdx'] as int? ?? 0,
                                source['target'] as String? ?? 'result',
                              );
                            }
                            // 定数リンク
                            if (source['type'] == 'constant') {
                              final constIdx = source['constIdx'] as int? ?? 0;
                              if (constIdx >= 0 &&
                                  constIdx < constants.length) {
                                return (constants[constIdx]['value'] as num? ??
                                        0.0)
                                    .toDouble();
                              }
                              return fallback;
                            }
                            // 論理式リンク
                            if (source['type'] == 'logic') {
                              final logicId = source['logicId'] as String?;
                              if (logicId != null) {
                                Map<String, dynamic>? logic;
                                for (final l in _logicItems) {
                                  if (l['id'] == logicId) {
                                    logic = l;
                                    break;
                                  }
                                }
                                if (logic != null) {
                                  final isTrue = _evalLogicItem(logic, resolveLink);
                                  final trueVal = (source['trueLink'] as bool? ?? false)
                                      ? resolveLink(source['trueLinkSource'] as Map<String, dynamic>?, true, 1.0)
                                      : (source['trueVal'] as num? ?? 1.0).toDouble();
                                  final falseVal = (source['falseLink'] as bool? ?? false)
                                      ? resolveLink(source['falseLinkSource'] as Map<String, dynamic>?, true, 0.0)
                                      : (source['falseVal'] as num? ?? 0.0).toDouble();
                                  return isTrue ? trueVal : falseVal;
                                }
                              }
                              return fallback;
                            }
                            final int sRowIdx = source['rowIdx'] as int? ?? 0;
                            final String sTarget =
                                source['target'] as String? ?? 'result';
                            if (sRowIdx < 0 || sRowIdx >= items.length) {
                              return fallback;
                            }

                            final sItem = items[sRowIdx];
                            if (sTarget == 'result') {
                              return finalResults[sRowIdx];
                            }
                            if (sTarget == 'input') {
                              return (sItem['input'] as num? ?? 0.0).toDouble();
                            }
                            if (sTarget == 'operand') {
                              return (sItem['operand'] as num? ?? 0.0)
                                  .toDouble();
                            }
                            if (sTarget.startsWith('other_')) {
                              final idx =
                                  int.tryParse(sTarget.split('_')[1]) ?? 0;
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
                                  List.from(item['others'] as List? ?? []).map((
                                    e,
                                  ) {
                                    final map = Map<String, dynamic>.from(
                                      e as Map,
                                    );
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
                                  (item['inputPowExp'] as num? ?? 2.0)
                                      .toDouble();
                              final operandTransform =
                                  item['operandTransform'] as String?;
                              final operandPowExp =
                                  (item['operandPowExp'] as num? ?? 2.0)
                                      .toDouble();
                              final inputForCalc =
                                  _CalculatorRow._applyTermTransform(
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
                                final exp = (m['powExp'] as num? ?? 2.0)
                                    .toDouble();
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
                              if ((res - finalResults[i]).abs() > 1e-10) {
                                anyChange = true;
                              }
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

                          return [
                            ReorderableListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              padding: EdgeInsets.only(bottom: 50),
                              onReorder: (int oldIndex, int newIndex) {
                                if (newIndex > oldIndex) newIndex -= 1;
                                _moveItem(oldIndex, newIndex);
                              },
                              children: (() {
                                final memos = _memos;
                                final listItems = <Widget>[];
                                int displayIdx = 0;
                                for (final entry in displayOrder) {
                                  final di = displayIdx++;
                                  if (entry['type'] == 'calc') {
                                    final ci = entry['calcIdx'] as int;
                                    if (ci < 0 ||
                                        ci >= items.length ||
                                        ci >= resolvedRows.length) {
                                      continue;
                                    }
                                    final item = items[ci];
                                    final resolved = resolvedRows[ci];
                                    final memoWidgets = <Widget>[];
                                    for (int mi = 0; mi < memos.length; mi++) {
                                      if ((memos[mi]['afterCalcIdx'] as int? ??
                                              -1) ==
                                          ci) {
                                        final memoIdx = mi;
                                        memoWidgets.add(
                                          _MemoRowWidget(
                                            key: ValueKey(
                                              'memo_${widget.config.id}_$memoIdx',
                                            ),
                                            text:
                                                memos[mi]['text'] as String? ??
                                                '',
                                            isDark: isDark,
                                            onUpdate: (t) =>
                                                _updateMemo(memoIdx, t),
                                            onDelete: () =>
                                                _deleteMemo(memoIdx),
                                          ),
                                        );
                                      }
                                    }
                                    listItems.add(
                                      Column(
                                        key: ValueKey(
                                          'calc_${widget.config.id}_$ci',
                                        ),
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (di > 0)
                                            Divider(
                                              color: isDark
                                                  ? Colors.white.withOpacity(
                                                      0.07,
                                                    )
                                                  : Colors.black.withOpacity(
                                                      0.08,
                                                    ),
                                              height: 1,
                                              indent: 16,
                                              endIndent: 16,
                                            ),
                                          _CalculatorRow(
                                            name: item['name'] as String? ?? '',
                                            myIndex: ci,
                                            isFirst: di == 0,
                                            input: resolved['input'],
                                            inputLink:
                                                item['inputLink'] as bool? ??
                                                false,
                                            inputLinkSource:
                                                item['inputLinkSource']
                                                    as Map<String, dynamic>?,
                                            inputTransform:
                                                item['inputTransform']
                                                    as String?,
                                            inputPowExp:
                                                (item['inputPowExp'] as num? ??
                                                        2.0)
                                                    .toDouble(),
                                            op: item['op'] as String? ?? '+',
                                            operand: resolved['operand'],
                                            operandLink:
                                                item['operandLink'] as bool? ??
                                                false,
                                            operandLinkSource:
                                                item['operandLinkSource']
                                                    as Map<String, dynamic>?,
                                            operandTransform:
                                                item['operandTransform']
                                                    as String?,
                                            operandPowExp:
                                                (item['operandPowExp']
                                                            as num? ??
                                                        2.0)
                                                    .toDouble(),
                                            others: resolved['others'],
                                            result: resolved['result'],
                                            precision:
                                                item['precision'] as int? ?? 2,
                                            unit1:
                                                item['unit1'] as String? ?? '',
                                            unit2:
                                                item['unit2'] as String? ?? '',
                                            unitResult:
                                                item['unitResult'] as String? ??
                                                '',
                                            isDark: isDark,
                                            brackets:
                                                item['brackets'] as List? ?? [],
                                            allItems: items,
                                            allResults: finalResults,
                                            constants: constants,
                                            onChanged: (newItem) =>
                                                _updateItem(ci, newItem),
                                            onDelete: () => _removeItem(ci),
                                            onCopy: () => _duplicateItem(ci),
                                            onCut: () => _cutItem(ci),
                                            onPaste: () =>
                                                _pasteFromClipboard(ci),
                                            hasClipboard:
                                                widget
                                                    .clipboardNotifier
                                                    ?.value !=
                                                null,
                                            onMoveUp: di > 0
                                                ? () => _moveItem(di, di - 1)
                                                : null,
                                            onMoveDown:
                                                di < displayOrder.length - 1
                                                ? () => _moveItem(di, di + 1)
                                                : null,
                                            onAdd: () => _addTerm(ci),
                                            onPickBrackets: () =>
                                                _pickBracketsFor(ci),
                                            onAllItemsUpdate: (newItems) =>
                                                widget.onUpdate({
                                                  ...widget.config.data,
                                                  'items': newItems,
                                                }),
                                            nameVisible:
                                                item['nameVisible'] as bool? ??
                                                true,
                                            onInsertBelow: () =>
                                                _insertItemAfter(ci),
                                            onInsertMemoBelow: () =>
                                                _insertMemoAfter(ci, context),
                                            onToggleName: () =>
                                                _toggleNameVisible(ci),
                                            wrapFormula: _wrapFormula,
                                            termLabels:
                                                _effectiveTermLabels.isNotEmpty
                                                ? _effectiveTermLabels
                                                : null,
                                            exposed:
                                                item['exposed'] as bool? ??
                                                false,
                                            onToggleExpose: () =>
                                                _toggleExposed(ci),
                                            onLinkSettingsPressed:
                                                (mode, fieldKey) {
                                                  if (mode == 'source') {
                                                    _showSheetLinkSettingsDialog(
                                                      initialSrcCalcIdx: ci,
                                                      initialSrcField: fieldKey,
                                                    );
                                                  } else {
                                                    _showSheetLinkSettingsDialog(
                                                      initialDestCalcIdx: ci,
                                                      initialDestField:
                                                          fieldKey,
                                                    );
                                                  }
                                                },
                                            logicItems: _logicItems,
                                            onAddLogicItem: _onAddLogicItem,
                                            onPickLinkSource: () =>
                                                _showLinkSourcePicker(
                                              excludeRowIdx: ci,
                                            ),
                                            dragHandle:
                                                ReorderableDragStartListener(
                                                  index: di,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 4,
                                                        ),
                                                    child: Icon(
                                                      Icons.drag_indicator,
                                                      color: isDark
                                                          ? Colors.white24
                                                          : Colors.black26,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                          ),
                                          ...memoWidgets,
                                        ],
                                      ),
                                    );
                                  } else if (entry['type'] == 'standalone') {
                                    // スタンドアロンメモ
                                    final itemId =
                                        entry['itemId'] as String? ?? '';
                                    final memo = standaloneItems.firstWhere(
                                      (e) => e['id'] == itemId,
                                      orElse: () => {'id': itemId, 'text': ''},
                                    );
                                    listItems.add(
                                      Column(
                                        key: ValueKey(
                                          'standalone_${widget.config.id}_$itemId',
                                        ),
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (di > 0)
                                            Divider(
                                              color: isDark
                                                  ? Colors.white.withOpacity(
                                                      0.07,
                                                    )
                                                  : Colors.black.withOpacity(
                                                      0.08,
                                                    ),
                                              height: 1,
                                              indent: 16,
                                              endIndent: 16,
                                            ),
                                          _StandaloneMemoRow(
                                            text: memo['text'] as String? ?? '',
                                            isDark: isDark,
                                            onUpdate: (t) =>
                                                _updateStandaloneMemo(
                                                  itemId,
                                                  t,
                                                ),
                                            onDelete: () =>
                                                _deleteStandaloneMemo(itemId),
                                            dragHandle:
                                                ReorderableDragStartListener(
                                                  index: di,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 4,
                                                        ),
                                                    child: Icon(
                                                      Icons.drag_indicator,
                                                      color: isDark
                                                          ? Colors.white24
                                                          : Colors.black26,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else if (entry['type'] == 'logic') {
                                    // 論理式行
                                    final itemId =
                                        entry['itemId'] as String? ?? '';
                                    final logicItem = logicItems.firstWhere(
                                      (e) => e['id'] == itemId,
                                      orElse: () => <String, dynamic>{},
                                    );
                                    if (logicItem.isEmpty) continue;
                                    listItems.add(
                                      Column(
                                        key: ValueKey(
                                          'logic_${widget.config.id}_$itemId',
                                        ),
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (di > 0)
                                            Divider(
                                              color: isDark
                                                  ? Colors.white.withOpacity(
                                                      0.07,
                                                    )
                                                  : Colors.black.withOpacity(
                                                      0.08,
                                                    ),
                                              height: 1,
                                              indent: 16,
                                              endIndent: 16,
                                            ),
                                          _LogicRow(
                                            item: logicItem,
                                            isDark: isDark,
                                            resolver: resolveLink,
                                            onUpdate: (data) =>
                                                _updateLogicItem(itemId, data),
                                            onDelete: () =>
                                                _deleteLogicItem(itemId),
                                            onPickLinkSource: () =>
                                                _showLinkSourcePicker(
                                              excludeRowIdx: null,
                                            ),
                                            getSourceRowName: (source) {
                                              if (source == null) return 'リンク';
                                              final sheetId = source['sheetId'] as String?;
                                              final rowIdx = source['rowIdx'] as int? ?? 0;
                                              final target = source['target'] as String? ?? 'result';
                                              final effectiveId = sheetId ?? widget.config.id;
                                              final srcConfig = widget.allConfigs.firstWhere(
                                                (c) => c.id == effectiveId,
                                                orElse: () => widget.config,
                                              );
                                              final srcItems = (srcConfig.data['items'] as List? ?? [])
                                                  .map((e) => Map<String, dynamic>.from(e as Map))
                                                  .toList();
                                              if (rowIdx < 0 || rowIdx >= srcItems.length) return 'リンク';
                                              final item = srcItems[rowIdx];
                                              final rowName = item['name'] as String? ?? '計算 ${rowIdx + 1}';
                                              String targetLabel;
                                              if (target == 'input') {
                                                targetLabel = '項1';
                                              } else if (target == 'operand') {
                                                targetLabel = '項2';
                                              } else if (target.startsWith('other_')) {
                                                final oi = int.tryParse(target.split('_')[1]) ?? 0;
                                                targetLabel = '項${oi + 3}';
                                              } else {
                                                targetLabel = '答え';
                                              }
                                              final v = _resolveExternalValue(effectiveId, rowIdx, target);
                                              final precision = item['precision'] as int? ?? 2;
                                              final valStr = (v == v.truncateToDouble() && v.abs() < 1e12)
                                                  ? v.toStringAsFixed(0)
                                                  : v.toStringAsFixed(precision);
                                              return '$rowName / $targetLabel: $valStr';
                                            },
                                            dragHandle:
                                                ReorderableDragStartListener(
                                                  index: di,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 4,
                                                        ),
                                                    child: Icon(
                                                      Icons.drag_indicator,
                                                      color: isDark
                                                          ? Colors.white24
                                                          : Colors.black26,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                }
                                return listItems;
                              })(),
                            ),
                          ];
                        })(),
                      const SizedBox(height: 12),
                      // 下部ツールバー（showToolbar=true のときのみ表示）
                      if (widget.showToolbar) ...[
                        Divider(
                          color: Colors.white.withOpacity(0.3),
                          height: 1,
                        ),
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
                              icon: _isAiGenerating
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.purpleAccent.withOpacity(
                                          0.7,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.auto_awesome_outlined,
                                      color: Colors.purpleAccent.withOpacity(
                                        0.7,
                                      ),
                                      size: 18,
                                    ),
                              label: Text(
                                'AI生成',
                                style: TextStyle(
                                  color: Colors.purpleAccent.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              onPressed: _isAiGenerating
                                  ? null
                                  : _showAiGenerateCalcDialog,
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
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
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
                                    : (isDark
                                          ? Colors.white54
                                          : Colors.black45),
                                size: 18,
                              ),
                              label: Text(
                                '電卓',
                                style: TextStyle(
                                  color: _showCalc
                                      ? Colors.blueAccent
                                      : (isDark
                                            ? Colors.white54
                                            : Colors.black45),
                                  fontSize: 12,
                                ),
                              ),
                              onPressed: () =>
                                  setState(() => _showCalc = !_showCalc),
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
          ),
        ),
      ),
    );
  }

  void _showAiGenerateCalcDialog() async {
    final ai = GemmaAi();
    // ローカルモデルは初期化必須。OpenRouter は常に利用可能。
    if (ai.currentModel == AiModel.local && !ai.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ローカルAIが初期化されていません。'),
          backgroundColor: Color(0xFF2A2A3A),
        ),
      );
      return;
    }

    final result =
        await showModalBottomSheet<
          ({String instruction, bool isModify, Uint8List? imageBytes})
        >(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => const _AiPromptSheet(
            title: 'AIで計算式を生成',
            initialText: '',
            showModeSwitcher: false,
          ),
        );

    if (result == null ||
        (result.instruction.isEmpty && result.imageBytes == null))
      return;
    if (!mounted) return;

    final canUse = await RevenueCatService.consumeUse();
    if (!canUse) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: const Text(
              'AI機能は購入が必要です',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            content: const Text(
              'AI機能を使用するには、AI利用回数のチャージが必要です。ストアページで購入してください。',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StorePage()),
                  );
                },
                child: const Text('ストアへ'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final instruction = result.instruction;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('計算式を生成中...'),
        duration: Duration(seconds: 2),
      ),
    );

    setState(() => _isAiGenerating = true);
    widget.onAiGeneratingChanged?.call(true);

    final prompt =
        """
User wants to generate calculator expression(s) for: "$instruction".
Return a JSON array of objects. Multiple formulas are allowed if the request implies multiple steps or variations.

[CRITICAL INSTRUCTIONS]
1. Combine calculation steps into the 'others' list of an item where appropriate. 
2. For variables the user needs to input (e.g., "base", "height"), set "input" or "val" to 0.0 and put the label in "unit".
3. For mathematical constants required by the formula (e.g., "2" in triangle area, "3.14" in circle), set the specific numerical value in "input", "operand", or "val".
4. [IMPORTANT] Be mathematically precise. Only use division or constants (like /2) if the specific formula requires it.
5. Use "brackets" to specify priority calculations (parentheses). Index 0 is "input", index 1 is "operand", index 2 is "others[0]", index 3 is "others[1]", and so on.
6. Ensure every formula is mathematically correct.

Structure per item:
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

Example output:
[
  {
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
  }
]
""";

    try {
      final String res;
      final systemPrompt =
          "You are a calculator generator AI. Return a JSON array of formula objects.";

      if (result.imageBytes != null) {
        res = await ai.queryWithImage(
          prompt,
          result.imageBytes!,
          systemPrompt: systemPrompt,
        );
      } else {
        res = await ai.query(prompt, systemPrompt: systemPrompt);
      }

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

        // 複数生成を許可し、すべて追加する
        currentItems.addAll(newItems);

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
        widget.onAiGeneratingChanged?.call(false);
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

    setState(() {
      _isAiCounting = true;
      _showCalc = false; // 電卓を最小化してカメラ選択画面を隠れなくする
    });

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

  void _showCalcHistory() async {
    final bgColorVal = widget.config.data['bgColor'] as int?;
    final isDark = bgColorVal != null
        ? Color(bgColorVal).computeLuminance() < 0.5
        : true;
    final entries = await CalcHistoryManager.instance.loadAll();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CalcHistorySheet(
        entries: entries,
        isDark: isDark,
        onSelect: (entry) {
          Navigator.pop(ctx);
          setState(() {
            _calcDisplay = entry.result;
            _calcA = double.tryParse(entry.result);
            _calcNewEntry = true;
            _calcHasResult = true;
            _isClearState = true;
            _calcOp = '';
            _calcTermValues = _calcA != null ? [_calcA!] : [];
            _calcTermOps = [];
            _calcExprStr = '${entry.expression} = ${entry.result}';
          });
        },
        onClear: () {
          CalcHistoryManager.instance.clearAll();
          Navigator.pop(ctx);
        },
        onAddMultiple: (selectedEntries) {
          Navigator.pop(ctx);
          _addItemsFromMaps(selectedEntries.map(_historyEntryToItem).toList());
        },
      ),
    );
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
            backgroundColor: Colors.black,
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
                  dropdownColor: Colors.black,
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
                  dropdownColor: Colors.black,
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
