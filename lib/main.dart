import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:home_widget/home_widget.dart';
import 'widget_page.dart';
import 'link_graph_page.dart';
import 'revenuecat_service.dart';
import 'pro_guard.dart';
import 'ai_service.dart';
import 'store_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  HomeWidget.setAppGroupId('group.com.yama.genbacalc');
  await AppSettings.instance.load();
  await RevenueCatService.init();
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
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'NotoSansJP'),
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
  static const _kUserConstantsKey = 'aicalc_user_constants_v1';

  List<WidgetConfig> _configs = [];
  List<Map<String, dynamic>> _userConstants = [];
  bool _isLoading = true;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isHomeAiGenerating = false;
  bool _isCalcExpanded = true;
  final GlobalKey<HomeCalcBottomPanelState> _homeCalcPanelKey = GlobalKey();
  bool _isSelectMode = false;
  final Set<int> _selectedForMerge = {};
  String? _appendTargetSheetId;

  // ── QR共有選択モード ──────────────────────────────────────────────────────
  bool _isQrSelectMode = false;
  final Set<int> _selectedForQrShare = {};

  /// アプリ内クリップボード（シート間共有）
  final ValueNotifier<Map<String, dynamic>?> _clipboardNotifier = ValueNotifier(
    null,
  );

  @override
  void dispose() {
    _clipboardNotifier.dispose();
    super.dispose();
  }

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
          },
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
      // ユーザー定義定数を読み込む
      final ucJsonStr = prefs.getString(_kUserConstantsKey);
      if (ucJsonStr != null && ucJsonStr.isNotEmpty) {
        final ucList = json.decode(ucJsonStr) as List<dynamic>;
        _userConstants = ucList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      final jsonStr = prefs.getString(_kPrefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = json.decode(jsonStr) as List<dynamic>;
        final _migrationNow = DateTime.now().toIso8601String();
        final loaded = list.map((e) {
          final m = e as Map<String, dynamic>;
          final data = _deepCopy(m['data']) as Map<String, dynamic>;
          // マイグレーション: 日付フィールドがない既存シートに現在時刻を設定
          if (!data.containsKey('createdAt') || data['createdAt'] == null) {
            data['createdAt'] = _migrationNow;
          }
          if (!data.containsKey('updatedAt') || data['updatedAt'] == null) {
            data['updatedAt'] = _migrationNow;
          }
          return WidgetConfig(
            id:
                m['id'] as String? ??
                '${DateTime.now().millisecondsSinceEpoch}',
            type: m['type'] as String? ?? 'calculator',
            data: data,
          );
        }).toList();
        if (mounted)
          setState(() {
            _configs = loaded;
            _isLoading = false;
          });
        return;
      }
    } catch (e, st) {
      // 読み込み失敗時はデフォルトに戻す
      debugPrint('[_loadConfigs] 読み込みに失敗しました: $e\n$st');
    }
    if (mounted)
      setState(() {
        _configs = _defaultConfigs;
        _isLoading = false;
      });
  }

  // ── SharedPreferences へ保存 ─────────────────────────────────────────────
  Future<void> _saveConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _configs
          .map((c) => {'id': c.id, 'type': c.type, 'data': c.data})
          .toList();
      await prefs.setString(_kPrefsKey, json.encode(list));
    } catch (e, st) {
      // 保存失敗をデバッグコンソールに記録（アプリはクラッシュさせない）
      debugPrint('[_saveConfigs] 保存に失敗しました: $e\n$st');
    }
  }

  Future<void> _saveUserConstants() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUserConstantsKey, json.encode(_userConstants));
    } catch (e, st) {
      debugPrint('[_saveUserConstants] 保存に失敗しました: $e\n$st');
    }
  }

  void _updateConfig(int index, Map<String, dynamic> data) {
    final now = DateTime.now().toIso8601String();
    // 既存の createdAt を引き継ぎ、updatedAt を現在時刻で上書き
    final updated = <String, dynamic>{
      ...data,
      'updatedAt': now,
    };
    if (!updated.containsKey('createdAt') || updated['createdAt'] == null) {
      updated['createdAt'] = _configs[index].data['createdAt'] ?? now;
    }
    setState(() {
      _configs[index] = _configs[index].copyWith(data: updated);
    });
    _saveConfigs();
  }

  Future<void> _duplicateConfig(int index) async {
    if (_configs.length >= _kFreeSheetLimit) {
      final isPro = await RevenueCatService.isProActive();
      if (!isPro) {
        if (!mounted) return;
        await showSheetLimitDialog(context);
        return;
      }
    }
    final src = _configs[index];
    final now = DateTime.now().toIso8601String();
    setState(() {
      _configs.insert(
        index + 1,
        WidgetConfig(
          id: '${DateTime.now().millisecondsSinceEpoch}',
          type: src.type,
          data: Map<String, dynamic>.from(src.data)
            ..['title'] = '${src.data['title'] ?? '定型計算'} (コピー)'
            ..['createdAt'] = now
            ..['updatedAt'] = now,
        ),
      );
    });
    _saveConfigs();
  }

  static const int _kFreeSheetLimit = 5;

  Future<void> _addConfig() async {
    // 無料版は5枚まで
    if (_configs.length >= _kFreeSheetLimit) {
      final isPro = await RevenueCatService.isProActive();
      if (!isPro) {
        if (!mounted) return;
        await showSheetLimitDialog(context);
        return;
      }
    }
    final _nowStr = DateTime.now().toIso8601String();
    final newConfig = WidgetConfig(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      type: 'calculator',
      data: {
        'title': '無題のシート',
        'items': _sampleItems,
        'isExpanded': true,
        'bgColor': 0xFF1A1A2E,
        'createdAt': _nowStr,
        'updatedAt': _nowStr,
      },
    );
    setState(() => _configs.insert(0, newConfig));
    _saveConfigs();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WidgetDetailPage(
          initialConfig: newConfig,
          onUpdate: (data) => _updateConfig(0, data),
          onDuplicate: () => _duplicateConfig(0),
          globalConstants: _userConstants,
          clipboardNotifier: _clipboardNotifier,
          allConfigs: _configs,
        ),
      ),
    );
  }

  /// 電卓パネルの計算結果を新規シートに追加する
  void _addCalcItemToNewSheet(Map<String, dynamic> item) {
    _addCalcItemsToNewSheet([item]);
  }

  Future<void> _addCalcItemsToNewSheet(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    // 無料版は5枚まで
    if (_configs.length >= _kFreeSheetLimit) {
      final isPro = await RevenueCatService.isProActive();
      if (!isPro) {
        if (!mounted) return;
        await showSheetLimitDialog(context);
        return;
      }
    }
    final _nowStr2 = DateTime.now().toIso8601String();
    final newConfig = WidgetConfig(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      type: 'calculator',
      data: {
        'title': '無題のシート',
        'items': items,
        'isExpanded': true,
        'bgColor': 0xFF1A1A2E,
        'createdAt': _nowStr2,
        'updatedAt': _nowStr2,
      },
    );
    setState(() => _configs.insert(0, newConfig));
    _saveConfigs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(items.length == 1 ? '新規シートに追加しました' : '${items.length}件を新規シートに追加しました'),
          backgroundColor: const Color.fromARGB(255, 234, 234, 235),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      // 追加したシート（先頭）を開く
      _openDetail(0);
    }
  }

  /// AI に計算式を生成させ、新規シートとして保存する
  Future<void> _openHomeAiGenerate() async {
    if (_isHomeAiGenerating) return;
    final ai = GemmaAi();
    if (ai.currentModel == AiModel.local && !ai.isInitialized) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ローカルAIが初期化されていません。'),
          backgroundColor: Color(0xFF2A2A3A),
        ),
      );
      return;
    }

    final result = await showHomeAiGenerateSheet(context);
    if (result == null || (result.instruction.isEmpty && result.imageBytes == null)) return;
    if (!mounted) return;

    final canUse = await RevenueCatService.consumeUse();
    if (!canUse) {
      if (!mounted) return;
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
      return;
    }

    setState(() => _isHomeAiGenerating = true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('計算式を生成中...'),
        duration: Duration(seconds: 3),
        backgroundColor: Color(0xFF2A2A3A),
      ),
    );

    final instruction = result.instruction;
    final prompt =
