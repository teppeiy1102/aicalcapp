import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Calc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF5E81FF),
          surface: Color.fromARGB(255, 31, 31, 31),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'NotoSansJP',
        ),
        primaryTextTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'NotoSansJP',
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _kPrefsKey = 'aicalc_configs_v1';

  List<WidgetConfig> _configs = [];
  bool _isLoading = true;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  PersistentBottomSheetController? _calcSheetController;

  // ── デフォルト初期シート ──────────────────────────────────────────────────
  static List<WidgetConfig> get _defaultConfigs => [
    WidgetConfig(
      id: '1',
      type: 'calculator',
      data: {
        'title': '現場計算シート',
        'items': [
          {
            'name': 'サンプルの計算',
            'input': 100.0,
            'op': '+',
            'operand': 50.0,
            'others': <dynamic>[],
            'brackets': <dynamic>[],
            'precision': 0,
            'unit1': 'kg',
            'unit2': 'kg',
            'unitResult': 'kg',
          }
        ],
        'isExpanded': true,
        'bgColor': 0xFF1A1A2E,
      },
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  // ── JSON から深いコピーで WidgetConfig を復元 ─────────────────────────────
  // json.decode は Map<String, dynamic> を返すが、ネストされた List/Map も
  // 同様に正しく型付けされている。ただし参照を共有しないよう deepCopy する。
  static dynamic _deepCopy(dynamic v) {
    if (v is Map) {
      return Map<String, dynamic>.fromEntries(
        v.entries.map((e) => MapEntry(e.key as String, _deepCopy(e.value))),
      );
    }
    if (v is List) {
      return v.map(_deepCopy).toList();
    }
    return v; // String, num, bool, null はイミュータブルなのでそのまま
  }

  // ── SharedPreferences からロード ──────────────────────────────────────────
  Future<void> _loadConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kPrefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = json.decode(jsonStr) as List<dynamic>;
        final loaded = list.map((e) {
          final m = e as Map<String, dynamic>;
          return WidgetConfig(
            id: m['id'] as String? ?? '${DateTime.now().millisecondsSinceEpoch}',
            type: m['type'] as String? ?? 'calculator',
            data: _deepCopy(m['data']) as Map<String, dynamic>,
          );
        }).toList();
        if (mounted) setState(() { _configs = loaded; _isLoading = false; });
        return;
      }
    } catch (e, st) {
      // 読み込み失敗時はデフォルトに戻す
      debugPrint('[_loadConfigs] 読み込みに失敗しました: $e\n$st');
    }
    if (mounted) setState(() { _configs = _defaultConfigs; _isLoading = false; });
  }

  // ── SharedPreferences へ保存 ─────────────────────────────────────────────
  Future<void> _saveConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _configs.map((c) => {
        'id': c.id,
        'type': c.type,
        'data': c.data,
      }).toList();
      await prefs.setString(_kPrefsKey, json.encode(list));
    } catch (e, st) {
      // 保存失敗をデバッグコンソールに記録（アプリはクラッシュさせない）
      debugPrint('[_saveConfigs] 保存に失敗しました: $e\n$st');
    }
  }

  void _updateConfig(int index, Map<String, dynamic> data) {
    setState(() {
      _configs[index] = _configs[index].copyWith(data: data);
    });
    _saveConfigs();
  }

  void _duplicateConfig(int index) {
    final src = _configs[index];
    setState(() {
      _configs.insert(
        index + 1,
        WidgetConfig(
          id: '${DateTime.now().millisecondsSinceEpoch}',
          type: src.type,
          data: Map<String, dynamic>.from(src.data)
            ..['title'] = '${src.data['title'] ?? '定型計算'} (コピー)',
        ),
      );
    });
    _saveConfigs();
  }

  void _addConfig() {
    final newConfig = WidgetConfig(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      type: 'calculator',
      data: {
        'title': '無題のシート',
        'items': _sampleItems,
        'isExpanded': true,
        'bgColor': 0xFF1A1A2E,
      },
    );
    setState(() => _configs.insert(0, newConfig));
    _saveConfigs();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WidgetDetailPage(
          initialConfig: newConfig,
          onUpdate: (data) => _updateConfig(0, data),
          onDuplicate: () => _duplicateConfig(0),
        ),
      ),
    );
  }

  void _openHomeCalc() {
    if (_calcSheetController != null) {
      _calcSheetController!.close();
      return;
    }
    _calcSheetController = showHomeCalcSheet(
      scaffoldKey: _scaffoldKey,
      onAddItem: (item) {
        final newConfig = WidgetConfig(
          id: '${DateTime.now().millisecondsSinceEpoch}',
          type: 'calculator',
          data: {
            'title': '無題のシート',
            'items': [item],
            'isExpanded': true,
            'bgColor': 0xFF1A1A2E,
          },
        );
        setState(() => _configs.insert(0, newConfig));
        _saveConfigs();
      },
      onClosed: () {
        if (mounted) setState(() => _calcSheetController = null);
      },
    );
  }

  static List<Map<String, dynamic>> get _sampleItems => [
    {
      'name': '新規計算',
      'input': 0.0,
      'op': '+',
      'operand': 0.0,
      'others': <dynamic>[],
      'brackets': <dynamic>[],
      'precision': 2,
    },
  ];

  void _deleteConfig(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161625),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('シートの削除', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '「${_configs[index].data['title'] ?? '定型計算'}」を削除しますか？この操作は取り消せません。',
          style: const TextStyle(color: Colors.white60, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _configs.removeAt(index));
              Navigator.pop(ctx);
              _saveConfigs();
            },
            child: const Text('削除する', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _reorderConfigs(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _configs.removeAt(oldIndex);
      _configs.insert(newIndex, item);
    });
    _saveConfigs();
  }

  void _openDetail(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WidgetDetailPage(
          initialConfig: _configs[index],
          onUpdate: (data) => _updateConfig(index, data),
          onDuplicate: () => _duplicateConfig(index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D14),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF5E81FF))),
      );
    }
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0D0D14),
      body: Stack(
        children: [
          // 背景のグラデーション装飾
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF5E81FF).withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF9E7AFF).withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 200,
                  backgroundColor: const Color(0xFF0D0D14).withOpacity(0.9),
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 28, bottom: 0),
                    centerTitle: false,
                    title: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Spacer(flex: 4),
                        const Text(
                          'Genba Calc',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          '現場を支える、次世代の計算機',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Spacer(flex: 1,)
                      ],
                    ),
                  ),
                ),
                if (_configs.isEmpty)
                  const SliverFillRemaining(
                    child: _EmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 140),
                    sliver: SliverReorderableList(
                      itemCount: _configs.length,
                      onReorder: _reorderConfigs,
                      itemBuilder: (ctx, i) => Padding(
                        key: ValueKey(_configs[i].id),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _WidgetCard(
                          config: _configs[i],
                          index: i,
                          onTap: () => _openDetail(i),
                          onDelete: () => _deleteConfig(i),
                          onUpdate: (data) => _updateConfig(i, data),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _HomeFab(
        onOpenCalc: _openHomeCalc,
        onAddSheet: _addConfig,
        calcActive: _calcSheetController != null,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Icon(
              Icons.auto_awesome_mosaic_rounded, color: Colors.white.withOpacity(0.15), size: 40,),), const SizedBox(height: 32), const Text( 'まだシートがありません', style: TextStyle( color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5,),), const SizedBox(height: 12), Text( '計算を自動化する魔法を始めましょう', style: TextStyle( color: Colors.white.withOpacity(0.3), fontSize: 14, fontWeight: FontWeight.w400,),), ],),); } } class _WidgetCard extends StatefulWidget {
  final WidgetConfig config;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final void Function(Map<String, dynamic>) onUpdate;

  const _WidgetCard({
    required this.config,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.onUpdate,
  });

  static const List<Color> _accentColors = [
    Color(0xFF5E81FF),
  ];

  @override
  State<_WidgetCard> createState() => _WidgetCardState();
}

