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
  /// 形式: [{'type':'calc','calcIdx':int} | {'type':'standalone','itemId':String}]
  List<Map<String, dynamic>> get _effectiveDisplayOrder {
    final items = _items;
    final raw = widget.config.data['displayOrder'] as List<dynamic>?;
    if (raw == null) {
      return List.generate(items.length, (i) => {'type': 'calc', 'calcIdx': i});
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
        builder: (ctx) => const _LogicItemEditDialog(initial: null),
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
  static bool _evalLogicItem(Map<String, dynamic> item) {
    final conditions = item['conditions'] as List? ?? [];
    final chainOps = item['chainOps'] as List? ?? [];
    if (conditions.isEmpty) return false;
    bool result = _evalCondition(
      Map<String, dynamic>.from(conditions[0] as Map),
    );
    for (int i = 1; i < conditions.length; i++) {
      final condResult = _evalCondition(
        Map<String, dynamic>.from(conditions[i] as Map),
      );
      final op = (i - 1 < chainOps.length ? chainOps[i - 1] : 'AND') as String;
      if (op == 'OR') {
        result = result || condResult;
      } else {
        result = result && condResult;
      }
    }
    return result;
  }

  static bool _evalCondition(Map<String, dynamic> cond) {
    final lhsVal = (cond['lhsVal'] as num? ?? 0.0).toDouble();
    final rhsVal = (cond['rhsVal'] as num? ?? 0.0).toDouble();
    final op = cond['op'] as String? ?? '==';
    if (op == '==') return (lhsVal - rhsVal).abs() < 1e-10;
    if (op == '!=') return (lhsVal - rhsVal).abs() >= 1e-10;
    if (op == '>') return lhsVal > rhsVal;
    if (op == '>=') return lhsVal >= rhsVal;
    if (op == '<') return lhsVal < rhsVal;
    if (op == '<=') return lhsVal <= rhsVal;
    if (op == 'between') {
      final rhs2 = (cond['rhsVal2'] as num? ?? 0.0).toDouble();
      return lhsVal >= rhsVal && lhsVal <= rhs2;
    }
    if (op == 'not_between') {
      final rhs2 = (cond['rhsVal2'] as num? ?? 0.0).toDouble();
      return lhsVal < rhsVal || lhsVal > rhs2;
    }
    if (op == 'divisible') {
      if (rhsVal == 0) return false;
      return (lhsVal % rhsVal).abs() < 1e-10;
    }
    return false;
  }

  /// 論理式全体の式文字列を生成する
  static String _buildLogicExprString(Map<String, dynamic> item) {
    final conditions = item['conditions'] as List? ?? [];
    final chainOps = item['chainOps'] as List? ?? [];
    if (conditions.isEmpty) return '(条件なし)';
    final parts = <String>[];
    for (int i = 0; i < conditions.length; i++) {
      parts.add(
        _buildConditionString(Map<String, dynamic>.from(conditions[i] as Map)),
      );
      if (i < chainOps.length) {
        parts.add((chainOps[i] as String?) == 'OR' ? 'または' : 'かつ');
      }
    }
    return parts.join(' ');
  }

  static String _buildConditionString(Map<String, dynamic> cond) {
    final lhsLabel = cond['lhsLabel'] as String? ?? '';
    final lhsVal = (cond['lhsVal'] as num? ?? 0.0).toDouble();
    final rhsLabel = cond['rhsLabel'] as String? ?? '';
    final rhsVal = (cond['rhsVal'] as num? ?? 0.0).toDouble();
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

    final lhs = lhsLabel.isNotEmpty ? lhsLabel : fmtN(lhsVal);
    final rhs = rhsLabel.isNotEmpty ? rhsLabel : fmtN(rhsVal);
    if (op == 'between' || op == 'not_between') {
      final rhs2Label = cond['rhsLabel2'] as String? ?? '';
      final rhs2Val = (cond['rhsVal2'] as num? ?? 0.0).toDouble();
      final rhs2 = rhs2Label.isNotEmpty ? rhs2Label : fmtN(rhs2Val);
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

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
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
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.calculate_outlined,
                      color: Colors.blueAccent,
                    ),
                    tooltip: '計算機',
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
        ),
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
                _shareAsCsvQr();
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

  void _applyLinkDestsForRow(
    int srcRowIdx,
    String srcField,
    Set<String> selectedDests,
  ) {
    final items = _items;
    final newItems = items
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    for (int i = 0; i < newItems.length; i++) {
      if (i == srcRowIdx) continue;
      final item = newItems[i];
      final origItem = items[i];
      bool wasLinked(Map? src) =>
          src != null &&
          src['rowIdx'] == srcRowIdx &&
          src['target'] == srcField;

      // input
      final inputDest = '${i}_input';
      final inputWas =
          origItem['inputLink'] == true &&
          wasLinked(origItem['inputLinkSource'] as Map?);
      if (selectedDests.contains(inputDest)) {
        item['inputLink'] = true;
        item['inputLinkSource'] = {'rowIdx': srcRowIdx, 'target': srcField};
      } else if (inputWas) {
        item['inputLink'] = false;
        item['inputLinkSource'] = null;
      }

      // operand
      final operandDest = '${i}_operand';
      final operandWas =
          origItem['operandLink'] == true &&
          wasLinked(origItem['operandLinkSource'] as Map?);
      if (selectedDests.contains(operandDest)) {
        item['operandLink'] = true;
        item['operandLinkSource'] = {'rowIdx': srcRowIdx, 'target': srcField};
      } else if (operandWas) {
        item['operandLink'] = false;
        item['operandLinkSource'] = null;
      }

      // others
      final othersList = ((item['others'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      )).toList();
      final origOthersList = origItem['others'] as List? ?? [];
      for (int j = 0; j < othersList.length; j++) {
        final otherDest = '${i}_other_$j';
        final origO = j < origOthersList.length ? origOthersList[j] as Map : {};
        final otherWas =
            origO['valLink'] == true &&
            wasLinked(origO['valLinkSource'] as Map?);
        if (selectedDests.contains(otherDest)) {
          othersList[j]['valLink'] = true;
          othersList[j]['valLinkSource'] = {
            'rowIdx': srcRowIdx,
            'target': srcField,
          };
        } else if (otherWas) {
          othersList[j]['valLink'] = false;
          othersList[j]['valLinkSource'] = null;
        }
      }
      item['others'] = othersList;
    }
    widget.onUpdate({...widget.config.data, 'items': newItems});
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
        final allConsts = [...srcConstants, ...(widget.globalConstants ?? [])];
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

  /// 別シートの行/フィールドのリンク先を現在シートに保存する
  void _applyLinkDestsForExternalRow(
    String sheetId,
    int srcRowIdx,
    String srcField,
    Set<String> selectedDests,
  ) {
    final linkSource = {
      'sheetId': sheetId,
      'rowIdx': srcRowIdx,
      'target': srcField,
    };
    final items = _items;
    final newItems = items
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    for (int i = 0; i < newItems.length; i++) {
      final item = newItems[i];
      final origItem = items[i];
      bool wasLinked(Map? src) =>
          src != null &&
          src['sheetId'] == sheetId &&
          src['rowIdx'] == srcRowIdx &&
          src['target'] == srcField;

      final inputDest = '${i}_input';
      final inputWas =
          origItem['inputLink'] == true &&
          wasLinked(origItem['inputLinkSource'] as Map?);
      if (selectedDests.contains(inputDest)) {
        item['inputLink'] = true;
        item['inputLinkSource'] = linkSource;
      } else if (inputWas) {
        item['inputLink'] = false;
        item['inputLinkSource'] = null;
      }

      final operandDest = '${i}_operand';
      final operandWas =
          origItem['operandLink'] == true &&
          wasLinked(origItem['operandLinkSource'] as Map?);
      if (selectedDests.contains(operandDest)) {
        item['operandLink'] = true;
        item['operandLinkSource'] = linkSource;
      } else if (operandWas) {
        item['operandLink'] = false;
        item['operandLinkSource'] = null;
      }

      final othersList = ((item['others'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      )).toList();
      final origOthersList = origItem['others'] as List? ?? [];
      for (int j = 0; j < othersList.length; j++) {
        final otherDest = '${i}_other_$j';
        final origO = j < origOthersList.length ? origOthersList[j] as Map : {};
        final otherWas =
            origO['valLink'] == true &&
            wasLinked(origO['valLinkSource'] as Map?);
        if (selectedDests.contains(otherDest)) {
          othersList[j]['valLink'] = true;
          othersList[j]['valLinkSource'] = linkSource;
        } else if (otherWas) {
          othersList[j]['valLink'] = false;
          othersList[j]['valLinkSource'] = null;
        }
      }
      item['others'] = othersList;
    }
    widget.onUpdate({...widget.config.data, 'items': newItems});
  }

  void _showSheetLinkSettingsDialog() {
    final items = _items;
    if (items.isEmpty) return;

    int? selectedSrcCalcIdx = items.isNotEmpty ? 0 : null;
    String selectedSrcField = 'result';
    // 初期表示時: tab0 で最初の式に既存リンク先を事前設定
    Set<String> selectedDests = selectedSrcCalcIdx != null
        ? _calcSelectedDestsForRow(selectedSrcCalcIdx, 'result')
        : {};
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
        if (sid == null) return _calcSelectedDestsForRow(calcIdx, fld);
        return _calcSelectedDestsForExternalRow(sid, calcIdx, fld);
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
      if (v == v.truncateToDouble() && v.abs() < 1e12) {
        return v.toStringAsFixed(0);
      }
      return v.toStringAsFixed(precision);
    }

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDs) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
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
                                              children: List.generate(items.length, (
                                                i,
                                              ) {
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
                                              }),
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
                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  itemCount: destItems.length,
                                  itemBuilder: (context, i) {
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
                                                final valStr = fmtDest(
                                                  df['val'] as double? ?? 0.0,
                                                );
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
                                                      fmtDest(resultVal),
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

    // 表示順をコンパクト形式で含める（スタンドアロンメモがある場合のみ）
    List<Map<String, dynamic>>? qrDOrder;
    if (standaloneItems.isNotEmpty) {
      final displayOrder = _effectiveDisplayOrder;
      // standaloneItems の itemId → 配列インデックスのマップを作成
      final sItemIdToIdx = <String, int>{};
      for (int si = 0; si < standaloneItems.length; si++) {
        final id = standaloneItems[si]['id'] as String? ?? '';
        sItemIdToIdx[id] = si;
      }
      qrDOrder = displayOrder
          .map((e) {
            if (e['type'] == 'calc') {
              return {'c': e['calcIdx'] as int};
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
    final logicItems = _logicItems;
    final qrLogicItems = logicItems.isNotEmpty
        ? logicItems.map((l) {
            final conditions = (l['conditions'] as List? ?? [])
                .map((c) => Map<String, dynamic>.from(c as Map))
                .toList();
            final chainOps = (l['chainOps'] as List? ?? [])
                .map((e) => e as String)
                .toList();
            return {
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
          // 履歴に保存
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
            ipParts.add(_fmtCalc(_calcTermValues[i]));
            if (i < _calcTermOps.length) ipParts.add(_calcTermOps[i]);
          }
          inProgressExpr = ipParts.join(' ');
        }
        final String subtitle = _calcHasResult ? _calcExprStr : inProgressExpr;

        Widget content = SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 46),
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
                    // AIカウントアイコンボタン（横長）
                    GestureDetector(
                      onTap: _isAiCounting ? null : _showAiCountDialog,
                      child: AnimatedOpacity(
                        opacity: _isAiCounting ? 0.4 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          width: 70,
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
                              Icon(
                                Icons.camera_alt_outlined,
                                color: Colors.tealAccent,
                                size: 22,
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
                    const SizedBox(width: 16),
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
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
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
                                _calcDisplay,
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

  // ── 閲覧モード用の定数セクション（読み取り専用） ──────────────────────────
  Widget _buildViewModeConstantsSection(
    List<Map<String, dynamic>> constants,
    bool isDark,
  ) {
    final fgColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white54 : Colors.black45;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amberAccent.withOpacity(isDark ? 0.07 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amberAccent.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.push_pin_outlined,
                size: 12,
                color: Colors.amberAccent,
              ),
              const SizedBox(width: 5),
              Text(
                '定数',
                style: TextStyle(
                  color: Colors.amberAccent,
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
                  ? value.toInt().toString()
                  : value
                        .toStringAsFixed(4)
                        .replaceAll(RegExp(r'0+$'), '')
                        .replaceAll(RegExp(r'\.$'), '');
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: Colors.amberAccent.withOpacity(0.3),
                  ),
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
                        fontWeight: FontWeight.bold,
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

  // ── 表モード ──────────────────────────────────────────────────────────────
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
                final exprStr = _buildLogicExprString(logicItem);
                final isTrue = _evalLogicItem(logicItem);
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

  // ── 閲覧モード用ウィジェット ──
  Widget _buildViewModeWidget() {
    final items = _items;
    final constants = _constants;
    final standaloneItems = _standaloneItems;
    final displayOrder = _effectiveDisplayOrder;
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
        return v.toInt().toString();
      }
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
      final double operandPow = (item['operandPowExp'] as num? ?? 2.0)
          .toDouble();

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

    final bgColor = bgColorValue != null
        ? Color(bgColorValue)
        : (isDark ? const Color(0xFF1A1A22) : const Color(0xFFFAFAFA));

    return Container(
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
                '内容がありません',
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
                  final exprStr = _buildLogicExprString(logicItem);
                  final isTrue = _evalLogicItem(logicItem);
                  final logicName = logicItem['name'] as String? ?? '';
                  widgets.add(
                    Padding(
                      padding: const EdgeInsets.only(left: 10, bottom: 4),
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
                final formula = buildFormula(item, resolved, precision);
                final resultStr =
                    '${fmtNum(result, precision)}${unitResult.isNotEmpty ? ' $unitResult' : ''}';

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
                              TextSpan(
                                text: formula,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                  fontSize: 14,
                                  fontFamily: 'ZenOldMincho',
                                  height: 1.5,
                                ),
                              ),
                              TextSpan(
                                text: ' = ',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.black12,
                                  fontSize: 16,
                                ),
                              ),
                              TextSpan(
                                text: resultStr,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'ZenOldMincho',
                                  letterSpacing: -0.5,
                                ),
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
    );
  }

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
                const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                              padding: EdgeInsets.zero,
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
                                            onUpdate: (data) =>
                                                _updateLogicItem(itemId, data),
                                            onDelete: () =>
                                                _deleteLogicItem(itemId),
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
    widget.onAiGeneratingChanged?.call(true);

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

// ── 列ラベル単体編集シート ───────────────────────────────────────────────────
class _ColumnLabelEditSheet extends StatefulWidget {
  final String columnKey;
  final String currentLabel;
  final List<Map<String, dynamic>> allColumns;

  const _ColumnLabelEditSheet({
    required this.columnKey,
    required this.currentLabel,
    required this.allColumns,
  });

  @override
  State<_ColumnLabelEditSheet> createState() => _ColumnLabelEditSheetState();
}

class _ColumnLabelEditSheetState extends State<_ColumnLabelEditSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentLabel);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                  '列名の編集',
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
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 20),
            decoration: InputDecoration(
              hintText: '列名',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E81FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                final newColConfig = widget.allColumns.map((col) {
                  final key = col['key'] as String;
                  return <String, dynamic>{
                    'key': key,
                    'label': key == widget.columnKey
                        ? _ctrl.text
                        : col['label'],
                    'visible': col['visible'] ?? true,
                  };
                }).toList();
                Navigator.pop(context, newColConfig);
              },
              child: const Text('保存', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 列設定シート（表示/非表示・列名一括編集） ────────────────────────────────
class _ColumnSettingsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> columns;

  const _ColumnSettingsSheet({required this.columns});

  @override
  State<_ColumnSettingsSheet> createState() => _ColumnSettingsSheetState();
}

class _ColumnSettingsSheetState extends State<_ColumnSettingsSheet> {
  late final List<Map<String, dynamic>> _localCols;
  late final Map<String, TextEditingController> _labelControllers;

  @override
  void initState() {
    super.initState();
    _localCols = widget.columns
        .map((c) => Map<String, dynamic>.from(c))
        .toList();
    _labelControllers = {
      for (final c in _localCols)
        c['key'] as String: TextEditingController(text: c['label'] as String),
    };
  }

  @override
  void dispose() {
    for (final ctrl in _labelControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _save() {
    final newColConfig = _localCols.map((c) {
      final key = c['key'] as String;
      return <String, dynamic>{
        'key': key,
        'label': _labelControllers[key]!.text,
        'visible': c['visible'] as bool,
      };
    }).toList();
    Navigator.pop(context, newColConfig);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '列の設定',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _save,
                  child: const Text(
                    '保存',
                    style: TextStyle(
                      color: Color(0xFF5E81FF),
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
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: _localCols.length,
              itemBuilder: (ctx, i) {
                final col = _localCols[i];
                final key = col['key'] as String;
                final visible = col['visible'] as bool;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Switch(
                        value: visible,
                        onChanged: (val) => setState(
                          () => _localCols[i] = {
                            ..._localCols[i],
                            'visible': val,
                          },
                        ),
                        activeThumbColor: const Color(0xFF5E81FF),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _labelControllers[key],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: '列名',
                            hintStyle: const TextStyle(color: Colors.white24),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            enabled: visible,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 列表示/非表示アラートダイアログ ──────────────────────────────────────────
class _ColumnVisibilityDialog extends StatefulWidget {
  final List<Map<String, dynamic>> columns;
  final void Function(List<Map<String, dynamic>>) onSave;

  const _ColumnVisibilityDialog({required this.columns, required this.onSave});

  @override
  State<_ColumnVisibilityDialog> createState() =>
      _ColumnVisibilityDialogState();
}

class _ColumnVisibilityDialogState extends State<_ColumnVisibilityDialog> {
  late List<Map<String, dynamic>> _localCols;

  @override
  void initState() {
    super.initState();
    _localCols = widget.columns
        .map((c) => Map<String, dynamic>.from(c))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        '列の表示設定',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'ZenOldMincho',
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 280,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _localCols.map((col) {
              final key = col['key'] as String;
              final label = col['label'] as String;
              final visible = col['visible'] as bool;
              return SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'ZenOldMincho',
                    fontSize: 14,
                  ),
                ),
                value: visible,
                onChanged: (val) => setState(() {
                  _localCols = _localCols.map((c) {
                    if (c['key'] == key) return {...c, 'visible': val};
                    return c;
                  }).toList();
                }),
                activeThumbColor: const Color(0xFF5E81FF),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onSave(_localCols);
          },
          child: const Text(
            '保存',
            style: TextStyle(
              color: Color(0xFF5E81FF),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// ── 論理式行ウィジェット ──────────────────────────────────────────────────────
class _LogicRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDark;
  final void Function(Map<String, dynamic>) onUpdate;
  final VoidCallback onDelete;
  final Widget? dragHandle;

  const _LogicRow({
    required this.item,
    required this.isDark,
    required this.onUpdate,
    required this.onDelete,
    this.dragHandle,
  });

  void _showEditDialog(BuildContext context) {
    showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => _LogicItemEditDialog(initial: item),
    ).then((result) {
      if (result == null) return;
      onUpdate(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? '';
    final exprStr = _CalculatorWidgetState._buildLogicExprString(item);
    final isTrue = _CalculatorWidgetState._evalLogicItem(item);
    return GestureDetector(
      onTap: () => _showEditDialog(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.deepPurpleAccent.withOpacity(0.07)
              : Colors.deepPurple.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? Colors.deepPurpleAccent.withOpacity(0.25)
                : Colors.deepPurple.withOpacity(0.18),
          ),
        ),
        child: Row(
          children: [
            if (dragHandle != null) ...[dragHandle!, const SizedBox(width: 4)],
            Icon(
              Icons.rule_rounded,
              size: 14,
              color: isDark
                  ? Colors.deepPurpleAccent.withOpacity(0.7)
                  : Colors.deepPurple.withOpacity(0.6),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name.isNotEmpty)
                    Text(
                      name,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.5)
                            : Colors.black54,
                        fontSize: 11,
                        fontFamily: 'ZenOldMincho',
                      ),
                    ),
                  Text(
                    exprStr,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.82)
                          : Colors.black.withOpacity(0.75),
                      fontSize: 13,
                      fontFamily: 'ZenOldMincho',
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isTrue
                    ? (isDark
                          ? Colors.greenAccent.withOpacity(0.15)
                          : Colors.green.withOpacity(0.12))
                    : (isDark
                          ? Colors.redAccent.withOpacity(0.15)
                          : Colors.red.withOpacity(0.10)),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isTrue
                      ? (isDark
                            ? Colors.greenAccent.withOpacity(0.4)
                            : Colors.green.withOpacity(0.35))
                      : (isDark
                            ? Colors.redAccent.withOpacity(0.4)
                            : Colors.red.withOpacity(0.35)),
                ),
              ),
              child: Text(
                isTrue ? '真' : '偽',
                style: TextStyle(
                  color: isTrue
                      ? (isDark ? Colors.greenAccent : Colors.green.shade700)
                      : (isDark ? Colors.redAccent : Colors.red.shade700),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'ZenOldMincho',
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDelete,
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 論理式編集ダイアログ ──────────────────────────────────────────────────────
class _LogicItemEditDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;

  const _LogicItemEditDialog({this.initial});

  @override
  State<_LogicItemEditDialog> createState() => _LogicItemEditDialogState();
}

class _LogicItemEditDialogState extends State<_LogicItemEditDialog> {
  late TextEditingController _nameCtrl;
  late List<Map<String, dynamic>> _conditions;
  late List<String> _chainOps;

  static const List<Map<String, String>> _ops = [
    {'value': '>', 'label': '> (より大きい)'},
    {'value': '>=', 'label': '≥ (以上)'},
    {'value': '<', 'label': '< (より小さい)'},
    {'value': '<=', 'label': '≤ (以下)'},
    {'value': '==', 'label': '= (等しい)'},
    {'value': '!=', 'label': '≠ (等しくない)'},
    {'value': 'between', 'label': '範囲内 (a ≤ x ≤ b)'},
    {'value': 'not_between', 'label': '範囲外 (x < a または x > b)'},
    {'value': 'divisible', 'label': '倍数判定 (x が n の倍数)'},
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _nameCtrl = TextEditingController(text: init?['name'] as String? ?? '');
    if (init != null && (init['conditions'] as List? ?? []).isNotEmpty) {
      _conditions = (init['conditions'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _chainOps = ((init['chainOps'] as List? ?? []))
          .map((e) => e as String)
          .toList();
    } else {
      _conditions = [
        {
          'lhsVal': 0.0,
          'lhsLabel': '',
          'op': '>',
          'rhsVal': 0.0,
          'rhsLabel': '',
          'rhsVal2': 0.0,
          'rhsLabel2': '',
        },
      ];
      _chainOps = [];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildResult() => {
    'name': _nameCtrl.text.trim(),
    'conditions': _conditions,
    'chainOps': _chainOps,
  };

  void _addCondition() {
    setState(() {
      _chainOps.add('AND');
      _conditions.add({
        'lhsVal': 0.0,
        'lhsLabel': '',
        'op': '>',
        'rhsVal': 0.0,
        'rhsLabel': '',
        'rhsVal2': 0.0,
        'rhsLabel2': '',
      });
    });
  }

  void _removeCondition(int idx) {
    if (_conditions.length <= 1) return;
    setState(() {
      _conditions.removeAt(idx);
      if (idx > 0 && idx - 1 < _chainOps.length) {
        _chainOps.removeAt(idx - 1);
      } else if (_chainOps.isNotEmpty) {
        _chainOps.removeAt(0);
      }
    });
  }

  Widget _buildConditionEditor(int idx) {
    final cond = _conditions[idx];
    final bool isBetween =
        cond['op'] == 'between' || cond['op'] == 'not_between';
    final bool isDivisible = cond['op'] == 'divisible';

    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '条件 ${idx + 1}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const Spacer(),
                if (_conditions.length > 1)
                  GestureDetector(
                    onTap: () => _removeCondition(idx),
                    child: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.white38,
                      size: 18,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '左辺 (値)',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 4),
            _NumLabelField(
              initVal: (cond['lhsVal'] as num? ?? 0.0).toDouble(),
              initLabel: cond['lhsLabel'] as String? ?? '',
              onChanged: (v, l) => setState(() {
                _conditions[idx]['lhsVal'] = v;
                _conditions[idx]['lhsLabel'] = l;
              }),
            ),
            const SizedBox(height: 8),
            const Text(
              '演算子',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: cond['op'] as String? ?? '>',
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1A2E),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
              items: _ops
                  .map(
                    (o) => DropdownMenuItem(
                      value: o['value'],
                      child: Text(
                        o['label']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _conditions[idx]['op'] = v),
            ),
            const SizedBox(height: 8),
            if (!isDivisible) ...[
              Text(
                isBetween ? '下限値 (a)' : '右辺 (値)',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 4),
              _NumLabelField(
                initVal: (cond['rhsVal'] as num? ?? 0.0).toDouble(),
                initLabel: cond['rhsLabel'] as String? ?? '',
                onChanged: (v, l) => setState(() {
                  _conditions[idx]['rhsVal'] = v;
                  _conditions[idx]['rhsLabel'] = l;
                }),
              ),
              if (isBetween) ...[
                const SizedBox(height: 8),
                const Text(
                  '上限値 (b)',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 4),
                _NumLabelField(
                  initVal: (cond['rhsVal2'] as num? ?? 0.0).toDouble(),
                  initLabel: cond['rhsLabel2'] as String? ?? '',
                  onChanged: (v, l) => setState(() {
                    _conditions[idx]['rhsVal2'] = v;
                    _conditions[idx]['rhsLabel2'] = l;
                  }),
                ),
              ],
            ] else ...[
              const Text(
                '除数 (n)',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 4),
              _NumLabelField(
                initVal: (cond['rhsVal'] as num? ?? 0.0).toDouble(),
                initLabel: cond['rhsLabel'] as String? ?? '',
                onChanged: (v, l) => setState(() {
                  _conditions[idx]['rhsVal'] = v;
                  _conditions[idx]['rhsLabel'] = l;
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _buildResult();
    final isTrue = _CalculatorWidgetState._evalLogicItem(preview);
    final exprStr = _CalculatorWidgetState._buildLogicExprString(preview);

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: const Row(
        children: [
          Icon(Icons.rule_rounded, color: Colors.deepPurpleAccent, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '論理式を編集',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              const Text(
                '名前 (省略可)',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '例: 正常範囲チェック',
                  hintStyle: const TextStyle(color: Colors.white24),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFF5E81FF)),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              ...List.generate(
                _conditions.length,
                (idx) => Column(
                  children: [
                    if (idx > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final op in ['AND', 'OR'])
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: ChoiceChip(
                                label: Text(
                                  op == 'AND' ? 'かつ (AND)' : 'または (OR)',
                                  style: TextStyle(
                                    color: _chainOps[idx - 1] == op
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                selected: _chainOps[idx - 1] == op,
                                selectedColor: const Color(0xFF5E81FF),
                                backgroundColor: Colors.white10,
                                onSelected: (_) =>
                                    setState(() => _chainOps[idx - 1] = op),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    _buildConditionEditor(idx),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _addCondition,
                icon: const Icon(
                  Icons.add_circle_outline,
                  size: 16,
                  color: Color(0xFF5E81FF),
                ),
                label: const Text(
                  '条件を追加',
                  style: TextStyle(color: Color(0xFF5E81FF), fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(height: 12),
              // リアルタイムプレビュー
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        exprStr,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontFamily: 'ZenOldMincho',
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isTrue
                            ? Colors.greenAccent.withOpacity(0.15)
                            : Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isTrue
                              ? Colors.greenAccent.withOpacity(0.4)
                              : Colors.redAccent.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        isTrue ? '真' : '偽',
                        style: TextStyle(
                          color: isTrue ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'ZenOldMincho',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _buildResult()),
          child: const Text(
            '保存',
            style: TextStyle(
              color: Color(0xFF5E81FF),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// ── 数値＋ラベル入力フィールド ────────────────────────────────────────────────
class _NumLabelField extends StatefulWidget {
  final double initVal;
  final String initLabel;
  final void Function(double val, String label) onChanged;

  const _NumLabelField({
    required this.initVal,
    required this.initLabel,
    required this.onChanged,
  });

  @override
  State<_NumLabelField> createState() => _NumLabelFieldState();
}

class _NumLabelFieldState extends State<_NumLabelField> {
  late TextEditingController _valCtrl;
  late TextEditingController _labelCtrl;

  @override
  void initState() {
    super.initState();
    String fmtN(double v) {
      if (v == v.truncateToDouble() && v.abs() < 1e12) {
        return v.toInt().toString();
      }
      return v.toString();
    }

    _valCtrl = TextEditingController(text: fmtN(widget.initVal));
    _labelCtrl = TextEditingController(text: widget.initLabel);
  }

  @override
  void dispose() {
    _valCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(double.tryParse(_valCtrl.text) ?? 0.0, _labelCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: TextField(
            controller: _valCtrl,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: '数値',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFF5E81FF)),
              ),
            ),
            onChanged: (_) => _notify(),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: _labelCtrl,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'ラベル (省略可)',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFF5E81FF)),
              ),
            ),
            onChanged: (_) => _notify(),
          ),
        ),
      ],
    );
  }
}
