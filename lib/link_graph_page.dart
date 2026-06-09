// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  link_graph_page.dart — リンクグラフ可視化（完全独立ファイル）
//
//  Obsidian グラフビューにならった実装:
//    • D3.js 準拠フォース・ダイレクテッド・シミュレーション（α 冷却）
//    • Ticker で毎フレーム 60fps 物理演算
//    • ChangeNotifier + CustomPainter.repaint で setState 不要の高効率描画
//    • 生ポインターイベントでノードドラッグ＋ピンチズーム＋スクロールズーム
//    • Obsidian 風ダークスタイル（小丸ノード・細線・グロー）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// データモデル
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// グラフのノード（計算式 or 論理式）
class _Node {
  final String id;
  final String label;
  final String sheetName;
  final String sheetId;   // リンク解決用シートID
  final bool isLogic;
  final Map<String, dynamic> rawData; // 元データ（式/論理式）

  Offset pos;
  Offset vel = Offset.zero;
  bool pinned = false;

  _Node({
    required this.id,
    required this.label,
    required this.sheetName,
    required this.sheetId,
    required this.isLogic,
    required this.rawData,
    required this.pos,
  });

  /// 描画半径（シーン座標系）
  static const double r = 9.0;
  /// タップ判定半径（スクリーン座標系・ピクセル固定）
  static const double hitPx = 22.0;
}

/// グラフのエッジ（リンク）
class _Edge {
  final String fromId;
  final String toId;
  final String label;
  const _Edge({required this.fromId, required this.toId, required this.label});
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// グラフモデル（物理シミュレーション + ChangeNotifier）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _GraphModel extends ChangeNotifier {
  List<_Node> nodes = [];
  List<_Edge> edges = [];

  // D3.js 準拠の α クーリング
  double alpha = 0.0;
  static const double alphaDecay = 0.0228; // ~300 フレームで収束
  static const double alphaMin = 0.001;
  static const double velocityDecay = 0.4;

  bool get settled => alpha <= alphaMin;

  Map<String, _Node> _map = {};

  void load(List<_Node> newNodes, List<_Edge> newEdges) {
    nodes = newNodes;
    edges = newEdges;
    _map = {for (final n in nodes) n.id: n};
    alpha = 1.0;
    notifyListeners();
  }

  /// 1 フレーム分の力学演算
  void tick() {
    if (settled || nodes.isEmpty) return;
    alpha -= alpha * alphaDecay;
    if (alpha < alphaMin) alpha = 0;

    _applyManyBody();
    _applyLinkForce();
    _applyCenterForce();
    _applyVelocity();

    notifyListeners();
  }

  /// 多体斥力（全ノードペア間）
  void _applyManyBody() {
    const strength = -180.0;
    final n = nodes;
    for (int i = 0; i < n.length; i++) {
      if (n[i].pinned) continue;
      for (int j = i + 1; j < n.length; j++) {
        final d = n[i].pos - n[j].pos;
        final distSq = d.distanceSquared.clamp(0.01, double.infinity);
        final dist = math.sqrt(distSq);
        final force = strength.abs() * alpha / distSq;
        final f = d / dist * force;
        n[i].vel += f;
        if (!n[j].pinned) n[j].vel -= f;
      }
    }
  }

  /// リンクバネ力
  void _applyLinkForce() {
    const idealDist = 110.0;
    const strength = 0.5;
    for (final e in edges) {
      final from = _map[e.fromId];
      final to = _map[e.toId];
      if (from == null || to == null) continue;
      final d = to.pos - from.pos;
      final dist = d.distance.clamp(0.01, double.infinity);
      final diff = (dist - idealDist) / dist * strength * alpha;
      final f = d * diff;
      if (!from.pinned) from.vel += f;
      if (!to.pinned) to.vel -= f;
    }
  }

  /// 中心力（グラフが画面外に流れないよう）
  void _applyCenterForce() {
    if (nodes.isEmpty) return;
    const strength = 0.05;
    double cx = 0, cy = 0;
    for (final n in nodes) { cx += n.pos.dx; cy += n.pos.dy; }
    cx /= nodes.length;
    cy /= nodes.length;
    for (final n in nodes) {
      if (n.pinned) continue;
      n.vel -= Offset(cx * strength * alpha, cy * strength * alpha);
    }
  }

  /// 速度適用 + ダンピング
  void _applyVelocity() {
    const maxV = 25.0;
    for (final n in nodes) {
      if (n.pinned) continue;
      n.vel *= velocityDecay;
      final spd = n.vel.distance;
      if (spd > maxV) n.vel = n.vel / spd * maxV;
      n.pos += n.vel;
    }
  }

  /// シミュレーションを再加熱
  void reheat([double heat = 0.3]) {
    alpha = math.max(heat, alpha);
  }

  void pinAndMove(String id, Offset pos) {
    final n = _map[id];
    if (n == null) return;
    n.pinned = true;
    n.pos = pos;
    n.vel = Offset.zero;
    notifyListeners();
  }

  void unpin(String id) {
    final n = _map[id];
    if (n == null) return;
    n.pinned = false;
    reheat(0.2);
  }

  /// シートの全ノードを一括移動する（シートタイトルドラッグ用）
  void moveSheetNodes(
      String sheetName, Map<String, Offset> startPos, Offset delta) {
    for (final n in nodes.where((n) => n.sheetName == sheetName)) {
      final sp = startPos[n.id];
      if (sp != null) {
        n.pos = sp + delta;
        n.vel = Offset.zero;
      }
    }
    reheat(0.1);
    notifyListeners();
  }

  /// シートの全ノードのピンを外す
  void unpinSheet(String sheetName) {
    for (final n in nodes.where((n) => n.sheetName == sheetName)) {
      n.pinned = false;
    }
    reheat(0.3);
  }

  _Node? nodeById(String id) => _map[id];

  Set<String> connectedTo(String id) {
    final s = <String>{};
    for (final e in edges) {
      if (e.fromId == id) s.add(e.toId);
      if (e.toId == id) s.add(e.fromId);
    }
    return s;
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ビュー状態（ChangeNotifier）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _ViewState extends ChangeNotifier {
  Offset offset = Offset.zero;
  double scale = 1.0;
  String? selId;
  String? draggingId;

  _ViewState();

  void update({
    Offset? offset,
    double? scale,
    String? Function()? selIdFn,
    String? Function()? draggingIdFn,
  }) {
    if (offset != null) this.offset = offset;
    if (scale != null) this.scale = scale;
    if (selIdFn != null) selId = selIdFn();
    if (draggingIdFn != null) draggingId = draggingIdFn();
    notifyListeners();
  }

  Offset toScene(Offset screen) => (screen - offset) / scale;
  Offset toScreen(Offset scene) => scene * scale + offset;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ページ
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class LinkGraphPage extends StatefulWidget {
  /// null のときは SharedPreferences から読み込む（全シート表示）。
  /// 渡す場合は `[{'id':…,'type':…,'data':{…}}, …]` 形式のリスト。
  final List<Map<String, dynamic>>? configs;

  /// 起動時にフォーカスするシート ID（null なら全体フィット）
  final String? initialSheetId;

  /// ノードの「リンクを設定」ボタンで呼ばれる。sheetId を渡す。
  /// 提供されない場合はボタンを非表示にする。
  final void Function(String sheetId)? onOpenSheet;

  const LinkGraphPage({
    super.key,
    this.configs,
    this.initialSheetId,
    this.onOpenSheet,
  });

  @override
  State<LinkGraphPage> createState() => _LinkGraphPageState();
}

class _LinkGraphPageState extends State<LinkGraphPage>
    with SingleTickerProviderStateMixin {
  static const _kPrefsKey = 'aicalc_configs_v1';

  final _model = _GraphModel();
  final _view = _ViewState();
  bool _loading = true;
  bool _showAll = true;

  // ── ポインター追跡 ──────────────────────────────────────────────────────
  final _ptrs = <int, _PtrInfo>{};
  Offset _panStartOff = Offset.zero;
  Offset _panStartFocal = Offset.zero;
  Offset _pinchStartMid = Offset.zero;
  double _pinchStartDist = 1.0;
  double _pinchStartScale = 1.0;
  Offset _pinchStartOff = Offset.zero;
  Offset _dragStartScene = Offset.zero;
  Offset _dragStartNodePos = Offset.zero;

  // ── シートクラスタードラッグ ─────────────────────────────────────────
  String? _draggingSheetName;
  Offset _sheetDragStartScene = Offset.zero;
  Map<String, Offset> _sheetDragStartPositions = {};

  // ── ダブルタップ / ダブルタップ+ドラッグズーム ────────────────────────
  int _lastTapMs = 0;
  Offset _lastTapPos = Offset.zero;
  bool _maybeDoubleTap = false;
  bool _doubleTapZooming = false;
  Offset _doubleTapZoomOrigin = Offset.zero;
  double _doubleTapZoomStartScale = 1.0;
  Offset _doubleTapZoomFocal = Offset.zero;

  /// sheetId → そのシートを含む結合シートのタイトル一覧
  Map<String, List<String>> _mergedSheetNames = {};

  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (!_model.settled) _model.tick();
    })..start();
    _load();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _model.dispose();
    _view.dispose();
    super.dispose();
  }

  // ── データ読み込み ────────────────────────────────────────────────────

