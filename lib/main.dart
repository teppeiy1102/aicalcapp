import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'widget_page.dart';
import 'revenuecat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
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
  PersistentBottomSheetController? _calcSheetController;
  bool _isSelectMode = false;
  final Set<int> _selectedForMerge = {};
  String? _appendTargetSheetId;

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
        final loaded = list.map((e) {
          final m = e as Map<String, dynamic>;
          return WidgetConfig(
            id:
                m['id'] as String? ??
                '${DateTime.now().millisecondsSinceEpoch}',
            type: m['type'] as String? ?? 'calculator',
            data: _deepCopy(m['data']) as Map<String, dynamic>,
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
          globalConstants: _userConstants,
          clipboardNotifier: _clipboardNotifier,
          allConfigs: _configs,
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
                setState(() {
                  _configs[idx] = _configs[idx].copyWith(data: data);
                });
                _saveConfigs();
              }
            },
            clipboardNotifier: _clipboardNotifier,
            onSheetDuplicate: (sheetId) {
              final srcIdx = _configs.indexWhere((c) => c.id == sheetId);
              if (srcIdx == -1) return;
              final src = _configs[srcIdx];
              final newConfig = WidgetConfig(
                id: '${DateTime.now().millisecondsSinceEpoch}',
                type: src.type,
                data: Map<String, dynamic>.from(src.data)
                  ..['title'] = '${src.data['title'] ?? '定型計算'} (コピー)',
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
                title: const Text(
                  '計算シートを結合する',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '複数のシートを1画面に並べて表示',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _startSelectMode();
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
                title: const Text(
                  'シートを取り込む',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'QRコードからシートをインポート',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showQrScanner();
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
    final newConfig = WidgetConfig(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      type: 'merged',
      data: {'title': titles, 'sheetIds': sheetIds},
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
            Navigator.pop(ctx);
            _importSheetFromQr(qrData);
          },
        ),
      ),
    );
  }

  /// スキャンした QR データからシートをインポートする
  void _importSheetFromQr(String qrData) {
    try {
      final decoded = json.decode(qrData);
      if (decoded is! Map<String, dynamic> ||
          decoded['v'] != 1 ||
          decoded['items'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('有効なシートQRコードではありません'),
            backgroundColor: Color(0xFF2A2A3A),
          ),
        );
        return;
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
            };
          }).toList(),
          'brackets': <dynamic>[],
          'precision': (m['p'] as num? ?? 2).toInt(),
          'unit1': m['u1'] as String? ?? '',
          'unit2': m['u2'] as String? ?? '',
          'unitResult': m['ur'] as String? ?? '',
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

      // 表示順を復元（スタンドアロンメモがある場合のみ）
      List<Map<String, dynamic>>? displayOrder;
      final qrDOrder = decoded['dorder'] as List<dynamic>?;
      if (qrDOrder != null &&
          standaloneItems != null &&
          standaloneItems.isNotEmpty) {
        displayOrder = qrDOrder.map<Map<String, dynamic>>((e) {
          final entry = e as Map;
          if (entry.containsKey('c')) {
            return {'type': 'calc', 'calcIdx': (entry['c'] as num).toInt()};
          } else {
            final si = (entry['s'] as num).toInt();
            final id = si < standaloneItems.length
                ? standaloneItems[si]['id'] as String
                : '';
            return {'type': 'standalone', 'itemId': id};
          }
        }).toList();
      }

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

      final newConfig = WidgetConfig(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        type: 'calculator',
        data: {
          'title': title,
          'items': items,
          'isExpanded': true,
          'bgColor': 0xFF1A1A2E,
          if (memos != null && memos.isNotEmpty) 'memos': memos,
          if (standaloneItems != null && standaloneItems.isNotEmpty)
            'standaloneItems': standaloneItems,
          if (displayOrder != null && displayOrder.isNotEmpty)
            'displayOrder': displayOrder,
          if (constants != null && constants.isNotEmpty) 'constants': constants,
        },
      );

      setState(() => _configs.insert(0, newConfig));
      _saveConfigs();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「$title」を取り込みました（${items.length}件）'),
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QRコードの読み取りに失敗しました'),
          backgroundColor: Color(0xFF2A2A3A),
        ),
      );
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
                  expandedHeight: _isSelectMode ? 0 : 200,
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
                                      : Colors.white38,
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
                  flexibleSpace: _isSelectMode
                      ? null
                      : FlexibleSpaceBar(
                          titlePadding: const EdgeInsets.only(
                            left: 28,
                            bottom: 0,
                          ),
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
                                '現場を支える、次世代の電卓',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              Spacer(flex: 1),
                            ],
                          ),
                        ),
                ),
                if (_configs.isEmpty)
                  const SliverFillRemaining(child: _EmptyState())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 140),
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
                                : () => _openDetail(i),
                            onDelete: () => _deleteConfig(i),
                            onUpdate: (data) => _updateConfig(i, data),
                            isSelectMode: _isSelectMode,
                            isSelected: _selectedForMerge.contains(i),
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
          Positioned(
            bottom: 0,
            right: 0,
            left: 0,

            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black, Colors.black, Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _isSelectMode
          ? _MergeActionBar(
              selectedCount: _selectedForMerge.length,
              onMerge: _executeMergeOrAppend,
              onCancel: _cancelSelectMode,
              isAppendMode: _appendTargetSheetId != null,
            )
          : _calcSheetController != null
          ? null
          : _HomeFab(
              onOpenCalc: _openHomeCalc,
              onAddSheet: _addConfig,
              calcActive: false,
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
    // For merged, derive bg from first resolved sheet
    final effectiveBgValue = isMerged && resolvedSheets.isNotEmpty
        ? resolvedSheets.first.data['bgColor'] as int?
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

    // leading: checkbox in select mode, drag handle otherwise
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
                    : (isDark ? Colors.white38 : Colors.black38),
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
                : Colors.black.withOpacity(isDark ? 0.4 : 0.15),
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
                                          '$sheetCountつの結合されたシート',
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
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.delete_sweep_rounded,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.2)
                                      : Colors.black.withOpacity(0.25),
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
  final VoidCallback onOpenCalc;
  final bool calcActive;
  const _HomeFab({
    required this.onAddSheet,
    required this.onOpenCalc,
    this.calcActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return !calcActive
        ? Row(
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
                        color: const Color(
                          0xFF5E81FF,
                        ).withOpacity(calcActive ? 0.35 : 0.15),
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
              const SizedBox(width: 10),
            ],
          )
        : const SizedBox.shrink();
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
          GestureDetector(
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
              child: Expanded(
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
    return showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setSS) => Padding(
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
                autofocus: true,
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
        ),
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
        ],
      ),
    );
  }
}

