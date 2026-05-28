part of 'widget_page.dart';

// ── 紙のライン背景ペインター ──
class _PaperPainter extends CustomPainter {
  final bool isDark;
  const _PaperPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = isDark
          ? Colors.white.withOpacity(0.045)
          : Colors.black.withOpacity(0.055)
      ..strokeWidth = 0.6;
    const lineSpacing = 26.0;
    const topOffset = 16.0;
    double y = topOffset;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      y += lineSpacing;
    }
    // 左マージン線
    final marginPaint = Paint()
      ..color = isDark
          ? Colors.blueAccent.withOpacity(0.12)
          : Colors.redAccent.withOpacity(0.12)
      ..strokeWidth = 1.0;
    canvas.drawLine(const Offset(28, 0), Offset(28, size.height), marginPaint);
  }

  @override
  bool shouldRepaint(covariant _PaperPainter old) => old.isDark != isDark;
}

// ── スタンドアロンメモ行ウィジェット（並び替え可能） ──
class _StandaloneMemoRow extends StatelessWidget {
  final String text;
  final bool isDark;
  final void Function(String) onUpdate;
  final VoidCallback onDelete;
  final Widget? dragHandle;

  const _StandaloneMemoRow({
    required this.text,
    required this.isDark,
    required this.onUpdate,
    required this.onDelete,
    this.dragHandle,
  });