  Future<void> _load() async {
    if (widget.configs != null) {
      // 呼び出し元から渡されたデータを直接使用
      _buildGraph(widget.configs!);
    } else {
      // SharedPreferences から全シートを読み込む
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw != null) {
        try {
          _buildGraph(jsonDecode(raw) as List);
        } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialSheetId != null) {
        _fitToSheetById(widget.initialSheetId!);
      } else {
        _fitToView();
      }
    });
  }

  // ── グラフ構築 ────────────────────────────────────────────────────────

  void _buildGraph(List<dynamic> cfgs) {
    final rng = math.Random(42);
    final nodes = <_Node>[];
    final edgeMap = <String, _Edge>{};

    final sheets = cfgs
        .map((c) => Map<String, dynamic>.from(c as Map))
        .where((c) => (c['type'] as String?) != 'merged')
        .toList();

    for (int si = 0; si < sheets.length; si++) {
      final cfg = sheets[si];
      final sid = cfg['id'] as String? ?? 'sheet$si';
      final d = Map<String, dynamic>.from(cfg['data'] as Map? ?? {});
      final sheetName = d['title'] as String? ?? 'シート${si + 1}';

      final items = (d['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final logics = (d['logicItems'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // シートを放射状に配置
      final sheetAngle = sheets.length > 1
          ? 2 * math.pi * si / sheets.length
          : 0.0;
      final sheetDist = sheets.length > 1 ? 400.0 : 0.0;
      final cx = sheetDist * math.cos(sheetAngle);
      final cy = sheetDist * math.sin(sheetAngle);

      for (int i = 0; i < items.length; i++) {
        final angle = 2 * math.pi * i / math.max(1, items.length);
        final rad = math.max(80.0, items.length * 25.0);
        nodes.add(_Node(
          id: '${sid}_c$i',
          label: items[i]['name'] as String? ?? '計算${i + 1}',
          sheetName: sheetName,
          sheetId: sid,
          isLogic: false,
          rawData: items[i],
          pos: Offset(
            cx + rad * math.cos(angle) + (rng.nextDouble() - 0.5) * 30,
            cy + rad * math.sin(angle) + (rng.nextDouble() - 0.5) * 30,
          ),
        ));
      }

      for (int li = 0; li < logics.length; li++) {
        final lg = logics[li];
        final lid = lg['id'] as String? ?? 'lg$li';
        final angle = 2 * math.pi * li / math.max(1, logics.length);
        nodes.add(_Node(
          id: '${sid}_l$lid',
          label: lg['name'] as String? ?? '論理式${li + 1}',
          sheetName: sheetName,
          sheetId: sid,
          isLogic: true,
          rawData: lg,
          pos: Offset(
            cx + 250 + 60 * math.cos(angle) + (rng.nextDouble() - 0.5) * 20,
            cy + 60 * math.sin(angle) + (rng.nextDouble() - 0.5) * 20,
          ),
        ));
      }
    }

    final nids = {for (final n in nodes) n.id};

    void addEdge(bool linked, Map? src, String destId, String lbl, String sid) {
      if (!linked || src == null) return;
      final type = src['type'] as String?;
      if (type == 'constant') return;
      final fromSid = src['sheetId'] as String? ?? sid;
      final String fromId;
      if (type == 'logic') {
        final logicId = src['logicId'] as String?;
        if (logicId == null) return;
        fromId = '${fromSid}_l$logicId';
      } else {
        final row = src['rowIdx'] as int? ?? 0;
        fromId = '${fromSid}_c$row';
      }
      if (fromId == destId || !nids.contains(fromId) || !nids.contains(destId)) return;
      final key = '$fromId→$destId';
      if (edgeMap.containsKey(key)) {
        final ex = edgeMap[key]!;
        edgeMap[key] = _Edge(fromId: fromId, toId: destId, label: '${ex.label}, $lbl');
      } else {
        edgeMap[key] = _Edge(fromId: fromId, toId: destId, label: lbl);
      }
    }

    for (int si = 0; si < sheets.length; si++) {
      final cfg = sheets[si];
      final sid = cfg['id'] as String? ?? 'sheet$si';
      final d = Map<String, dynamic>.from(cfg['data'] as Map? ?? {});

      final items = (d['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final logics = (d['logicItems'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final dest = '${sid}_c$i';
        addEdge(item['inputLink'] == true,
            item['inputLinkSource'] as Map?, dest, '項1', sid);
        addEdge(item['operandLink'] == true,
            item['operandLinkSource'] as Map?, dest, '項2', sid);
        final others = (item['others'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        for (int j = 0; j < others.length; j++) {
          addEdge(others[j]['valLink'] == true,
              others[j]['valLinkSource'] as Map?, dest, '項${j + 3}', sid);
        }
      }

      for (int li = 0; li < logics.length; li++) {
        final lg = logics[li];
        final lid = lg['id'] as String? ?? 'lg$li';
        final ldest = '${sid}_l$lid';
        final conds = (lg['conditions'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        for (int k = 0; k < conds.length; k++) {
          final c = conds[k];
          addEdge(c['lhsLink'] == true,
              c['lhsLinkSource'] as Map?, ldest, '条件${k + 1}左辺', sid);
          addEdge(c['rhsLink'] == true,
              c['rhsLinkSource'] as Map?, ldest, '条件${k + 1}右辺', sid);
        }
      }
    }

    _model.load(nodes, edgeMap.values.toList());

    // 結合シート情報を構築（sheetId → 結合シートタイトル一覧）
    final mergedMap = <String, List<String>>{};
    for (final raw in cfgs) {
      final c = Map<String, dynamic>.from(raw as Map);
      if ((c['type'] as String?) != 'merged') continue;
      final d = Map<String, dynamic>.from(c['data'] as Map? ?? {});
      final title = d['title'] as String? ?? '結合ビュー';
      final ids = (d['sheetIds'] as List? ?? []).map((e) => e as String);
      for (final id in ids) {
        mergedMap.putIfAbsent(id, () => []).add(title);
      }
    }
    _mergedSheetNames = mergedMap;
  }

  // ── フィルタ ──────────────────────────────────────────────────────────

  Set<String> get _linkedIds {
    final s = <String>{};
    for (final e in _model.edges) { s.add(e.fromId); s.add(e.toId); }
    return s;
  }

  List<_Node> get _visibleNodes {
    if (_showAll) return _model.nodes;
    final lids = _linkedIds;
    return _model.nodes.where((n) => lids.contains(n.id)).toList();
  }

  // ── ビュー操作 ────────────────────────────────────────────────────────

  _Node? _hitTest(Offset screenPos) {
    for (final n in _visibleNodes.reversed) {
      if ((_view.toScreen(n.pos) - screenPos).distance < _Node.hitPx) return n;
    }
    return null;
  }

  void _fitToView() {
    if (!mounted) return;
    final visible = _visibleNodes;
    if (visible.isEmpty) return;

    final size = MediaQuery.of(context).size;
    final topPad = kToolbarHeight + MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    const pad = 70.0;

    double minX = visible.first.pos.dx, maxX = minX;
    double minY = visible.first.pos.dy, maxY = minY;
    for (final n in visible) {
      minX = math.min(minX, n.pos.dx); maxX = math.max(maxX, n.pos.dx);
      minY = math.min(minY, n.pos.dy); maxY = math.max(maxY, n.pos.dy);
    }

    final cW = (maxX - minX) + pad * 2;
    final cH = (maxY - minY) + pad * 2;
    final aW = size.width;
    final aH = size.height - topPad - bottomPad;
    final scale = math.min(2.5, math.min(aW / cW, aH / cH));
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;

    _view.update(
      offset: Offset(aW / 2 - cx * scale, aH / 2 - cy * scale),
      scale: scale,
    );
  }

  /// 指定したシート名のノードが全部収まるようにズーム
  void _fitToSheet(String sheetName) {    if (!mounted) return;
    final ns = _visibleNodes.where((n) => n.sheetName == sheetName).toList();
    if (ns.isEmpty) return;

    final size = MediaQuery.of(context).size;
    final topPad = kToolbarHeight + MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    const pad = 70.0;

    double minX = ns.first.pos.dx, maxX = minX;
    double minY = ns.first.pos.dy, maxY = minY;
    for (final n in ns) {
      minX = math.min(minX, n.pos.dx); maxX = math.max(maxX, n.pos.dx);
      minY = math.min(minY, n.pos.dy); maxY = math.max(maxY, n.pos.dy);
    }

    final cW = (maxX - minX) + pad * 2;
    final cH = (maxY - minY) + pad * 2;
    final aW = size.width;
    final aH = size.height - topPad - bottomPad;
    final scale = math.min(4.0, math.min(aW / cW, aH / cH));
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;

    _view.update(
      offset: Offset(aW / 2 - cx * scale, aH / 2 - cy * scale),
      scale: scale,
    );
  }

  /// シート ID からシート名を特定してフィットズームする
  void _fitToSheetById(String sheetId) {
    final match = _visibleNodes.where((n) => n.sheetId == sheetId).firstOrNull;
    if (match != null) _fitToSheet(match.sheetName);
  }

  /// 画面座標がシートクラスターのタイトル帯（上部ストリップ）内かどうかを判定
  String? _hitTestClusterTitle(Offset screenPos) {
    final scenePos = _view.toScene(screenPos);
    final bySheet = <String, List<_Node>>{};
    for (final n in _visibleNodes) {
      bySheet.putIfAbsent(n.sheetName, () => []).add(n);
    }
    for (final entry in bySheet.entries) {
      final ns = entry.value;
      if (ns.length < 2) continue;
      double minX = ns.first.pos.dx, maxX = minX;
      double minY = ns.first.pos.dy, maxY = minY;
      for (final n in ns) {
        minX = math.min(minX, n.pos.dx); maxX = math.max(maxX, n.pos.dx);
        minY = math.min(minY, n.pos.dy); maxY = math.max(maxY, n.pos.dy);
      }
      const p = 55.0;
      // タイトル帯: クラスター上端から 40 シーン単位（シート名 + バッジ分）
      const titleH = 40.0;
      if (scenePos.dx >= minX - p && scenePos.dx <= maxX + p &&
          scenePos.dy >= minY - p && scenePos.dy <= minY - p + titleH) {
        return entry.key;
      }
    }
    return null;
  }

  /// 画面座標がシートクラスター内に収まるか判定し、シート名を返す
  String? _hitTestCluster(Offset screenPos) {
    final bySheet = <String, List<_Node>>{};
    for (final n in _visibleNodes) {
      bySheet.putIfAbsent(n.sheetName, () => []).add(n);
    }
    for (final entry in bySheet.entries) {
      final ns = entry.value;
      if (ns.length < 2) continue;
      double minX = ns.first.pos.dx, maxX = minX;
      double minY = ns.first.pos.dy, maxY = minY;
      for (final n in ns) {
        minX = math.min(minX, n.pos.dx); maxX = math.max(maxX, n.pos.dx);
        minY = math.min(minY, n.pos.dy); maxY = math.max(maxY, n.pos.dy);
      }
      const p = 55.0;
      final topLeft = _view.toScreen(Offset(minX - p, minY - p));
      final botRight = _view.toScreen(Offset(maxX + p, maxY + p));
      if (screenPos.dx >= topLeft.dx && screenPos.dx <= botRight.dx &&
          screenPos.dy >= topLeft.dy && screenPos.dy <= botRight.dy) {
        return entry.key;
      }
    }
    return null;
  }

  // ── ポインターイベント ────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent e) {
    _ptrs[e.pointer] = _PtrInfo(e.localPosition);

    if (_ptrs.length == 1) {
      // ダブルタップ判定
      final now = DateTime.now().millisecondsSinceEpoch;
      final dist = (e.localPosition - _lastTapPos).distance;
      if (now - _lastTapMs < 300 && dist < 60) {
        // 2回目のタップ開始 → ダブルタップモード
        _maybeDoubleTap = true;
        _doubleTapZooming = false;
        _doubleTapZoomOrigin = e.localPosition;
        _doubleTapZoomStartScale = _view.scale;
        _doubleTapZoomFocal = _view.toScene(e.localPosition);
        _lastTapMs = 0; // 3連打防止
        return;
      }

      _panStartFocal = e.localPosition;
      _panStartOff = _view.offset;
      final hit = _hitTest(e.localPosition);
      if (hit != null) {
        _view.update(draggingIdFn: () => hit.id);
        _dragStartScene = _view.toScene(e.localPosition);
        _dragStartNodePos = hit.pos;
        _model.pinAndMove(hit.id, hit.pos);
      } else {
        // シートタイトル帯ドラッグの判定
        final titleSheet = _hitTestClusterTitle(e.localPosition);
        if (titleSheet != null) {
          _draggingSheetName = titleSheet;
          _sheetDragStartScene = _view.toScene(e.localPosition);
          _sheetDragStartPositions = {
            for (final n in _model.nodes.where((n) => n.sheetName == titleSheet))
              n.id: n.pos
          };
          for (final n in _model.nodes.where((n) => n.sheetName == titleSheet)) {
            n.pinned = true;
            n.vel = Offset.zero;
          }
        }
        _view.update(draggingIdFn: () => null);
      }
    } else if (_ptrs.length == 2) {
      // 2本指操作開始時はダブルタップモードをキャンセル
      _maybeDoubleTap = false;
      _doubleTapZooming = false;
      final did = _view.draggingId;
      if (did != null) { _model.unpin(did); _view.update(draggingIdFn: () => null); }
      final pts = _ptrs.values.toList();
      _pinchStartMid = (pts[0].pos + pts[1].pos) / 2;
      _pinchStartDist = (pts[0].pos - pts[1].pos).distance;
      _pinchStartScale = _view.scale;
      _pinchStartOff = _view.offset;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    _ptrs[e.pointer]?.pos = e.localPosition;

    if (_ptrs.length == 1) {
      // ダブルタップ+ドラッグ → 上下ドラッグでズーム
      if (_maybeDoubleTap) {
        final dy = _doubleTapZoomOrigin.dy - e.localPosition.dy; // 上が正
        if (_doubleTapZooming || (e.localPosition - _doubleTapZoomOrigin).distance > 5) {
          _doubleTapZooming = true;
          final factor = math.exp(dy * 0.010);
          final newScale = (_doubleTapZoomStartScale * factor).clamp(0.03, 15.0);
          _view.update(
            scale: newScale,
            offset: _doubleTapZoomOrigin - _doubleTapZoomFocal * newScale,
          );
        }
        return;
      }

      final did = _view.draggingId;
      if (did != null) {
        final scene = _view.toScene(e.localPosition);
        _model.pinAndMove(did, _dragStartNodePos + (scene - _dragStartScene));
      } else if (_draggingSheetName != null) {
        // シートクラスター一括ドラッグ
        final scene = _view.toScene(e.localPosition);
        final delta = scene - _sheetDragStartScene;
        _model.moveSheetNodes(
            _draggingSheetName!, _sheetDragStartPositions, delta);
      } else {
        _view.update(offset: _panStartOff + (e.localPosition - _panStartFocal));
      }
    } else if (_ptrs.length == 2) {
      final pts = _ptrs.values.toList();
      final mid = (pts[0].pos + pts[1].pos) / 2;
      final dist = (pts[0].pos - pts[1].pos).distance;
      if (_pinchStartDist < 1) return;
      final newScale = (_pinchStartScale * dist / _pinchStartDist).clamp(0.03, 15.0);
      final focal = (_pinchStartMid - _pinchStartOff) / _pinchStartScale;
      _view.update(
        scale: newScale,
        offset: _pinchStartMid - focal * newScale + (mid - _pinchStartMid),
      );
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    final info = _ptrs.remove(e.pointer);

    // ダブルタップモードの処理
    if (_maybeDoubleTap) {
      if (!_doubleTapZooming) {
        // ドラッグなしのダブルタップ → 全体フィット
        _fitToView();
      }
      _maybeDoubleTap = false;
      _doubleTapZooming = false;
      final did = _view.draggingId;
      if (did != null && _ptrs.isEmpty) {
        _model.unpin(did);
        _view.update(draggingIdFn: () => null);
      }
      return;
    }

    if (info != null) {
      final moved = (e.localPosition - info.startPos).distance;
      if (moved < 12 && info.elapsedMs < 280) {
        // 単一タップ → 次のタップのためにタイム・位置を記録
        _lastTapMs = DateTime.now().millisecondsSinceEpoch;
        _lastTapPos = e.localPosition;

        final hit = _hitTest(e.localPosition);
        if (hit != null) {
          final newSel = (hit.id == _view.selId) ? null : hit.id;
          _view.update(selIdFn: () => newSel);
          setState(() {});
        } else {
          // シートクラスタータップ → そのシートにフィット
          final cluster = _hitTestCluster(e.localPosition);
          if (cluster != null) {
            _fitToSheet(cluster);
          } else {
            _view.update(selIdFn: () => null);
            setState(() {});
          }
        }
      }
    }
    final did = _view.draggingId;
    if (did != null && _ptrs.isEmpty) {
      _model.unpin(did);
      _view.update(draggingIdFn: () => null);
    }
    if (_draggingSheetName != null && _ptrs.isEmpty) {
      _model.unpinSheet(_draggingSheetName!);
      _draggingSheetName = null;
      _sheetDragStartPositions = {};
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _maybeDoubleTap = false;
    _doubleTapZooming = false;
    final did = _view.draggingId;
    _ptrs.remove(e.pointer);
    if (did != null) { _model.unpin(did); _view.update(draggingIdFn: () => null); }
    if (_draggingSheetName != null) {
      _model.unpinSheet(_draggingSheetName!);
      _draggingSheetName = null;
      _sheetDragStartPositions = {};
    }
  }

  void _onScrollWheel(PointerScrollEvent e) {
    final factor = e.scrollDelta.dy > 0 ? 0.88 : 1.14;
    final newScale = (_view.scale * factor).clamp(0.03, 15.0);
    final focal = _view.toScene(e.localPosition);
    _view.update(scale: newScale, offset: e.localPosition - focal * newScale);
  }

  // ── ビルド ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final visible = _visibleNodes;

    return PopScope(
      canPop: false,
      child: Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('リンクグラフ',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
            if (!_loading)
              Text(
                _showAll
                    ? '全 ${_model.nodes.length} ノード'
                    : 'リンク済み ${visible.length} ノード',
                style: const TextStyle(color: Color.fromARGB(151, 221, 254, 181), fontSize: 14),
              ),
          ],
        ),
        actions: const [],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7B7FFF)))
          : visible.isEmpty
              ? _EmptyState(
                  showAll: _showAll,
                  onShowAll: () {
                    setState(() => _showAll = true);
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _fitToView());
                  },
                )
              : Stack(
                  children: [
                    // ── Canvas ──────────────────────────────────────
                    Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: _onPointerUp,
                      onPointerCancel: _onPointerCancel,
                      onPointerSignal: (e) {
                        if (e is PointerScrollEvent) _onScrollWheel(e);
                      },
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _GraphPainter(
                            model: _model,
                            view: _view,
                            visibleNodes: visible,
                            mergedSheetNames: _mergedSheetNames,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),

                    // ── ツールボタン ────────────────────────────────
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'graph_toggle',
                            backgroundColor: const Color(0xFF1A1A2A),
                            foregroundColor: _showAll
                                ? const Color(0xFF7B7FFF)
                                : Colors.white54,
                            elevation: 2,
                            tooltip: _showAll ? '全ノード表示中' : 'リンク済みのみ表示中',
                            onPressed: () {
                              setState(() => _showAll = !_showAll);
                              WidgetsBinding.instance
                                  .addPostFrameCallback((_) => _fitToView());
                            },
                            child: Icon(
                              _showAll ? Icons.hub : Icons.hub_outlined,
                              size: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            heroTag: 'graph_fit',
                            backgroundColor: const Color(0xFF1A1A2A),
                            foregroundColor: Colors.white54,
                            elevation: 2,
                            tooltip: '画面にフィット',
                            onPressed: _fitToView,
                            child: const Icon(Icons.fit_screen, size: 18),
                          ),
                        ],
                      ),
                    ),

                    // ── 凡例 ────────────────────────────────────────
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _LegendWidget(
                        calcCount:
                            visible.where((n) => !n.isLogic).length,
                        logicCount:
                            visible.where((n) => n.isLogic).length,
                        edgeCount: _model.edges.length,
                        model: _model,
                      ),
                    ),

                    // ── ヒント ──────────────────────────────────────
                    Positioned(
                      bottom: 18,
                      left: 0,
                      right: 0,
                      child: ListenableBuilder(
                        listenable: _model,
                        builder: (_, __) => AnimatedOpacity(
                          opacity: (_model.settled || _view.selId != null)
                              ? 0.0
                              : 0.55,
                          duration: const Duration(milliseconds: 800),
                          child: const Center(
                            child: Text(
                              'ドラッグ移動  ·  ピンチ/スクロールズーム  ·  ダブルタップで全体表示  ·  シートタップで拡大',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── 詳細カード ──────────────────────────────────
                    if (_view.selId != null)
                      Positioned(
                        bottom: 20,
                        left: 16,
                        right: 16,
                        child: Builder(builder: (_) {
                          _Node? sel;
                          try {
                            sel = _model.nodes
                                .firstWhere((n) => n.id == _view.selId);
                          } catch (_) {}
                          if (sel == null) return const SizedBox.shrink();
                          return _DetailCard(
                            node: sel,
                            edges: _model.edges,
                            nodes: _model.nodes,
                            onClose: () {
                              _view.update(selIdFn: () => null);
                              setState(() {});
                            },
                            onOpenSheet: widget.onOpenSheet,
                          );
                        }),
                      ),
                  ],
                ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// グラフ描画（CustomPainter — repaint は model + view）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _GraphPainter extends CustomPainter {
  final _GraphModel model;
  final _ViewState view;
  final List<_Node> visibleNodes;
  final Map<String, List<String>> mergedSheetNames;

  _GraphPainter({
    required this.model,
    required this.view,
    required this.visibleNodes,
    this.mergedSheetNames = const {},
  }) : super(repaint: Listenable.merge([model, view]));

  static const Color _bg = Color.fromARGB(255, 0, 0, 0);
  static const Color _calcColor = Color.fromARGB(255, 74, 153, 255);
  static const Color _logicColor = Color(0xFFFFAA33);
  static const Color _edgeColor = Color(0xFF888AAA);
  static const Color _edgeSelColor = Color(0xFFAAB0FF);
  static const Color _labelColor = Color(0xFFD0D0E8);

  @override
  void paint(Canvas canvas, Size size) {
    final nodeMap = <String, _Node>{for (final n in visibleNodes) n.id: n};
    final selId = view.selId;
    final sc = view.scale;
    final off = view.offset;
    final connectedIds = selId != null ? model.connectedTo(selId) : <String>{};

    // 背景
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg);

    // ビュー変換
    canvas.save();
    canvas.translate(off.dx, off.dy);
    canvas.scale(sc);

    // シートクラスター背景
    _drawClusters(canvas, visibleNodes, sc);

    // エッジ
    for (final e in model.edges) {
      final from = nodeMap[e.fromId];
      final to = nodeMap[e.toId];
      if (from == null || to == null) continue;
      final isActive =
          selId != null && (e.fromId == selId || e.toId == selId);
      final isDimmed = selId != null && !isActive;
      _drawEdge(canvas, from.pos, to.pos, e.label,
          sc: sc, isActive: isActive, isDimmed: isDimmed);
    }

    // ノード
    for (final n in visibleNodes) {
      final isSel = n.id == selId;
      final isConn = connectedIds.contains(n.id);
      final isDrag = n.id == view.draggingId;
      final isDimmed = selId != null && !isSel && !isConn;
      _drawNode(canvas, n,
          sc: sc,
          isSel: isSel,
          isConn: isConn,
          isDrag: isDrag,
          isDimmed: isDimmed);
    }

    canvas.restore();
  }

  // 結合シートのバッジ色パレット（ハッシュで安定割り当て）
  static const _mergedColors = [
    Color(0xFF5E81FF), // 青紫
    Color(0xFFFF6B9D), // ピンク
    Color(0xFF43D49E), // 緑
    Color(0xFFFFAA33), // オレンジ
    Color(0xFF8BC8FF), // 水色
  ];

  Color _mergedColor(String title) =>
      _mergedColors[title.hashCode.abs() % _mergedColors.length];

  void _drawClusters(Canvas canvas, List<_Node> nodes, double sc) {
    // sheetId → sheetName の逆引きマップ
    final idToName = <String, String>{};
    for (final n in nodes) {
      idToName[n.sheetId] = n.sheetName;
    }

    final bySheet = <String, List<_Node>>{};
    for (final n in nodes) {
      bySheet.putIfAbsent(n.sheetName, () => []).add(n);
    }
    for (final entry in bySheet.entries) {
      final ns = entry.value;
      if (ns.length < 2) continue;
      final sid = ns.first.sheetId;
      final merged = mergedSheetNames[sid] ?? [];
      final hasMerged = merged.isNotEmpty;
      final accentColor = hasMerged ? _mergedColor(merged.first) : null;

      double minX = ns.first.pos.dx, maxX = minX;
      double minY = ns.first.pos.dy, maxY = minY;
      for (final n in ns) {
        minX = math.min(minX, n.pos.dx); maxX = math.max(maxX, n.pos.dx);
        minY = math.min(minY, n.pos.dy); maxY = math.max(maxY, n.pos.dy);
      }
      const p = 55.0;
      final rr = RRect.fromRectAndRadius(
          Rect.fromLTRB(minX - p, minY - p, maxX + p, maxY + p),
          const Radius.circular(20));

      // 背景塗り（結合あり → アクセント色のうっすらグロー）
      canvas.drawRRect(
        rr,
        Paint()
          ..color = (hasMerged ? accentColor! : Colors.white)
              .withOpacity(hasMerged ? 0.04 : 0.02),
      );
      // 枠線
      canvas.drawRRect(
          rr,
          Paint()
            ..color = (hasMerged ? accentColor! : Colors.white)
                .withOpacity(hasMerged ? 0.25 : 0.05)
            ..style = PaintingStyle.stroke
            ..strokeWidth = (hasMerged ? 1.4 : 1.0) / sc);

      if (sc > 0.25) {
        // シート名
        final sheetTp = TextPainter(
          text: TextSpan(
            text: entry.key,
            style: TextStyle(
              color: (hasMerged ? accentColor! : Colors.white)
                  .withOpacity(hasMerged ? 0.55 : 0.18),
              fontSize: (11 / sc).clamp(8.0, 14.0),
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        sheetTp.paint(canvas, Offset(minX - p + 10, minY - p + 6));

        // 結合シートバッジ（シート名の下に縦に並べる）
        if (hasMerged && sc > 0.3) {
          final bx = minX - p + 6;
          double by = minY - p + 4 + sheetTp.height + (4 / sc);
          final badgeFontSize = (10 / sc).clamp(7.0, 13.0);
          for (final mTitle in merged) {
            final col = _mergedColor(mTitle);
            final badgeTp = TextPainter(
              text: TextSpan(
                text: mTitle,
                style: TextStyle(
                  color: col.withOpacity(0.55),
                  fontSize: badgeFontSize,
                  fontWeight: FontWeight.w100,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            const hPad = 6.0;
            const vPad = 3.0;
            final bh = badgeTp.height + vPad * 2 / sc;
            badgeTp.paint(
              canvas,
              Offset(bx + hPad / sc, by + vPad / sc),
            );
            by += bh + (-3 / sc);
          }
        }
      }
    }
  }

  void _drawEdge(
    Canvas canvas,
    Offset from,
    Offset to,
    String label, {
    required double sc,
    bool isActive = false,
    bool isDimmed = false,
  }) {
    final opacity = isDimmed ? 0.04 : (isActive ? 0.80 : 0.18);
    final color = (isActive ? _edgeSelColor : _edgeColor).withOpacity(opacity);
    final sw = (isActive ? 1.5 : 1.0) / sc;

    final dir = to - from;
    final dist = dir.distance;
    if (dist < 1) return;
    final unit = dir / dist;
    final r = _Node.r;
    final start = from + unit * (r + 1);
    final end = to - unit * (r + 5);

    canvas.drawLine(start, end,
        Paint()
          ..color = color
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round);

    // 矢印（アクティブ時のみ）
    if (isActive) {
      final arrowSz = 7.0 / sc;
      final perp = Offset(-unit.dy, unit.dx);
      canvas.drawPath(
        Path()
          ..moveTo(end.dx, end.dy)
          ..lineTo((end - unit * arrowSz + perp * arrowSz * 0.45).dx,
              (end - unit * arrowSz + perp * arrowSz * 0.45).dy)
          ..lineTo((end - unit * arrowSz - perp * arrowSz * 0.45).dx,
              (end - unit * arrowSz - perp * arrowSz * 0.45).dy)
          ..close(),
        Paint()..color = color..style = PaintingStyle.fill,
      );
    }

    // エッジラベル（アクティブ × ズームイン時）
    if (isActive && sc > 0.45) {
      final mid = (start + end) / 2;
      final perp = Offset(-unit.dy, unit.dx);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
              color: _edgeSelColor.withOpacity(0.85),
              fontSize: (10.0 / sc).clamp(7.0, 13.0),
              fontWeight: FontWeight.w500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          mid + perp * (12 / sc) - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _drawNode(
    Canvas canvas,
    _Node node, {
    required double sc,
    bool isSel = false,
    bool isConn = false,
    bool isDrag = false,
    bool isDimmed = false,
  }) {
    final r = _Node.r;
    final c = node.pos;
    final base = node.isLogic ? _logicColor : _calcColor;

    // グロー
    if (isSel || isDrag) {
      canvas.drawCircle(c, r * 4,
          Paint()
            ..color = base.withOpacity(0.12)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16 / sc));
      canvas.drawCircle(c, r * 2.5,
          Paint()
            ..color = base.withOpacity(0.22)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 / sc));
    } else if (isConn) {
      canvas.drawCircle(c, r * 2.5,
          Paint()
            ..color = base.withOpacity(0.10)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 / sc));
    }

    // 背景（ノード内側）
    canvas.drawCircle(c, r, Paint()..color = _bg);

    // リング
    final ringAlpha =
        isDimmed ? 0.18 : (isSel ? 1.0 : isConn ? 0.80 : 0.65);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = base.withOpacity(ringAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (isSel ? 2.0 : 1.4) / sc);

    // 中心ドット
    canvas.drawCircle(
        c,
        r * (isSel ? 0.44 : 0.28),
        Paint()
          ..color = base
              .withOpacity(isDimmed ? 0.15 : (isSel ? 0.90 : 0.55)));

    // ラベル
    if (sc > 0.28 && !isDimmed) {
      final maxCh = isSel ? 22 : 12;
      final lbl = node.label.length > maxCh
          ? '${node.label.substring(0, maxCh)}…'
          : node.label;
      final fs = (11.0 / sc).clamp(7.0, 14.0);
      final la = isSel ? 1.0 : (isConn ? 0.80 : 0.55);
      final tp = TextPainter(
        text: TextSpan(
          text: lbl,
          style: TextStyle(
              color: _labelColor.withOpacity(la),
              fontSize: fs,
              fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 140 / sc);
      tp.paint(canvas, Offset(c.dx + r + 4 / sc, c.dy - tp.height / 2));
    }

    // シート名（ズームイン時）
    if (sc > 0.7 && !isDimmed) {
      final stp = TextPainter(
        text: TextSpan(
          text: node.sheetName,
          style: TextStyle(
              color: Colors.white.withOpacity(0.20),
              fontSize: (8.5 / sc).clamp(5.5, 10.0)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      stp.paint(canvas,
          Offset(c.dx + r + 4 / sc, c.dy + (12 / sc) * 0.65));
    }

    // ピン留めインジケーター
    if (node.pinned) {
      canvas.drawCircle(c + Offset(r * 0.65, -r * 0.65), 2.5 / sc,
          Paint()..color = Colors.white70);
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => true;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ポインター情報
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PtrInfo {
  Offset pos;
  final Offset startPos;
  final int _t0;

  _PtrInfo(Offset p)
      : pos = p,
        startPos = p,
        _t0 = DateTime.now().millisecondsSinceEpoch;

  int get elapsedMs => DateTime.now().millisecondsSinceEpoch - _t0;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 空状態
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _EmptyState extends StatelessWidget {
  final bool showAll;
  final VoidCallback onShowAll;

  const _EmptyState({required this.showAll, required this.onShowAll});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.scatter_plot_outlined,
              size: 64, color: Colors.white.withOpacity(0.08)),
          const SizedBox(height: 20),
          Text(
            showAll ? 'シートにデータがありません' : 'リンクが設定されていません',
            style: const TextStyle(
                color: Color(0xFF5A5A7A),
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            showAll
                ? '計算シートを作成してください'
                : '計算シート内で値をリンク設定すると\nここにグラフが表示されます',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF3A3A5A), fontSize: 13),
          ),
          if (!showAll) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onShowAll,
              icon: const Icon(Icons.scatter_plot_outlined, size: 16),
              label: const Text('全ノードを表示'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7B7FFF),
                side: const BorderSide(color: Color(0xFF3A4080)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 凡例
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _LegendWidget extends StatelessWidget {
  final int calcCount;
  final int logicCount;
  final int edgeCount;
  final _GraphModel model;

  const _LegendWidget({
    required this.calcCount,
    required this.logicCount,
    required this.edgeCount,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LegRow(
                color: const Color(0xFF7B7FFF),
                label: '計算式',
                count: calcCount),
            const SizedBox(height: 6),
            _LegRow(
                color: const Color(0xFFFFAA33),
                label: '論理式',
                count: logicCount),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 3),
              child: Divider(color: Colors.white10, height: 1),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 16, height: 1.2, color: const Color(0xFF404060)),
                const SizedBox(width: 7),
                Text('接続 $edgeCount 本',
                    style: const TextStyle(
                        color: Color(0xFF505070), fontSize: 10)),
              ],
            ),
            const SizedBox(width: 10),
            ListenableBuilder(
              listenable: model,
              builder: (_, __) {
                if (model.settled) return const SizedBox.shrink();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 10, height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.2,
                        value: 1.0 - model.alpha,
                        color: const Color(0xFF7B7FFF),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('配置計算中…',
                        style: TextStyle(
                            color: Color(0xFF4A4A6A), fontSize: 9.5)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LegRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _LegRow(
      {required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
              color: color.withOpacity(0.18)),
        ),
        const SizedBox(width: 7),
        Text('$label  $count',
            style: TextStyle(
                color: color.withOpacity(0.75), fontSize: 10.5)),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ノード詳細カード
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _DetailCard extends StatelessWidget {
  final _Node node;
  final List<_Edge> edges;
  final List<_Node> nodes;
  final VoidCallback onClose;
  final void Function(String sheetId)? onOpenSheet;

  const _DetailCard({
    required this.node,
    required this.edges,
    required this.nodes,
    required this.onClose,
    this.onOpenSheet,
  });

  String _resolveLabel(Map src, String ownSid, Map<String, _Node> nm, {bool resolveRemoteLink = true}) {
    if (!resolveRemoteLink) {
        return '? (リンクされていません)';
    }
    final sid = src['sheetId'] as String? ?? ownSid;
    final type = src['type'] as String?;
    if (type == 'logic') {
      final logicId = src['logicId'] as String?;
      return nm['${sid}_l$logicId']?.label ?? '?';
    }
    final row = src['rowIdx'] as int? ?? 0;
    return nm['${sid}_c$row']?.label ?? '?';
  }

  // 数値を短く整形
  String _fmtNum(dynamic v) {
    final d = (v as num?)?.toDouble() ?? 0.0;
    if (d == d.truncateToDouble()) return d.truncate().toString();
    final s = d.toStringAsFixed(4);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final nodeMap = <String, _Node>{for (final n in nodes) n.id: n};
    final incoming = edges.where((e) => e.toId == node.id).toList();
    final outgoing = edges.where((e) => e.fromId == node.id).toList();
    final accent =
        node.isLogic ? const Color(0xFFFFAA33) : const Color(0xFF7B7FFF);

    return Container(
      constraints: const BoxConstraints(maxHeight: 360),
      decoration: BoxDecoration(
        color: const Color(0xFF0F101E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.22), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.60),
              blurRadius: 28,
              offset: const Offset(0, 6)),
          BoxShadow(color: accent.withOpacity(0.07), blurRadius: 20),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── ヘッダー ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(node.isLogic ? '論理式' : '計算式',
                      style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(node.label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ),
                if (onOpenSheet != null)
                  GestureDetector(
                    onTap: () => onOpenSheet!(node.sheetId),
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                     
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('編集',
                              style: TextStyle(
                                  color: Color(0xFF7B7FFF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close,
                      color: Colors.white24, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: Text('シート: ${node.sheetName}',
                style: const TextStyle(
                    color: Color(0xFF3A3A5A), fontSize: 11)),
          ),
          const Divider(color: Colors.white10, height: 1),

          // ── 式セクション ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 式の表示
                  if (!node.isLogic)
                    _CalcFormulaView(
                        item: node.rawData,
                        sheetId: node.sheetId,
                        nodeMap: nodeMap,
                        resolveLabel: _resolveLabel,
                        fmtNum: _fmtNum,
                        incomingEdges: incoming,
                        outgoingEdges: outgoing)
                  else
                    _LogicFormulaView(
                        item: node.rawData,
                        sheetId: node.sheetId,
                        nodeMap: nodeMap,
                        resolveLabel: _resolveLabel,
                        fmtNum: _fmtNum),
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 8),
                  // 参照元・先
                  if (incoming.isNotEmpty) ...[
                    _ConSection(
                        title: '← 参照元',
                        accentColor: const Color(0xFF5EFFBB),
                        edges: incoming,
                        allEdges: edges,
                        nodeMap: nodeMap,
                        isIncoming: true,
                        resolveLabel: _resolveLabel,
                        fmtNum: _fmtNum),
                    if (outgoing.isNotEmpty) const SizedBox(height: 10),
                  ],
                  if (outgoing.isNotEmpty)
                    _ConSection(
                        title: '→ 参照先',
                        accentColor: const Color(0xFFFF9B5E),
                        edges: outgoing,
                        allEdges: edges,
                        nodeMap: nodeMap,
                        isIncoming: false,
                        resolveLabel: _resolveLabel,
                        fmtNum: _fmtNum),
                  if (incoming.isEmpty && outgoing.isEmpty)
                    const Text('接続なし',
                        style: TextStyle(
                            color: Color(0xFF3A3A5A), fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// リンクを辿って計算結果を再帰的に解決するヘルパー
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 項変換を適用する（calculator_row.dart の _applyTermTransform と同等）
double _applyTermTransformLocal(double v, String? transform, double powExp) {
  switch (transform) {
    case 'sqrt':      return math.sqrt(v < 0 ? 0 : v);
    case 'pow':       return math.pow(v, powExp).toDouble();
    case 'nroot':     return powExp != 0 ? math.pow(v < 0 ? 0 : v, 1.0 / powExp).toDouble() : 0;
    case 'abs':       return v.abs();
    case 'floor':     return v.floorToDouble();
    case 'ceil':      return v.ceilToDouble();
    case 'round':     return v.roundToDouble();
    case 'log10':     return v > 0 ? math.log(v) / math.ln10 : 0;
    case 'reciprocal': return v != 0 ? 1.0 / v : 0;
    case 'sin':       return math.sin(v);
    case 'cos':       return math.cos(v);
    case 'tan':       return math.tan(v);
    default:          return v;
  }
}

/// 単一演算（calculator_widget.dart の _calculateSingle と同等）
double _calcSingle(double a, String op, double b) {
  switch (op) {
    case '+': return a + b;
    case '-': return a - b;
    case 'x': return a * b;
    case '/': return b != 0 ? a / b : double.nan;
    case '%': return b != 0 ? a % b : double.nan;
    default:  return a;
  }
}

/// トークンリストを優先順位付きで評価（calculator_widget.dart の _evaluateTokens と同等）
double _evaluateTokensLocal(List<dynamic> tokens) {
  if (tokens.isEmpty) return 0.0;
  double extractVal(dynamic t) =>
      (t is Map ? (t['val'] ?? 0.0) : (t ?? 0.0) as num).toDouble();

  // 第1パス: 高優先度の演算子（x, /, %）を先に評価
  final work = List<dynamic>.from(tokens);
  int i = 1;
  while (i < work.length) {
    final op = work[i] as String;
    if (op == 'x' || op == '/' || op == '%') {
      final result = _calcSingle(extractVal(work[i - 1]), op, extractVal(work[i + 1]));
      work.replaceRange(i - 1, i + 2, [<String, dynamic>{'val': result}]);
    } else {
      i += 2;
    }
  }

  // 第2パス: 低優先度の演算子（+, -）を評価
  double res = extractVal(work[0]);
  for (int j = 1; j < work.length; j += 2) {
    res = _calcSingle(res, work[j] as String, extractVal(work[j + 1]));
  }
  return res;
}

/// 括弧と演算子優先順位を反映した式全体の評価（calculator_widget.dart の _calculate と同等）
double _calculateFull(
  double input,
  String op,
  double operand,
  List<dynamic> others,
  List<dynamic> brackets,
) {
  // トークンリストの構築
  final tokens = <dynamic>[
    {'val': input, 'termIdx': 0},
    op,
    {'val': operand, 'termIdx': 1},
  ];
  for (int idx = 0; idx < others.length; idx++) {
    final m = others[idx] as Map;
    tokens.add(m['op'] as String? ?? '+');
    tokens.add({'val': (m['val'] as num? ?? 0.0).toDouble(), 'termIdx': idx + 2});
  }

  if (brackets.isEmpty) return _evaluateTokensLocal(tokens);

  final currentTokens = List<dynamic>.from(tokens);
  final bList = brackets.map((e) {
    final m = e as Map;
    return {'start': (m['start'] as num).toInt(), 'end': (m['end'] as num).toInt()};
  }).toList()
    ..sort((a, b) {
      final aSpan = (a['end'] as int) - (a['start'] as int);
      final bSpan = (b['end'] as int) - (b['start'] as int);
      return aSpan.compareTo(bSpan);
    });

  for (final b in bList) {
    final start = b['start'] as int;
    final end = b['end'] as int;
    int firstIdx = -1, lastIdx = -1;
    for (int j = 0; j < currentTokens.length; j++) {
      final t = currentTokens[j];
      if (t is Map && t.containsKey('termIdx')) {
        final tidx = (t['termIdx'] as num).toInt();
        if (tidx <= start) firstIdx = j;
        if (tidx <= end) lastIdx = j;
      }
    }
    if (firstIdx != -1 && lastIdx != -1 && firstIdx < lastIdx) {
      final sub = currentTokens.sublist(firstIdx, lastIdx + 1);
      final res = _evaluateTokensLocal(sub);
      final firstMap = currentTokens[firstIdx] as Map;
      currentTokens.replaceRange(firstIdx, lastIdx + 1, [
        <String, dynamic>{'val': res, 'termIdx': (firstMap['termIdx'] as num).toInt()},
      ]);
    }
  }

  return _evaluateTokensLocal(currentTokens);
}

/// リンクを辿りながら再帰的に計算結果を解決する
/// （演算子の正規化・項変換・括弧・優先順位に対応）
double _calcLinkedResult(
    Map<String, dynamic> item,
    String sheetId,
    Map<String, _Node> nodeMap, [
    Set<String>? visited,
]) {
  // リンク先またはローカル値を解決して返す（再帰対応）
  double resolveValue(bool linked, Map? src, dynamic rawVal) {
    if (linked && src != null) {
      final sid = src['sheetId'] as String? ?? sheetId;
      final row = src['rowIdx'] as int? ?? 0;
      final srcId = '${sid}_c$row';
      final v = visited ?? {};
      if (v.contains(srcId)) return (rawVal as num? ?? 0).toDouble();
      final srcNode = nodeMap[srcId];
      if (srcNode != null && !srcNode.isLogic) {
        v.add(srcId);
        return _calcLinkedResult(srcNode.rawData, srcNode.sheetId, nodeMap, v);
      }
    }
    return (rawVal as num? ?? 0).toDouble();
  }

  // 各項の値を解決してから transform を適用
  final inp = _applyTermTransformLocal(
    resolveValue(
      item['inputLink'] == true,
      item['inputLinkSource'] as Map?,
      item['input'],
    ),
    item['inputTransform'] as String?,
    (item['inputPowExp'] as num? ?? 2.0).toDouble(),
  );

  final ope = _applyTermTransformLocal(
    resolveValue(
      item['operandLink'] == true,
      item['operandLinkSource'] as Map?,
      item['operand'],
    ),
    item['operandTransform'] as String?,
    (item['operandPowExp'] as num? ?? 2.0).toDouble(),
  );

  final op = item['op'] as String? ?? '+';

  final others = (item['others'] as List? ?? []).map((x) {
    final m = Map<String, dynamic>.from(x as Map);
    final resolvedVal = resolveValue(
      m['valLink'] == true,
      m['valLinkSource'] as Map?,
      m['val'],
    );
    m['val'] = _applyTermTransformLocal(
      resolvedVal,
      m['transform'] as String?,
      (m['powExp'] as num? ?? 2.0).toDouble(),
    );
    return m;
  }).toList();

  final brackets = item['brackets'] as List? ?? [];

  return _calculateFull(inp, op, ope, others, brackets);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 計算式フォーミュラビュー（項とリンク状況を色で表現）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _CalcFormulaView extends StatelessWidget {
  final Map<String, dynamic> item;
  final String sheetId;
  final Map<String, _Node> nodeMap;
  final String Function(Map, String, Map<String, _Node>, {bool resolveRemoteLink}) resolveLabel;
  final String Function(dynamic) fmtNum;
  /// 参照元エッジ（現在ノードへの入力リンク）
  final List<_Edge>? incomingEdges;
  /// 参照先エッジ（現在ノードからの出力リンク）
  final List<_Edge>? outgoingEdges;

  const _CalcFormulaView({
    required this.item,
    required this.sheetId,
    required this.nodeMap,
    required this.resolveLabel,
    required this.fmtNum,
    this.incomingEdges,
    this.outgoingEdges,
  });

  // 参照元（緑）・参照先（橙）・両方（金）
  static const _srcColor  = Color(0xFF5EFFBB);
  static const _dstColor  = Color(0xFFFF9B5E);
  static const _bothColor = Color(0xFFFFCC44);
  static const _noLinkColor = Color(0xFF1E1E30);
  static const _opColor = Color(0xFF5050A0);

  /// リンクソースの接続種別を返す（循環参照判定用）
  String _connType(Map? src) {
    if (src == null) return 'source';
    final sid = src['sheetId'] as String? ?? sheetId;
    final row = (src['rowIdx'] as num?)?.toInt() ?? 0;
    final srcId = '${sid}_c$row';
    final isFrom = incomingEdges?.any((e) => e.fromId == srcId) ?? false;
    final isDest = outgoingEdges?.any((e) => e.toId == srcId) ?? false;
    if (isFrom && isDest) return 'both';
    if (isDest) return 'dest';
    return 'source';
  }

  Widget _term(String text, {bool linked = false, Map? src}) {
    // linked == true の場合は常にマーキング（エッジ有無を問わない）
    if (!linked || (text == '? (リンクされていません)')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: _noLinkColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
      );
    }
    final ct = src != null ? _connType(src) : 'source';
    final Color accent;
    switch (ct) {
      case 'dest':   accent = _dstColor;  break;
      case 'both':   accent = _bothColor; break;
      default:       accent = _srcColor;  break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withOpacity(0.50), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link, size: 10, color: accent.withOpacity(0.9)),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _op(String symbol) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(symbol,
            style: const TextStyle(color: _opColor, fontSize: 13, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    bool isLinked(Map src) {
      final sid = src['sheetId'] as String? ?? sheetId;
      final type = src['type'] as String?;
      final String srcId;
      if (type == 'logic') {
        srcId = '${sid}_l${src['logicId']}';
      } else {
        final row = (src['rowIdx'] as num?)?.toInt() ?? 0;
        srcId = '${sid}_c$row';
      }
      return incomingEdges?.any((e) => e.fromId == srcId) ?? false;
    }

    final inputLinked = item['inputLink'] == true;
    final inputSrc = item['inputLinkSource'] as Map?;
    final inputLabel = inputLinked && inputSrc != null
        ? resolveLabel(inputSrc, sheetId, nodeMap, resolveRemoteLink: isLinked(inputSrc))
        : fmtNum(item['input']);

    final opSym = item['op'] as String? ?? '+';

    final operandLinked = item['operandLink'] == true;
    final operandSrc = item['operandLinkSource'] as Map?;
    final operandLabel = operandLinked && operandSrc != null
        ? resolveLabel(operandSrc, sheetId, nodeMap, resolveRemoteLink: isLinked(operandSrc))
        : fmtNum(item['operand']);

    final others = (item['others'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final children = <Widget>[
      _term(inputLabel, linked: inputLinked, src: inputSrc),
      _op(opSym),
      _term(operandLabel, linked: operandLinked, src: operandSrc),
    ];

    for (final o in others) {
      final vLinked = o['valLink'] == true;
      final vSrc = o['valLinkSource'] as Map?;
      final vLabel = vLinked && vSrc != null
          ? resolveLabel(vSrc, sheetId, nodeMap, resolveRemoteLink: isLinked(vSrc))
          : fmtNum(o['val']);
      children.add(_op(o['op'] as String? ?? '+'));
      children.add(_term(vLabel, linked: vLinked, src: vSrc));
    }

    final result = _calcLinkedResult(item, sheetId, nodeMap);
    final resultStr = result.isNaN ? '÷0' : result.isInfinite ? '∞' : fmtNum(result);
    final hasLinks = inputLinked || operandLinked || others.any((o) => o['valLink'] == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('式',
            style: TextStyle(
                color: Color(0xFF5050A0),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
        const SizedBox(height: 5),
        
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
          
          Wrap(spacing: 0, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: children),
            _op('='),
            Builder(builder: (context) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white12,
                  ),
                ),
                child: Text(resultStr,
                    style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              );
            }),
            if (hasLinks)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('(保存値で計算)',
                    style: TextStyle(color: Colors.white38, fontSize: 9.5)),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          if (incomingEdges?.isNotEmpty == true) ...[
            _LinkedLegend(linked: true, label: '参照元', color: _srcColor),
            const SizedBox(width: 8),
          ],
          if (outgoingEdges?.isNotEmpty == true) ...[
            _LinkedLegend(linked: true, label: '参照先', color: _dstColor),
            const SizedBox(width: 8),
          ],
          if ((incomingEdges?.isNotEmpty == true) && (outgoingEdges?.isNotEmpty == true))
            _LinkedLegend(linked: true, label: '両方', color: _bothColor),
          if (incomingEdges == null && outgoingEdges == null) ...[
            _LinkedLegend(linked: true),
            const SizedBox(width: 12),
            _LinkedLegend(linked: false),
          ],
        ]),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 論理式フォーミュラビュー
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _LogicFormulaView extends StatelessWidget {
  final Map<String, dynamic> item;
  final String sheetId;
  final Map<String, _Node> nodeMap;
  final String Function(Map, String, Map<String, _Node>, {bool resolveRemoteLink}) resolveLabel;
  final String Function(dynamic) fmtNum;

  const _LogicFormulaView({
    required this.item,
    required this.sheetId,
    required this.nodeMap,
    required this.resolveLabel,
    required this.fmtNum,
  });

  static const _lhsColor = Color(0xFF5EFFBB);
  static const _rhsColor = Color(0xFFFF9B5E);
  static const _noLinkBg = Color(0xFF1E1E30);
  static const _opColor = Color(0xFF5050A0);

  Widget _term(String text, {required bool linked, required Color linkColor}) {
    if (text == '? (リンクされていません)') {
      linked = false;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: linked ? linkColor.withOpacity(0.15) : _noLinkBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: linked ? linkColor.withOpacity(0.5) : Colors.white12,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (linked) ...[
            Icon(Icons.link, size: 10, color: linkColor.withOpacity(0.9)),
            const SizedBox(width: 3),
          ],
          Text(text,
              style: TextStyle(
                color: linked ? linkColor : Colors.white60,
                fontSize: 11,
                fontWeight: linked ? FontWeight.w600 : FontWeight.normal,
              )),
        ],
      ),
    );
  }

  Widget _small(String t, {Color color = _opColor}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(t, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    bool isLinked(Map src) {
      final sid = src['sheetId'] as String? ?? sheetId;
      final type = src['type'] as String?;
      final String srcId;
      if (type == 'logic') {
        srcId = '${sid}_l${src['logicId']}';
      } else {
        final row = (src['rowIdx'] as num?)?.toInt() ?? 0;
        srcId = '${sid}_c$row';
      }
      return nodeMap.containsKey(srcId);
    }
  
    final conds = (item['conditions'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final chainOps = (item['chainOps'] as List? ?? []).cast<String>();

    final rows = <Widget>[];
    for (int k = 0; k < conds.length; k++) {
      final c = conds[k];
      final lLinked = c['lhsLink'] == true;
      final lSrc = c['lhsLinkSource'] as Map?;
      final lLabel = lLinked && lSrc != null
          ? resolveLabel(lSrc, sheetId, nodeMap, resolveRemoteLink: isLinked(lSrc))
          : fmtNum(c['lhsVal']);

      final rLinked = c['rhsLink'] == true;
      final rSrc = c['rhsLinkSource'] as Map?;
      final rLabel = rLinked && rSrc != null
          ? resolveLabel(rSrc, sheetId, nodeMap, resolveRemoteLink: isLinked(rSrc))
          : fmtNum(c['rhsVal']);

      final condOp = c['op'] as String? ?? '==';

      rows.add(Wrap(
        spacing: 0, runSpacing: 3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _term(lLabel, linked: lLinked, linkColor: _lhsColor),
          _small(condOp),
          _term(rLabel, linked: rLinked, linkColor: _rhsColor),
        ],
      ));

      if (k < conds.length - 1) {
        final chainOp = k < chainOps.length ? chainOps[k] : 'AND';
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 2),
          child: Text(chainOp,
              style: const TextStyle(
                  color: Color(0xFF8080C0),
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ));
      }
    }

    final isTrue = _evalLogic(item);
    final hasLinks = conds.any((c) => c['lhsLink'] == true || c['rhsLink'] == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('条件式',
            style: TextStyle(
                color: Color(0xFFFFAA33),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
        const SizedBox(height: 5),
        ...rows,
        const SizedBox(height: 6),
        Row(children: [
          _small('結果:', color: Colors.white54),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isTrue ? const Color(0xFF0E2A1A) : const Color(0xFF2A0E0E),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: isTrue ? const Color(0xFF2A7A4A) : const Color(0xFF7A2A2A),
                  width: 1),
            ),
            child: Text(isTrue ? '真' : '偽',
                style: TextStyle(
                    color: isTrue ? const Color(0xFF5EFFBB) : const Color(0xFFFF7070),
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
          if (hasLinks)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Text('(保存値で評価)',
                  style: TextStyle(color: Colors.white38, fontSize: 9.5)),
            ),
        ]),
        const SizedBox(height: 5),
        Row(children: [
          _LinkedLegend(linked: true, label: 'リンク値', color: _lhsColor),
          const SizedBox(width: 12),
          _LinkedLegend(linked: false),
        ]),
      ],
    );
  }

  static bool _evalLogic(Map<String, dynamic> item) {
    final conds = (item['conditions'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (conds.isEmpty) return false;
    bool evalOne(Map<String, dynamic> c) {
      final lhs = (c['lhsVal'] as num? ?? 0).toDouble();
      final rhs = (c['rhsVal'] as num? ?? 0).toDouble();
      final op = c['op'] as String? ?? '==';
      switch (op) {
        case '==': return (lhs - rhs).abs() < 1e-10;
        case '!=': return (lhs - rhs).abs() >= 1e-10;
        case '>': return lhs > rhs;
        case '>=': return lhs >= rhs;
        case '<': return lhs < rhs;
        case '<=': return lhs <= rhs;
        case 'between': {
          final rhs2 = (c['rhsVal2'] as num? ?? 0).toDouble();
          return lhs >= rhs && lhs <= rhs2;
        }
        case 'not_between': {
          final rhs2 = (c['rhsVal2'] as num? ?? 0).toDouble();
          return lhs < rhs || lhs > rhs2;
        }
        default: return false;
      }
    }
    final chainOps = (item['chainOps'] as List? ?? []).cast<String>();
    bool result = evalOne(conds[0]);
    for (int i = 1; i < conds.length; i++) {
      final r = evalOne(conds[i]);
      final op = i - 1 < chainOps.length ? chainOps[i - 1] : 'AND';
      if (op == 'OR') result = result || r;
      else if (op == 'XOR') result = result ^ r;
      else result = result && r;
    }
    return result;
  }
}

/// リンク状況の凡例チップ
class _LinkedLegend extends StatelessWidget {
  final bool linked;
  final String? label;
  final Color? color;
  const _LinkedLegend({required this.linked, this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF7B7FFF);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: linked ? c.withOpacity(0.20) : const Color(0xFF1E1E30),
            border: Border.all(
                color: linked ? c.withOpacity(0.55) : Colors.white12),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          linked ? (label ?? 'リンク') : '固定値',
          style: const TextStyle(color: Color(0xFF3A3A5A), fontSize: 9.5),
        ),
      ],
    );
  }
}

class _ConSection extends StatelessWidget {
  final String title;
  final Color accentColor;
  final List<_Edge> edges;
  final List<_Edge> allEdges;
  final Map<String, _Node> nodeMap;
  final bool isIncoming;
  final String Function(Map, String, Map<String, _Node>, {bool resolveRemoteLink}) resolveLabel;
  final String Function(dynamic) fmtNum;

  const _ConSection({
    required this.title,
    required this.accentColor,
    required this.edges,
    required this.allEdges,
    required this.nodeMap,
    required this.isIncoming,
    required this.resolveLabel,
    required this.fmtNum,
  });

  // 計算式のコンパクトな文字列表現（項 op 項 op … = 結果）
  List<String> _formulaTerms(Map<String, dynamic> item, String sid) {
    bool isLinked(Map src) {
      final tid = src['sheetId'] as String? ?? sid;
      final type = src['type'] as String?;
      final String srcId;
      if (type == 'logic') {
        srcId = '${tid}_l${src['logicId']}';
      } else {
        final row = (src['rowIdx'] as num?)?.toInt() ?? 0;
        srcId = '${tid}_c$row';
      }
      return nodeMap.containsKey(srcId);
    }
    String termLabel(bool linked, Map? src, dynamic val) {
      if (linked && src != null) return resolveLabel(src, sid, nodeMap, resolveRemoteLink: isLinked(src));
      final d = (val as num?)?.toDouble() ?? 0.0;
      return d == d.truncateToDouble()
          ? d.truncate().toString()
          : d.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    final terms = <String>[];
    terms.add(termLabel(item['inputLink'] == true, item['inputLinkSource'] as Map?, item['input']));
    terms.add(item['op'] as String? ?? '+');
    terms.add(termLabel(item['operandLink'] == true, item['operandLinkSource'] as Map?, item['operand']));
    for (final o in (item['others'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map))) {
      terms.add(o['op'] as String? ?? '+');
      terms.add(termLabel(o['valLink'] == true, o['valLinkSource'] as Map?, o['val']));
    }
    return terms;
  }

  /// エッジラベルから対象項インデックスを返す（0=項1/入力, 2=項2, 4=項3…）
  static int _labelToTermIdx(String label) {
    // 「入力」は後方互換のため残す
    if (label == '入力') return 0;
    final m = RegExp(r'項(\d+)').firstMatch(label);
    if (m != null) {
      final n = int.parse(m.group(1)!);
      if (n == 1) return 0;           // 入力（第1項）
      if (n == 2) return 2;           // 第2項（operand）
      if (n >= 3) return 4 + (n - 3) * 2; // others[n-3]
    }
    return -1;
  }


  /// エッジラベル（複合ラベル '項1, 項2' も可）に ti が含まれるか
  static bool _isEdgeTarget(String label, int ti) {
    for (final part in label.split(RegExp(r'[,、]\s*'))) {
      if (_labelToTermIdx(part.trim()) == ti) return true;
    }
    return false;
  }

  /// 各項のリンク状態を返す（演算子インデックスは false）
  /// インデックスは _formulaTerms と同じ構造 [term0, op, term1, op, term2, ...]
  static List<bool> _formulaTermLinkStatus(Map<String, dynamic> item) {
    final status = <bool>[];
    status.add(item['inputLink'] == true);
    status.add(false); // op
    status.add(item['operandLink'] == true);
    for (final o in (item['others'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))) {
      status.add(false); // op
      status.add(o['valLink'] == true);
    }
    return status;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セクションタイトル
        Row(
          children: [
            Container(
              width: 3, height: 14,
              margin: const EdgeInsets.only(right: 7),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(title,
                style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3)),
          ],
        ),
        const SizedBox(height: 6),
        ...edges.take(5).map((e) {
          final othId = isIncoming ? e.fromId : e.toId;
          final oth = nodeMap[othId];
          if (oth == null) return const SizedBox.shrink();
          final oc = oth.isLogic
              ? const Color(0xFFFFAA33)
              : const Color(0xFF7B7FFF);

          // 式の項リスト（計算式のみ）
          final terms = oth.isLogic
              ? null
              : _formulaTerms(oth.rawData, oth.sheetId);
          final linkStatuses = (terms != null)
              ? _formulaTermLinkStatus(oth.rawData)
              : null;

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withOpacity(0.18), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ノード名 + エッジラベル
                Row(
                  children: [
                    Container(
                      width: 7, height: 7,
                      margin: const EdgeInsets.only(right: 7),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: oc.withOpacity(0.3),
                          border: Border.all(color: oc, width: 1.3)),
                    ),
                    Expanded(
                      child: Text(oth.label,
                          style: TextStyle(
                              color: accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: accentColor.withOpacity(0.3), width: 0.8)),
                      child: Text(e.label,
                          style: TextStyle(
                              color: accentColor.withOpacity(0.8),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                // シート名
                Padding(
                  padding: const EdgeInsets.only(left: 14, top: 2),
                  child: Text(oth.sheetName,
                      style: const TextStyle(
                          color: Color(0xFF3A3A5A), fontSize: 10)),
                ),
                // 式（計算式の場合のみ）
                if (terms != null && terms.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int ti = 0; ti < terms.length; ti++)
                          if (ti.isOdd)
                            // 演算子
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(terms[ti],
                                  style: const TextStyle(
                                      color: Color(0xFF5050A0),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            )
                          else
                            // 値チップ
                            // リンク設定済みの項 OR 参照先でエッジラベル指定の項 → 色付け
                            Builder(builder: (_) {
                              // 参照先セクション: このノードのデータを受け取る項をハイライト
                              final isHighlighted =
                                  !isIncoming && _isEdgeTarget(e.label, ti);
                              // 参照元セクション: ソースノード自身のリンク項を緑で示す
                              // （isHighlighted が true の場合は accentColor を優先）
                              final isLinked = !isHighlighted &&
                                  (linkStatuses != null &&
                                      ti < linkStatuses.length &&
                                      linkStatuses[ti]);
                              const linkColor = Color(0xFF5EFFBB); // 参照元色（緑）
                              final Color? chipColor = isHighlighted
                                  ? accentColor
                                  : (isLinked ? linkColor : null);
                              return Container(
                                margin: const EdgeInsets.only(right: 1),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: chipColor != null
                                      ? chipColor.withOpacity(0.15)
                                      : const Color(0xFF1A1A2A),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: chipColor != null
                                        ? chipColor.withOpacity(0.45)
                                        : Colors.white10,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (chipColor != null) ...[
                                      Icon(Icons.link,
                                          size: 9,
                                          color: chipColor.withOpacity(0.9)),
                                      const SizedBox(width: 3),
                                    ],
                                    Text(terms[ti],
                                        style: TextStyle(
                                            color: chipColor ?? Colors.white38,
                                            fontSize: 10,
                                            fontWeight: chipColor != null
                                                ? FontWeight.w600
                                                : FontWeight.normal)),
                                  ],
                                ),
                              );
                            }),
                        // 結果（色なし）
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('=',
                              style: TextStyle(
                                  color: Color(0xFF5050A0),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                        Builder(builder: (_) {
                          final r = _calcLinkedResult(
                              oth.rawData, oth.sheetId, nodeMap);
                          final resultStr = r.isNaN ? '÷0' : r.isInfinite ? '∞' : fmtNum(r);
                          // 答え自身がこのノード（あるいは他ノード）に参照されているか
                          // 参照元リスト（isIncoming == true）の場合、othの答えが自ノードに供給されているのでハイライトする
                          final isHighlighted = isIncoming;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isHighlighted
                                  ? accentColor.withOpacity(0.15)
                                  : const Color(0xFF1A1A2A),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: isHighlighted
                                    ? accentColor.withOpacity(0.45)
                                    : Colors.white10,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isHighlighted) ...[
                                  Icon(Icons.call_made,
                                      size: 9,
                                      color: accentColor.withOpacity(0.9)),
                                  const SizedBox(width: 3),
                                ],
                                Text(
                                  resultStr,
                                  style: TextStyle(
                                      color: isHighlighted
                                          ? accentColor
                                          : Colors.white38,
                                      fontSize: 10,
                                      fontWeight: isHighlighted
                                          ? FontWeight.w600
                                          : FontWeight.normal),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                // 論理式の場合
                if (oth.isLogic) ...[
                  const SizedBox(height: 4),
                  Text('条件式 (${(oth.rawData['conditions'] as List? ?? []).length} 条件)',
                      style: const TextStyle(
                          color: Color(0xFFFFAA33), fontSize: 10)),
                ],
              ],
            ),
          );
        }),
        if (edges.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('他 ${edges.length - 5} 件…',
                style: const TextStyle(
                    color: Color(0xFF3A3A5A), fontSize: 11)),
          ),
      ],
    );
  }
}

