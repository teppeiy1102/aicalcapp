part of 'widget_page.dart';

class _SorobanPracticeRecord {
  final DateTime playedAt;
  final int digits;
  final bool subtraction;
  final bool multiplication;
  final bool division;
  final int solvedCount;
  final int elapsedMs;

  const _SorobanPracticeRecord({
    required this.playedAt,
    required this.digits,
    required this.subtraction,
    required this.multiplication,
    required this.division,
    required this.solvedCount,
    required this.elapsedMs,
  });

  double get averageSeconds => elapsedMs / solvedCount / 1000;

  Map<String, dynamic> toJson() => {
    'playedAt': playedAt.toIso8601String(),
    'digits': digits,
    'subtraction': subtraction,
    'multiplication': multiplication,
    'division': division,
    'solvedCount': solvedCount,
    'elapsedMs': elapsedMs,
  };

  factory _SorobanPracticeRecord.fromJson(Map<String, dynamic> json) {
    return _SorobanPracticeRecord(
      playedAt:
          DateTime.tryParse(json['playedAt'] as String? ?? '') ??
          DateTime.now(),
      digits: (json['digits'] as num? ?? 2).toInt(),
      subtraction: json['subtraction'] == true,
      multiplication: json['multiplication'] == true,
      division: json['division'] == true,
      solvedCount: (json['solvedCount'] as num? ?? 0).toInt(),
      elapsedMs: (json['elapsedMs'] as num? ?? 0).toInt(),
    );
  }

  String get configurationLabel {
    final operators = <String>['+'];
    if (subtraction) operators.add('-');
    if (multiplication) operators.add('×');
    if (division) operators.add('÷');
    return '${digits}桁・${operators.join()}';
  }
}

class _SorobanPracticeStore {
  _SorobanPracticeStore._();
  static final instance = _SorobanPracticeStore._();

  static const _historyKey = 'soroban_practice_history_v1';
  final List<_SorobanPracticeRecord> _records = [];
  bool _loaded = false;

  List<_SorobanPracticeRecord> get records => List.unmodifiable(_records);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = json.decode(raw) as List<dynamic>;
      _records.addAll(
        decoded.map(
          (entry) => _SorobanPracticeRecord.fromJson(
            Map<String, dynamic>.from(entry as Map),
          ),
        ),
      );
    } catch (_) {
      _records.clear();
    }
  }

  Future<void> add(_SorobanPracticeRecord record) async {
    await load();
    _records.insert(0, record);
    if (_records.length > 100) {
      _records.removeRange(100, _records.length);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _historyKey,
        json.encode(_records.map((entry) => entry.toJson()).toList()),
      );
    } catch (_) {}
  }
}

class SorobanPage extends StatefulWidget {
  const SorobanPage({super.key});

  @override
  State<SorobanPage> createState() => _SorobanPageState();
}

class _SorobanPracticeQuestion {
  final int? previous;
  final String? operator;
  final int? operand;
  final int answer;

  const _SorobanPracticeQuestion({
    required this.previous,
    required this.operator,
    required this.operand,
    required this.answer,
  });
}

