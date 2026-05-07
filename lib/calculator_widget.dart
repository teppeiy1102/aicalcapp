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

  /// tableColumnConfig から項名マップを返す
  Map<String, String> get _effectiveTermLabels {
    final rawColConfig = widget.config.data['tableColumnConfig'] as List<dynamic>? ?? [];
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
    widget.onUpdate({...widget.config.data, 'items': newItems, 'displayOrder': order});
  }

  void _addItemFromMap(Map<String, dynamic> item) {
    final newItems = List<Map<String, dynamic>>.from(_items);
    final newCalcIdx = newItems.length;
    newItems.add(item);
    final order = List<Map<String, dynamic>>.from(_effectiveDisplayOrder);
    order.add({'type': 'calc', 'calcIdx': newCalcIdx});
    widget.onUpdate({...widget.config.data, 'items': newItems, 'displayOrder': order});
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
    widget.onUpdate({...widget.config.data, 'items': newItems, 'displayOrder': order, 'memos': _memos});
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
        builder: (ctx) => _MemoEditDialog(
          initialText: '',
          title: 'メモを追加',
          saveLabel: '追加',
        ),
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
    final allVisible =
        items.every((item) => item['nameVisible'] as bool? ?? true);
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
    consts.add({
      'id': newId,
      'name': '定数${consts.length + 1}',
      'value': 0.0,
    });
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
        context: this.context,
        builder: (ctx) => _MemoEditDialog(
          initialText: '',
          title: 'メモを追加',
          saveLabel: '追加',
        ),
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
      order = [{'type': 'calc', 'calcIdx': 0}];
    }
    // 削除した計算のメモも削除し、以降のインデックスを繰り上げ
    final newMemos = _remapMemoIndices(_memos, (old) {
      if (old == calcIdx) return null;
      if (old > calcIdx) return old - 1;
      return old;
    });
    widget.onUpdate({...widget.config.data, 'items': newItems, 'displayOrder': order, 'memos': newMemos});
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
          backgroundColor: const Color(0xFF1A2A4A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          backgroundColor: const Color(0xFF2A1A0A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      if (order[i]['type'] == 'calc' && order[i]['calcIdx'] == insertAfterCalcIdx) {
        insertPos = i + 1;
        break;
      }
    }
    order.insert(insertPos, {'type': 'calc', 'calcIdx': newCalcIdx});
    widget.onUpdate({...widget.config.data, 'items': newItems, 'displayOrder': order, 'memos': _memos});
  }

  /// 表示順上の from 位置を to 位置へ移動する（displayOrder のみ更新）
  void _moveItem(int from, int to) {
    final order = List<Map<String, dynamic>>.from(_effectiveDisplayOrder);
    if (from < 0 || to < 0 || from >= order.length || to >= order.length) return;
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
                (othersList[otherIdx] as Map)['valLink'] == true)
              return item;
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
      backgroundColor:Colors.black87,
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
  Widget _buildConstantsSection(List<Map<String, dynamic>> constants, bool isDark) {
    final fgColor = isDark ? Colors.white :Colors.black87;
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
              const Icon(Icons.push_pin_outlined, size: 14, color: Colors.amberAccent),
              const SizedBox(width: 6),
              Text('定数', style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: _addConstant,
                child: const Icon(Icons.add_rounded, size: 18, color: Colors.amberAccent),
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
              final valStr = value == value.truncateToDouble() && value.abs() < 1e12
                  ? value.toInt().toString()
                  : value.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
              return GestureDetector(
                onTap: () => _editConstant(idx),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amberAccent.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, style: TextStyle(color: subColor, fontSize: 12)),
                      const SizedBox(width: 6),
                      Text('=', style: TextStyle(color: subColor, fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(valStr, style: TextStyle(color: fgColor, fontSize: 13, fontWeight: FontWeight.bold)),
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
    final valCtrl = TextEditingController(text: (c['value'] as num? ?? 0.0).toString());

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
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('定数の設定', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
            const Text('名前', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: '例: 税率', hintStyle: TextStyle(color: Colors.white24)),
            ),
            const SizedBox(height: 16),
            const Text('値', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: valCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                    decoration: const InputDecoration(hintText: '0.0', hintStyle: TextStyle(color: Colors.white24)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calculate_outlined, color: Colors.blueAccent),
                  tooltip: '計算機',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.black87,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (calcCtx) => _MiniCalcSheet(onResult: (v) {
                        setSheetState(() {
                          if (v == v.truncateToDouble() && v.abs() < 1e15) {
                            valCtrl.text = v.toInt().toString();
                          } else {
                            valCtrl.text = v.toStringAsFixed(15)
                                .replaceAll(RegExp(r'0+$'), '')
                                .replaceAll(RegExp(r'\.$'), '');
                          }
                        });
                      }),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.backspace_outlined, color: Colors.white54),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amberAccent.withOpacity(0.4)),
                        ),
                        child: Text(label,
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
                        valCtrl.text = value == value.truncateToDouble() && value.abs() < 1e15
                            ? value.toInt().toString()
                            : value.toString();
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5E81FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF5E81FF).withOpacity(0.4)),
                        ),
                        child: Text(name,
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
                  child: const Text('削除', style: TextStyle(color: Colors.redAccent)),
                ),
                const Spacer(),
                SizedBox(
                  width: 120,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final allNamesVisible =
        items.every((item) => item['nameVisible'] as bool? ?? true);
    final wrapFormula = _wrapFormula;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.push_pin_outlined, color: Colors.amberAccent),
              title: const Text('定数を追加', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _addConstant();
              },
            ),
            ListTile(
              leading: const Icon(Icons.sticky_note_2_outlined, color: Colors.tealAccent),
              title: const Text('メモを追加', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _addStandaloneMemo();
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
                allNamesVisible
                    ? 'すべての計算名を非表示'
                    : 'すべての計算名を表示',
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
                  ? const Icon(Icons.check_rounded, color: Colors.blueAccent, size: 18)
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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

    // ---- パス1: 暫定計算（リンクなし）----
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

    // ---- パス2: 反復収束によりチェーンリンクを正しく解決 ----
    // finalResults をあらかじめ暫定値で初期化しておくことで
    // 前方参照（移動後に順序逆転したチェーン）でも正しい値が伝播する
    final List<double> finalResults = List<double>.from(provisionalResults);
    var resolvedRows = <Map<String, dynamic>>[];

    // ---- リンク解決ヘルパー ----
    double resolveLink(
      Map<String, dynamic>? source,
      bool isLink,
      double fallback,
    ) {
      if (!isLink) return fallback;
      if (source == null) {
        return finalResults.isNotEmpty ? finalResults.last : fallback;
      }
      final int sRowIdx = source['rowIdx'] as int? ?? 0;
      final String sTarget = source['target'] as String? ?? 'result';
      if (sRowIdx < 0 || sRowIdx >= items.length) return fallback;
      final sItem = items[sRowIdx];
      if (sTarget == 'result') return finalResults[sRowIdx];
      if (sTarget == 'input') return (sItem['input'] as num? ?? 0.0).toDouble();
      if (sTarget == 'operand')
        return (sItem['operand'] as num? ?? 0.0).toDouble();
      if (sTarget.startsWith('other_')) {
        final idx = int.tryParse(sTarget.split('_')[1]) ?? 0;
        final sOthers = sItem['others'] as List? ?? [];
        if (idx < sOthers.length) {
          return (sOthers[idx]['val'] as num? ?? 0.0).toDouble();
        }
      }
      return fallback;
    }

    // 最大 items.length 回の反復で任意のチェーン深さを収束させる
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

        final inputTransform = item['inputTransform'] as String?;
        final inputPowExp = (item['inputPowExp'] as num? ?? 2.0).toDouble();
        final operandTransform = item['operandTransform'] as String?;
        final operandPowExp = (item['operandPowExp'] as num? ?? 2.0).toDouble();

        final inputForCalc = _CalculatorRow._applyTermTransform(
          inputValue,
          inputTransform,
          inputPowExp,
        );
        final operandForCalc = _CalculatorRow._applyTermTransform(
          operandValue,
          operandTransform,
          operandPowExp,
        );
        final othersForCalc = othersValue.map((e) {
          final m = Map<String, dynamic>.from(e);
          final t = m['transform'] as String?;
          final exp = (m['powExp'] as num? ?? 2.0).toDouble();
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

    // ---- CSV 文字列組み立て ----
    String escapeCsv(String s) {
      if (s.contains(',') || s.contains('"') || s.contains('\n')) {
        return '"${s.replaceAll('"', '""')}"';
      }
      return s;
    }

    String fmtNum(double v, int precision) {
      if (v == v.truncateToDouble() && v.abs() < 1e12)
        return v.toInt().toString();
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
      final result = finalResults[i];
      final resultStr = '${fmtNum(result, precision)}$unitResult';

      final double input = resolved['input'] as double;
      final double operand = resolved['operand'] as double;
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

      buf.writeln(
        '${escapeCsv(name)},${escapeCsv(formula)},${escapeCsv(resultStr)}',
      );
    }

    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSVをクリップボードにコピーしました'),
        backgroundColor: Color(0xFF2A2A3A),
      ),
    );
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

        final textColor = isDark ? Colors.white : Colors.black87;
        final keyBg = isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.07);
        final opColor = isDark ? Colors.blueAccent : Colors.black87;
        final eqColor = isDark ? Colors.orangeAccent : Colors.black87;

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
                          width:70,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(isDark ? 0.25 : 0.12),
                            border: Border.all(
                              color: Colors.tealAccent.withOpacity(0.45),
                              width: 0.8,
                            ),
                            shape: BoxShape.circle
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt_outlined,
                                color: Colors.tealAccent,
                                size:22,
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
                                  fontSize: displayFontSize,
                                  fontWeight: FontWeight.bold,
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
                    calcKey('=', bg: eqColor.withOpacity(0.8), fg: Colors.white),
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
  Widget _buildViewModeConstantsSection(List<Map<String, dynamic>> constants, bool isDark) {
    final fgColor = isDark ? Colors.white : Colors.black87;
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
              const Icon(Icons.push_pin_outlined, size: 12, color: Colors.amberAccent),
              const SizedBox(width: 5),
              Text('定数', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'ZenOldMincho')),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 5,
            children: constants.map((c) {
              final name = c['name'] as String? ?? '';
              final value = (c['value'] as num? ?? 0.0).toDouble();
              final valStr = value == value.truncateToDouble() && value.abs() < 1e12
                  ? value.toInt().toString()
                  : value.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: TextStyle(color: subColor, fontSize: 11, fontFamily: 'ZenOldMincho')),
                    const SizedBox(width: 5),
                    Text('=', style: TextStyle(color: subColor, fontSize: 11, fontFamily: 'ZenOldMincho')),
                    const SizedBox(width: 3),
                    Text(valStr, style: TextStyle(color: fgColor, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'ZenOldMincho')),
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
        ? _kNoteColorPresets.firstWhere((p) => p.value == bgColorValue, orElse: () => _kNoteColorPresets.first).isDark
        : true;
    final bgColor = bgColorValue != null ? Color(bgColorValue) : (isDark ? const Color(0xFF1A1A22) : const Color(0xFFFAFAFA));

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
        _CalculatorRow._applyTermTransform((pItem['input'] as num? ?? 0.0).toDouble(), pItem['inputTransform'] as String?, (pItem['inputPowExp'] as num? ?? 2.0).toDouble()),
        pItem['op'] as String? ?? '+',
        _CalculatorRow._applyTermTransform((pItem['operand'] as num? ?? 0.0).toDouble(), pItem['operandTransform'] as String?, (pItem['operandPowExp'] as num? ?? 2.0).toDouble()),
        pOthers, pItem['brackets'] as List? ?? [],
      );
    }
    final List<double> finalResults = List<double>.from(provisionalResults);
    // リンク解決後の各行の実際の値を保持（セル表示用）
    final resolvedRows = List<Map<String, dynamic>>.generate(
      items.length,
      (i) => <String, dynamic>{
        'input': (items[i]['input'] as num? ?? 0.0).toDouble(),
        'operand': (items[i]['operand'] as num? ?? 0.0).toDouble(),
        'others': List<Map<String, dynamic>>.from((items[i]['others'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map))),
      },
    );
    for (int pass = 0; pass < items.length; pass++) {
      bool anyChange = false;
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        double resolveLink(Map<String, dynamic>? source, bool isLink, double fallback) {
          if (!isLink) return fallback;
          if (source == null) return finalResults.isNotEmpty ? finalResults.last : fallback;
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
          if (sTarget == 'input') return (items[sRowIdx]['input'] as num? ?? 0.0).toDouble();
          if (sTarget == 'operand') return (items[sRowIdx]['operand'] as num? ?? 0.0).toDouble();
          if (sTarget.startsWith('other_')) {
            final idx = int.tryParse(sTarget.split('_')[1]) ?? 0;
            final sOthers = items[sRowIdx]['others'] as List? ?? [];
            if (idx < sOthers.length) return (sOthers[idx]['val'] as num? ?? 0.0).toDouble();
          }
          return fallback;
        }
        final inputValue = resolveLink(item['inputLinkSource'] as Map<String, dynamic>?, item['inputLink'] == true, (item['input'] as num? ?? 0.0).toDouble());
        final operandValue = resolveLink(item['operandLinkSource'] as Map<String, dynamic>?, item['operandLink'] == true, (item['operand'] as num? ?? 0.0).toDouble());
        final othersValue = List.from(item['others'] as List? ?? []).map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          map['val'] = resolveLink(map['valLinkSource'] as Map<String, dynamic>?, map['valLink'] == true, (map['val'] as num? ?? 0.0).toDouble());
          return map;
        }).toList();
        final res = _calculate(
          _CalculatorRow._applyTermTransform(inputValue, item['inputTransform'] as String?, (item['inputPowExp'] as num? ?? 2.0).toDouble()),
          item['op'] as String? ?? '+',
          _CalculatorRow._applyTermTransform(operandValue, item['operandTransform'] as String?, (item['operandPowExp'] as num? ?? 2.0).toDouble()),
          othersValue.map((e) { final m = Map<String, dynamic>.from(e); m['val'] = _CalculatorRow._applyTermTransform((m['val'] as double), m['transform'] as String?, (m['powExp'] as num? ?? 2.0).toDouble()); return m; }).toList(),
          item['brackets'] as List? ?? [],
        );
        if ((res - finalResults[i]).abs() > 1e-10) anyChange = true;
        finalResults[i] = res;
        resolvedRows[i] = {'input': inputValue, 'operand': operandValue, 'others': othersValue};
      }
      if (!anyChange) break;
    }

    String fmtNum(double v, int precision) {
      if (v.isNaN || v.isInfinite) return '0';
      if (v == v.truncateToDouble() && v.abs() < 1e12) return v.toInt().toString();
      return v.toStringAsFixed(precision);
    }

    // 変換オプション付きの値表示文字列
    String termWithTransform(double rawV, String? transform, double powExp, int precision) {
      final s = fmtNum(rawV, precision);
      if (transform == null) return s;
      switch (transform) {
        case 'sqrt': return '√$s';
        case 'pow':
          final expStr = powExp == powExp.truncateToDouble() ? powExp.toInt().toString() : fmtNum(powExp, 1);
          return '$s^$expStr';
        case 'nroot':
          final expStr = powExp == powExp.truncateToDouble() ? powExp.toInt().toString() : fmtNum(powExp, 1);
          return '${expStr}√$s';
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

    // ── カラム定義を生成 ──────────────────────────────────────────────────
    // 行 = 計算式、列 = 名前 | 項1 | 項2 | 項3... | 答え
    final maxOthers = items.fold(0, (int acc, item) => math.max(acc, (item['others'] as List? ?? []).length));
    final allColumnKeys = <String>['name', 'input', 'operand'];
    for (int i = 0; i < maxOthers; i++) allColumnKeys.add('other_$i');
    allColumnKeys.add('result');

    final rawColConfig = widget.config.data['tableColumnConfig'] as List<dynamic>? ?? [];
    final colConfigMap = <String, Map<String, dynamic>>{
      for (final c in rawColConfig.whereType<Map>()) c['key'] as String: Map<String, dynamic>.from(c),
    };

    String defaultLabel(String key) {
      if (key == 'name') return '名前';
      if (key == 'input') return '項1';
      if (key == 'operand') return '項2';
      if (key == 'result') return '答え';
      final i = int.tryParse(key.split('_')[1]) ?? 0;
      return '項${i + 3}';
    }

    final columns = allColumnKeys.map((key) => <String, dynamic>{
      'key': key,
      'label': colConfigMap[key]?['label'] as String? ?? defaultLabel(key),
      'visible': colConfigMap[key]?['visible'] as bool? ?? true,
    }).toList();

    final visibleColumns = columns.where((c) => c['visible'] as bool).toList();

    // ── スタイル ──────────────────────────────────────────────────────────
    final fgColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final borderColor = isDark ? Colors.white.withOpacity(0.09) : Colors.black.withOpacity(0.10);
    final headerBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04);

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
        return termWithTransform(v, transform, powExp, precision) + (unit1.isNotEmpty ? ' $unit1' : '');
      }
      if (key == 'operand') {
        final v = resolved['operand'] as double;
        final transform = item['operandTransform'] as String?;
        final powExp = (item['operandPowExp'] as num? ?? 2.0).toDouble();
        return termWithTransform(v, transform, powExp, precision) + (unit2.isNotEmpty ? ' $unit2' : '');
      }
      if (key == 'result') {
        return fmtNum(finalResults[rowIdx], precision) + (unitResult.isNotEmpty ? ' $unitResult' : '');
      }
      if (key.startsWith('other_')) {
        final i = int.tryParse(key.split('_')[1]) ?? 0;
        final resolvedOthers = resolved['others'] as List;
        final rawOthers = item['others'] as List? ?? [];
        if (i < resolvedOthers.length) {
          final o = resolvedOthers[i] as Map;
          final v = (o['val'] as num? ?? 0.0).toDouble();
          final unit = i < rawOthers.length ? (rawOthers[i] as Map)['unit'] as String? ?? '' : '';
          final transform = i < rawOthers.length ? (rawOthers[i] as Map)['transform'] as String? : null;
          final powExp = i < rawOthers.length ? ((rawOthers[i] as Map)['powExp'] as num? ?? 2.0).toDouble() : 2.0;
          return termWithTransform(v, transform, powExp, precision) + (unit.isNotEmpty ? ' $unit' : '');
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
        final col = columns.firstWhere((c) => c['key'] == colKey, orElse: () => <String, dynamic>{'label': colKey});
        return col['label'] as String;
      }

      final inputRaw = resolved['input'] as double;
      final operandRaw = resolved['operand'] as double;

      // 式の各パーツを構築
      final parts = <String>[];
      parts.add('${colLabel('input')}: ${termWithTransform(inputRaw, inputTransform, inputPowExp, precision)}${unit1.isNotEmpty ? ' $unit1' : ''}');
      parts.add('  $op ${colLabel('operand')}: ${termWithTransform(operandRaw, operandTransform, operandPowExp, precision)}${unit2.isNotEmpty ? ' $unit2' : ''}');
      for (int i = 0; i < resolvedOthers.length; i++) {
        final o = resolvedOthers[i] as Map;
        final rawO = i < rawOthers.length ? rawOthers[i] as Map : <String, dynamic>{};
        final oVal = (o['val'] as num? ?? 0.0).toDouble();
        final oOp = rawO['op'] as String? ?? '+';
        final oTransform = rawO['transform'] as String?;
        final oPowExp = (rawO['powExp'] as num? ?? 2.0).toDouble();
        final oUnit = rawO['unit'] as String? ?? '';
        parts.add('  $oOp ${colLabel('other_$i')}: ${termWithTransform(oVal, oTransform, oPowExp, precision)}${oUnit.isNotEmpty ? ' $oUnit' : ''}');
      }
      parts.add('= ${fmtNum(finalResults[rowIdx], precision)}${unitResult.isNotEmpty ? ' $unitResult' : ''}');

      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            item['name'] as String? ?? '答えの計算式',
            style: const TextStyle(color: Colors.white, fontFamily: 'ZenOldMincho', fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Text(
            parts.join('\n'),
            style: const TextStyle(color: Colors.white70, fontFamily: 'ZenOldMincho', fontSize: 15, height: 1.9),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('閉じる', style: TextStyle(color: Color(0xFF5E81FF))),
            ),
          ],
        ),
      );
    }

    bool isResultCol(String key) => key == 'result';

    return Container(
      padding: widget.contentPadding ?? const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader) ...[
            Row(
              children: [
                Expanded(child: Text(title, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'ZenOldMincho', letterSpacing: 1.2))),
                IconButton(
                  icon: const Icon(Icons.view_column_rounded, size: 20),
                  tooltip: '列の設定',
                  onPressed: () => _showTableColumnSettingsSheet(columns, isDark),
                  color: isDark ? Colors.white38 : Colors.black38,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                  onPressed: () => widget.onUpdate({...widget.config.data, 'viewMode': false, 'tableMode': false}),
                  color: isDark ? Colors.white24 : Colors.black26,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: isDark ? Colors.white10 : Colors.black12, thickness: 0.5),
            const SizedBox(height: 12),
          ],
          if (visibleColumns.isEmpty || items.isEmpty)
            Center(child: Text(items.isEmpty ? '計算式がありません' : '表示する列がありません',
                style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontFamily: 'ZenOldMincho')))
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
                            : (isEditable ? () => _showTableColumnLabelEdit(key, label, columns) : null),
                        child: Container(
                          width: w,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          decoration: BoxDecoration(
                            color: headerBg,
                            border: Border(
                              bottom: BorderSide(color: borderColor),
                              right: isLast ? BorderSide.none : BorderSide(color: borderColor),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(label,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'ZenOldMincho', letterSpacing: 0.3)),
                              ),
                              if (isNameCol) ...[
                                const SizedBox(width: 3),
                                Icon(Icons.view_column_rounded, size: 8, color: isDark ? Colors.white12 : Colors.black12),
                              ] else if (isEditable) ...[
                                const SizedBox(width: 3),
                                Icon(Icons.edit_rounded, size: 8, color: isDark ? Colors.white12 : Colors.black12),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  // ── データ行 ────────────────────────────────────────────
                  ...items.asMap().entries.map((entry) {
                    final rowIdx = entry.key;
                    final isLastRow = rowIdx == items.length - 1;
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
                              ? () => showResultFormula(rowIdx)
                              : (editable ? () => _showTableItemEditSheet(rowIdx, key, col['label'] as String) : null),
                          child: Container(
                            width: w,
                            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 14),
                            decoration: BoxDecoration(
                              color: isRes ? (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)) : Colors.transparent,
                              border: Border(
                                bottom: isLastRow ? BorderSide.none : BorderSide(color: borderColor),
                                right: isLastCol ? BorderSide.none : BorderSide(color: borderColor),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(val,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isRes ? fgColor : (isDark ? Colors.white70 : Colors.black87),
                                      fontSize: isRes ? 16 : 15,
                                      fontWeight: isRes ? FontWeight.w700 : FontWeight.w400,
                                      fontFamily: 'ZenOldMincho',
                                    )),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 列ヘッダーのラベルをインラインで編集するシート（表モード専用）
  void _showTableColumnLabelEdit(String columnKey, String currentLabel, List<Map<String, dynamic>> allColumns) {
    showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ColumnLabelEditSheet(
        columnKey: columnKey,
        currentLabel: currentLabel,
        allColumns: allColumns,
      ),
    ).then((newColConfig) {
      if (newColConfig == null || !mounted) return;
      widget.onUpdate({...widget.config.data, 'tableColumnConfig': newColConfig});
    });
  }

  /// セルをタップしたときに値/名前を編集するシート（編集モードと同じ詳細シートを使用）
  void _showTableItemEditSheet(int rowIdx, String columnKey, String columnLabel) {
    final items = _items;
    if (rowIdx < 0 || rowIdx >= items.length) return;
    final item = items[rowIdx];
    final constants = _constants;
    final bgColorValue = widget.config.data['bgColor'] as int?;
    final isDark = bgColorValue != null
        ? _kNoteColorPresets.firstWhere((p) => p.value == bgColorValue, orElse: () => _kNoteColorPresets.first).isDark
        : true;

    // 簡易結果計算（リンク未解決）
    final allResults = items.map((it) => _calculate(
      (it['input'] as num? ?? 0.0).toDouble(),
      it['op'] as String? ?? '+',
      (it['operand'] as num? ?? 0.0).toDouble(),
      (it['others'] as List? ?? []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        m['val'] = (m['val'] as num? ?? 0.0).toDouble();
        return m;
      }).toList(),
      it['brackets'] as List? ?? [],
    )).toList();

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
      input: (item['input'] as num? ?? 0.0).toDouble(),
      inputLink: item['inputLink'] as bool? ?? false,
      inputLinkSource: item['inputLinkSource'] as Map<String, dynamic>?,
      inputTransform: item['inputTransform'] as String?,
      inputPowExp: (item['inputPowExp'] as num? ?? 2.0).toDouble(),
      op: item['op'] as String? ?? '+',
      operand: (item['operand'] as num? ?? 0.0).toDouble(),
      operandLink: item['operandLink'] as bool? ?? false,
      operandLinkSource: item['operandLinkSource'] as Map<String, dynamic>?,
      operandTransform: item['operandTransform'] as String?,
      operandPowExp: (item['operandPowExp'] as num? ?? 2.0).toDouble(),
      others: List.from(item['others'] as List? ?? []),
      result: allResults[rowIdx],
      precision: item['precision'] as int? ?? 2,
      unit1: item['unit1'] as String? ?? '',
      unit2: item['unit2'] as String? ?? '',
      unitResult: item['unitResult'] as String? ?? '',
      isDark: isDark,
      brackets: item['brackets'] as List? ?? [],
      allItems: items,
      allResults: allResults,
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

    if (columnKey == 'name') {
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
  void _showTableColumnSettingsSheet(List<Map<String, dynamic>> columns, bool isDark) {
    showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ColumnSettingsSheet(columns: columns),
    ).then((newColConfig) {
      if (newColConfig == null || !mounted) return;
      widget.onUpdate({...widget.config.data, 'tableColumnConfig': newColConfig});
    });
  }

  /// 表の左上「名前」ヘッダータップ時：列の表示/非表示をアラートで切り替える
  void _showColumnVisibilityDialog(List<Map<String, dynamic>> columns, bool isDark) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ColumnVisibilityDialog(
        columns: columns,
        onSave: (newConfig) {
          if (mounted) {
            widget.onUpdate({...widget.config.data, 'tableColumnConfig': newConfig});
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
      if (source == null)
        return finalResults.isNotEmpty ? finalResults.last : fallback;
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
      if (sTarget == 'operand')
        return (sItem['operand'] as num? ?? 0.0).toDouble();
      if (sTarget.startsWith('other_')) {
        final idx = int.tryParse(sTarget.split('_')[1]) ?? 0;
        final sOthers = sItem['others'] as List? ?? [];
        if (idx < sOthers.length)
          return (sOthers[idx]['val'] as num? ?? 0.0).toDouble();
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
      if (v == v.truncateToDouble() && v.abs() < 1e12)
        return v.toInt().toString();
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
      final double operandPow = (item['operandPowExp'] as num? ?? 2.0).toDouble();

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
      padding: widget.contentPadding ?? const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
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
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'ZenOldMincho',
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                  onPressed: () => widget.onUpdate({...widget.config.data, 'viewMode': false}),
                  color: isDark ? Colors.white24 : Colors.black26,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: isDark ? Colors.white10 : Colors.black12, thickness: 0.5),
            const SizedBox(height: 24),
          ],
          
          if (constants.isNotEmpty) ...[
            _buildViewModeConstantsSection(constants, isDark),
            const SizedBox(height: 16),
          ],

          if (items.isEmpty && standaloneItems.isEmpty)
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
              for (int orderIdx = 0; orderIdx < displayOrder.length; orderIdx++) {
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
                    widgets.add(Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                      child: Divider(
                        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
                        thickness: 0.5,
                      ),
                    ));
                  }
                  widgets.add(Padding(
                    padding: const EdgeInsets.only(left: 10, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.sticky_note_2_outlined,
                          size: 13,
                          color: isDark ? Colors.tealAccent.withOpacity(0.6) : Colors.teal.shade700.withOpacity(0.7),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            text,
                            style: TextStyle(
                              color: isDark ? Colors.white.withOpacity(0.55) : Colors.black.withOpacity(0.55),
                              fontSize: 13,
                              fontFamily: 'ZenOldMincho',
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ));
                  continue;
                }

                // type == 'calc'
                final ci = entry['calcIdx'] as int? ?? 0;
                if (ci < 0 || ci >= items.length || ci >= resolvedRows.length) continue;

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
                  widgets.add(Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 6),
                    child: Divider(
                      color: isDark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.black.withOpacity(0.03),
                      thickness: 0.5,
                    ),
                  ));
                }

                widgets.add(Padding(
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
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontSize: 14,
                                fontFamily: 'ZenOldMincho',
                                height: 1.5,
                              ),
                            ),
                            TextSpan(
                              text: ' = ',
                              style: TextStyle(
                                color: isDark ? Colors.white24 : Colors.black12,
                                fontSize: 16,
                              ),
                            ),
                            TextSpan(
                              text: resultStr,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
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
                ));

                // この計算行に紐付いたメモを表示（閲覧モードは読み取り専用）
                for (final memo in memos) {
                  if ((memo['afterCalcIdx'] as int? ?? -1) == ci) {
                    final text = memo['text'] as String? ?? '';
                    if (text.isNotEmpty) {
                      widgets.add(Padding(
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
                      ));
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
            padding: widget.contentPadding ??
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
                          widget.config.data['title'] as String? ?? '定型計算',
                          style: TextStyle(
                            color: headerTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => widget.onUpdate(
                            {...widget.config.data, 'viewMode': true}),
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
                if (items.isEmpty && displayOrder.every((e) => e['type'] == 'calc'))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        '計算式がありません',
                        style: TextStyle(color: Colors.white24, fontSize: 12),
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
                      final pOthers = (pItem['others'] as List? ?? []).map((
                        e,
                      ) {
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
                    final List<double> finalResults =
                        List<double>.from(provisionalResults);
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
                      // 定数リンク
                      if (source['type'] == 'constant') {
                        final constIdx = source['constIdx'] as int? ?? 0;
                        if (constIdx >= 0 && constIdx < constants.length) {
                          return (constants[constIdx]['value'] as num? ?? 0.0).toDouble();
                        }
                        return fallback;
                      }
                      final int sRowIdx = source['rowIdx'] as int? ?? 0;
                      final String sTarget =
                          source['target'] as String? ?? 'result';
                      if (sRowIdx < 0 || sRowIdx >= items.length)
                        return fallback;

                      final sItem = items[sRowIdx];
                      if (sTarget == 'result') {
                        return finalResults[sRowIdx];
                      }
                      if (sTarget == 'input') {
                        return (sItem['input'] as num? ?? 0.0).toDouble();
                      }
                      if (sTarget == 'operand') {
                        return (sItem['operand'] as num? ?? 0.0).toDouble();
                      }
                      if (sTarget.startsWith('other_')) {
                        final idx = int.tryParse(sTarget.split('_')[1]) ?? 0;
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
                            List.from(item['others'] as List? ?? []).map((e) {
                              final map = Map<String, dynamic>.from(e as Map);
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
                            (item['inputPowExp'] as num? ?? 2.0).toDouble();
                        final operandTransform =
                            item['operandTransform'] as String?;
                        final operandPowExp =
                            (item['operandPowExp'] as num? ?? 2.0).toDouble();
                        final inputForCalc = _CalculatorRow._applyTermTransform(
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
                          final exp =
                              (m['powExp'] as num? ?? 2.0).toDouble();
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
                        if ((res - finalResults[i]).abs() > 1e-10)
                          anyChange = true;
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
                              if (ci < 0 || ci >= items.length || ci >= resolvedRows.length) continue;
                              final item = items[ci];
                              final resolved = resolvedRows[ci];
                              final memoWidgets = <Widget>[];
                              for (int mi = 0; mi < memos.length; mi++) {
                                if ((memos[mi]['afterCalcIdx'] as int? ?? -1) == ci) {
                                  final memoIdx = mi;
                                  memoWidgets.add(_MemoRowWidget(
                                    key: ValueKey('memo_${widget.config.id}_$memoIdx'),
                                    text: memos[mi]['text'] as String? ?? '',
                                    isDark: isDark,
                                    onUpdate: (t) => _updateMemo(memoIdx, t),
                                    onDelete: () => _deleteMemo(memoIdx),
                                  ));
                                }
                              }
                              listItems.add(Column(
                                key: ValueKey('calc_${widget.config.id}_$ci'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (di > 0)
                                    Divider(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.07)
                                          : Colors.black.withOpacity(0.08),
                                      height: 1,
                                      indent: 16,
                                      endIndent: 16,
                                    ),
                                  _CalculatorRow(
                                    name: item['name'] as String? ?? '',
                                    myIndex: ci,
                                    isFirst: di == 0,
                                    input: resolved['input'],
                                    inputLink: item['inputLink'] as bool? ?? false,
                                    inputLinkSource:
                                        item['inputLinkSource'] as Map<String, dynamic>?,
                                    inputTransform: item['inputTransform'] as String?,
                                    inputPowExp: (item['inputPowExp'] as num? ?? 2.0)
                                        .toDouble(),
                                    op: item['op'] as String? ?? '+',
                                    operand: resolved['operand'],
                                    operandLink: item['operandLink'] as bool? ?? false,
                                    operandLinkSource:
                                        item['operandLinkSource'] as Map<String, dynamic>?,
                                    operandTransform: item['operandTransform'] as String?,
                                    operandPowExp: (item['operandPowExp'] as num? ?? 2.0)
                                        .toDouble(),
                                    others: resolved['others'],
                                    result: resolved['result'],
                                    precision: item['precision'] as int? ?? 2,
                                    unit1: item['unit1'] as String? ?? '',
                                    unit2: item['unit2'] as String? ?? '',
                                    unitResult: item['unitResult'] as String? ?? '',
                                    isDark: isDark,
                                    brackets: item['brackets'] as List? ?? [],
                                    allItems: items,
                                    allResults: finalResults,
                                    constants: constants,
                                    onChanged: (newItem) => _updateItem(ci, newItem),
                                    onDelete: () => _removeItem(ci),
                                    onCopy: () => _duplicateItem(ci),
                                    onCut: () => _cutItem(ci),
                                    onPaste: () => _pasteFromClipboard(ci),
                                    hasClipboard: widget.clipboardNotifier?.value != null,
                                    onMoveUp: di > 0 ? () => _moveItem(di, di - 1) : null,
                                    onMoveDown: di < displayOrder.length - 1
                                        ? () => _moveItem(di, di + 1)
                                        : null,
                                    onAdd: () => _addTerm(ci),
                                    onPickBrackets: () => _pickBracketsFor(ci),
                                    onAllItemsUpdate: (newItems) => widget.onUpdate(
                                      {...widget.config.data, 'items': newItems},
                                    ),
                                    nameVisible: item['nameVisible'] as bool? ?? true,
                                    onInsertBelow: () => _insertItemAfter(ci),
                                    onInsertMemoBelow: () =>
                                        _insertMemoAfter(ci, context),
                                    onToggleName: () => _toggleNameVisible(ci),
                                    wrapFormula: _wrapFormula,
                                    termLabels: _effectiveTermLabels.isNotEmpty ? _effectiveTermLabels : null,
                                    dragHandle: ReorderableDragStartListener(
                                      index: di,
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Icon(
                                          Icons.drag_indicator,
                                          color: isDark ? Colors.white24 : Colors.black26,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  ...memoWidgets,
                                ],
                              ));
                            } else {
                              // スタンドアロンメモ
                              final itemId = entry['itemId'] as String? ?? '';
                              final memo = standaloneItems.firstWhere(
                                (e) => e['id'] == itemId,
                                orElse: () => {'id': itemId, 'text': ''},
                              );
                              listItems.add(Column(
                                key: ValueKey('standalone_${widget.config.id}_$itemId'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (di > 0)
                                    Divider(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.07)
                                          : Colors.black.withOpacity(0.08),
                                      height: 1,
                                      indent: 16,
                                      endIndent: 16,
                                    ),
                                  _StandaloneMemoRow(
                                    text: memo['text'] as String? ?? '',
                                    isDark: isDark,
                                    onUpdate: (t) => _updateStandaloneMemo(itemId, t),
                                    onDelete: () => _deleteStandaloneMemo(itemId),
                                    dragHandle: ReorderableDragStartListener(
                                      index: di,
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Icon(
                                          Icons.drag_indicator,
                                          color: isDark ? Colors.white24 : Colors.black26,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ));
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
                  Divider(color: Colors.white.withOpacity(0.3), height: 1),
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
                                  color: Colors.purpleAccent.withOpacity(0.7),
                                ),
                              )
                            : Icon(
                                Icons.auto_awesome_outlined,
                                color: Colors.purpleAccent.withOpacity(0.7),
                                size: 18,
                              ),
                        label: Text(
                          'AI生成',
                          style: TextStyle(
                            color: Colors.purpleAccent.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        onPressed: _isAiGenerating ? null : _showAiGenerateCalcDialog,
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
                            color: isDark ? Colors.white54 : Colors.black45,
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
                              : (isDark ? Colors.white54 : Colors.black45),
                          size: 18,
                        ),
                        label: Text(
                          '電卓',
                          style: TextStyle(
                            color: _showCalc
                                ? Colors.blueAccent
                                : (isDark ? Colors.white54 : Colors.black45),
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () => setState(() => _showCalc = !_showCalc),
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
            backgroundColor: Colors.black87,
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
                  dropdownColor: Colors.black87,
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
                  dropdownColor: Colors.black87,
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
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('列名の編集',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E81FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                final newColConfig = widget.allColumns.map((col) {
                  final key = col['key'] as String;
                  return <String, dynamic>{
                    'key': key,
                    'label': key == widget.columnKey ? _ctrl.text : col['label'],
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
    _localCols = widget.columns.map((c) => Map<String, dynamic>.from(c)).toList();
    _labelControllers = {
      for (final c in _localCols)
        c['key'] as String: TextEditingController(text: c['label'] as String),
    };
  }

  @override
  void dispose() {
    for (final ctrl in _labelControllers.values) ctrl.dispose();
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
                  child: Text('列の設定',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: _save,
                  child: const Text('保存',
                      style: TextStyle(color: Color(0xFF5E81FF), fontWeight: FontWeight.bold)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Switch(
                        value: visible,
                        onChanged: (val) =>
                            setState(() => _localCols[i] = {..._localCols[i], 'visible': val}),
                        activeColor: const Color(0xFF5E81FF),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _labelControllers[key],
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: '列名',
                            hintStyle: const TextStyle(color: Colors.white24),
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.06),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none),
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
  State<_ColumnVisibilityDialog> createState() => _ColumnVisibilityDialogState();
}

class _ColumnVisibilityDialogState extends State<_ColumnVisibilityDialog> {
  late List<Map<String, dynamic>> _localCols;

  @override
  void initState() {
    super.initState();
    _localCols = widget.columns.map((c) => Map<String, dynamic>.from(c)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('列の表示設定',
          style: TextStyle(color: Colors.white, fontFamily: 'ZenOldMincho', fontSize: 16, fontWeight: FontWeight.bold)),
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
                title: Text(label,
                    style: const TextStyle(color: Colors.white70, fontFamily: 'ZenOldMincho', fontSize: 14)),
                value: visible,
                onChanged: (val) => setState(() {
                  _localCols = _localCols.map((c) {
                    if (c['key'] == key) return {...c, 'visible': val};
                    return c;
                  }).toList();
                }),
                activeColor: const Color(0xFF5E81FF),
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
          child: const Text('保存', style: TextStyle(color: Color(0xFF5E81FF), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