"""
User wants to generate calculator expression(s) for: "$instruction".
Return a JSON array of objects. Multiple formulas are allowed if the request implies multiple steps or variations.

[CRITICAL INSTRUCTIONS]
1. Combine calculation steps into the 'others' list of an item where appropriate. 
2. [IMPORTANT] If the user explicitly mentions specific numbers in the instruction (e.g., "3万円", "5人"), use those actual numbers in the corresponding fields ("input", "operand", or "val") instead of 0.0. 
3. If a value is required for the calculation but NOT specified in the user's instruction, set "input", "operand", or "val" to 0.0 and put the label in "unit".
4. For mathematical constants required by the formula (e.g., "2" in triangle area, "3.14" in circle), set the specific numerical value in "input", "operand", or "val".
5. Be mathematically precise. Only use division or constants (like /2) if the specific formula requires it.
6. Use "brackets" to specify priority calculations (parentheses). Index 0 is "input", index 1 is "operand", index 2 is "others[0]", index 3 is "others[1]", and so on.
7. Ensure every formula is mathematically correct.

Structure per item:
{
  "name": "Calculation name",
  "input": 0.0, // Use the user's specified number if available, otherwise 0.0
  "unit1": "label for first value",
  "op": "+", (one of: +, -, x, /, %)
  "operand": 0.0, // Use the user's specified number if available, otherwise 0.0
  "unit2": "label for second value",
  "others": [
    { "op": "/", "val": 2.0, "unit": "" } // Use the user's specified number if available
  ],
  "brackets": [
    { "start": 0, "end": 1 }
  ],
  "unitResult": "label for result",
  "precision": 2
}

Example output for "3万円を5人で割り勘":
[
  {
    "name": "割り勘計算",
    "input": 30000.0,
    "unit1": "総額（円）",
    "op": "/",
    "operand": 5.0,
    "unit2": "人数",
    "others": [],
    "brackets": [],
    "unitResult": "1人あたりの支払額",
    "precision": 0
  }
]
""";

    try {
      const systemPrompt =
          "You are a calculator generator AI. Return a JSON array of formula objects.";
      final String res;
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
        final items = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        final title = instruction.isNotEmpty ? instruction : '新規シート';
        final _aiNowStr = DateTime.now().toIso8601String();
        final newConfig = WidgetConfig(
          id: '${DateTime.now().millisecondsSinceEpoch}',
          type: 'calculator',
          data: {
            'title': title,
            'items': items,
            'isExpanded': true,
            'bgColor': 0xFF1A1A2E,
            'createdAt': _aiNowStr,
            'updatedAt': _aiNowStr,
          },
        );
        if (mounted) {
          setState(() => _configs.insert(0, newConfig));
          _saveConfigs();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('「$title」を生成しました'),
              backgroundColor: const Color.fromARGB(255, 230, 230, 230),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('生成失敗: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isHomeAiGenerating = false);
    }
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
        title: const Text(
          'シートの削除',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
            child: const Text(
              '削除する',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
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
    final config = _configs[index];
    if (config.type == 'merged') {
      final sheetIds = (config.data['sheetIds'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList();
      final sheets = sheetIds
          .map((id) {
            try {
              return _configs.firstWhere((c) => c.id == id);
            } catch (_) {
              return null;
            }
          })
          .whereType<WidgetConfig>()
          .toList();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MergedDetailPage(
            mergedConfig: config,
            onMergedUpdate: (data) => _updateConfig(index, data),
            sheets: sheets,
            allConfigs: _configs,
            onSheetUpdate: (sheetId, data) {
              final idx = _configs.indexWhere((c) => c.id == sheetId);
              if (idx != -1) {
                final _sheetNow = DateTime.now().toIso8601String();
                final updatedData = <String, dynamic>{
                  ...data,
                  'updatedAt': _sheetNow,
                };
                if (!updatedData.containsKey('createdAt') || updatedData['createdAt'] == null) {
                  updatedData['createdAt'] = _configs[idx].data['createdAt'] ?? _sheetNow;
                }
                setState(() {
                  _configs[idx] = _configs[idx].copyWith(data: updatedData);
                });
                _saveConfigs();
              }
            },
            clipboardNotifier: _clipboardNotifier,
            onSheetDuplicate: (sheetId) {
              final srcIdx = _configs.indexWhere((c) => c.id == sheetId);
              if (srcIdx == -1) return;
              final src = _configs[srcIdx];
              final _dupNow = DateTime.now().toIso8601String();
              final newConfig = WidgetConfig(
                id: '${DateTime.now().millisecondsSinceEpoch}',
                type: src.type,
                data: Map<String, dynamic>.from(src.data)
                  ..['title'] = '${src.data['title'] ?? '定型計算'} (コピー)'
                  ..['createdAt'] = _dupNow
                  ..['updatedAt'] = _dupNow,
              );
              setState(() => _configs.insert(srcIdx + 1, newConfig));
              _saveConfigs();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '「${src.data['title'] ?? '定型計算'}」を複製しました',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.black,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            globalConstants: _userConstants,
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WidgetDetailPage(
          initialConfig: config,
          onUpdate: (data) => _updateConfig(index, data),
          onDuplicate: () => _duplicateConfig(index),
          globalConstants: _userConstants,
          clipboardNotifier: _clipboardNotifier,
          allConfigs: _configs,
        ),
      ),
    );
  }

  void _showMainMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5E81FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.merge_rounded,
                    color: Color(0xFF5E81FF),
                    size: 22,
                  ),
                ),
                title: const Row(
                  children: [
                    Text(
                      '計算シートを結合する',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    ProBadge(),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '複数のシートを1画面に並べて表示',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const ProRequiredLabel(text: 'プロ版が必要です'),
                  ],
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ProGuard.checkAndRun(context, _startSelectMode);
                },
              ),
              const Divider(color: Colors.white10, indent: 16, endIndent: 16),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Colors.purpleAccent,
                    size: 22,
                  ),
                ),
                title: const Row(
                  children: [
                    Text(
                      'QRコードで共有',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    ProBadge(),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'シートを選択してQRコードで書き出す',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const ProRequiredLabel(text: 'プロ版が必要です'),
                  ],
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ProGuard.checkAndRun(context, _startQrSelectMode);
                },
              ),
              const Divider(color: Colors.white10, indent: 16, endIndent: 16),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.tealAccent,
                    size: 22,
                  ),
                ),
                title: const Row(
                  children: [
                    Text(
                      'シートを取り込む',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    ProBadge(),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QRコードからシートをインポート',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const ProRequiredLabel(text: 'プロ版が必要です'),
                  ],
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ProGuard.checkAndRun(context, _showQrScanner);
                },
              ),
              const Divider(color: Colors.white10, indent: 16, endIndent: 16),
             ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B7FFF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.hub_rounded,
                    color: Color(0xFF7B7FFF),
                    size: 22,
                  ),
                ),
                title: const Row(
                  children: [
                    Text(
                      'リンクグラフ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'シート間のリンク関係をグラフで可視化',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LinkGraphPage(
                          configs: _configs
                              .map((c) => {
                                    'id': c.id,
                                    'type': c.type,
                                    'data': c.data,
                                  })
                              .toList(),
                          onOpenSheet: (sheetId) {
                            final idx =
                                _configs.indexWhere((c) => c.id == sheetId);
                            if (idx != -1) _openDetail(idx);
                          },
                        ),
                      ),
                    );
                },
              ),
              const Divider(color: Colors.white10, indent: 16, endIndent: 16),
    ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Colors.amberAccent,
                    size: 22,
                  ),
                ),
                title: const Text(
                  '設定',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'ユーザー定義定数の管理',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openSettings();
                },
              ),
           
            ],
          ),
        ),
        ),
      ),
    );
  }

  void _startSelectMode() {
    if (_configs.isEmpty) return;
    setState(() {
      _isSelectMode = true;
      _appendTargetSheetId = null;
      _selectedForMerge.clear();
    });
  }

  void _startAppendMode(String targetId) {
    if (_configs.isEmpty) return;
    final targetIdx = _configs.indexWhere((c) => c.id == targetId);
    if (targetIdx == -1) return;

    final targetConfig = _configs[targetIdx];
    final currentSheetIds =
        (targetConfig.data['sheetIds'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList();

    final initialSelected = <int>{};
    for (final id in currentSheetIds) {
      final idx = _configs.indexWhere((c) => c.id == id);
      if (idx != -1) {
        initialSelected.add(idx);
      }
    }

    setState(() {
      _isSelectMode = true;
      _appendTargetSheetId = targetId;
      _selectedForMerge.clear();
      _selectedForMerge.addAll(initialSelected);
    });
  }

  void _cancelSelectMode() {
    setState(() {
      _isSelectMode = false;
      _appendTargetSheetId = null;
      _selectedForMerge.clear();
    });
  }

  // ── QR共有選択モード ──────────────────────────────────────────────────────
  void _startQrSelectMode() {
    if (_configs.isEmpty) return;
    setState(() {
      _isQrSelectMode = true;
      _selectedForQrShare.clear();
    });
  }

  void _cancelQrSelectMode() {
    setState(() {
      _isQrSelectMode = false;
      _selectedForQrShare.clear();
    });
  }

  void _toggleQrSelection(int index) {
    setState(() {
      if (_selectedForQrShare.contains(index)) {
        _selectedForQrShare.remove(index);
      } else {
        _selectedForQrShare.add(index);
      }
    });
  }

  /// 選択シートの QR データを生成してダイアログを表示する
  void _executeQrShare() {
    if (_selectedForQrShare.isEmpty) return;
    final sorted = _selectedForQrShare.toList()..sort();
    // 結合シートはその構成シートに展開し、重複を除外する
    final seenIds = <String>{};
    final targetConfigs = <WidgetConfig>[];
    for (final i in sorted) {
      final cfg = _configs[i];
      if (cfg.type == 'merged') {
        final sheetIds = (cfg.data['sheetIds'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList();
        for (final id in sheetIds) {
          if (seenIds.contains(id)) continue;
          try {
            final sheet = _configs.firstWhere((c) => c.id == id);
            if (sheet.type != 'merged') {
              seenIds.add(id);
              targetConfigs.add(sheet);
            }
          } catch (_) {}
        }
      } else {
        if (seenIds.contains(cfg.id)) continue;
        seenIds.add(cfg.id);
        targetConfigs.add(cfg);
      }
    }
    if (targetConfigs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('共有できるシートがありません'),
          backgroundColor: Color(0xFF2A2A3A),
        ),
      );
      return;
    }

    final sheets = targetConfigs.map((config) {
      final title = config.data['title'] as String? ?? '定型計算';
      final items = config.data['items'] as List<dynamic>? ?? [];
      final qrDataList = _buildQrDataForConfig(config);
      return (title: title, itemCount: items.length, qrDataList: qrDataList);
    }).toList();

    setState(() {
      _isQrSelectMode = false;
      _selectedForQrShare.clear();
    });

    showDialog(
      context: context,
      builder: (ctx) => MultiSheetQrDialog(sheets: sheets),
    );
  }

  /// WidgetConfig から QR データチャンクを生成する（リンク/変換/論理式含む）
  List<String> _buildQrDataForConfig(WidgetConfig config) {
    double safeDouble(num? v) {
      final d = (v ?? 0.0).toDouble();
      if (d.isNaN || d.isInfinite) return 0.0;
      return d;
    }

    // Simple single-operation arithmetic (same operators as _calculateSingle)
    double calcSingle(double a, String op, double b) {
      switch (op) {
        case '+': return a + b;
        case '-': return a - b;
        case 'x': return a * b;
        case '/': return b != 0 ? a / b : 0.0;
        case '%': return b != 0 ? a % b : 0.0;
        default: return a;
      }
    }

    // Two-pass arithmetic evaluator with operator precedence (mirrors _evaluateTokens)
    double simpleEval(double inp, String op, double ope, List<dynamic> others) {
      final work = <dynamic>[inp, op, ope];
      for (final o in others) {
        final om = o as Map;
        work.add(om['op'] as String? ?? '+');
        work.add((om['val'] as num? ?? 0.0).toDouble());
      }
      // Pass 1: high-priority ops (x / %)
      int i = 1;
      while (i < work.length) {
        final op2 = work[i] as String;
        if (op2 == 'x' || op2 == '/' || op2 == '%') {
          final res = calcSingle(
            (work[i - 1] as num).toDouble(), op2, (work[i + 1] as num).toDouble());
          work.replaceRange(i - 1, i + 2, [res]);
        } else {
          i += 2;
        }
      }
      // Pass 2: low-priority ops (+ -)
      double result = (work[0] as num).toDouble();
      for (int j = 1; j < work.length; j += 2) {
        result = calcSingle(result, work[j] as String, (work[j + 1] as num).toDouble());
      }
      return result;
    }

    // Compute item results for a WidgetConfig using stored values + same-sheet link resolution
    List<double> computeSheetResults(WidgetConfig cfg) {
      final items = (cfg.data['items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (items.isEmpty) return [];
      final results = List<double>.filled(items.length, 0.0);

      // Pass 1: raw stored values
      for (int i = 0; i < items.length; i++) {
        final it = items[i];
        results[i] = simpleEval(
          safeDouble(it['input'] as num?),
          it['op'] as String? ?? '+',
          safeDouble(it['operand'] as num?),
          it['others'] as List? ?? [],
        );
      }

      // Resolve a same-sheet link (skip cross-sheet / constant / logic links)
      double resolveInSheet(bool isLink, Map? src, double stored) {
        if (!isLink || src == null) return stored;
        if (src['sheetId'] != null || src['type'] != null) return stored;
        final si = src['rowIdx'] as int? ?? 0;
        final st = src['target'] as String? ?? 'result';
        if (si < 0 || si >= items.length) return stored;
        if (st == 'result') return results[si];
        if (st == 'input') return safeDouble(items[si]['input'] as num?);
        if (st == 'operand') return safeDouble(items[si]['operand'] as num?);
        return stored;
      }

      // Passes 2+: iterative convergence for same-sheet links
      for (int pass = 0; pass < items.length; pass++) {
        bool anyChange = false;
        final next = List<double>.filled(items.length, 0.0);
        for (int i = 0; i < items.length; i++) {
          final it = items[i];
          final inp = resolveInSheet(
              it['inputLink'] == true, it['inputLinkSource'] as Map?,
              safeDouble(it['input'] as num?));
          final ope = resolveInSheet(
              it['operandLink'] == true, it['operandLinkSource'] as Map?,
              safeDouble(it['operand'] as num?));
          final oth = (it['others'] as List? ?? []).map((o) {
            final om = Map<String, dynamic>.from(o as Map);
            om['val'] = resolveInSheet(
                om['valLink'] == true, om['valLinkSource'] as Map?,
                safeDouble(om['val'] as num?));
            return om;
          }).toList();
          next[i] = simpleEval(inp, it['op'] as String? ?? '+', ope, oth);
          if ((next[i] - results[i]).abs() > 1e-10) anyChange = true;
        }
        for (int i = 0; i < items.length; i++) results[i] = next[i];
        if (!anyChange) break;
      }
      return results;
    }

    // For cross-sheet / constant / logic links: resolve to a concrete value.
    // Returns null for same-sheet links → caller preserves link metadata.
    double? resolveComplexLink(
        bool isLinked, Map<String, dynamic>? src, double stored) {
      if (!isLinked || src == null) return null;
      final sheetId = src['sheetId'] as String?;
      final type = src['type'] as String?;

      if (sheetId != null) {
        // Cross-sheet link: look up source sheet in _configs and compute
        try {
          final srcCfg = _configs.firstWhere(
            (c) => c.id == sheetId,
            orElse: () => WidgetConfig(id: '', type: '', data: {}),
          );
          if (srcCfg.id.isEmpty) return 0.0;
          final srcItems = (srcCfg.data['items'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final rowIdx = src['rowIdx'] as int? ?? 0;
          final target = src['target'] as String? ?? 'result';
          if (rowIdx < 0 || rowIdx >= srcItems.length) return 0.0;
          if (target == 'input') {
            return safeDouble(srcItems[rowIdx]['input'] as num?);
          }
          if (target == 'operand') {
            return safeDouble(srcItems[rowIdx]['operand'] as num?);
          }
          if (target.startsWith('other_')) {
            final idx = int.tryParse(target.split('_')[1]) ?? 0;
            final oth = srcItems[rowIdx]['others'] as List? ?? [];
            if (idx < oth.length) {
              return safeDouble((oth[idx] as Map)['val'] as num?);
            }
            return 0.0;
          }
          // target == 'result': compute via sheet results
          final results = computeSheetResults(srcCfg);
          return rowIdx < results.length ? results[rowIdx] : 0.0;
        } catch (_) {
          return 0.0;
        }
      }

      if (type == 'constant') {
        // Constant link: look up constant value from this sheet's constants
        final ci = src['constIdx'] as int? ?? 0;
        final consts = config.data['constants'] as List<dynamic>? ?? [];
        if (ci >= 0 && ci < consts.length) {
          return safeDouble((consts[ci] as Map)['value'] as num?);
        }
        return stored;
      }

      if (type == 'logic') {
        // Logic links: preserve link metadata (logic items are exported with their IDs)
        return null;
      }

      // Same-sheet link (no sheetId, no special type) → preserve metadata
      return null;
    }

    // Compact a link source by removing null/false values to minimize QR size.
    // Safe: receivers check e.g. source['trueLink'] == true (missing key → false)
    // and source['trueLinkSource'] as Map? (missing key → null).
    Map<String, dynamic> compactSrc(Map<String, dynamic> src) =>
        Map.fromEntries(
            src.entries.where((e) => e.value != null && e.value != false));

    final title = config.data['title'] as String? ?? '定型計算';
    final rawItems = config.data['items'] as List<dynamic>? ?? [];

    final qrItems = rawItems.map<Map<String, dynamic>>((e) {
      final item = Map<String, dynamic>.from(e as Map);

      final inputLinkSrc = item['inputLinkSource'] as Map<String, dynamic>?;
      final inputLinked = item['inputLink'] == true;
      final resolvedInput = resolveComplexLink(
          inputLinked, inputLinkSrc, safeDouble(item['input'] as num?));
      final inputVal = resolvedInput ?? safeDouble(item['input'] as num?);
      final keepInputLink = inputLinked && resolvedInput == null;

      final operandLinkSrc = item['operandLinkSource'] as Map<String, dynamic>?;
      final operandLinked = item['operandLink'] == true;
      final resolvedOperand = resolveComplexLink(
          operandLinked, operandLinkSrc, safeDouble(item['operand'] as num?));
      final operandVal = resolvedOperand ?? safeDouble(item['operand'] as num?);
      final keepOperandLink = operandLinked && resolvedOperand == null;

      return {
        'n': item['name'] as String? ?? '',
        'i': inputVal,
        'op': item['op'] as String? ?? '+',
        'o': operandVal,
        'oth': (item['others'] as List? ?? []).map<Map<String, dynamic>>((o) {
          final om = Map<String, dynamic>.from(o as Map);
          final valLinkSrc = om['valLinkSource'] as Map<String, dynamic>?;
          final valLinked = om['valLink'] == true;
          final resolvedVal = resolveComplexLink(
              valLinked, valLinkSrc, safeDouble(om['val'] as num?));
          final valVal = resolvedVal ?? safeDouble(om['val'] as num?);
          final keepValLink = valLinked && resolvedVal == null;
          return {
            'op': om['op'] as String? ?? '+',
            'v': valVal,
            'u': om['unit'] as String? ?? '',
            if (keepValLink) 'l': true,
            if (keepValLink && valLinkSrc != null) 'ls': compactSrc(valLinkSrc),
            if (om['transform'] != null) 't': om['transform'],
            if (om['powExp'] != null) 'pe': safeDouble(om['powExp'] as num?),
          };
        }).toList(),
        'p': (item['precision'] as num? ?? 2).toInt(),
        'u1': item['unit1'] as String? ?? '',
        'u2': item['unit2'] as String? ?? '',
        'ur': item['unitResult'] as String? ?? '',
        if (keepInputLink) 'il': true,
        if (keepInputLink && inputLinkSrc != null) 'ils': compactSrc(inputLinkSrc),
        if (item['inputTransform'] != null) 'it': item['inputTransform'],
        if (item['inputPowExp'] != null) 'ipe': safeDouble(item['inputPowExp'] as num?),
        if (keepOperandLink) 'ol': true,
        if (keepOperandLink && operandLinkSrc != null) 'ols': compactSrc(operandLinkSrc),
        if (item['operandTransform'] != null) 'ot': item['operandTransform'],
        if (item['operandPowExp'] != null) 'ope': safeDouble(item['operandPowExp'] as num?),
      };
    }).toList();

    // メモ
    final memos = config.data['memos'] as List<dynamic>?;
    final qrMemos = memos?.map<Map<String, dynamic>>((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return {'txt': m['text'] as String? ?? '', 'aci': m['afterCalcIdx'] as int? ?? -1};
    }).toList();

    // スタンドアロンメモ
    final standaloneItems = config.data['standaloneItems'] as List<dynamic>?;
    final qrSItems = standaloneItems
        ?.map((s) => (s as Map)['text'] as String? ?? '')
        .toList();

    // 論理式
    final logicItems = config.data['logicItems'] as List<dynamic>?;
    final qrLogicItems = logicItems?.map<Map<String, dynamic>>((l) {
      final lm = Map<String, dynamic>.from(l as Map);
      final conditions = (lm['conditions'] as List? ?? [])
          .map<Map<String, dynamic>>((c) {
            final cm = Map<String, dynamic>.from(c as Map);
            return {
              'lv': safeDouble(cm['lhsVal'] as num?),
              'll': cm['lhsLabel'] as String? ?? '',
              'op': cm['op'] as String? ?? '==',
              'rv': safeDouble(cm['rhsVal'] as num?),
              'rl': cm['rhsLabel'] as String? ?? '',
              'rv2': safeDouble(cm['rhsVal2'] as num?),
              'rl2': cm['rhsLabel2'] as String? ?? '',
              if (cm['lhsLink'] == true) 'lhl': true,
              if (cm['lhsLinkSource'] != null) 'lhls': compactSrc(Map<String, dynamic>.from(cm['lhsLinkSource'] as Map)),
              if (cm['rhsLink'] == true) 'rhl': true,
              if (cm['rhsLinkSource'] != null) 'rhls': compactSrc(Map<String, dynamic>.from(cm['rhsLinkSource'] as Map)),
              if (cm['rhsLink2'] == true) 'rhl2': true,
              if (cm['rhsLinkSource2'] != null) 'rhls2': compactSrc(Map<String, dynamic>.from(cm['rhsLinkSource2'] as Map)),
            };
          })
          .toList();
      final chainOps = (lm['chainOps'] as List? ?? [])
          .map((e) => e as String)
          .toList();
      return {
        'id': lm['id'] as String? ?? '',
        'n': lm['name'] as String? ?? '',
        'conds': conditions,
        'cops': chainOps,
      };
    }).toList();

    // 表示順（スタンドアロンメモまたは論理式がある場合に含める）
    List<Map<String, dynamic>>? qrDOrder;
    if ((standaloneItems != null && standaloneItems.isNotEmpty) ||
        (logicItems != null && logicItems.isNotEmpty)) {
      final displayOrder = config.data['displayOrder'] as List<dynamic>?;
      final sItemIdToIdx = <String, int>{};
      if (standaloneItems != null) {
        for (int si = 0; si < standaloneItems.length; si++) {
          final id = (standaloneItems[si] as Map)['id'] as String? ?? '';
          sItemIdToIdx[id] = si;
        }
      }
      final lItemIdToIdx = <String, int>{};
      if (logicItems != null) {
        for (int li = 0; li < logicItems.length; li++) {
          final id = (logicItems[li] as Map)['id'] as String? ?? '';
          lItemIdToIdx[id] = li;
        }
      }
      if (displayOrder != null) {
        qrDOrder = displayOrder
            .map<Map<String, dynamic>?>((e) {
              final entry = e as Map;
              if (entry['type'] == 'calc') {
                return {'c': entry['calcIdx'] as int};
              } else if (entry['type'] == 'logic') {
                final id = entry['itemId'] as String? ?? '';
                final idx = lItemIdToIdx[id];
                if (idx == null) return null;
                return {'li': idx};
              } else {
                final id = entry['itemId'] as String? ?? '';
                final idx = sItemIdToIdx[id];
                if (idx == null) return null;
                return {'s': idx};
              }
            })
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    }

    // 定数
    final constants = config.data['constants'] as List<dynamic>?;
    final qrConsts = constants?.map<Map<String, dynamic>>((c) {
      final cm = Map<String, dynamic>.from(c as Map);
      return {'n': cm['name'] as String? ?? '', 'v': safeDouble(cm['value'] as num?)};
    }).toList();

    // チャンク生成（calculator_widget の _buildQrChunks と同じロジック）
    final singlePayload = <String, dynamic>{
      'v': 1,
      't': title,
      'items': qrItems,
      if (qrMemos != null && qrMemos.isNotEmpty) 'memos': qrMemos,
      if (qrSItems != null && qrSItems.isNotEmpty) 'sitems': qrSItems,
      if (qrDOrder != null && qrDOrder.isNotEmpty) 'dorder': qrDOrder,
      if (qrConsts != null && qrConsts.isNotEmpty) 'consts': qrConsts,
      if (qrLogicItems != null && qrLogicItems.isNotEmpty) 'logics': qrLogicItems,
    };
    final singleQr = json.encode(singlePayload);
    if (singleQr.length <= 350) return [singleQr];

    const dataChunkSize = 300;
    final itemsJson = json.encode(qrItems);
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
        'v': 1, 'm': 1, 'tot': total, 'idx': idx, 'd': dataChunks[idx],
      };
      if (idx == 0) {
        envelope['t'] = title;
        if (qrMemos != null && qrMemos.isNotEmpty) envelope['memos'] = qrMemos;
        if (qrSItems != null && qrSItems.isNotEmpty) envelope['sitems'] = qrSItems;
        if (qrDOrder != null && qrDOrder.isNotEmpty) envelope['dorder'] = qrDOrder;
        if (qrConsts != null && qrConsts.isNotEmpty) envelope['consts'] = qrConsts;
        if (qrLogicItems != null && qrLogicItems.isNotEmpty) envelope['logics'] = qrLogicItems;
      }
      return json.encode(envelope);
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedForMerge.contains(index)) {
        _selectedForMerge.remove(index);
      } else {
        _selectedForMerge.add(index);
      }
    });
  }

  void _executeMergeOrAppend() {
    if (_appendTargetSheetId != null) {
      if (_selectedForMerge.isEmpty) return;
      final targetIdx = _configs.indexWhere(
        (c) => c.id == _appendTargetSheetId,
      );
      if (targetIdx != -1) {
        final targetConfig = _configs[targetIdx];
        final currentSheetIds =
            (targetConfig.data['sheetIds'] as List<dynamic>? ?? [])
                .map((e) => e as String)
                .toList();

        final List<String> finalSheetIds = [];

        // 既存のシートのうち、引き続き選択されているものを元の順序で追加
        for (final id in currentSheetIds) {
          final idx = _configs.indexWhere((c) => c.id == id);
          if (idx != -1 && _selectedForMerge.contains(idx)) {
            finalSheetIds.add(id);
          }
        }

        // 新しく選択されたシートを追加
        final newlySelectedIdxs = _selectedForMerge.where((idx) {
          final id = _configs[idx].id;
          return !currentSheetIds.contains(id);
        }).toList()..sort();

        for (final idx in newlySelectedIdxs) {
          finalSheetIds.add(_configs[idx].id);
        }

        final newConfig = targetConfig.copyWith(
          data: {...targetConfig.data, 'sheetIds': finalSheetIds},
        );
        setState(() {
          _configs[targetIdx] = newConfig;
          _isSelectMode = false;
          _appendTargetSheetId = null;
          _selectedForMerge.clear();
        });
        _saveConfigs();
      }
      return;
    }

    if (_selectedForMerge.length < 2) return;
    final sorted = _selectedForMerge.toList()..sort();
    final selectedConfigs = sorted.map((i) => _configs[i]).toList();
    final titles = selectedConfigs
        .map((c) => c.data['title'] as String? ?? '定型計算')
        .join(' + ');
    final sheetIds = selectedConfigs.map((c) => c.id).toList();
    final _mergeNowStr = DateTime.now().toIso8601String();
    final newConfig = WidgetConfig(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      type: 'merged',
      data: {'title': titles, 'sheetIds': sheetIds, 'createdAt': _mergeNowStr, 'updatedAt': _mergeNowStr},
    );
    setState(() {
      _configs.insert(0, newConfig);
      _isSelectMode = false;
      _selectedForMerge.clear();
    });
    _saveConfigs();
    _openDetail(0);
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SettingsPage(
          userConstants: List<Map<String, dynamic>>.from(_userConstants),
          onSave: (updated) {
            setState(() => _userConstants = updated);
            _saveUserConstants();
          },
        ),
      ),
    );
  }

  /// QR コードスキャナー画面を開く
  void _showQrScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => _QrScannerPage(
          onScanned: (String qrData) {
            // スキャナーは開いたまま（複数シートの連続スキャンに対応）
            return _importSheetFromQr(qrData);
          },
          onDone: () {
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  /// スキャンした QR データからシートをインポートする。成功時はシートタイトルを、失敗時は null を返す。
  String? _importSheetFromQr(String qrData) {
    try {
      final decoded = json.decode(qrData);
      if (decoded is! Map<String, dynamic> ||
          decoded['v'] != 1 ||
          decoded['items'] == null) {
        return null;
      }

      final title = decoded['t'] as String? ?? '取り込んだシート';
      final qrItems = decoded['items'] as List<dynamic>;

      final items = qrItems.map<Map<String, dynamic>>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return {
          'name': m['n'] as String? ?? '',
          'input': (m['i'] as num? ?? 0.0).toDouble(),
          'op': m['op'] as String? ?? '+',
          'operand': (m['o'] as num? ?? 0.0).toDouble(),
          'others': (m['oth'] as List? ?? []).map<Map<String, dynamic>>((o) {
            final om = Map<String, dynamic>.from(o as Map);
            return {
              'op': om['op'] as String? ?? '+',
              'val': (om['v'] as num? ?? 0.0).toDouble(),
              'unit': om['u'] as String? ?? '',
              if (om['l'] == true) 'valLink': true,
              if (om['ls'] != null) 'valLinkSource': om['ls'],
              if (om['t'] != null) 'transform': om['t'],
              if (om['pe'] != null) 'powExp': (om['pe'] as num).toDouble(),
            };
          }).toList(),
          'brackets': <dynamic>[],
          'precision': (m['p'] as num? ?? 2).toInt(),
          'unit1': m['u1'] as String? ?? '',
          'unit2': m['u2'] as String? ?? '',
          'unitResult': m['ur'] as String? ?? '',
          if (m['il'] == true) 'inputLink': true,
          if (m['ils'] != null) 'inputLinkSource': m['ils'],
          if (m['it'] != null) 'inputTransform': m['it'],
          if (m['ipe'] != null) 'inputPowExp': (m['ipe'] as num).toDouble(),
          if (m['ol'] == true) 'operandLink': true,
          if (m['ols'] != null) 'operandLinkSource': m['ols'],
          if (m['ot'] != null) 'operandTransform': m['ot'],
          if (m['ope'] != null) 'operandPowExp': (m['ope'] as num).toDouble(),
        };
      }).toList();

      // メモを復元
      final qrMemos = decoded['memos'] as List<dynamic>?;
      final memos = qrMemos?.map<Map<String, dynamic>>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return {
          'text': m['txt'] as String? ?? '',
          'afterCalcIdx': (m['aci'] as num? ?? -1).toInt(),
        };
      }).toList();

      // スタンドアロンメモを復元
      final qrSItems = decoded['sitems'] as List<dynamic>?;
      final baseTs = DateTime.now().millisecondsSinceEpoch;
      final standaloneItems = qrSItems
          ?.asMap()
          .map<int, Map<String, dynamic>>((si, txt) {
            return MapEntry(si, {
              'id': '${baseTs}_si$si',
              'text': txt as String? ?? '',
            });
          })
          .values
          .toList();

      // シート固有定数を復元
      final qrConsts = decoded['consts'] as List<dynamic>?;
      final constants = qrConsts?.map<Map<String, dynamic>>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return {
          'id': '${DateTime.now().millisecondsSinceEpoch}_${m['n']}',
          'name': m['n'] as String? ?? '',
          'value': (m['v'] as num? ?? 0.0).toDouble(),
        };
      }).toList();

      // 論理式を復元（表示順の復元より先に行う）
      final qrLogics = decoded['logics'] as List<dynamic>?;
      final logicItems = qrLogics?.map<Map<String, dynamic>>((l) {
        final lm = Map<String, dynamic>.from(l as Map);
        final baseId = lm['id'] as String? ??
            '${DateTime.now().millisecondsSinceEpoch}_logic';
        final conditions = (lm['conds'] as List? ?? [])
            .map<Map<String, dynamic>>((c) {
              final cm = Map<String, dynamic>.from(c as Map);
              return {
                'lhsVal': (cm['lv'] as num? ?? 0.0).toDouble(),
                'lhsLabel': cm['ll'] as String? ?? '',
                'op': cm['op'] as String? ?? '==',
                'rhsVal': (cm['rv'] as num? ?? 0.0).toDouble(),
                'rhsLabel': cm['rl'] as String? ?? '',
                'rhsVal2': (cm['rv2'] as num? ?? 0.0).toDouble(),
                'rhsLabel2': cm['rl2'] as String? ?? '',
                if (cm['lhl'] == true) 'lhsLink': true,
                if (cm['lhls'] != null) 'lhsLinkSource': cm['lhls'],
                if (cm['rhl'] == true) 'rhsLink': true,
                if (cm['rhls'] != null) 'rhsLinkSource': cm['rhls'],
                if (cm['rhl2'] == true) 'rhsLink2': true,
                if (cm['rhls2'] != null) 'rhsLinkSource2': cm['rhls2'],
              };
            })
            .toList();
        final chainOps = (lm['cops'] as List? ?? [])
            .map((e) => e as String)
            .toList();
        return {
          'id': baseId,
          'name': lm['n'] as String? ?? '',
          'conditions': conditions,
          'chainOps': chainOps,
        };
      }).toList();

      // 表示順を復元（スタンドアロンメモまたは論理式がある場合）
      List<Map<String, dynamic>>? displayOrder;
      final qrDOrder = decoded['dorder'] as List<dynamic>?;
      if (qrDOrder != null &&
          ((standaloneItems != null && standaloneItems.isNotEmpty) ||
              (logicItems != null && logicItems.isNotEmpty))) {
        displayOrder = qrDOrder.map<Map<String, dynamic>>((e) {
          final entry = e as Map;
          if (entry.containsKey('c')) {
            return {'type': 'calc', 'calcIdx': (entry['c'] as num).toInt()};
          } else if (entry.containsKey('li')) {
            final li = (entry['li'] as num).toInt();
            final id = logicItems != null && li < logicItems.length
                ? logicItems[li]['id'] as String
                : '';
            return {'type': 'logic', 'itemId': id};
          } else {
            final si = (entry['s'] as num).toInt();
            final id = standaloneItems != null && si < standaloneItems.length
                ? standaloneItems[si]['id'] as String
                : '';
            return {'type': 'standalone', 'itemId': id};
          }
        }).toList();
      }

      final _qrNowStr = DateTime.now().toIso8601String();
      final newConfig = WidgetConfig(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        type: 'calculator',
        data: {
          'title': title,
          'items': items,
          'isExpanded': true,
          'bgColor': 0xFF1A1A2E,
          'createdAt': _qrNowStr,
          'updatedAt': _qrNowStr,
          if (memos != null && memos.isNotEmpty) 'memos': memos,
          if (standaloneItems != null && standaloneItems.isNotEmpty)
            'standaloneItems': standaloneItems,
          if (displayOrder != null && displayOrder.isNotEmpty)
            'displayOrder': displayOrder,
          if (constants != null && constants.isNotEmpty) 'constants': constants,
          if (logicItems != null && logicItems.isNotEmpty)
            'logicItems': logicItems,
        },
      );

      setState(() => _configs.insert(0, newConfig));
      _saveConfigs();
      return '$title（${items.length}件）';
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D14),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF5E81FF)),
        ),
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
                  expandedHeight: (_isSelectMode || _isQrSelectMode) ? 0 : 200,
                  backgroundColor: const Color(0xFF0D0D14).withOpacity(0.9),
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  actions: _isSelectMode
                      ? [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                _selectedForMerge.length < 2
                                    ? '2件以上選択してください'
                                    : '${_selectedForMerge.length}件選択中',
                                style: TextStyle(
                                  color: _selectedForMerge.length >= 2
                                      ? const Color(0xFF5E81FF)
                                      : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ]
                      : _isQrSelectMode
                      ? [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                _selectedForQrShare.isEmpty
                                    ? '共有するシートを選択してください'
                                    : '${_selectedForQrShare.length}件選択中',
                                style: TextStyle(
                                  color: _selectedForQrShare.isNotEmpty
                                      ? Colors.purpleAccent
                                      : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ]
                      : [
                          IconButton(
                            icon: const Icon(
                              Icons.menu_rounded,
                              color: Colors.white70,
                              size: 26,
                            ),
                            onPressed: _showMainMenu,
                            tooltip: 'メニュー',
                          ),
                          const SizedBox(width: 8),
                        ],
                  flexibleSpace: (_isSelectMode || _isQrSelectMode)
                      ? null
                      : FlexibleSpaceBar(
                          titlePadding: const EdgeInsets.only(
                            left: 28,
                            bottom: 0,
                          ),
                          centerTitle: false,
                          title: _HomeLogoTitle(),
                        ),
                ),
                if (_configs.isEmpty)
                  const SliverFillRemaining(child: _EmptyState())
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(24, 8, 24,
                        (MediaQuery.of(context).size.height * 0.55).clamp(460.0, 580.0) + 80),
                    sliver: SliverReorderableList(
                      itemCount: _configs.length,
                      onReorder: _reorderConfigs,
                      itemBuilder: (ctx, i) {
                        final cfg = _configs[i];
                        List<WidgetConfig>? resolvedSheets;
                        if (cfg.type == 'merged') {
                          final ids =
                              (cfg.data['sheetIds'] as List<dynamic>? ?? [])
                                  .map((e) => e as String)
                                  .toList();
                          resolvedSheets = ids
                              .map((id) {
                                try {
                                  return _configs.firstWhere((c) => c.id == id);
                                } catch (_) {
                                  return null;
                                }
                              })
                              .whereType<WidgetConfig>()
                              .toList();
                        }
                        return Padding(
                          key: ValueKey(cfg.id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _WidgetCard(
                            config: cfg,
                            index: i,
                            onTap: _isSelectMode
                                ? (_appendTargetSheetId == cfg.id
                                      ? () {}
                                      : () => _toggleSelection(i))
                                : _isQrSelectMode
                                ? () => _toggleQrSelection(i)
                                : () => _openDetail(i),
                            onDelete: () => _deleteConfig(i),
                            onUpdate: (data) => _updateConfig(i, data),
                            isSelectMode: _isSelectMode || _isQrSelectMode,
                            isSelected: _isSelectMode
                                ? _selectedForMerge.contains(i)
                                : _selectedForQrShare.contains(i),
                            resolvedSheets: resolvedSheets,
                            onReorderSheets: resolvedSheets == null
                                ? null
                                : (oldIdx, newIdx) {
                                    final sheetIds =
                                        (cfg.data['sheetIds'] as List<dynamic>)
                                            .map((e) => e as String)
                                            .toList();
                                    if (newIdx > oldIdx) newIdx -= 1;
                                    final id = sheetIds.removeAt(oldIdx);
                                    sheetIds.insert(newIdx, id);
                                    _updateConfig(i, {
                                      ...cfg.data,
                                      'sheetIds': sheetIds,
                                    });
                                  },
                            onTapSheet: (sheetId) {
                              final sheetIdx = _configs.indexWhere(
                                (c) => c.id == sheetId,
                              );
                              if (sheetIdx != -1) {
                                _openDetail(sheetIdx);
                              }
                            },
                            onAppendTap: () => _startAppendMode(cfg.id),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          // 常時表示電卓パネル（スワイプで開閉）
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: HomeCalcBottomPanel(
              key: _homeCalcPanelKey,
              onAddItem: _addCalcItemToNewSheet,
              onAddItems: _addCalcItemsToNewSheet,
              onExpandChanged: (v) => setState(() => _isCalcExpanded = v),
            ),
          ),
        ],
      ),
      floatingActionButton: _isQrSelectMode
          ? _QrShareActionBar(
              selectedCount: _selectedForQrShare.length,
              onShare: _executeQrShare,
              onCancel: _cancelQrSelectMode,
            )
          : _isSelectMode
          ? _MergeActionBar(
              selectedCount: _selectedForMerge.length,
              onMerge: _executeMergeOrAppend,
              onCancel: _cancelSelectMode,
              isAppendMode: _appendTargetSheetId != null,
            )
          : _isCalcExpanded
          ? null
          : Padding(
            padding: const EdgeInsets.only(bottom: 40.0),
            child: _HomeFab(
                onAiGenerate: _openHomeAiGenerate,
                onAddSheet: _addConfig,
                isAiGenerating: _isHomeAiGenerating,
              ),
          ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: _clipboardNotifier,
        builder: (ctx, clipboardItem, _) {
          if (clipboardItem == null) return const SizedBox.shrink();
          return ClipboardBottomBar(
            item: clipboardItem,
            onClear: () => _clipboardNotifier.value = null,
          );
        },
      ),
    );
  }
}