class _WidgetCardState extends State<_WidgetCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.config.data['title'] as String? ?? '定型計算';
    final items = widget.config.data['items'] as List<dynamic>? ?? [];
    final memos = widget.config.data['memos'] as List<dynamic>? ?? [];
    final accent = _WidgetCard._accentColors[widget.index % _WidgetCard._accentColors.length];
    final bgColorValue = widget.config.data['bgColor'] as int?;
    final cardBgColor = bgColorValue != null ? Color(bgColorValue) : const Color(0xFF1A1A26);
    final isDark = cardBgColor.computeLuminance() < 0.5;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subIconColor = isDark ? Colors.white24 : Colors.black26;
    final borderColor = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.12);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: cardBgColor.withAlpha(200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                splashColor: accent.withOpacity(0.1),
                highlightColor: accent.withOpacity(0.05),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 15, 10, 15),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: borderColor,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(32),
                      topRight: const Radius.circular(32),
                      bottomLeft: _isExpanded ? Radius.zero : const Radius.circular(32),
                      bottomRight: _isExpanded ? Radius.zero : const Radius.circular(32),
                    ),
                  ),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: widget.index,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(
                            Icons.drag_indicator,
                            color: subIconColor,
                            size: 22,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.data_usage_rounded,
                                        size: 12,
                                        color: accent,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        items.isEmpty ? '計算式未設定' : '${items.length}件の計算項目',
                                        style: TextStyle(
                                          color: accent.withOpacity(0.9),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (memos.isNotEmpty) ...
                                [
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.sticky_note_2_outlined,
                                          size: 12,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${memos.length}件のメモ',
                                          style: const TextStyle(
                                            color: Colors.amber,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(children: [
                    
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.delete_sweep_rounded,
                            color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.25),
                            size: 22,
                          ),
                        ),
                      ),
                      SizedBox(height: 10,),
        GestureDetector(
                        onTap: () => setState(() => _isExpanded = !_isExpanded),
                        child: Padding(
                          padding: const EdgeInsets.all(0),
                          child: Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: isDark ? Colors.white38 : Colors.black38,
                            size: 22,
                          ),
                        ),
                      ),
      
                      ],)
                   ],
                  ),
                ),
              ),
            ),
            if (_isExpanded)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                child: CalculatorViewCard(
                  config: widget.config,
                  onUpdate: widget.onUpdate,
                  contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                ),
              ),
          ],
        ),
      );
  }
}

class _HomeFab extends StatelessWidget {
  final VoidCallback onAddSheet;
  final VoidCallback onOpenCalc;
  final bool calcActive;
  const _HomeFab({
    required this.onAddSheet,
    required this.onOpenCalc,
    this.calcActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Spacer(),
    
        // 新規シートボタン
        GestureDetector(
          onTap: onAddSheet,
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 241, 243, 249),
                  Color.fromARGB(255, 202, 183, 255),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5E81FF).withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.black, size: 28),
                SizedBox(width: 10),
                Text(
                  '新しいシート',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        Spacer(),
    // 電卓ボタン
        GestureDetector(
          onTap: onOpenCalc,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
             gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 241, 243, 249),
                  Color.fromARGB(255, 202, 183, 255),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5E81FF).withOpacity(
                    calcActive ? 0.35 : 0.15,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              calcActive
                  ? Icons.calculate_rounded
                  : Icons.calculate_outlined,
              color: calcActive ? Colors.black : Colors.black,
              size: 28,
            ),
          ),
        ),
        SizedBox(width: 12,)
      ],
    );
  }
}