// ── QR コードスキャナーページ ─────────────────────────────────────────────────
class _QrScannerPage extends StatefulWidget {
  final void Function(String) onScanned;

  const _QrScannerPage({required this.onScanned});

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

  // ── 連結QR 収集状態 ──
  /// 収集済みチャンク: idx → データ文字列
  final Map<int, String> _chunks = {};
  int? _totalChunks;
  String? _multiTitle;
  List<dynamic>? _multiMemos;
  List<dynamic>? _multiSItems;
  List<dynamic>? _multiDOrder;
  List<dynamic>? _multiConsts;

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
  void _onDetected(String rawValue) {
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
      _triggerFlash();
      setState(() => _done = true);
      widget.onScanned(rawValue);
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

    // 先頭チャンクからメモ・定数を抽出
    final List<dynamic>? chunkMemos = decoded['memos'] as List<dynamic>?;
    final List<dynamic>? chunkSItems = decoded['sitems'] as List<dynamic>?;
    final List<dynamic>? chunkDOrder = decoded['dorder'] as List<dynamic>?;
    final List<dynamic>? chunkConsts = decoded['consts'] as List<dynamic>?;

    _triggerFlash();
    setState(() {
      _totalChunks = tot;
      if (title != null) _multiTitle = title;
      if (chunkMemos != null) _multiMemos = chunkMemos;
      if (chunkSItems != null) _multiSItems = chunkSItems;
      if (chunkDOrder != null) _multiDOrder = chunkDOrder;
      if (chunkConsts != null) _multiConsts = chunkConsts;
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
        final assembled = json.encode(assembledMap);
        setState(() => _done = true);
        widget.onScanned(assembled);
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
          isMulti ? 'QRスキャン ($collected/$total枚)' : 'QRコードをスキャン',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          // 連結スキャン中はリセットボタンを表示
          if (isMulti && !_done)
            TextButton(
              onPressed: () => setState(() {
                _chunks.clear();
                _totalChunks = null;
                _multiTitle = null;
                _multiMemos = null;
                _multiConsts = null;
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