  void _showEditDialog(BuildContext context) {
    showDialog<String?>(
      context: context,
      builder: (ctx) => _MemoEditDialog(initialText: text),
    ).then((result) {
      if (result == null) return;
      onUpdate(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final empty = text.trim().isEmpty;
    return GestureDetector(
      onTap: () => _showEditDialog(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.tealAccent.withOpacity(0.06)
              : Colors.teal.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? Colors.tealAccent.withOpacity(0.22)
                : Colors.teal.withOpacity(0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dragHandle != null) ...[dragHandle!, const SizedBox(width: 4)],
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.notes_rounded,
                size: 14,
                color: Colors.tealAccent.withOpacity(0.8),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                empty ? 'メモ（タップして編集）' : text,
                style: TextStyle(
                  color: empty
                      ? (isDark ? Colors.white24 : Colors.black26)
                      : (isDark
                            ? Colors.white70
                            : Colors.black.withOpacity(0.7)),
                  fontSize: 13,
                  fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDelete,
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: Colors.redAccent.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── メモ行ウィジェット ──
class _MemoRowWidget extends StatelessWidget {
  final String text;
  final bool isDark;
  final void Function(String) onUpdate;
  final VoidCallback onDelete;

  const _MemoRowWidget({
    super.key,
    required this.text,
    required this.isDark,
    required this.onUpdate,
    required this.onDelete,
  });

  void _showEditDialog(BuildContext context) {
    showDialog<String?>(
      context: context,
      builder: (ctx) => _MemoEditDialog(initialText: text),
    ).then((result) {
      if (result == null) return;
      onUpdate(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final empty = text.trim().isEmpty;
    return GestureDetector(
      onTap: () => _showEditDialog(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.amber.withOpacity(0.06)
              : Colors.amber.withOpacity(0.09),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? Colors.amber.withOpacity(0.2)
                : Colors.amber.withOpacity(0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.sticky_note_2_outlined,
                size: 14,
                color: Colors.amber.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                empty ? 'メモ（タップして編集）' : text,
                style: TextStyle(
                  color: empty
                      ? (isDark ? Colors.white24 : Colors.black26)
                      : (isDark
                            ? Colors.white70
                            : Colors.black.withOpacity(0.7)),
                  fontSize: 13,
                  fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDelete,
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: Colors.redAccent.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── AIカウント専用ページ ──
class _AiCountPage extends StatefulWidget {
  final Future<AiCountResult?> Function(
    Uint8List imageBytes,
    String instruction,
  )
  onCount;

  const _AiCountPage({required this.onCount});

  @override
  State<_AiCountPage> createState() => _AiCountPageState();
}

class _AiCountPageState extends State<_AiCountPage> {
  Uint8List? _imageBytes;
  double _imageWidth = 1.0;
  double _imageHeight = 1.0;
  bool _isCounting = false;
  bool _showMarkers = true;
  AiCountResult? _lastResult;
  final _labelCtrl = TextEditingController();
  final _picker = ImagePicker();

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final Permission perm = source == ImageSource.camera
        ? Permission.camera
        : Permission.photos;
    final status = await perm.request();
    if (!mounted) return;
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'カメラのアクセス許可が必要です。'
                : '写真へのアクセス許可が必要です。',
          ),
          action: SnackBarAction(label: '設定を開く', onPressed: openAppSettings),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final decodedImage = await decodeImageFromList(bytes);
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageWidth = decodedImage.width.toDouble();
        _imageHeight = decodedImage.height.toDouble();
        _lastResult = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('画像の取得に失敗しました: $e')));
      }
    }
  }

  // ── OpenRouter LLM でカウント ──
  Future<void> _runLlmCount() async {
    final instruction = _labelCtrl.text.trim();
    if (instruction.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('何を数えるか入力してください。')));
      return;
    }
    if (_imageBytes == null) return;

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

    setState(() {
      _isCounting = true;
      _lastResult = null;
    });
    try {
      final result = await widget.onCount(_imageBytes!, instruction);
      if (!mounted) return;
      setState(() => _lastResult = result);
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('数字を読み取れませんでした。別の指示を試してください。'),
            backgroundColor: Colors.deepOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCounting = false);
    }
  }

  void _showSourcePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.tealAccent),
              title: const Text(
                'カメラで撮影',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Colors.tealAccent,
              ),
              title: const Text(
                'ギャラリーから選択',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isCounting;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: const Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: Colors.tealAccent,
              size: 18,
            ),
            SizedBox(width: 8),
            Text('AIカウント', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        actions: [if (_lastResult != null) ...[]],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D1A), Color.fromARGB(255, 38, 38, 38)],
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: _imageBytes == null
                  ? _buildPickerArea()
                  : _buildImageArea(),
            ),
            if (_imageBytes != null) _buildInstructionBar(isBusy),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerArea() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_search, color: Colors.white30, size: 150),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: const Text(
                '画像を選択してください。AIが画像を解析して、指定した対象の数をカウントします。',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSourceButton(
                  icon: Icons.camera_alt,
                  label: 'カメラ',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: 20),
                _buildSourceButton(
                  icon: Icons.photo_library,
                  label: 'ギャラリー',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        width: 100,
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.30),
          border: Border.all(color: Colors.tealAccent.withOpacity(0.4)),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.tealAccent, size: 32),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.tealAccent, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final double viewWidth = constraints.maxWidth;
            final double viewHeight = constraints.maxHeight;

            return InteractiveViewer(
              maxScale: 5.0,
              minScale: 0.5,
              boundaryMargin: const EdgeInsets.all(40),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewHeight),
                child: Center(
                  child: SizedBox(
                    width: viewWidth,
                    child: AspectRatio(
                      aspectRatio: _imageWidth / _imageHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(_imageBytes!, fit: BoxFit.fill),
                          if (_showMarkers &&
                              _lastResult != null &&
                              _lastResult!.points.isNotEmpty)
                            _MarkerOverlay(
                              points: _lastResult!.points,
                              imageBytes: _imageBytes!,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (_lastResult != null)
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(8),
              ),
              icon: Icon(
                _showMarkers ? Icons.visibility : Icons.visibility_off,
                color: Colors.white,
              ),
              onPressed: () => setState(() => _showMarkers = !_showMarkers),
              tooltip: 'マーカーの表示/非表示',
            ),
          ),

        // カウント結果バッジ
        if (_lastResult != null && _showMarkers)
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_lastResult!.count}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 46,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, _lastResult!.count),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      icon: const Icon(
                        Icons.check_circle,
                        color: Colors.teal,
                        size: 18,
                      ),
                      label: Text(
                        '${_lastResult!.count} を反映',
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 処理中オーバーレイ
        if (_isCounting)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.tealAccent),
                  SizedBox(height: 16),
                  Text(
                    'AIが画像を解析中...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

        // 写真変更ボタン
        Positioned(
          bottom: 18,
          right: 20,
          left: 20,
          child: GestureDetector(
            onTap: _isCounting ? null : _showSourcePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh, color: Colors.white70, size: 14),
                  SizedBox(width: 4),
                  Text(
                    '写真を変更',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionBar(bool isBusy) {
    return Container(
      color: const Color(0xFF0D0D1A),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 説明テキスト
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.tealAccent,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'カウント対象を入力して、AIに画像を解析させましょう。',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                // 入力フィールド
                Expanded(
                  child: TextField(
                    controller: _labelCtrl,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.done,
                    onSubmitted: isBusy ? null : (_) => _runLlmCount(),
                    decoration: InputDecoration(
                      hintText: '何を数えますか？（例：人、ボルト、箱）',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.07),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // カウントボタン（メインアクション）
                GestureDetector(
                  onTap: isBusy ? null : _runLlmCount,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isBusy
                          ? Colors.teal.withOpacity(0.3)
                          : Colors.teal,
                      shape: BoxShape.circle,
                      boxShadow: isBusy
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.teal.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: _isCounting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── メモ編集ダイアログ（電卓付き） ──
class _MemoEditDialog extends StatefulWidget {
  final String initialText;
  final String title;
  final String saveLabel;
  const _MemoEditDialog({
    required this.initialText,
    this.title = 'メモを編集',
    this.saveLabel = '保存',
  });

  @override
  State<_MemoEditDialog> createState() => _MemoEditDialogState();
}

class _MemoEditDialogState extends State<_MemoEditDialog> {
  late final TextEditingController _ctrl;
  // ── 電卓ステート ──
  String _calcDisplay = '0';
  double? _calcA;
  String _calcOp = '';
  bool _calcNewEntry = true;
  bool _calcHasResult = false;
  String _calcExprStr = '';
  List<double> _calcTermValues = [];
  List<String> _calcTermOps = [];
  bool _isClearState = true;
  bool _isAiCounting = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _insertCalcValue() {
    if (!_calcHasResult) return;
    final val = _calcExprStr.isNotEmpty ? _calcExprStr : _calcDisplay;
    if (val.isEmpty || val == '0') return;
    final sel = _ctrl.selection;
    final text = _ctrl.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    // 挿入位置の直前が改行でなければ改行を追加
    final needsNewline = start > 0 && text[start - 1] != '\n';
    final insert = needsNewline ? '\n$val' : val;
    final newText = text.replaceRange(start, end, insert);
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
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
    if (v.abs() < 1e-15 || v.abs() >= 1e15) return v.toString();
    String s = v.toStringAsFixed(15);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  void _onCalcKey(String key) {
    setState(() {
      if (key == 'C' || key == 'AC') {
        if (_calcDisplay == '0' || key == 'AC') {
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
            allTerms = List<double>.from(_calcTermValues);
            effectiveOps = List<String>.from(_calcTermOps)..removeLast();
          } else {
            final b = double.tryParse(_calcDisplay) ?? 0;
            allTerms = List<double>.from(_calcTermValues)..add(b);
            effectiveOps = List<String>.from(_calcTermOps);
          }
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
          if (_calcDisplay != '0' || _calcA != null) {
            _calcHasResult = true;
          }
        }
      } else if (['+', '-', '×', '÷'].contains(key)) {
        _isClearState = true;
        if (!_calcNewEntry || _calcA == null) {
          final currentVal = double.tryParse(_calcDisplay) ?? 0;
          if (_calcTermValues.isEmpty) {
            _calcTermValues.add(currentVal);
          } else if (!_calcNewEntry) {
            _calcTermValues.add(currentVal);
          }
          _calcTermOps.add(key);
          _calcA = currentVal;
          // 複数項がある場合、そこまでの計算結果を表示
          if (_calcTermValues.length >= 2) {
            double runningResult = _calcTermValues[0];
            for (int i = 0; i + 1 < _calcTermValues.length; i++) {
              runningResult = _evalCalcSimple(
                runningResult,
                _calcTermOps[i],
                _calcTermValues[i + 1],
              );
            }
            _calcDisplay = _fmtCalc(runningResult);
            _calcA = runningResult;
          }
        } else if (_calcOp.isNotEmpty) {
          if (_calcTermOps.isNotEmpty) {
            _calcTermOps[_calcTermOps.length - 1] = key;
          }
          _calcOp = key;
          return;
        } else {
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
        _isClearState = false;
        if (_calcNewEntry || _calcDisplay == '0') {
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

  void _showAiCountDialog() async {
    final ai = GemmaAi();
    setState(() => _isAiCounting = true);
    final count = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => _AiCountPage(onCount: ai.countInImage),
      ),
    );
    if (!mounted) return;
    setState(() {
      _isAiCounting = false;
      if (count != null) {
        _calcDisplay = count.toString();
        _calcNewEntry = true;
        _calcHasResult = false;
        _isClearState = false;
        _calcA = null;
        _calcOp = '';
        _calcTermValues = [];
        _calcTermOps = [];
        _calcExprStr = '';
      }
    });
  }

  void _showCalcHistory() async {
    final entries = await CalcHistoryManager.instance.loadAll();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CalcHistorySheet(
        entries: entries,
        isDark: true,
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
        addMultipleLabel: 'メモに挿入',
        onAddMultiple: (selectedEntries) {
          Navigator.pop(ctx);
          final sb = StringBuffer();
          for (final e in selectedEntries) {
            if (sb.isNotEmpty) sb.write('\n');
            sb.write('${e.expression} = ${e.result}');
          }
          final insertText = sb.toString();
          final sel = _ctrl.selection;
          final text = _ctrl.text;
          final start = sel.isValid ? sel.start : text.length;
          final end = sel.isValid ? sel.end : text.length;
          final needsNewline = start > 0 && text[start - 1] != '\n';
          final insert = needsNewline ? '\n$insertText' : insertText;
          final newText = text.replaceRange(start, end, insert);
          setState(() {
            _ctrl.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: start + insert.length),
            );
          });
        },
      ),
    );
  }

  Widget _buildCalcPanel() {
    const textColor = Colors.white;
    final keyBg = Colors.white.withOpacity(0.1);
    const opColor = Colors.blueAccent;
    const eqColor = Colors.orangeAccent;
    const keyFontSize = 26.0;
    const displayFontSize = 64.0;
    const subtitleFontSize = 16.0;

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

    return SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const SizedBox(height: 8),
            // カメラ・履歴ボタンと挿入ボタンを横並びに
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // AIカウントアイコン
                GestureDetector(
                  onTap: _isAiCounting ? null : _showAiCountDialog,
                  child: AnimatedOpacity(
                    opacity: _isAiCounting ? 0.4 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.45),
                          width: 0.8,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.black,
                            size: 16,
                          ),
                          if (_isAiCounting)
                            const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.tealAccent,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 履歴アイコン
                GestureDetector(
                  onTap: _showCalcHistory,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 0.8,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 挿入ボタン
                Expanded(
                  child: AnimatedOpacity(
                    opacity: _calcHasResult ? 1.0 : 0.3,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: _calcHasResult ? _insertCalcValue : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _calcHasResult
                              ? Colors.blueAccent
                              : Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                _calcHasResult && _calcExprStr.isNotEmpty
                                    ? _calcExprStr
                                    : 'メモに挿入',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 表示エリア
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              height: 82,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 数値・式表示エリア
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (subtitle.isNotEmpty)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                color: textColor.withOpacity(0.45),
                                fontSize: subtitleFontSize,
                              ),
                            ),
                          ),
                        FittedBox(
                          child: Text(
                            _calcDisplay,
                            maxLines: 1,
                            style: const TextStyle(
                              color: textColor,
                              fontSize: displayFontSize,
                              fontWeight: FontWeight.w200,
                              height: 0.8,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              padding: EdgeInsets.zero,
              crossAxisCount: 4,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              childAspectRatio: 1.15,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                calcKey(
                  'C',
                  bg: Colors.redAccent.withOpacity(0.18),
                  fg: Colors.redAccent,
                ),
                calcKey('+/-'),
                calcKey('%'),
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
                calcKey('⌫'),
                calcKey('0'),
                calcKey('.'),
                calcKey('=', bg: eqColor.withOpacity(0.8), fg: Colors.white),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            //  height: MediaQuery.of(context).size.height * 0.95,
            child: Column(
              children: [
                // タイトル
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.sticky_note_2_outlined,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                // スクロール可能なコンテンツ
                const SizedBox(height: 12),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  maxLines: 5,
                  minLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'メモを入力...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.amber),
                    ),
                  ),
                ),
                // アクションバー
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        child: const Text(
                          'キャンセル',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final t = _ctrl.text;
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(context).pop(t);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                        ),
                        child: Text(widget.saveLabel),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                _buildCalcPanel(),
                SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── マーカーオーバーレイ ──
class _MarkerOverlay extends StatelessWidget {
  final List<List<double>> points;
  final Uint8List imageBytes;

  const _MarkerOverlay({required this.points, required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _MarkerPainter(points),
        );
      },
    );
  }
}

class _MarkerPainter extends CustomPainter {
  final List<List<double>> points;
  _MarkerPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final center = Offset(p[0] * size.width, p[1] * size.height);

      // 影
      canvas.drawCircle(center + const Offset(1, 1), 6, shadowPaint);
      // 白枠
      canvas.drawCircle(center, 6, borderPaint);
      // 赤丸
      canvas.drawCircle(center, 5, dotPaint);

      // 番号描画 (Chain of Thought に対応)
      final textSpan = TextSpan(
        text: '${i + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarkerPainter old) => old.points != points;
}