class _SorobanPageState extends State<SorobanPage>
    with TickerProviderStateMixin {
  static const _columnCount = 7;

  final List<int> _digits = List<int>.filled(_columnCount, 0);
  late final AnimationController _beadController;
  late final AnimationController _correctEffectController;
  List<double> _animationFromUpper = List<double>.filled(_columnCount, 0);
  List<double> _animationFromLower = List<double>.filled(_columnCount, 0);
  final _random = math.Random();
  bool _practiceActive = false;
  int _practiceDigits = 2;
  bool _practiceSubtraction = false;
  bool _practiceMultiplication = false;
  bool _practiceDivision = false;
  _SorobanPracticeQuestion? _practiceQuestion;
  bool? _practiceLastCorrect;
  int _practiceSolvedCount = 0;
  DateTime? _practiceStartedAt;
  Timer? _practiceTimer;
  int _practiceElapsedMs = 0;
  List<_SorobanPracticeRecord> _practiceRecords = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _beadController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
        )..addListener(() {
          if (mounted) setState(() {});
        });
    _correctEffectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _loadPracticeHistory();
  }

  @override
  void dispose() {
    _practiceTimer?.cancel();
    _beadController.dispose();
    _correctEffectController.dispose();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  int get _value {
    var value = 0;
    for (final digit in _digits) {
      value = value * 10 + digit;
    }
    return value;
  }

  double get _animationProgress {
    return Curves.easeOutCubic.transform(_beadController.value);
  }

  String _formatValue(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  void _setColumnValue(int column, int value) {
    final nextValue = value.clamp(0, 9).toInt();
    if (_digits[column] == nextValue) return;
    _captureCurrentAnimationState();
    setState(() {
      _digits[column] = nextValue;
      _practiceLastCorrect = null;
    });
    _beadController.forward(from: 0);
    _checkPracticeAnswer();
  }

  void _checkPracticeAnswer() {
    final question = _practiceQuestion;
    if (!_practiceActive || question == null) return;
    if (_value != question.answer) return;

    setState(() {
      _practiceElapsedMs = _currentPracticeElapsedMs;
      _practiceQuestion = _generatePracticeQuestion(question.answer);
      _practiceLastCorrect = true;
      _practiceSolvedCount++;
    });
    _correctEffectController.forward(from: 0);
  }

  int get _currentPracticeElapsedMs {
    final startedAt = _practiceStartedAt;
    if (startedAt == null) return _practiceElapsedMs;
    return DateTime.now().difference(startedAt).inMilliseconds;
  }

  double get _practiceAverageSeconds => _practiceSolvedCount == 0
      ? 0
      : _practiceElapsedMs / _practiceSolvedCount / 1000;

  _SorobanPracticeRecord? get _bestPracticeRecord {
    if (_practiceRecords.isEmpty) return null;
    return _practiceRecords.reduce(
      (current, next) =>
          current.averageSeconds < next.averageSeconds ? current : next,
    );
  }

  Future<void> _loadPracticeHistory() async {
    await _SorobanPracticeStore.instance.load();
    if (!mounted) return;
    setState(() {
      _practiceRecords = _SorobanPracticeStore.instance.records;
    });
  }

  void _startPracticeTimer() {
    _practiceTimer?.cancel();
    _practiceStartedAt = DateTime.now();
    _practiceElapsedMs = 0;
    _practiceTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || !_practiceActive) return;
      setState(() {
        _practiceElapsedMs = _currentPracticeElapsedMs;
      });
    });
  }

  Future<void> _recordPracticeSession() async {
    if (!_practiceActive || _practiceSolvedCount == 0) return;
    _practiceElapsedMs = _currentPracticeElapsedMs;
    final record = _SorobanPracticeRecord(
      playedAt: DateTime.now(),
      digits: _practiceDigits,
      subtraction: _practiceSubtraction,
      multiplication: _practiceMultiplication,
      division: _practiceDivision,
      solvedCount: _practiceSolvedCount,
      elapsedMs: _practiceElapsedMs,
    );
    await _SorobanPracticeStore.instance.add(record);
    _practiceRecords = _SorobanPracticeStore.instance.records;
  }

  String _formatSeconds(double seconds) => '${seconds.toStringAsFixed(1)}秒';

  String _formatPracticeDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}/${local.month}/${local.day} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showPracticeHistory() async {
    await _loadPracticeHistory();
    if (!mounted) return;
    final records = _practiceRecords;
    final best = _bestPracticeRecord;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.fromLTRB(24, 0, 24, 0),
        insetPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        title: const Text('そろばん練習履歴'),
        content: SizedBox(
          width: 420,
          child: records.isEmpty
              ? const Text('まだ練習履歴がありません。')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '最高記録（最速）  ${_formatSeconds(best!.averageSeconds)} /問',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: records.length,
                        separatorBuilder: (_, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${_formatSeconds(record.averageSeconds)} /問  '
                              '${record.solvedCount}問',
                            ),
                            subtitle: Text(
                              '${record.configurationLabel}  '
                              '${_formatPracticeDate(record.playedAt)}',
                            ),
                          );
                        },
                      ),
                    ),
 TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
                  ],
                ),
        ),
      ),
    );
  }

  _SorobanPracticeQuestion _generateInitialQuestion() {
    final minimum = _practiceDigits == 1
        ? 1
        : math.pow(10, _practiceDigits - 1).toInt();
    final maximum = math.pow(10, _practiceDigits).toInt() - 1;
    return _SorobanPracticeQuestion(
      previous: null,
      operator: null,
      operand: null,
      answer: _randomInRange(minimum, maximum),
    );
  }

  _SorobanPracticeQuestion _generatePracticeQuestion(int previous) {
    final minimum = _practiceDigits == 1
        ? 1
        : math.pow(10, _practiceDigits - 1).toInt();
    final maximum = math.pow(10, _practiceDigits).toInt() - 1;
    final operations = <String>['+'];
    if (_practiceSubtraction) operations.add('-');
    if (_practiceMultiplication) operations.add('×');
    if (_practiceDivision) operations.add('÷');
    final maxSorobanValue = math.pow(10, _columnCount).toInt() - 1;

    operations.shuffle(_random);
    for (final operator in operations) {
      switch (operator) {
        case '+':
          final maximumOperand = math
              .min(maximum, maxSorobanValue - previous)
              .toInt();
          if (maximumOperand < 1) continue;
          final minimumOperand = minimum <= maximumOperand ? minimum : 1;
          final operand = _randomInRange(minimumOperand, maximumOperand);
          return _SorobanPracticeQuestion(
            previous: previous,
            operator: operator,
            operand: operand,
            answer: previous + operand,
          );
        case '-':
          final maximumOperand = math.min(maximum, previous - 1).toInt();
          if (maximumOperand < 1) continue;
          final minimumOperand = minimum <= maximumOperand ? minimum : 1;
          final operand = _randomInRange(minimumOperand, maximumOperand);
          return _SorobanPracticeQuestion(
            previous: previous,
            operator: operator,
            operand: operand,
            answer: previous - operand,
          );
        case '×':
          final factors = <int>[];
          for (var factor = 2; factor <= 9; factor++) {
            if (previous <= maxSorobanValue ~/ factor) {
              factors.add(factor);
            }
          }
          if (factors.isEmpty) continue;
          final factor = factors[_random.nextInt(factors.length)];
          return _SorobanPracticeQuestion(
            previous: previous,
            operator: operator,
            operand: factor,
            answer: previous * factor,
          );
        case '÷':
          final divisors = <int>[];
          for (var divisor = 2; divisor <= 9; divisor++) {
            if (previous % divisor == 0) divisors.add(divisor);
          }
          if (divisors.isEmpty) continue;
          final divisor = divisors[_random.nextInt(divisors.length)];
          return _SorobanPracticeQuestion(
            previous: previous,
            operator: operator,
            operand: divisor,
            answer: previous ~/ divisor,
          );
      }
    }
    return _generateInitialQuestion();
  }

  int _randomInRange(int minimum, int maximum) {
    return minimum + _random.nextInt(maximum - minimum + 1);
  }

  Future<void> _showPracticeSettings() async {
    var digits = _practiceDigits;
    var subtraction = _practiceSubtraction;
    var multiplication = _practiceMultiplication;
    var division = _practiceDivision;
    final settings = await showDialog<_SorobanPracticeSettings>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('そろばん練習問題'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('桁数')),
                      Text('$digits 桁'),
                    ],
                  ),
                  Slider(
                    value: digits.toDouble(),
                    min: 1,
                    max: _columnCount.toDouble() - 2,
                    divisions: _columnCount - 1,
                    label: '$digits 桁',
                    onChanged: (value) =>
                        setDialogState(() => digits = value.round()),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('引き算'),
                    value: subtraction,
                    onChanged: (value) =>
                        setDialogState(() => subtraction = value),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('掛け算'),
                    value: multiplication,
                    onChanged: (value) =>
                        setDialogState(() => multiplication = value),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('割り算'),
                    value: division,
                    onChanged: (value) =>
                        setDialogState(() => division = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  _SorobanPracticeSettings(
                    digits: digits,
                    subtraction: subtraction,
                    multiplication: multiplication,
                    division: division,
                  ),
                ),
                child: Text(_practiceActive ? 'この設定で続ける' : '開始'),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || settings == null) return;

    await _recordPracticeSession();
    if (!mounted) return;
    _practiceTimer?.cancel();
    _captureCurrentAnimationState();
    setState(() {
      _practiceDigits = settings.digits;
      _practiceSubtraction = settings.subtraction;
      _practiceMultiplication = settings.multiplication;
      _practiceDivision = settings.division;
      _practiceActive = true;
      _practiceQuestion = _generateInitialQuestion();
      _practiceLastCorrect = null;
      _practiceSolvedCount = 0;
      for (var index = 0; index < _digits.length; index++) {
        _digits[index] = 0;
      }
    });
    _startPracticeTimer();
    _beadController.forward(from: 0);
  }

  Future<void> _stopPractice() async {
    await _recordPracticeSession();
    if (!mounted) return;
    _practiceTimer?.cancel();
    setState(() {
      _practiceActive = false;
      _practiceQuestion = null;
      _practiceLastCorrect = null;
      _practiceSolvedCount = 0;
      _practiceStartedAt = null;
      _practiceElapsedMs = 0;
    });
  }

  Future<void> _exitSimulator() async {
    await _recordPracticeSession();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _captureCurrentAnimationState() {
    final progress = _animationProgress;
    for (var index = 0; index < _digits.length; index++) {
      final targetUpper = _digits[index] >= 5 ? 1.0 : 0.0;
      final targetLower = (_digits[index] % 5).toDouble();
      _animationFromUpper[index] =
          _animationFromUpper[index] +
          (targetUpper - _animationFromUpper[index]) * progress;
      _animationFromLower[index] =
          _animationFromLower[index] +
          (targetLower - _animationFromLower[index]) * progress;
    }
  }

  void _reset() {
    if (_value == 0) return;
    _captureCurrentAnimationState();
    setState(() {
      for (var index = 0; index < _digits.length; index++) {
        _digits[index] = 0;
      }
    });
    _beadController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 49, 42, 31),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 46, 44, 45),
              Color.fromARGB(255, 56, 35, 18),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: _SorobanBoard(
                    digits: _digits,
                    animationFromUpper: _animationFromUpper,
                    animationFromLower: _animationFromLower,
                    animationProgress: _animationProgress,
                    logicalDigits: _digits,
                    onColumnValueChanged: _setColumnValue,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 180, child: _buildValuePanel()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValuePanel() {
    final currentValue = _formatValue(_value);
    final best = _bestPracticeRecord;
    if (_practiceActive) return _buildPracticePanel();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'リセット',
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded, size: 36),
              color: const Color(0xFFE8D8B9),
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            Spacer(),
            OutlinedButton.icon(
              onPressed: _exitSimulator,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('back'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB8C6C0),
                side: const BorderSide(color: Color(0xFF53615F)),
              ),
            ),
          ],
        ),

        const Spacer(),
        const Text(
          '現在の値',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF9EB1A7), fontSize: 13),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: FittedBox(
            child: Container(
              child: Text(
                currentValue,
                key: ValueKey(currentValue),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFF4E7CE),
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),

        const Spacer(),
        if (best != null) ...[
          Text(
            '最高記録  ${_formatSeconds(best.averageSeconds)} /問',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFFD98A),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: _showPracticeHistory,
          icon: const Icon(Icons.history_rounded, size: 18),
          label: const Text('履歴'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB8C6C0),
            side: const BorderSide(color: Color(0xFF53615F)),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _showPracticeSettings,
          icon: const Icon(Icons.school_rounded, size: 18),
          label: const Text('練習問題'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFFD98A),
            side: const BorderSide(color: Color(0xFF8B6B43)),
          ),
        ),
      ],
    );
  }

  Widget _buildPracticePanel() {
    final question = _practiceQuestion;
    final isInitialQuestion = question == null || question.previous == null;
    return AnimatedBuilder(
      animation: _correctEffectController,
      builder: (context, child) {
        final pulse = Curves.easeOut.transform(
          math.sin(_correctEffectController.value * math.pi),
        );
        return Transform.scale(
          scale: 1 + pulse * .055,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Color.lerp(
                Colors.transparent,
                const Color.fromARGB(0, 104, 169, 194),
                pulse * .12,
              ),
              boxShadow: [
                if (pulse > 0)
                  BoxShadow(
                    color: const Color.fromARGB(
                      255,
                      155,
                      247,
                      143,
                    ).withValues(alpha: pulse * .35),
                    blurRadius: 22 * pulse,
                    spreadRadius: 3 * pulse,
                  ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '問題設定',
                onPressed: _showPracticeSettings,
                icon: const Icon(Icons.tune_rounded),
                color: const Color(0xFFE8D8B9),
              ),

              const Spacer(),
              OutlinedButton.icon(
                onPressed: _exitSimulator,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB8C6C0),
                  side: const BorderSide(color: Color(0xFF53615F)),
                ),
              ),
            ],
          ),

          Spacer(),
          Text(
            isInitialQuestion ? '最初の数字' : '前の数字',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isInitialQuestion
                  ? const Color(0xFF9EB1A7)
                  : const Color(0xFF9EB1A7).withValues(alpha: .8),
              fontSize: isInitialQuestion ? 13 : 11,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              question == null
                  ? ''
                  : _formatValue(
                      isInitialQuestion ? question.answer : question.previous!,
                    ),
              key: ValueKey(
                question == null
                    ? null
                    : isInitialQuestion
                    ? question.answer
                    : question.previous,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFC1CEC6),
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (!isInitialQuestion) ...[
            const Spacer(),
            const Text(
              '演算する数字',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9EB1A7), fontSize: 12),
            ),
            const SizedBox(height: 2),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                '${question.operator} ${_formatValue(question.operand!)}',
                key: ValueKey('${question.operator}${question.operand}'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFD98A),
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          Text(
            _practiceLastCorrect == true
                ? 'OK！'
                : isInitialQuestion
                ? '最初の数字をそろばんで入力'
                : '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _practiceLastCorrect == true
                  ? const Color(0xFF9ED6A5)
                  : const Color(0xFF9EB1A7),
              fontSize: _practiceLastCorrect == true ? 17 : 12,
              fontWeight: _practiceLastCorrect == true
                  ? FontWeight.w900
                  : FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            '$_practiceSolvedCount 問正解',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFE0A458), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '経過 ${_formatSeconds(_practiceElapsedMs / 1000)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFC1CEC6), fontSize: 12),
          ),
          Text(
            _practiceSolvedCount == 0
                ? '平均 -- /問'
                : '平均 ${_formatSeconds(_practiceAverageSeconds)} /問',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFFD98A),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (_bestPracticeRecord != null)
            Text(
              '最高 ${_formatSeconds(_bestPracticeRecord!.averageSeconds)} /問',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9ED6A5), fontSize: 11),
            ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _stopPractice,
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            label: const Text('練習を終了'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFFD98A),
              side: const BorderSide(color: Color(0xFF8B6B43)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SorobanPracticeSettings {
  final int digits;
  final bool subtraction;
  final bool multiplication;
  final bool division;

  const _SorobanPracticeSettings({
    required this.digits,
    required this.subtraction,
    required this.multiplication,
    required this.division,
  });
}

class _SorobanBoard extends StatelessWidget {
  final List<int> digits;
  final List<double> animationFromUpper;
  final List<double> animationFromLower;
  final double animationProgress;
  final List<int> logicalDigits;
  final void Function(int column, int value) onColumnValueChanged;

  const _SorobanBoard({
    required this.digits,
    required this.animationFromUpper,
    required this.animationFromLower,
    required this.animationProgress,
    required this.logicalDigits,
    required this.onColumnValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) =>
              _updateFromPosition(details.localPosition, constraints.biggest),
          child: CustomPaint(
            painter: _SorobanPainter(
              digits: digits,
              animationFromUpper: animationFromUpper,
              animationFromLower: animationFromLower,
              animationProgress: animationProgress,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  void _updateFromPosition(Offset position, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final geometry = _SorobanGeometry.fromSize(size, digits.length);
    if (!geometry.contentRect.contains(position)) return;
    final column =
        ((position.dx - geometry.contentRect.left) / geometry.columnWidth)
            .floor();
    if (column < 0 || column >= digits.length) return;

    final currentDigit = logicalDigits[column];
    final progress = animationProgress;
    final upperState = geometry.lerp(
      animationFromUpper[column],
      currentDigit >= 5 ? 1.0 : 0.0,
      progress,
    );
    final upperY = geometry.upperBeadY(upperState);
    final upperHit = (position.dy - upperY).abs() <= geometry.beadHeight * .8;
    if (upperHit) {
      onColumnValueChanged(
        column,
        currentDigit >= 5 ? currentDigit - 5 : currentDigit + 5,
      );
      return;
    }

    final currentLower = geometry.lerp(
      animationFromLower[column],
      (currentDigit % 5).toDouble(),
      progress,
    );
    var nearestIndex = -1;
    var nearestDistance = double.infinity;
    for (var index = 0; index < 4; index++) {
      final beadY = geometry.lowerBeadY(currentLower, index);
      final distance = (position.dy - beadY).abs();
      if (distance < nearestDistance) {
        nearestIndex = index;
        nearestDistance = distance;
      }
    }
    if (nearestDistance > geometry.beadHeight * .8) return;
    final lowerValue = nearestIndex < currentLower
        ? nearestIndex
        : nearestIndex + 1;
    onColumnValueChanged(column, (currentDigit >= 5 ? 5 : 0) + lowerValue);
  }
}

class _SorobanGeometry {
  final Rect contentRect;
  final double dividerY;
  final double bottomY;
  final double columnWidth;
  final double beadWidth;
  final double beadHeight;
  final double beadGap;

  const _SorobanGeometry({
    required this.contentRect,
    required this.dividerY,
    required this.bottomY,
    required this.columnWidth,
    required this.beadWidth,
    required this.beadHeight,
    required this.beadGap,
  });

  factory _SorobanGeometry.fromSize(Size size, int columnCount) {
    const sidePadding = 14.0;
    const topPadding = 9.0;
    const bottomPadding = 2.0;
    final contentRect = Rect.fromLTRB(
      sidePadding,
      topPadding,
      size.width - sidePadding,
      size.height - bottomPadding,
    );
    final columnWidth = contentRect.width / columnCount;
    final beadHeight = math.min(74.0, contentRect.height / 6.3).toDouble();
    final beadGap = math.min(9.0, beadHeight * .05).toDouble();
    final dividerY = contentRect.top + beadHeight * 1.5;
    return _SorobanGeometry(
      contentRect: contentRect,
      dividerY: dividerY,
      bottomY: contentRect.bottom,
      columnWidth: columnWidth,
      beadWidth: math.min(columnWidth * .88, 68.0).toDouble(),
      beadHeight: beadHeight,
      beadGap: beadGap,
    );
  }

  double upperBeadY(double progress) {
    return lerp(
      contentRect.top + beadHeight / 2,
      dividerY - beadHeight / 1.6,
      progress,
    );
  }

  double lowerBeadY(double lowerProgress, int beadIndex) {
    final beadProgress = (lowerProgress - beadIndex).clamp(0.0, .7);
    final activeY =
        dividerY + beadHeight / 2 + beadIndex * (beadHeight + beadGap);
    final inactiveY = activeY + beadHeight / 2;
    return lerp(inactiveY, activeY, beadProgress);
  }

  double lerp(double start, double end, double amount) {
    return start + (end - start) * amount.clamp(0.0, 1.0);
  }
}

class _SorobanPainter extends CustomPainter {
  final List<int> digits;
  final List<double> animationFromUpper;
  final List<double> animationFromLower;
  final double animationProgress;
  const _SorobanPainter({
    required this.digits,
    required this.animationFromUpper,
    required this.animationFromLower,
    required this.animationProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _SorobanGeometry.fromSize(size, digits.length);
    final boardRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final framePaint = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.fill;
    final innerPaint = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.fill;
    final frameHighlightPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    final rodPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 6;
    final dividerPaint = Paint()
      ..color = const Color.fromARGB(255, 245, 186, 158)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(8)),
      framePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect.deflate(9), const Radius.circular(3)),
      innerPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect.deflate(5), const Radius.circular(5)),
      frameHighlightPaint,
    );

    for (var index = 0; index < digits.length; index++) {
      final x = geometry.contentRect.left + geometry.columnWidth * (index + .5);
      canvas.drawLine(
        Offset(x, geometry.contentRect.top + 1),
        Offset(x, geometry.contentRect.bottom - 8),
        rodPaint,
      );

      final digit = digits[index].clamp(0, 9).toInt();
      final upperTarget = digit >= 5 ? 1.0 : 0.0;
      final lowerTarget = (digit % 5).toDouble();
      final upperProgress = _lerp(
        animationFromUpper[index],
        upperTarget,
        animationProgress,
      );
      final lowerProgress = _lerp(
        animationFromLower[index],
        lowerTarget,
        animationProgress,
      );
      final upperY = geometry.upperBeadY(upperProgress);
      _drawBead(
        canvas,
        Offset(x, upperY),
        geometry.beadWidth,
        geometry.beadHeight,
        upperProgress > .5,
      );

      for (var beadIndex = 0; beadIndex < 4; beadIndex++) {
        final beadProgress = (lowerProgress - beadIndex).clamp(0.0, 1.0);
        final y = geometry.lowerBeadY(lowerProgress, beadIndex);
        _drawBead(
          canvas,
          Offset(x, y),
          geometry.beadWidth,
          geometry.beadHeight,
          beadProgress > .5,
        );
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          geometry.contentRect.left - 4,
          geometry.dividerY - 9,
          geometry.contentRect.right + 4,
          geometry.dividerY + 9,
        ),
        const Radius.circular(0),
      ),
      dividerPaint,
    );
  }

  double _lerp(double start, double end, double amount) {
    return start + (end - start) * amount.clamp(0.0, 1.0);
  }

  void _drawBead(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    bool active,
  ) {
    final beadPaint = Paint()
      ..color = active
          ? const Color.fromARGB(255, 231, 109, 78)
          : const Color.fromARGB(255, 63, 195, 200)
      //..color = active ? const Color(0xFFE7A44E) : const Color(0xFFC8793F)
      ..style = PaintingStyle.fill;
    final highlightPaint = Paint()
      ..color = active ? Colors.grey.shade300 : Colors.grey.shade300
      //..color = active ? const Color(0xFFFFD78E) : const Color(0xFFE09A58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..moveTo(center.dx - width / 1.8, center.dy)
      ..lineTo(center.dx - width * .15, center.dy - height / 1.95)
      ..lineTo(center.dx + width * .15, center.dy - height / 1.95)
      ..lineTo(center.dx + width / 1.8, center.dy)
      ..lineTo(center.dx + width * .15, center.dy + height / 1.95)
      ..lineTo(center.dx - width * .15, center.dy + height / 1.95)
      ..close();
    canvas.drawPath(path, beadPaint);
    // canvas.drawPath(path, highlightPaint);
    canvas.drawLine(
      Offset(center.dx - width / 2.3, center.dy),
      Offset(center.dx + width / 2.3, center.dy),
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SorobanPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        !_sameDigits(oldDelegate.digits, digits) ||
        !_sameDoubles(oldDelegate.animationFromUpper, animationFromUpper) ||
        !_sameDoubles(oldDelegate.animationFromLower, animationFromLower);
  }

  bool _sameDigits(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  bool _sameDoubles(List<double> left, List<double> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if ((left[index] - right[index]).abs() > .001) return false;
    }
    return true;
  }
}
