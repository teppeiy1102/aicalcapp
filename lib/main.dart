import 'package:flutter/material.dart';
import 'widget_page.dart';

void main() {
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
          surface: Color(0xFF1A1A26),
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
  final List<WidgetConfig> _configs = [
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
      },
    ),
  ];

  void _updateConfig(int index, Map<String, dynamic> data) {
    setState(() {
      _configs[index] = _configs[index].copyWith(data: data);
    });
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
  }

  void _addConfig() {
    final newConfig = WidgetConfig(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      type: 'calculator',
      data: {
        'title': '無題のシート',
        'items': _sampleItems,
        'isExpanded': true,
      },
    );
    setState(() => _configs.add(newConfig));
    final newIndex = _configs.length - 1;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WidgetDetailPage(
          initialConfig: newConfig,
          onUpdate: (data) => _updateConfig(newIndex, data),
          onDuplicate: () => _duplicateConfig(newIndex),
        ),
      ),
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
            },
            child: const Text('削除する', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
    return Scaffold(
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
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 160,
                backgroundColor: const Color(0xFF0D0D14).withOpacity(0.8),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 28, bottom: 24),
                  centerTitle: false,
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Calc',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
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
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _WidgetCard(
                          config: _configs[i],
                          index: i,
                          onTap: () => _openDetail(i),
                          onDelete: () => _deleteConfig(i),
                        ),
                      ),
                      childCount: _configs.length,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: _AddButton(onTap: _addConfig),
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
              Icons.auto_awesome_mosaic_rounded,
              color: Colors.white.withOpacity(0.15),
              size: 40,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'まだシートがありません',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '計算を自動化する魔法を始めましょう',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetCard extends StatelessWidget {
  final WidgetConfig config;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _WidgetCard({
    required this.config,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  static const List<Color> _accentColors = [
    Color(0xFF5E81FF),
    Color(0xFF9E7AFF),
    Color(0xFF43E5FF),
    Color(0xFFFF7B5C),
    Color(0xFF5CFFB6),
  ];

  @override
  Widget build(BuildContext context) {
    final title = config.data['title'] as String? ?? '定型計算';
    final items = config.data['items'] as List<dynamic>? ?? [];
    final accent = _accentColors[index % _accentColors.length];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: const Color(0xFF1A1A26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: accent.withOpacity(0.1),
          highlightColor: accent.withOpacity(0.05),
          child: Stack(
            children: [
              Positioned(
                top: -40,
                right: -40,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: accent.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.calculate_rounded,
                        color: accent,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
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
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.delete_sweep_rounded,
                          color: Colors.white.withOpacity(0.2),
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF5E81FF),
              Color(0xFF9E7AFF),
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
            Icon(Icons.add_rounded, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Text(
              '新しいシート',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
