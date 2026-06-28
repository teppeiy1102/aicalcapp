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
    final l10n = AppLocalizations.of(context)!;
    showDialog<String?>(
      context: context,
      builder: (ctx) => _MemoEditDialog(
        initialText: text,
        title: l10n.editMemoTitle,
        saveLabel: l10n.memoEditSave,
      ),
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
                empty ? AppLocalizations.of(context)!.memoEmptyHint : text,
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
    final l10n = AppLocalizations.of(context)!;
    showDialog<String?>(
      context: context,
      builder: (ctx) => _MemoEditDialog(
        initialText: text,
        title: l10n.editMemoTitle,
        saveLabel: l10n.memoEditSave,
      ),
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
                empty ? AppLocalizations.of(context)!.memoEmptyHint : text,
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
  int? _remainingUses;

  @override
  void initState() {
    super.initState();
    _loadRemainingUses();
  }

  Future<void> _loadRemainingUses() async {
    final uses = await RevenueCatService.getRemainingUses();
    if (mounted) setState(() => _remainingUses = uses);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.gallery &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      // Androidのギャラリー選択ではPhoto Pickerを使用するため、権限リクエストをスキップ
    } else {
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
                  ? AppLocalizations.of(context)!.cameraPermissionRequired
                  : AppLocalizations.of(context)!.galleryPermissionRequired,
            ),
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.openSettings,
              onPressed: openAppSettings,
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
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
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.imagePickFailed(e))));
      }
    }
  }

  // ── OpenRouter LLM でカウント ──
  Future<void> _runLlmCount() async {
    final instruction = _labelCtrl.text.trim();
    if (instruction.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.enterCountInstruction)));
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
            title: Text(
              AppLocalizations.of(context)!.aiPurchaseRequired,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            content: Text(
              AppLocalizations.of(context)!.aiPurchaseRequiredDesc,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context)!.cancel, style: const TextStyle(color: Colors.white54)),
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
                child: Text(AppLocalizations.of(context)!.goToStore),
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
          SnackBar(
            content: Text(AppLocalizations.of(context)!.countReadFailed),
            backgroundColor: Colors.deepOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorOccurred(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _isCounting = false);
    }
  }

  Future<void> _detectAndListObjects() async {
    if (_imageBytes == null) return;
    setState(() {
      _isCounting = true;
      _lastResult = null;
    });

    try {
      // AIクレジットを消費してから検出を行う
      final canUse = await RevenueCatService.consumeUse();
      if (!canUse) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: Text(
              AppLocalizations.of(context)!.aiPurchaseRequired,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            content: Text(
              AppLocalizations.of(context)!.aiPurchaseRequiredDesc,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context)!.cancel, style: const TextStyle(color: Colors.white54)),
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
                child: Text(AppLocalizations.of(context)!.goToStore),
              ),
            ],
          ),
        );
        if (mounted) setState(() => _isCounting = false);
        return;
      }

      final prompt = 'この画像に写っている主要なオブジェクト（物体）の名称を、カンマ区切りでリストアップしてください。できるだけ多くの対象を列挙し、不要な説明や箇条書きの記号は省き、必ず名称のみを日本語でカンマ区切りで出力してください。';
      final resultText = await GemmaAi().queryWithImage(
        prompt,
        _imageBytes!,
        systemPrompt: "You are an object detector.",
      );
      if (!mounted) return;
      
      final objects = resultText
          .split(RegExp(r'[,、\n]'))
          .map((e) => e.replaceAll(RegExp(r'^[-・* ]+|[-・* ]+$'), '').trim()) // remove markdown list dashes or stars
          .where((e) => e.isNotEmpty && e != 'なし')
          .toList();

      if (objects.isEmpty) {
        throw Exception('対象が見つかりませんでした。');
      }

      final selected = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFF1E1E2E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(AppLocalizations.of(context)!.selectObjectToCount, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: objects.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(objects[index], style: const TextStyle(color: Colors.white)),
                      leading: const Icon(Icons.check_circle_outline, color: Colors.tealAccent),
                      onTap: () {
                        Navigator.pop(ctx, objects[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

      if (selected != null && mounted) {
        // 選択されたアイテムはテキストフィールドに入力するだけ
        _labelCtrl.text = selected;
        setState(() => _isCounting = false);
      } else {
        if (mounted) setState(() => _isCounting = false);
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isCounting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorOccurred(e.toString()))),
        );
      }
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
            if (_remainingUses != null)
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StorePage()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: Colors.tealAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context)!.remainingUsesFormat(_remainingUses!),
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.tealAccent),
              title: Text(
                AppLocalizations.of(context)!.takePhoto,
                style: const TextStyle(color: Colors.white),
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
              title: Text(
                AppLocalizations.of(context)!.chooseFromGallery,
                style: const TextStyle(color: Colors.white),
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
        title: Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.tealAccent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.aiCountTitle, style: const TextStyle(color: Colors.white, fontSize: 16)),
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
            if (_remainingUses != null)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StorePage()),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(top: 24, bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.tealAccent.withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: Colors.tealAccent,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context)!.remainingUsesFormat(_remainingUses!),
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Text(
                AppLocalizations.of(context)!.selectImageDesc,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSourceButton(
                  icon: Icons.camera_alt,
                  label: AppLocalizations.of(context)!.cameraLabel,
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: 20),
                _buildSourceButton(
                  icon: Icons.photo_library,
                  label: AppLocalizations.of(context)!.galleryLabel,
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
                backgroundColor: Colors.teal.withOpacity(0.8),
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(8),
              ),
              icon: Icon(
                _showMarkers ? Icons.visibility : Icons.visibility_off,
                color: Colors.white,
              ),
              onPressed: () => setState(() => _showMarkers = !_showMarkers),
              tooltip: AppLocalizations.of(context)!.markerToggle,
            ),
          ),

        // カウント結果バッジ
        if (_lastResult != null && _showMarkers)
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
  padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 16,
                    ),
                  ],
                ),


                      child: Text(
                        '${_lastResult!.count}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 46,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                        AppLocalizations.of(context)!.reflectToCalc,
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
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.tealAccent),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.aiImageAnalyzing,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
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
              constraints: const BoxConstraints(minWidth: 140),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh, color: Colors.red, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context)!.changePhoto,
                    style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
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
                    AppLocalizations.of(context)!.countTargetInstruction,
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
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.done,
                    onSubmitted: isBusy ? null : (_) => _runLlmCount(),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.countHintText,
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
                  onTap: isBusy ? null : (_labelCtrl.text.isNotEmpty ? _runLlmCount : null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isBusy
                          ? Colors.teal.withOpacity(0.3)
                          :_labelCtrl.text.isEmpty ? Colors.grey.withOpacity(1) : Colors.teal,
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
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isBusy ? null : _detectAndListObjects,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.withOpacity(0.2),
                  foregroundColor: Colors.tealAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                icon: const Icon(Icons.list_alt, size: 20),
                label: Text(
                  AppLocalizations.of(context)!.listObjectsFromImage,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
  final String title;
  final String saveLabel;
  const _MemoEditDialog({
    required this.initialText,
    this.title = 'editMemoTitle',
    this.saveLabel = 'save',
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
    int intDigits = v.abs() >= 1 ? v.abs().toInt().toString().length : 0;
    int decDigits = (10 - intDigits).clamp(0, 10);
    String s = v.toStringAsFixed(decDigits);
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
          final displayExprParts = exprParts.map((p) => double.tryParse(p) != null ? _addCommas(p) : p).toList();
          _calcExprStr = '${displayExprParts.join(' ')} = ${_addCommas(_fmtCalc(result))}';
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
            _calcExprStr = '${entry.expression.split(' ').map((p) => double.tryParse(p) != null ? _addCommas(p) : p).join(' ')} = ${_addCommas(entry.result)}';
          });
        },
        onClear: () {
          CalcHistoryManager.instance.clearAll();
          Navigator.pop(ctx);
        },
        addMultipleLabel: AppLocalizations.of(context)!.insertToMemo,
        onAddMultiple: (selectedEntries) {
          Navigator.pop(ctx);
          final sb = StringBuffer();
          for (final e in selectedEntries) {
            if (sb.isNotEmpty) sb.write('\n');
            sb.write('${e.expression.split(' ').map((p) => double.tryParse(p) != null ? _addCommas(p) : p).join(' ')} = ${_addCommas(e.result)}');
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

  /// 演算子ポップアップメニュー（メモ電卓用）
  void _pickCalcOp(int opIndex, Offset globalPos) async {
    const ops = ['+', '-', '×', '÷'];
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(globalPos, globalPos),
      Offset.zero & overlay.size,
    );
    final String? selectedOp = await showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF2A2A32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: ops.map((o) => PopupMenuItem<String>(
        value: o,
        child: Center(child: Text(o, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
      )).toList(),
    );
    if (selectedOp != null) {
      setState(() {
        _calcTermOps[opIndex] = selectedOp;
        double r = _calcTermValues[0];
        for (int i = 0; i + 1 < _calcTermValues.length; i++) {
          r = _evalCalcSimple(r, _calcTermOps[i], _calcTermValues[i + 1]);
        }
        _calcDisplay = _fmtCalc(r);
        final ep = <String>[];
        for (int i = 0; i < _calcTermValues.length; i++) {
          ep.add(_fmtCalc(_calcTermValues[i]));
          if (i < _calcTermOps.length) ep.add(_calcTermOps[i]);
        }
        final dp = ep.map((p) { final v = double.tryParse(p); return v != null ? _addCommas(p) : p; }).toList();
        if (_calcHasResult) _calcExprStr = '${dp.join(' ')} = ${_addCommas(_fmtCalc(r))}';
      });
    }
  }

  /// 電卓の値をアラートで編集（メモ電卓用）
  void _editCalcTermValue(int index) {
    final currentVal = _calcTermValues[index];
    final text = _fmtCalc(currentVal);
    final ctrl = TextEditingController(text: text);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
        });
        return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(context)!.editValue, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl, autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          style: const TextStyle(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.numberInputHint, hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true, fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.cancel, style: TextStyle(color: Colors.grey.shade500))),
          TextButton(
            onPressed: () {
              final newVal = double.tryParse(ctrl.text.replaceAll(',', '')) ?? currentVal;
              setState(() {
                _calcTermValues[index] = newVal;
                double r = _calcTermValues[0];
                for (int i = 0; i + 1 < _calcTermValues.length; i++) { r = _evalCalcSimple(r, _calcTermOps[i], _calcTermValues[i + 1]); }
                _calcDisplay = _fmtCalc(r);
                final ep = <String>[];
                for (int i = 0; i < _calcTermValues.length; i++) { ep.add(_fmtCalc(_calcTermValues[i])); if (i < _calcTermOps.length) ep.add(_calcTermOps[i]); }
                final dp = ep.map((p) { final v = double.tryParse(p); return v != null ? _addCommas(p) : p; }).toList();
                if (_calcHasResult) _calcExprStr = '${dp.join(' ')} = ${_addCommas(_fmtCalc(r))}';
              });
              Navigator.pop(ctx);
            },
            child:  Text(AppLocalizations.of(context)!.save, style: TextStyle(color: Color(0xFF5E81FF), fontWeight: FontWeight.bold)),
          ),
        ],
      );
      },
    );
  }

  /// 計算式の表示（メモ電卓用）
  Widget _buildCalcFormulaDisplay() {
    if (_calcTermValues.isEmpty) return const SizedBox.shrink();
    final widgets = <Widget>[];
    for (int i = 0; i < _calcTermValues.length; i++) {
      widgets.add(GestureDetector(
        onTap: () => _editCalcTermValue(i),
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.0),
          ),
          child: Text(_addCommas(_fmtCalc(_calcTermValues[i])), style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ));
      if (i < _calcTermOps.length) {
        final opIdx = i;
        widgets.add(GestureDetector(
          onTapDown: (d) => _pickCalcOp(opIdx, d.globalPosition),
          child: Container(
          margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.08), shape: BoxShape.circle, border: Border.all(color: Colors.orangeAccent.withOpacity(0.2))),
            child: Text(_calcTermOps[i], style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ));
      }
    }
    if (_calcHasResult) {
      widgets.add(const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('=', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w500))));
    }
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(mainAxisSize: MainAxisSize.min, children: widgets));
  }

  Widget _buildCalcPanel() {
    const textColor = Colors.white;
    final keyBg = Colors.white.withOpacity(0.1);
    const opColor = Colors.blueAccent;
    const eqColor = Colors.orangeAccent;
    const keyFontSize = 26.0;
    const displayFontSize = 64.0;

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
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 0.8,
                      ),),
                     child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 14,
                            bottom: 0,

                            child: const Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.white70,
                              size: 24,
                            ),
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
 Positioned(
                                     top: -0,
                                     child: Text(
                                      'ai',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                                                       ),
                                   )
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
                      size: 24,
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
                                    AppLocalizations.of(context)!.insertToMemo,
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
              margin: const EdgeInsets.only( top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              height: 100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 数値・式表示エリア
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_calcTermValues.isNotEmpty)
                          _buildCalcFormulaDisplay(),
                        FittedBox(
                          child: Text(
                            _addCommas(_calcDisplay),
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
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: GridView.count(
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
              ),
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
                    hintText: AppLocalizations.of(context)!.memoPlaceholder,
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
                        child: Text(
                          AppLocalizations.of(context)!.cancel,
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
      ..strokeWidth = 0.5;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.0)
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
          fontSize: 8,
          letterSpacing: -0.8,
          fontWeight: FontWeight.w500,
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

// ── 画像アイテム行ウィジェット（並び替え可能） ──
class _ImageItemRow extends StatelessWidget {
  final String imageBytes;
  final double cropScale;
  final double cropOffsetX;
  final double cropOffsetY;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Widget? dragHandle;
  final String caption;
  final double? editorWidth;
  final double? editorHeight;

  static const double _fixedHeight = 180.0;

  const _ImageItemRow({
    super.key,
    required this.imageBytes,
    this.cropScale = 1.0,
    this.cropOffsetX = 0.0,
    this.cropOffsetY = 0.0,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
    this.dragHandle,
    this.caption = '',
    this.editorWidth,
    this.editorHeight,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = base64Decode(imageBytes);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.cyanAccent.withOpacity(0.06)
              : Colors.cyan.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? Colors.cyanAccent.withOpacity(0.22)
                : Colors.cyan.withOpacity(0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (dragHandle != null) ...[dragHandle!, const SizedBox(width: 4)],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: _fixedHeight,
                      width: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final h = _fixedHeight;
                          final s = cropScale;
                          // Center the scaled image, then apply crop offset.
                          // At offset (0,0): centered → left = -w*(s-1)/2
                          // At offset (-1,0): show left → left = 0
                          // At offset (1,0): show right → left = -w*(s-1)
                          final left = -w * (s - 1.0) / 2.0 * (1.0 + cropOffsetX);
                          final top = -h * (s - 1.0) / 2.0 * (1.0 + cropOffsetY);
                          return ClipRect(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: left,
                                  top: top,
                                  width: w * s,
                                  height: h * s,
                                  child: Image.memory(
                                    bytes,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.white10,
                                      child: const Center(
                                        child: Icon(Icons.broken_image, color: Colors.white38),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (caption.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      caption,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                     // maxLines: 2,
                     // overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
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

// ── 画像クリップ編集画面（フルスクリーン） ──
class _ImageCropEditor extends StatefulWidget {
  final Uint8List imageBytes;
  final double initialScale;
  final double initialOffsetX;
  final double initialOffsetY;
  final String initialCaption;

  const _ImageCropEditor({
    required this.imageBytes,
    this.initialScale = 1.0,
    this.initialOffsetX = 0.0,
    this.initialOffsetY = 0.0,
    this.initialCaption = '',
  });

  @override
  State<_ImageCropEditor> createState() => _ImageCropEditorState();
}

class _ImageCropEditorState extends State<_ImageCropEditor> {
  late double _scale;
  late Offset _offset;
  final TransformationController _transCtrl = TransformationController();
  Size _containerSize = Size.zero;
  late TextEditingController _captionCtrl;

  @override
  void initState() {
    super.initState();
    _scale = widget.initialScale;
    _offset = Offset(widget.initialOffsetX, widget.initialOffsetY);
    _captionCtrl = TextEditingController(text: widget.initialCaption);
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _transCtrl.dispose();
    super.dispose();
  }

  void _updateOffsetFromMatrix() {
    final m = _transCtrl.value;
    final s = m.getMaxScaleOnAxis();
    final t = m.getTranslation();
    if (s > 1.0 && _containerSize.width > 0 && _containerSize.height > 0) {
      // At scale s, the content is s times larger than the container.
      // Max pan in each direction = (s - 1) * containerSize / 2.
      // InteractiveViewer pan right (t.x > 0) reveals left side,
      // so negate to get alignment where -1 = show left, 1 = show right.
      final maxPanX = _containerSize.width * (s - 1.0) / 2.0;
      final maxPanY = _containerSize.height * (s - 1.0) / 2.0;
      final dx = maxPanX > 0 ? (-t.x / maxPanX).clamp(-1.0, 1.0) : 0.0;
      final dy = maxPanY > 0 ? (-t.y / maxPanY).clamp(-1.0, 1.0) : 0.0;
      setState(() {
        _scale = s;
        _offset = Offset(dx, dy);
      });
    } else {
      setState(() {
        _scale = s;
        _offset = Offset.zero;
      });
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _updateOffsetFromMatrix();
  }

  void _resetTransform() {
    _transCtrl.value = Matrix4.identity();
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
        appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        foregroundColor: Colors.white,
        title: Builder(
          builder: (context) => Text(
            AppLocalizations.of(context)!.adjustImage,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              tooltip: AppLocalizations.of(context)!.reset,
              onPressed: _resetTransform,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // キャプション入力欄
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Builder(
              builder: (context) => TextField(
                controller: _captionCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.captionHint,
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
                    borderSide: const BorderSide(color: Colors.cyanAccent),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _containerSize = Size(constraints.maxWidth, 200);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: constraints.maxWidth,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(
                              color: Colors.cyanAccent.withOpacity(0.5),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: InteractiveViewer(
                            transformationController: _transCtrl,
                            minScale: 0.5,
                            maxScale: 5.0,
                            onInteractionEnd: _onScaleEnd,
                            child: Image.memory(
                              widget.imageBytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  bottom: 24,
                  child: Builder(
                    builder: (context) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.cropEditorHint,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
                Builder(
                  builder: (context) => Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        AppLocalizations.of(context)!.cancel,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Builder(
                builder: (context) => Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5E81FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context, {
                      'scale': _scale,
                      'offsetX': _offset.dx,
                      'offsetY': _offset.dy,
                      'caption': _captionCtrl.text,
                      'editorWidth': _containerSize.width,
                      'editorHeight': _containerSize.height,
                    }),
                    child: Text(
                      AppLocalizations.of(context)!.apply,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