// ── ホーム画面ロゴ（Pro対応グラデーション） ──────────────────────────────────────
class _HomeLogoTitle extends StatefulWidget {
  const _HomeLogoTitle();

  @override
  State<_HomeLogoTitle> createState() => _HomeLogoTitleState();
}

class _HomeLogoTitleState extends State<_HomeLogoTitle> {
  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    _checkPro();
  }

  Future<void> _checkPro() async {
    final isPro = await RevenueCatService.isProActive();
    if (mounted) setState(() => _isPro = isPro);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(flex: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF5E81FF), Color(0xFFB08FFF), Color(0xFF82C8FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'Genba Calc',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            if (_isPro) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                   gradient: const LinearGradient(
                    colors: [Color.fromARGB(255, 255, 185, 94), Color.fromARGB(255, 255, 122, 246)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5E81FF).withOpacity(0.5),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        Text(
          '現場を支える、次世代の電卓',
          style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        const Spacer(flex: 1),
      ],
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

class _WidgetCard extends StatefulWidget {
  final WidgetConfig config;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final void Function(Map<String, dynamic>) onUpdate;
  final bool isSelectMode;
  final bool isSelected;
  final List<WidgetConfig>? resolvedSheets;
  final void Function(int oldIndex, int newIndex)? onReorderSheets;
  final void Function(String sheetId)? onTapSheet;
  final VoidCallback? onAppendTap;

  const _WidgetCard({
    required this.config,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.onUpdate,
    this.isSelectMode = false,
    this.isSelected = false,
    this.resolvedSheets,
    this.onReorderSheets,
    this.onTapSheet,
    this.onAppendTap,
  });

  static const List<Color> _accentColors = [Color(0xFF5E81FF)];

  @override
  State<_WidgetCard> createState() => _WidgetCardState();
}

class _WidgetCardState extends State<_WidgetCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isMerged = widget.config.type == 'merged';
    final title =
        widget.config.data['title'] as String? ?? (isMerged ? '結合ビュー' : '定型計算');
    final items = widget.config.data['items'] as List<dynamic>? ?? [];
    final memos = widget.config.data['memos'] as List<dynamic>? ?? [];
    final exposedCount = items
        .where((it) => (it as Map)['exposed'] == true)
        .length;
    final resolvedSheets = widget.resolvedSheets ?? [];
    final sheetCount = isMerged
        ? ((widget.config.data['sheetIds'] as List?)?.length ??
              resolvedSheets.length)
        : 0;
    final accent = _WidgetCard
        ._accentColors[widget.index % _WidgetCard._accentColors.length];
    final bgColorValue = widget.config.data['bgColor'] as int?;
    // For merged: prefer the merged config's own bgColor; fall back to first resolved sheet
    final effectiveBgValue = isMerged
        ? (bgColorValue ?? (resolvedSheets.isNotEmpty ? resolvedSheets.first.data['bgColor'] as int? : null))
        : bgColorValue;
    final cardBgColor = effectiveBgValue != null
        ? Color(effectiveBgValue)
        : const Color(0xFF1A1A26);
    final isDark = cardBgColor.computeLuminance() < 0.5;
    final titleColor = isDark ? Colors.white : Colors.black;
    final subIconColor = isDark ? Colors.white24 : Colors.black26;
    final borderColor = widget.isSelected
        ? const Color(0xFF5E81FF)
        : isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.12);

    // 最終更新日のフォーマット
    final _updatedAtStr = widget.config.data['updatedAt'] as String?;
    String _updatedLabel = '';
    if (_updatedAtStr != null) {
      try {
        final dt = DateTime.parse(_updatedAtStr).toLocal();
        _updatedLabel =
            '更新 ${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    final leading = widget.isSelectMode
        ? AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isSelected
                  ? const Color(0xFF5E81FF)
                  : Colors.transparent,
              border: Border.all(
                color: widget.isSelected
                    ? const Color(0xFF5E81FF)
                    : (isDark ? Colors.transparent : Colors.transparent),
                width: 2,
              ),
            ),
            child: widget.isSelected
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          )
        : ReorderableDragStartListener(
            index: widget.index,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.drag_indicator, color: subIconColor, size: 22),
            ),
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: cardBgColor.withAlpha(240),
        border: widget.isSelected
            ? Border.all(color: const Color(0xFF5E81FF), width: 2.5)
            : null,
        boxShadow: [
   BoxShadow(
            color: widget.isSelected
                ? const Color(0xFF5E81FF).withOpacity(0.25)
                : const Color.fromARGB(255, 234, 130, 255).withOpacity(isDark ? 0.05 : 0.05),
            blurRadius: 34,
            offset: const Offset(5, 5),
          ),
          BoxShadow(
            color: widget.isSelected
                ? const Color(0xFF5E81FF).withOpacity(0.25)
                : const Color.fromARGB(255, 130, 199, 255).withOpacity(isDark ? 0.05 : 0.05),
            blurRadius: 34,
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
                    width: widget.isSelected ? 0 : 1.5,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(32),
                    topRight: const Radius.circular(32),
                    bottomLeft: _isExpanded
                        ? Radius.zero
                        : const Radius.circular(32),
                    bottomRight: _isExpanded
                        ? Radius.zero
                        : const Radius.circular(32),
                  ),
                ),
                child: Row(
                  children: [
                    leading,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // merged indicator strip
                          if (isMerged) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: resolvedSheets.take(5).map<Widget>((
                                  s,
                                ) {
                                  final sColor = s.data['bgColor'] as int?;
                                  return Container(
                                    width: 16,
                                    height: 16,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      color: sColor != null
                                          ? Color(sColor)
                                          : const Color(0xFF5E81FF),
                                      borderRadius: BorderRadius.circular(50),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(1),
                                        width: 2,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
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
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isMerged) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(
                                        255,
                                        255,
                                        94,
                                        94,
                                      ).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.merge_rounded,
                                          size: 12,
                                          color: Color.fromARGB(
                                            255,
                                            255,
                                            94,
                                            94,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '($sheetCount) 結合シート',
                                          style: const TextStyle(
                                            color: Color.fromARGB(
                                              255,
                                              255,
                                              94,
                                              94,
                                            ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
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
                                          items.isEmpty
                                              ? '計算式未設定'
                                              : '${items.length}件',
                                          style: TextStyle(
                                            color: accent.withOpacity(0.9),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (memos.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
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
                                            '${memos.length}件',
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
                                  if (exposedCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.tealAccent.withOpacity(
                                          0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.link_rounded,
                                            size: 12,
                                            color: Colors.teal,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$exposedCount件',
                                            style: const TextStyle(
                                              color: Colors.teal,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                          if (_updatedLabel.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 10,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.28)
                                      : Colors.black.withOpacity(0.3),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _updatedLabel,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.28)
                                        : Colors.black.withOpacity(0.3),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!widget.isSelectMode)
                      Column(
                        children: [
                          GestureDetector(
                            onTap: widget.onDelete,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                             //   color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.delete_sweep_rounded,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.5)
                                      : Colors.black.withOpacity(0.55),
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20, width: 40),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _isExpanded = !_isExpanded),
                            child: Icon(
                              _isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: isDark ? Colors.white38 : Colors.black54,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
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
              child: isMerged
                  ? _buildMergedExpanded(resolvedSheets, isDark)
                  : CalculatorViewCard(
                      config: widget.config,
                      onUpdate: widget.onUpdate,
                      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildMergedExpanded(List<WidgetConfig> sheets, bool isDark) {
    if (sheets.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        itemCount: sheets.length,
        onReorder: (oldIndex, newIndex) =>
            widget.onReorderSheets?.call(oldIndex, newIndex),
        itemBuilder: (ctx, idx) {
          final s = sheets[idx];
          final sTitle = s.data['title'] as String? ?? '定型計算';
          final sColorVal = s.data['bgColor'] as int?;
          final sColor = sColorVal != null
              ? Color(sColorVal)
              : const Color(0xFF1A1A26);
          final sItemCount = (s.data['items'] as List?)?.length ?? 0;
          return Padding(
            key: ValueKey(s.id),
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: idx,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: Icon(
                      Icons.drag_indicator,
                      color: isDark ? Colors.white24 : Colors.black26,
                      size: 18,
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onTapSheet?.call(s.id),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: sColor,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 0.5,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            sTitle,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$sItemCount件',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        footer: widget.onAppendTap == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: InkWell(
                  onTap: widget.onAppendTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'シートを追加',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
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
}

class _HomeFab extends StatelessWidget {
  final VoidCallback onAddSheet;
  final VoidCallback onAiGenerate;
  final bool isAiGenerating;
  const _HomeFab({
    required this.onAddSheet,
    required this.onAiGenerate,
    this.isAiGenerating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Spacer(),

        // 新規シートボタン
        GestureDetector(
          onTap: onAddSheet,
          child: Container(
            height: 64,
            width: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
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
            child:
                Icon(Icons.add_rounded, color: Colors.black, size: 28),
               
          ),
        ),
        const SizedBox(width:16 ),
        // AI生成ボタン
        GestureDetector(
          onTap: isAiGenerating ? null : onAiGenerate,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isAiGenerating
                    ? [
                        Colors.purpleAccent.withOpacity(0.4),
                        Colors.deepPurple.withOpacity(0.4),
                      ]
                    : const [
                        Color.fromARGB(255, 241, 243, 249),
                        Color.fromARGB(255, 202, 183, 255),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purpleAccent.withOpacity(isAiGenerating ? 0.4 : 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: isAiGenerating
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.black,
                    size: 26,
                  ),
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}

// ── 結合モード用アクションバー ──────────────────────────────────────────────
class _MergeActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onMerge;
  final VoidCallback onCancel;
  final bool isAppendMode;

  const _MergeActionBar({
    required this.selectedCount,
    required this.onMerge,
    required this.onCancel,
    this.isAppendMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final canMerge = isAppendMode ? selectedCount >= 1 : selectedCount >= 2;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5E81FF).withOpacity(canMerge ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          const Spacer(),
          Flexible(
            child: GestureDetector(
              onTap: canMerge ? onMerge : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: canMerge
                      ? const LinearGradient(
                          colors: [
                            Color.fromARGB(255, 255, 94, 172),
                            Color(0xFF9E7AFF),
                          ],
                        )
                      : null,
                  color: canMerge ? null : Colors.white.withOpacity(0.06),
                ),
                child: Text(
                  overflow: TextOverflow.ellipsis,
                  canMerge
                      ? (isAppendMode
                            ? '$selectedCount件のシートを追加'
                            : '$selectedCount件のシートを結合')
                      : (isAppendMode ? '1件以上選択' : '2件以上選択'),
                  maxLines: 1,
                  style: TextStyle(
                    color: canMerge ? Colors.white : Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── QR共有アクションバー ──────────────────────────────────────────────────────
class _QrShareActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onShare;
  final VoidCallback onCancel;

  const _QrShareActionBar({
    required this.selectedCount,
    required this.onShare,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final canShare = selectedCount >= 1;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withOpacity(canShare ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: canShare ? onShare : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: canShare
                      ? const LinearGradient(
                          colors: [Color(0xFF9E7AFF), Colors.purpleAccent],
                        )
                      : null,
                  color: canShare ? null : Colors.white.withOpacity(0.06),
                ),
                child: Text(
                  canShare
                      ? '$selectedCount件のシートを共有'
                      : '1件以上選択してください',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: canShare ? Colors.white : Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 設定ページ (ユーザー定義定数管理) ────────────────────────────────────────
class _SettingsPage extends StatefulWidget {
  final List<Map<String, dynamic>> userConstants;
  final void Function(List<Map<String, dynamic>>) onSave;

  const _SettingsPage({required this.userConstants, required this.onSave});

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late List<Map<String, dynamic>> _constants;
  late bool _vibrateOnTap;
  bool _isPro = false;
  int _remainingUses = 0;
  bool _isBillingLoading = false;

  static const _builtinConstants = [
    {'label': 'π (円周率)', 'symbol': 'π', 'value': 3.14159265358979},
    {'label': 'e (自然対数の底)', 'symbol': 'e', 'value': 2.71828182845905},
    {'label': 'g (重力加速度)', 'symbol': 'g', 'value': 9.80665},
    {'label': 'φ (黄金比)', 'symbol': 'φ', 'value': 1.61803398874989},
    {'label': 'c (光速 m/s)', 'symbol': 'c', 'value': 299792458.0},
  ];

  @override
  void initState() {
    super.initState();
    _constants = List<Map<String, dynamic>>.from(widget.userConstants);
    _vibrateOnTap = AppSettings.instance.vibrateOnTap;
    _loadBillingStatus();
  }

  Future<void> _loadBillingStatus() async {
    final isPro = await RevenueCatService.isProActive();
    final uses = await RevenueCatService.getRemainingUses();
    if (mounted) {
      setState(() {
        _isPro = isPro;
        _remainingUses = uses;
      });
    }
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble() && v.abs() < 1e15)
      return v.toInt().toString();
    return v.toString();
  }

  void _addConstant() async {
    final result = await _showEditConstantDialog(
      context,
      name: '',
      value: '0',
      isNew: true,
    );
    if (result != null) {
      setState(() {
        _constants.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': result['name'] as String,
          'value': double.tryParse(result['value'] as String) ?? 0.0,
        });
      });
      widget.onSave(_constants);
    }
  }

  void _editConstant(int idx) async {
    final c = _constants[idx];
    final result = await _showEditConstantDialog(
      context,
      name: c['name'] as String? ?? '',
      value: _fmt((c['value'] as num? ?? 0.0).toDouble()),
      isNew: false,
    );
    if (result == null) return;
    if (result['delete'] == true) {
      setState(() => _constants.removeAt(idx));
    } else {
      setState(() {
        _constants[idx] = {
          'id': c['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'name': result['name'] as String,
          'value': double.tryParse(result['value'] as String) ?? 0.0,
        };
      });
    }
    widget.onSave(_constants);
  }

  Future<Map<String, dynamic>?> _showEditConstantDialog(
    BuildContext context, {
    required String name,
    required String value,
    required bool isNew,
  }) {
    final nameCtrl = TextEditingController(text: name);
    final valCtrl = TextEditingController(text: value);
    var _valSelected = false;
    return showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setSS) {
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
                  Expanded(
                    child: Text(
                      isNew ? '定数を追加' : '定数を編集',
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
                '名前',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '例: 消費税率',
                  hintStyle: TextStyle(color: Colors.white24),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '値',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: valCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: const InputDecoration(
                  hintText: '0.0',
                  hintStyle: TextStyle(color: Colors.white24),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (!isNew)
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
                        'name': nameCtrl.text.trim(),
                        'value': valCtrl.text.trim(),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D14),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '設定',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
    // ── 課金・購入 ───────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              '課金・購入',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // ── プロ版 ──
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5E81FF), Color(0xFF9E7AFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  title: const Text(
                    'プロ版',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _isPro ? 'すべての機能が利用可能です' : 'すべての機能を永久にアンロック（買い切り）',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                  trailing: _isBillingLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF5E81FF),
                          ),
                        )
                      : _isPro
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color.fromARGB(255, 255, 94, 94), Color(0xFF9E7AFF)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '購入済み ✓',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: () async {
                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const StorePage(isProContext: true),
                              ),
                            );
                            if (result == true && mounted) {
                              setState(() => _isBillingLoading = true);
                              await _loadBillingStatus();
                              setState(() => _isBillingLoading = false);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF5E81FF), Color(0xFF9E7AFF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF5E81FF).withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              '購入する →',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                ),
                const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
                // ── AIクレジット ──
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C9A7), Color(0xFF0288D1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'AIクレジット',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '残り $_remainingUses 回 ／ 何度でもチャージ可能',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                  trailing: GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StorePage(isProContext: false),
                        ),
                      );
                      if (mounted) {
                        await _loadBillingStatus();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C9A7), Color(0xFF0288D1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00C9A7).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'チャージ →',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'AIクレジットは累積されます。有効期限はありません。',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 32),
   // ── 操作設定 ─────────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              '操作設定',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              title: const Text(
                'ボタン振動',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              subtitle: Text(
                '電卓ボタンをタップしたときにバイブレーションでフィードバック',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.vibration_rounded,
                  color: Colors.blueAccent,
                  size: 18,
                ),
              ),
              value: _vibrateOnTap,
              activeColor: Colors.blueAccent,
              onChanged: (val) {
                setState(() => _vibrateOnTap = val);
                AppSettings.instance.setVibrateOnTap(val);
              },
            ),
          ),

          const SizedBox(height: 32),
   // ── ユーザー定義定数 ─────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Text(
                    'ユーザー定義定数',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addConstant,
                icon: const Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: Color(0xFF5E81FF),
                ),
                label: const Text(
                  '追加',
                  style: TextStyle(color: Color(0xFF5E81FF), fontSize: 13),
                ),
              ),
            ],
          ),
          if (_constants.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  'まだ定数がありません\n右上の「追加」から追加できます',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: _constants.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final c = entry.value;
                  final isLast = idx == _constants.length - 1;
                  return Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5E81FF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              () {
                                final s = c['name'] as String? ?? '';
                                return s.isNotEmpty
                                    ? s.substring(0, 1).toUpperCase()
                                    : '?';
                              }(),
                              style: const TextStyle(
                                color: Color(0xFF5E81FF),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          c['name'] as String? ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _fmt((c['value'] as num? ?? 0.0).toDouble()),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ],
                        ),
                        onTap: () => _editConstant(idx),
                      ),
                      if (!isLast)
                        const Divider(
                          color: Colors.white10,
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'ユーザー定義定数は全シートの定数追加プリセットに表示されます',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 11,
              ),
            ),
          ),

          const SizedBox(height: 32),
          // ── 組み込み定数 ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
            child: Text(
              '組み込み定数',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: _builtinConstants.asMap().entries.map((entry) {
                final idx = entry.key;
                final c = entry.value;
                final isLast = idx == _builtinConstants.length - 1;
                return Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            c['symbol'] as String,
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'ZenOldMincho',
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        c['label'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Text(
                        _fmt((c['value'] as num).toDouble()),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (!isLast)
                      const Divider(
                        color: Colors.white10,
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

       
          const SizedBox(height: 32),

       


      
        ],
      ),
    );
  }
}

// ── QR コードスキャナーページ ─────────────────────────────────────────────────
class _QrScannerPage extends StatefulWidget {
  /// QR データが揃ったときに呼ばれる。成功時はシートタイトル、失敗時は null を返す。
  final String? Function(String) onScanned;
  /// スキャナーを閉じるときに呼ばれる（「完了」ボタン）
  final VoidCallback? onDone;

  const _QrScannerPage({required this.onScanned, this.onDone});

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _flashController;
  late final Animation<double> _flashOpacity;

  /// スキャン完了フラグ（全チャンク揃ったら true）
  bool _done = false;

  /// このセッションで取り込んだシート数
  int _scannedCount = 0;

  /// 直前にスキャン完了したQR値（同一QRの連続取り込みを防ぐ）
  String? _lastScannedValue;

  // ── 連結QR 収集状態 ──
  /// 収集済みチャンク: idx → データ文字列
  final Map<int, String> _chunks = {};
  int? _totalChunks;
  String? _multiTitle;
  List<dynamic>? _multiMemos;
  List<dynamic>? _multiSItems;
  List<dynamic>? _multiDOrder;
  List<dynamic>? _multiConsts;
  List<dynamic>? _multiLogics;

  // ── 画像モード ──
  List<XFile>? _pickedImages;
  int _pickedImageIndex = 0;
  bool _isAnalyzing = false;
  bool _isZoomed = false;
  late final TransformationController _tc;
  late PageController _imagePageController;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: 1.0, // 初期状態は透明（アニメーション終了位置）
    );
    _flashOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _flashController, curve: Curves.easeOut));
    _tc = TransformationController();
    _tc.addListener(_onTransformChanged);
    _imagePageController = PageController();
  }

  @override
  void dispose() {
    _tc.removeListener(_onTransformChanged);
    _tc.dispose();
    _imagePageController.dispose();
    _flashController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _triggerFlash() {
    _flashController.forward(from: 0.0);
  }

  void _onTransformChanged() {
    final scale = _tc.value.getMaxScaleOnAxis();
    final nowZoomed = scale > 1.05;
    if (nowZoomed != _isZoomed) setState(() => _isZoomed = nowZoomed);
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return;
    _imagePageController.dispose();
    _imagePageController = PageController();
    _tc.value = Matrix4.identity();
    setState(() {
      _pickedImages = images;
      _pickedImageIndex = 0;
      _isZoomed = false;
    });
    await _analyzePickedImage(0);
  }

  Future<void> _analyzePickedImage(int index) async {
    if (_pickedImages == null || index >= _pickedImages!.length) return;
    if (_isAnalyzing || _done) return;
    setState(() => _isAnalyzing = true);
    try {
      final result = await _controller.analyzeImage(_pickedImages![index].path);
      if (!mounted) return;
      if (result != null && result.barcodes.isNotEmpty) {
        final rawValue = result.barcodes.first.rawValue;
        if (rawValue != null && rawValue.isNotEmpty) {
          _triggerFlash();
          _onDetected(rawValue);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('画像の解析に失敗しました'),
            backgroundColor: Color(0xFF2A2A3A),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _exitImageMode() {
    setState(() {
      _pickedImages = null;
      _pickedImageIndex = 0;
      _isZoomed = false;
    });
    _tc.value = Matrix4.identity();
  }

  /// QRコードを1枚検出したときの処理
  Future<void> _onDetected(String rawValue) async {
    if (_done) return;

    Map<String, dynamic> decoded;
    try {
      final d = json.decode(rawValue);
      if (d is! Map<String, dynamic>) return;
      decoded = d;
    } catch (_) {
      return; // JSON以外は無視
    }

    final multiFlag = decoded['m'];

    if (multiFlag == null || multiFlag == 0) {
      // ──── シングルQR ────
      if (_chunks.isNotEmpty) {
        // 連結収集中にシングルQRを読んだ場合は無視
        return;
      }
      // 直前と同じQRは再処理しない（カメラが同じQRを捉え続けることへの対策）
      if (rawValue == _lastScannedValue) return;
      _triggerFlash();
      _lastScannedValue = rawValue;
      final result = widget.onScanned(rawValue);
      if (mounted) {
        if (result != null) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1A2A1A),
              title: const Text('取り込み完了', style: TextStyle(color: Colors.white)),
              content: Text('「$result」を取り込みました', style: const TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(color: Color(0xFF5E81FF))),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('有効なシートQRコードではありません'),
            backgroundColor: Color(0xFF2A2A3A),
            duration: Duration(seconds: 2),
          ));
        }
      }
      setState(() => _scannedCount++);
      return;
    }

    // ──── 連結QR ────
    final int tot = (decoded['tot'] as num? ?? 0).toInt();
    final int idx = (decoded['idx'] as num? ?? 0).toInt();
    final String dataChunk = decoded['d'] as String? ?? '';
    final String? title = decoded['t'] as String?;

    if (tot <= 0 || idx < 0 || idx >= tot) return; // 不正フォーマット

    // 既に収集済みのチャンクは再処理しない
    if (_chunks.containsKey(idx)) return;

    // 先頭チャンクからメモ・定数・論理式を抽出
    final List<dynamic>? chunkMemos = decoded['memos'] as List<dynamic>?;
    final List<dynamic>? chunkSItems = decoded['sitems'] as List<dynamic>?;
    final List<dynamic>? chunkDOrder = decoded['dorder'] as List<dynamic>?;
    final List<dynamic>? chunkConsts = decoded['consts'] as List<dynamic>?;
    final List<dynamic>? chunkLogics = decoded['logics'] as List<dynamic>?;

    _triggerFlash();
    setState(() {
      _totalChunks = tot;
      if (title != null) _multiTitle = title;
      if (chunkMemos != null) _multiMemos = chunkMemos;
      if (chunkSItems != null) _multiSItems = chunkSItems;
      if (chunkDOrder != null) _multiDOrder = chunkDOrder;
      if (chunkConsts != null) _multiConsts = chunkConsts;
      if (chunkLogics != null) _multiLogics = chunkLogics;
      _chunks[idx] = dataChunk;
    });

    // 全チャンク揃ったか確認
    if (_chunks.length == _totalChunks) {
      // 順番に結合してアイテム配列を復元
      final assembledItemsJson = List.generate(
        _totalChunks!,
        (i) => _chunks[i]!,
      ).join('');

      try {
        final itemsDecoded = json.decode(assembledItemsJson);
        final assembledMap = <String, dynamic>{
          'v': 1,
          't': _multiTitle ?? '取り込んだシート',
          'items': itemsDecoded,
        };
        if (_multiMemos != null && _multiMemos!.isNotEmpty) {
          assembledMap['memos'] = _multiMemos;
        }
        if (_multiSItems != null && _multiSItems!.isNotEmpty) {
          assembledMap['sitems'] = _multiSItems;
        }
        if (_multiDOrder != null && _multiDOrder!.isNotEmpty) {
          assembledMap['dorder'] = _multiDOrder;
        }
        if (_multiConsts != null && _multiConsts!.isNotEmpty) {
          assembledMap['consts'] = _multiConsts;
        }
        if (_multiLogics != null && _multiLogics!.isNotEmpty) {
          assembledMap['logics'] = _multiLogics;
        }
        final assembled = json.encode(assembledMap);
        // 直前と同じアセンブル結果は再処理しない
        if (assembled == _lastScannedValue) {
          setState(() {
            _chunks.clear();
            _totalChunks = null;
            _multiTitle = null;
            _multiMemos = null;
            _multiSItems = null;
            _multiDOrder = null;
            _multiConsts = null;
            _multiLogics = null;
          });
          return;
        }
        _lastScannedValue = assembled;
        setState(() => _done = true);
        final result = widget.onScanned(assembled);
        if (mounted) {
          if (result != null) {
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1A2A1A),
                title: const Text('取り込み完了', style: TextStyle(color: Colors.white)),
                content: Text('「$result」を取り込みました', style: const TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK', style: TextStyle(color: Color(0xFF5E81FF))),
                  ),
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('有効なシートQRコードではありません'),
              backgroundColor: Color(0xFF2A2A3A),
              duration: Duration(seconds: 2),
            ));
          }
        }
        // スキャン成功：状態をリセットして次のシートに備える
        setState(() {
          _done = false;
          _scannedCount++;
          _chunks.clear();
          _totalChunks = null;
          _multiTitle = null;
          _multiMemos = null;
          _multiSItems = null;
          _multiDOrder = null;
          _multiConsts = null;
          _multiLogics = null;
        });
      } catch (_) {
        // 結合後にパース失敗 → 収集状態をリセットして再スキャンを促す
        setState(() {
          _chunks.clear();
          _totalChunks = null;
          _multiTitle = null;
          _multiMemos = null;
          _multiSItems = null;
          _multiDOrder = null;
          _multiConsts = null;
          _multiLogics = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QRデータの結合に失敗しました。最初からスキャンし直してください'),
            backgroundColor: Color(0xFF2A2A3A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMulti = _totalChunks != null && _totalChunks! > 1;
    final collected = _chunks.length;
    final total = _totalChunks ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D14),
        title: Text(
          isMulti
              ? 'QRスキャン ($collected/$total枚)'
              : _scannedCount > 0
                  ? '$_scannedCount件取り込み済み'
                  : 'QRコードをスキャン',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          // 完了ボタン（onDoneが設定されている場合のみ）
          if (widget.onDone != null && !isMulti)
            TextButton(
              onPressed: widget.onDone,
              child: Text(
                _scannedCount > 0 ? '完了 ($_scannedCount件)' : '完了',
                style: const TextStyle(
                    color: Colors.tealAccent, fontSize: 13),
              ),
            ),
          // 連結スキャン中はリセットボタンを表示
          if (isMulti && !_done)
            TextButton(
              onPressed: () => setState(() {
                _chunks.clear();
                _totalChunks = null;
                _multiTitle = null;
                _multiMemos = null;
                _multiSItems = null;
                _multiDOrder = null;
                _multiConsts = null;
                _multiLogics = null;
                _lastScannedValue = null;
              }),
              child: const Text(
                'リセット',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
              ),
            ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (ctx, state, _) {
                final torchOn = state.torchState == TorchState.on;
                return Icon(
                  torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: torchOn ? Colors.amberAccent : Colors.white38,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_done) return;
              if (_pickedImages != null) return; // 画像モード中はカメラスキャンを無視
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final rawValue = barcodes.first.rawValue;
              if (rawValue != null && rawValue.isNotEmpty) {
                _onDetected(rawValue);
              }
            },
          ),
          // スキャンガイド枠
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isMulti ? Colors.orangeAccent : Colors.tealAccent,
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          // 連結QR進捗インジケーター
          if (isMulti)
            Positioned(
              top: 20,
              left: 32,
              right: 32,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orangeAccent.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          color: Colors.orangeAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '連結QR: $collected/$total枚スキャン済み',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 枚数のドットインジケーター
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(total, (i) {
                        final done = _chunks.containsKey(i);
                        return Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: done ? Colors.tealAccent : Colors.white24,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          // 説明テキスト
          Positioned(
            bottom: 30,
            left: 32,
            right: 32,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isMulti
                    ? '残り ${total - collected}枚のQRをスキャンしてください'
                    : _scannedCount > 0
                        ? '続けて次のシートのQRをスキャンできます'
                        : 'シートのQRコードをフレーム内に合わせてください',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
          // ファイルから読み込みボタン
          if (!_done)
            Positioned(
              top: 0,
              bottom: -310,
              left: 32,
              right: 32,
              child: Center(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                  ),
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text(
                    'ファイルから読み込み',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          // 画像モード オーバーレイ
          if (_pickedImages != null)
            Positioned.fill(child: _buildImageViewer()),
          // フラッシュオーバーレイ
          AnimatedBuilder(
            animation: _flashOpacity,
            builder: (context, _) {
              if (_flashOpacity.value == 0.0) return const SizedBox.shrink();
              return Opacity(
                opacity: _flashOpacity.value,
                child: Container(color: Colors.white),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewer() {
    final images = _pickedImages!;
    final total = images.length;
    final isMulti = _totalChunks != null && _totalChunks! > 1;
    final collected = _chunks.length;
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _imagePageController,
            physics: _isZoomed
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            itemCount: total,
            onPageChanged: (idx) {
              setState(() {
                _pickedImageIndex = idx;
                _isZoomed = false;
              });
              _tc.value = Matrix4.identity();
              _analyzePickedImage(idx);
            },
            itemBuilder: (ctx, idx) {
              return Center(
                child: InteractiveViewer(
                  transformationController: idx == _pickedImageIndex
                      ? _tc
                      : null,
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: Image.file(
                    File(images[idx].path),
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          // 連結QR進捗インジケーター
          if (isMulti)
            Positioned(
              top: 20,
              left: 32,
              right: 32,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orangeAccent.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          color: Colors.orangeAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '連結QR: $collected/$total枚スキャン済み',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 枚数のドットインジケーター
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(total, (i) {
                        final done = _chunks.containsKey(i);
                        return Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: done ? Colors.tealAccent : Colors.white24,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          // ページカウンター
          if (total > 1)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_pickedImageIndex + 1} / $total  ← スワイプで切り替え →',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
            ),
          // フラッシュオーバーレイ（QR検出時）
          AnimatedBuilder(
            animation: _flashOpacity,
            builder: (context, _) {
              if (_flashOpacity.value == 0.0) return const SizedBox.shrink();
              return Opacity(
                opacity: _flashOpacity.value,
                child: Container(color: Colors.white),
              );
            },
          ),
          // 下部コントロール
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isAnalyzing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'QRコードを解析中...',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white12,
                          foregroundColor: Colors.white70,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _exitImageMode,
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('カメラに戻る'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent.withOpacity(0.15),
                          foregroundColor: Colors.tealAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _isAnalyzing
                            ? null
                            : () => _analyzePickedImage(_pickedImageIndex),
                        icon: _isAnalyzing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.tealAccent,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 18,
                              ),
                        label: Text(_isAnalyzing ? '解析中...' : 'QRを読み込む'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
