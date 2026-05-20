part of 'widget_page.dart';

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
  final Future<Map<String, dynamic>?> Function()? onPickLinkSource;
  final String Function(Map<String, dynamic>?)? getSourceRowName;
  final double Function(Map<String, dynamic>?, bool, double)? resolver;

  const _LogicRow({
    required this.item,
    required this.isDark,
    required this.onUpdate,
    required this.onDelete,
    this.dragHandle,
    this.onPickLinkSource,
    this.getSourceRowName,
    this.resolver,
  });

  void _showEditDialog(BuildContext context) {
    showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => _LogicItemEditDialog(
        initial: item,
        onPickLinkSource: onPickLinkSource,
        getSourceRowName: getSourceRowName,
        resolver: resolver,
      ),
    ).then((result) {
      if (result == null) return;
      onUpdate(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? '';
    final exprStr = _CalculatorWidgetState._buildLogicExprString(item, resolver);
    final isTrue = _CalculatorWidgetState._evalLogicItem(item, resolver);
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
  final Future<Map<String, dynamic>?> Function()? onPickLinkSource;
  final String Function(Map<String, dynamic>?)? getSourceRowName;
  final double Function(Map<String, dynamic>?, bool, double)? resolver;

  const _LogicItemEditDialog({
    this.initial,
    this.onPickLinkSource,
    this.getSourceRowName,
    this.resolver,
  });

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
              isLink: cond['lhsLink'] == true,
              linkSource: cond['lhsLinkSource'] as Map<String, dynamic>?,
              linkLabel: widget.getSourceRowName != null
                  ? widget.getSourceRowName!(cond['lhsLinkSource'] as Map<String, dynamic>?)
                  : null,
              onLinkPressed: widget.onPickLinkSource != null
                  ? () async {
                      final source = await widget.onPickLinkSource!();
                      if (source != null) {
                        setState(() {
                          _conditions[idx]['lhsLink'] = true;
                          _conditions[idx]['lhsLinkSource'] = source;
                        });
                      }
                    }
                  : null,
              onLinkRemoved: () => setState(() {
                _conditions[idx]['lhsLink'] = false;
                _conditions[idx]['lhsLinkSource'] = null;
              }),
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
              dropdownColor: Colors.black,
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
                isLink: cond['rhsLink'] == true,
                linkSource: cond['rhsLinkSource'] as Map<String, dynamic>?,
                linkLabel: widget.getSourceRowName != null
                    ? widget.getSourceRowName!(cond['rhsLinkSource'] as Map<String, dynamic>?)
                    : null,
                onLinkPressed: widget.onPickLinkSource != null
                    ? () async {
                        final source = await widget.onPickLinkSource!();
                        if (source != null) {
                          setState(() {
                            _conditions[idx]['rhsLink'] = true;
                            _conditions[idx]['rhsLinkSource'] = source;
                          });
                        }
                      }
                    : null,
                onLinkRemoved: () => setState(() {
                  _conditions[idx]['rhsLink'] = false;
                  _conditions[idx]['rhsLinkSource'] = null;
                }),
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
                  isLink: cond['rhsLink2'] == true,
                  linkSource: cond['rhsLinkSource2'] as Map<String, dynamic>?,
                  linkLabel: widget.getSourceRowName != null
                      ? widget.getSourceRowName!(cond['rhsLinkSource2'] as Map<String, dynamic>?)
                      : null,
                  onLinkPressed: widget.onPickLinkSource != null
                      ? () async {
                          final source = await widget.onPickLinkSource!();
                          if (source != null) {
                            setState(() {
                              _conditions[idx]['rhsLink2'] = true;
                              _conditions[idx]['rhsLinkSource2'] = source;
                            });
                          }
                        }
                      : null,
                  onLinkRemoved: () => setState(() {
                    _conditions[idx]['rhsLink2'] = false;
                    _conditions[idx]['rhsLinkSource2'] = null;
                  }),
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
                isLink: cond['rhsLink'] == true,
                linkSource: cond['rhsLinkSource'] as Map<String, dynamic>?,
                linkLabel: widget.getSourceRowName != null
                    ? widget.getSourceRowName!(cond['rhsLinkSource'] as Map<String, dynamic>?)
                    : null,
                onLinkPressed: widget.onPickLinkSource != null
                    ? () async {
                        final source = await widget.onPickLinkSource!();
                        if (source != null) {
                          setState(() {
                            _conditions[idx]['rhsLink'] = true;
                            _conditions[idx]['rhsLinkSource'] = source;
                          });
                        }
                      }
                    : null,
                onLinkRemoved: () => setState(() {
                  _conditions[idx]['rhsLink'] = false;
                  _conditions[idx]['rhsLinkSource'] = null;
                }),
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
    final isTrue = _CalculatorWidgetState._evalLogicItem(preview, widget.resolver);
    final exprStr = _CalculatorWidgetState._buildLogicExprString(preview, widget.resolver);

    return AlertDialog(
      backgroundColor: Colors.black,
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
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final op in ['AND', 'OR', 'XOR'])
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: ChoiceChip(
                                  label: Text(
                                    op == 'AND'
                                        ? 'かつ (AND)'
                                        : op == 'OR'
                                            ? 'または (OR)'
                                            : 'どちらか一方 (XOR)',
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
  final bool isLink;
  final Map<String, dynamic>? linkSource;
  final void Function(double val, String label) onChanged;
  final VoidCallback? onLinkPressed;
  final VoidCallback? onLinkRemoved;
  final String? linkLabel;

  const _NumLabelField({
    required this.initVal,
    required this.initLabel,
    this.isLink = false,
    this.linkSource,
    required this.onChanged,
    this.onLinkPressed,
    this.onLinkRemoved,
    this.linkLabel,
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
        if (widget.isLink)
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded,
                      color: Colors.blueAccent, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.linkLabel ?? 'リンク元',
                      style: const TextStyle(
                          color: Colors.blueAccent, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
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
          flex: 3,
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
        const SizedBox(width: 6),
        if (widget.isLink)
          IconButton(
            icon: const Icon(Icons.link_off_rounded, color: Colors.white38),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: widget.onLinkRemoved,
          )
        else
          IconButton(
            icon: const Icon(Icons.link_rounded, color: Colors.blueAccent),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: widget.onLinkPressed,
          ),
      ],
    );
  }
}
