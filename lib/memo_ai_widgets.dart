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
    canvas.drawLine(
      const Offset(28, 0),
      Offset(28, size.height),
      marginPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PaperPainter old) => old.isDark != isDark;
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
                      : (isDark ? Colors.white70 : Colors.black.withOpacity(0.7)),
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
  final Future<int?> Function(Uint8List imageBytes, String instruction) onCount;

  const _AiCountPage({required this.onCount});

  @override
  State<_AiCountPage> createState() => _AiCountPageState();
}

class _AiCountPageState extends State<_AiCountPage> {
  Uint8List? _imageBytes;
  bool _isCounting = false;
  int? _lastCount;
  final _instructionCtrl = TextEditingController();
  final _picker = ImagePicker();

  @override
  void dispose() {
    _instructionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final Permission perm =
        source == ImageSource.camera ? Permission.camera : Permission.photos;
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
          action: SnackBarAction(
            label: '設定を開く',
            onPressed: openAppSettings,
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _lastCount = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像の取得に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _runCount() async {
    final instruction = _instructionCtrl.text.trim();
    if (instruction.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('何を数えるか入力してください。')),
      );
      return;
    }
    if (_imageBytes == null) return;

    setState(() => _isCounting = true);
    try {
      final count = await widget.onCount(_imageBytes!, instruction);
      if (!mounted) return;
      setState(() => _lastCount = count);
      if (count == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('数字を読み取れませんでした。別の指示を試してください。'),
            backgroundColor: Colors.deepOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCounting = false);
    }
  }

  void _showSourcePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.camera_alt, color: Colors.tealAccent),
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
              leading:
                  const Icon(Icons.photo_library, color: Colors.tealAccent),
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: const Row(
          children: [
            Icon(Icons.camera_alt_outlined, color: Colors.tealAccent, size: 18),
            SizedBox(width: 8),
            Text(
              'AIカウント',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        actions: [
          if (_lastCount != null)
            TextButton.icon(
              onPressed: () => Navigator.pop(context, _lastCount),
              icon: const Icon(
                Icons.check_circle,
                color: Colors.tealAccent,
                size: 18,
              ),
              label: Text(
                '${_lastCount} を反映',
                style: const TextStyle(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 画像エリア
          Expanded(
            child: _imageBytes == null
                ? _buildPickerArea()
                : _buildImageArea(),
          ),
          // 指示入力バー（画像選択後に表示）
          if (_imageBytes != null) _buildInstructionBar(),
        ],
      ),
    );
  }

  Widget _buildPickerArea() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_search,
            color: Colors.white24,
            size: 72,
          ),
          const SizedBox(height: 20),
          const Text(
            '画像を選択してください',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.tealAccent.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.tealAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.tealAccent, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 画像表示
        Image.memory(_imageBytes!, fit: BoxFit.contain),

        // カウント結果バッジ
        if (_lastCount != null)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Text(
                  '${_lastCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),

        // カウント中オーバーレイ
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
                    'AIが解析中...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

        // 写真変更ボタン
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _isCounting ? null : _showSourcePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
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

  Widget _buildInstructionBar() {
    return Container(
      color: const Color(0xFF0D0D1A),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _instructionCtrl,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.send,
                onSubmitted: _isCounting ? null : (_) => _runCount(),
                decoration: InputDecoration(
                  hintText: '何を数えますか？（例: 人の数）',
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
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isCounting ? null : _runCount,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isCounting
                      ? Colors.teal.withOpacity(0.3)
                      : Colors.teal,
                  shape: BoxShape.circle,
                ),
                child: _isCounting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 22,
                      ),
              ),
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
  const _MemoEditDialog({required this.initialText});

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
    final newText = text.replaceRange(start, end, val);
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + val.length),
    );
  }

  double _evalCalcSimple(double a, String op, double b) {
    switch (op) {
      case '+': return a + b;
      case '-': return a - b;
      case '×': return a * b;
      case '÷': return b != 0 ? a / b : 0;
      default: return a;
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
          if (allTerms.length == effectiveOps.length + 1 && allTerms.length >= 2) {
            result = allTerms[0];
            for (int i = 0; i < effectiveOps.length; i++) {
              result = _evalCalcSimple(result, effectiveOps[i], allTerms[i + 1]);
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

  Widget _buildCalcPanel() {
    const textColor = Colors.white;
    final keyBg = Colors.white.withOpacity(0.1);
    const opColor = Colors.blueAccent;
    const eqColor = Colors.orangeAccent;
    const keyFontSize = 26.0;
    const displayFontSize = 44.0;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        // 挿入ボタン
        AnimatedOpacity(
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
        // 表示エリア
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          //height: 82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
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
                    fontWeight: FontWeight.bold,
                    height: 0.8,
                  ),
                  textAlign: TextAlign.right,
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
            calcKey('C', bg: Colors.redAccent.withOpacity(0.18), fg: Colors.redAccent),
            calcKey('+/-'),
            calcKey('%'),
            calcKey('÷', bg: opColor.withOpacity(0.18), fg: opColor),
            calcKey('7'), calcKey('8'), calcKey('9'),
            calcKey('×', bg: opColor.withOpacity(0.18), fg: opColor),
            calcKey('4'), calcKey('5'), calcKey('6'),
            calcKey('-', bg: opColor.withOpacity(0.18), fg: opColor),
            calcKey('1'), calcKey('2'), calcKey('3'),
            calcKey('+', bg: opColor.withOpacity(0.18), fg: opColor),
            calcKey('⌫'),
            calcKey('0'),
            calcKey('.'),
            calcKey('=', bg: eqColor.withOpacity(0.8), fg: Colors.white),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            // タイトル
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: const [
                  Icon(Icons.sticky_note_2_outlined, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Text('メモを編集', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // スクロール可能なコンテンツ
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ctrl,
                      autofocus: false,
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
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.amber),
                        ),
                      ),
                    ),
                    _buildCalcPanel(),
                  ],
                ),
              ),
            ),
            // アクションバー
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
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
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
