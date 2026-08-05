part of 'widget_page.dart';

class FlashMathPlay {
  final DateTime playedAt;
  final int level;
  final int digits;
  final int speedMs;
  final bool multiplication;
  final bool division;
  final bool subtraction;
  final String expression;
  final double answer;
  final double? userAnswer;
  final int responseMs;
  final int streak;
  final int termCount;
  final bool isCustom;

  const FlashMathPlay({
    required this.playedAt,
    required this.level,
    required this.digits,
    required this.speedMs,
    required this.multiplication,
    required this.division,
    required this.subtraction,
    required this.expression,
    required this.answer,
    required this.userAnswer,
    required this.responseMs,
    required this.streak,
    required this.termCount,
    this.isCustom = false,
  });

  bool get isCorrect =>
      userAnswer != null && (userAnswer! - answer).abs() < 0.0001;

  Map<String, dynamic> toJson() => {
    'playedAt': playedAt.toIso8601String(),
    'level': level,
    'digits': digits,
    'speedMs': speedMs,
    'multiplication': multiplication,
    'division': division,
    'subtraction': subtraction,
    'expression': expression,
    'answer': answer,
    'userAnswer': userAnswer,
    'responseMs': responseMs,
    'streak': streak,
    'termCount': termCount,
    'isCustom': isCustom,
  };

  factory FlashMathPlay.fromJson(Map<String, dynamic> json) {
    return FlashMathPlay(
      playedAt:
          DateTime.tryParse(json['playedAt'] as String? ?? '') ??
          DateTime.now(),
      level: (json['level'] as num? ?? 1).toInt(),
      digits: (json['digits'] as num? ?? 1).toInt(),
      speedMs: (json['speedMs'] as num? ?? 800).toInt(),
      multiplication: json['multiplication'] == true,
      division: json['division'] == true,
      subtraction: json['subtraction'] == true,
      expression: json['expression'] as String? ?? '',
      answer: (json['answer'] as num? ?? 0).toDouble(),
      userAnswer: (json['userAnswer'] as num?)?.toDouble(),
      responseMs: (json['responseMs'] as num? ?? 0).toInt(),
      streak: (json['streak'] as num? ?? 0).toInt(),
      termCount: (json['termCount'] as num? ?? 0).toInt(),
      isCustom: json['isCustom'] == true,
    );
  }

  String get configurationLabel {
    if (!isCustom) return 'レベル $level';
    final speed = (speedMs / 1000).toStringAsFixed(2);
    final count = termCount > 0 ? termCount : '-';
    final operators = <String>['+'];
    if (subtraction) operators.add('-');
    if (multiplication) operators.add('×');
    if (division) operators.add('÷');
    return 'カスタム・${digits}桁・${speed}秒・${count}個・${operators.join()}';
  }
}

class FlashMathStore {
  FlashMathStore._();
  static final FlashMathStore instance = FlashMathStore._();

  static const _historyKey = 'flash_math_history_v1';
  static const _settingsKey = 'flash_math_settings_v1';
  final ValueNotifier<int> changeNotifier = ValueNotifier(0);
  final List<FlashMathPlay> _plays = [];
  bool _loaded = false;

  List<FlashMathPlay> get plays => List.unmodifiable(_plays);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = json.decode(raw) as List<dynamic>;
      _plays.addAll(
        decoded.map(
          (entry) =>
              FlashMathPlay.fromJson(Map<String, dynamic>.from(entry as Map)),
        ),
      );
    } catch (_) {
      _plays.clear();
    }
  }

  Future<void> add(FlashMathPlay play) async {
    await load();
    _plays.insert(0, play);
    if (_plays.length > 300) _plays.removeRange(300, _plays.length);
    changeNotifier.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _historyKey,
        json.encode(_plays.map((entry) => entry.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> saveSettings({
    required int level,
    required bool multiplication,
    required bool division,
    required bool subtraction,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _settingsKey,
      json.encode({
        'level': level,
        'multiplication': multiplication,
        'division': division,
        'subtraction': subtraction,
      }),
    );
  }

  Future<Map<String, dynamic>?> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_settingsKey);
      if (raw == null || raw.isEmpty) return null;
      return Map<String, dynamic>.from(json.decode(raw) as Map);
    } catch (_) {
      return null;
    }
  }
}

class FlashMentalMathPage extends StatefulWidget {
  const FlashMentalMathPage({super.key});

  @override
  State<FlashMentalMathPage> createState() => _FlashMentalMathPageState();
}

enum _FlashPageMode { home, countdown, flashing, answer, result }

class _FlashTerm {
  final String label;
  final double value;
  const _FlashTerm(this.label, this.value);
}

class _FlashMathQuestion {
  final List<_FlashTerm> terms;
  final double answer;
  const _FlashMathQuestion(this.terms, this.answer);

  String get expression {
    final buffer = StringBuffer();
    for (var i = 0; i < terms.length; i++) {
      if (i > 0 && !terms[i].label.startsWith(' ')) buffer.write(' + ');
      buffer.write(terms[i].label.trim());
    }
    return buffer.toString();
  }
}

class _FlashMentalMathPageState extends State<FlashMentalMathPage> {
  final _random = math.Random();
  final _answerController = TextEditingController();
  Timer? _flashTimer;
  Timer? _countdownTimer;
  _FlashPageMode _mode = _FlashPageMode.home;
  _FlashMathQuestion? _question;
  int _termIndex = -1;
  String _visibleTerm = '';
  int _countdownValue = 3;
  int _level = 12;
  bool _multiplication = false;
  bool _division = false;
  bool _subtraction = false;
  bool _isCustomMode = false;
  int _customDigits = 2;
  int _customSpeedMs = 700;
  int _customTermCount = 8;
  int _streak = 0;
  int _roundStartedAt = 0;
  bool _loading = true;
  bool? _lastCorrect;
  double? _lastAnswer;
  double? _lastUserAnswer;
  String _lastExpression = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _countdownTimer?.cancel();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    await FlashMathStore.instance.load();
    final settings = await FlashMathStore.instance.loadSettings();
    if (!mounted) return;
    if (settings != null) {
      _level = _clampInt((settings['level'] as num?)?.toInt() ?? _level, 1, 99);
      _multiplication = settings['multiplication'] == true;
      _division = settings['division'] == true;
      _subtraction = settings['subtraction'] == true;
    }
    setState(() => _loading = false);
  }

  int _clampInt(int value, int min, int max) => value.clamp(min, max).toInt();

  int get _levelDigits {
    return 1 + (((_level - 1) * 5) / 98).round();
  }

  int get _levelSpeedMs =>
      _clampInt(1200 - ((_level - 1) * 950 / 98).round(), 250, 1200);

  int get _levelTermCount => 3 + (((_level - 1) * 27) / 98).round();

  int get _activeDigits => _isCustomMode ? _customDigits : _levelDigits;
  int get _activeSpeedMs => _isCustomMode ? _customSpeedMs : _levelSpeedMs;
  int get _activeTermCount =>
      _isCustomMode ? _customTermCount : _levelTermCount;

  String get _sessionLabel => _isCustomMode ? 'CUSTOM' : 'LEVEL $_level';

  int _randomNumber() {
    final minimum = _activeDigits == 1
        ? 1
        : math.pow(10, _activeDigits - 1).toInt();
    final maximum = math.pow(10, _activeDigits).toInt() - 1;
    return minimum + _random.nextInt(maximum - minimum + 1);
  }

  double _randomOperand(String operator, double previousValue) {
    double value;
    do {
      if (operator == '×') {
        value = (2 + _random.nextInt(8)).toDouble();
      } else if (operator == '÷') {
        value = (2 + _random.nextInt(7)).toDouble();
      } else {
        value = _randomNumber().toDouble();
      }
    } while (value == previousValue);
    return value;
  }

  _FlashMathQuestion _createQuestion() {
    final terms = <_FlashTerm>[];
    var previousValue = _randomNumber().toDouble();
    var result = previousValue;
    terms.add(_FlashTerm(_formatNumber(previousValue), previousValue));
    final operators = <String>['+'];
    if (_multiplication) operators.add('×');
    if (_division) operators.add('÷');
    if (_subtraction) operators.add('-');

    for (var index = 1; index < _activeTermCount; index++) {
      final operator = operators[_random.nextInt(operators.length)];
      final value = _randomOperand(operator, previousValue);
      if (operator == '÷' && result.abs() < 0.001) {
        result = _randomNumber().toDouble();
      }
      if (operator == '×') {
        result *= value;
      } else if (operator == '÷') {
        result /= value;
      } else if (operator == '-') {
        result -= value;
      } else {
        result += value;
      }
      terms.add(_FlashTerm(' $operator ${_formatNumber(value)}', value));
      previousValue = value;
    }
    return _FlashMathQuestion(terms, result);
  }

  void _startGame() {
    _flashTimer?.cancel();
    _countdownTimer?.cancel();
    FlashMathStore.instance.saveSettings(
      level: _level,
      multiplication: _multiplication,
      division: _division,
      subtraction: _subtraction,
    );
    setState(() {
      _question = _createQuestion();
      _termIndex = -1;
      _countdownValue = 3;
      _visibleTerm = '3';
      _mode = _FlashPageMode.countdown;
      _lastCorrect = null;
      _answerController.clear();
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownValue <= 1) {
        timer.cancel();
        setState(() {
          _visibleTerm = 'START';
          _mode = _FlashPageMode.flashing;
        });
        _countdownTimer = Timer(
          const Duration(milliseconds: 550),
          _showNextTerm,
        );
        return;
      }
      setState(() {
        _countdownValue--;
        _visibleTerm = '$_countdownValue';
      });
    });
  }

  void _startLevelGame() {
    setState(() => _isCustomMode = false);
    _startGame();
  }

  Future<void> _openCustomSettings() async {
    final config = await Navigator.push<_FlashCustomConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => _FlashCustomSettingsPage(
          initialDigits: _customDigits,
          initialSpeedMs: _customSpeedMs,
          initialTermCount: _customTermCount,
          initialMultiplication: _multiplication,
          initialDivision: _division,
          initialSubtraction: _subtraction,
        ),
      ),
    );
    if (!mounted || config == null) return;
    setState(() {
      _isCustomMode = true;
      _customDigits = config.digits;
      _customSpeedMs = config.speedMs;
      _customTermCount = config.termCount;
      _multiplication = config.multiplication;
      _division = config.division;
      _subtraction = config.subtraction;
    });
    _startGame();
  }

  void _showNextTerm() {
    if (!mounted || _question == null) return;
    _termIndex++;
    if (_termIndex >= _question!.terms.length) {
      setState(() {
        _visibleTerm = '';
        _mode = _FlashPageMode.answer;
        _roundStartedAt = DateTime.now().millisecondsSinceEpoch;
      });
      return;
    }
    setState(() => _visibleTerm = _question!.terms[_termIndex].label.trim());
    _flashTimer = Timer(Duration(milliseconds: _activeSpeedMs), _showNextTerm);
  }

  void _onAnswerKey(String key) {
    var raw = _answerController.text.replaceAll(',', '');
    if (key == 'AC') {
      raw = '';
    } else if (key == '⌫') {
      if (raw.isNotEmpty) raw = raw.substring(0, raw.length - 1);
    } else if (key == '+/-') {
      if (raw.startsWith('-')) {
        raw = raw.substring(1);
      } else if (raw.isNotEmpty && raw != '0') {
        raw = '-$raw';
      }
    } else if (key == '.') {
      if (!raw.contains('.'))
        raw = raw.isEmpty || raw == '-' ? '${raw}0.' : '$raw.';
    } else if (RegExp(r'^\d$').hasMatch(key)) {
      if (raw == '0') {
        raw = key;
      } else if (raw == '-0') {
        raw = '-$key';
      } else {
        raw += key;
      }
    }
    _answerController.value = TextEditingValue(
      text: _formatAnswerInput(raw),
      selection: TextSelection.collapsed(
        offset: _formatAnswerInput(raw).length,
      ),
    );
    setState(() {});
  }

  String _formatAnswerInput(String raw) {
    if (raw.isEmpty || raw == '-') return raw;
    final negative = raw.startsWith('-');
    final unsigned = negative ? raw.substring(1) : raw;
    final parts = unsigned.split('.');
    final integerPart = parts.first.isEmpty ? '0' : parts.first;
    final grouped = integerPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    return '${negative ? '-' : ''}$grouped${parts.length > 1 ? '.${parts[1]}' : ''}';
  }

  Widget _buildAnswerKeypad() {
    const keyBackground = Color(0xFFECE6E0);
    const actionBackground = Color(0xFFFFE4DD);
    final keys = [
      'AC',
      '+/-',
      '⌫',
      '7',
      '8',
      '9',
      '4',
      '5',
      '6',
      '1',
      '2',
      '3',
      '.',
      '0',
      '',
    ];
    return SizedBox(
      width: double.infinity,
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.05,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: keys.map((key) {
          if (key.isEmpty) return const SizedBox.shrink();
          final action = key == 'AC' || key == '+/-' || key == '⌫';
          return _CalcKeyButton(
            label: key,
            bg: action
                ? actionBackground
                : const Color.fromARGB(255, 220, 216, 210),
            fg: action ? const Color(0xFFC64932) : const Color(0xFF262321),
            fontSize: key == '⌫' ? 34 : 22,
            onTap: () => _onAnswerKey(key),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _submitAnswer() async {
    final userAnswer = double.tryParse(
      _answerController.text.replaceAll(',', '').trim(),
    );
    if (userAnswer == null || _question == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('答えを入力してください')));
      return;
    }
    final correct = (userAnswer - _question!.answer).abs() < 0.0001;
    final newStreak = correct ? _streak + 1 : 0;
    final play = FlashMathPlay(
      playedAt: DateTime.now(),
      level: _level,
      digits: _activeDigits,
      speedMs: _activeSpeedMs,
      multiplication: _multiplication,
      division: _division,
      subtraction: _subtraction,
      expression: _question!.expression,
      answer: _question!.answer,
      userAnswer: userAnswer,
      responseMs: DateTime.now().millisecondsSinceEpoch - _roundStartedAt,
      streak: newStreak,
      termCount: _activeTermCount,
      isCustom: _isCustomMode,
    );
    await FlashMathStore.instance.add(play);
    if (!mounted) return;
    setState(() {
      _streak = newStreak;
      _lastCorrect = correct;
      _lastAnswer = _question!.answer;
      _lastUserAnswer = userAnswer;
      _lastExpression = _question!.expression;
      _mode = _FlashPageMode.result;
    });
  }

  void _backToHome() {
    _flashTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() => _mode = _FlashPageMode.home);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F3EE),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFE05B3F)),
        ),
      );
    }
    switch (_mode) {
      case _FlashPageMode.countdown:
        return _buildCountdownPage();
      case _FlashPageMode.flashing:
        return _buildFlashingPage();
      case _FlashPageMode.answer:
        return _buildAnswerPage();
      case _FlashPageMode.result:
        return _buildResultPage();
      case _FlashPageMode.home:
        return _buildHomePage();
    }
  }

  Widget _pageScaffold({
    required String title,
    required Widget body,
    List<Widget>? actions,
    VoidCallback? onBack,
  }) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF262321),
          ),
          onPressed: onBack ?? () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF262321),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: actions,
      ),
      body: SafeArea(child: body),
    );
  }

  Widget _buildHomePage() {
    final plays = FlashMathStore.instance.plays;
    final today = DateTime.now();
    final todayPlays = plays.where((play) {
      return play.playedAt.year == today.year &&
          play.playedAt.month == today.month &&
          play.playedAt.day == today.day;
    }).toList();
    final correctCount = todayPlays.where((play) => play.isCorrect).length;
    final accuracy = todayPlays.isEmpty
        ? 0
        : (correctCount / todayPlays.length * 100).round();
    final bestStreak = plays.fold<int>(
      0,
      (best, play) => math.max(best, play.streak),
    );
    final bestLevel = plays
        .where((play) => !play.isCustom && play.isCorrect)
        .fold<int>(0, (best, play) => math.max(best, play.level));
    return _pageScaffold(
      title: 'フラッシュ暗算',
      actions: [
        IconButton(
          tooltip: '統計',
          icon: const Icon(Icons.insights_rounded, color: Color(0xFF262321)),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FlashMathStatsPage()),
          ),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          _buildHeroCard(),
          const SizedBox(height: 18),
          bestLevel == 0
              ? const Text(
                  '現在クリア済みのレベルはありません',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color.fromARGB(255, 54, 54, 54),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color.fromARGB(255, 97, 53, 240),
                      Color.fromARGB(255, 46, 216, 216),
                      Color.fromARGB(255, 153, 103, 234),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    'Lv.$bestLevel Cleared!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
          const SizedBox(height: 24),
          const Text(
            '今日の実績',
            style: TextStyle(
              color: Color(0xFF262321),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _achievementCard(
                'プレイ',
                '${todayPlays.length}回',
                Icons.bolt_rounded,
                const Color(0xFFE05B3F),
              ),
              const SizedBox(width: 8),
              _achievementCard(
                '正答率',
                '$accuracy%',
                Icons.track_changes_rounded,
                const Color(0xFF168A7A),
              ),
              const SizedBox(width: 8),
              _achievementCard(
                '連続正解',
                '$bestStreak',
                Icons.local_fire_department_rounded,
                const Color(0xFFC18127),
              ),
            ],
          ),
          const SizedBox(height: 18),

          OutlinedButton.icon(
            onPressed: _openCustomSettings,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('カスタム設定で始める'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE05B3F),
              side: const BorderSide(color: Color(0xFFE05B3F)),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(34),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _startLevelGame,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('ゲームをスタート'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 28),
              backgroundColor: const Color(0xFFE05B3F),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const SorobanPage()),
            ),
            icon: const Icon(Icons.view_agenda_rounded),
            label: const Text('そろばんシミュレーター'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF168A7A),
              side: const BorderSide(color: Color(0xFF168A7A)),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(34),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _settingsCard(),
          const SizedBox(height: 18),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF262321),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFE05B3F),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.flash_on_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '一瞬の数字をつかむ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '集中力と暗算力を毎日トレーニング',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _achievementCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7DFD7)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 7),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF262321),
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF766D66), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7DFD7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ゲーム設定',
                  style: TextStyle(
                    color: Color(0xFF262321),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4DD),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'LEVEL $_level',
                  style: const TextStyle(
                    color: Color(0xFFC64932),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'レベル',
                style: TextStyle(color: Color(0xFF766D66), fontSize: 13),
              ),
              Expanded(
                child: Slider(
                  value: _level.toDouble(),
                  min: 1,
                  max: 99,
                  divisions: 98,
                  activeColor: const Color(0xFFE05B3F),
                  inactiveColor: const Color(0xFFE9D9D1),
                  onChanged: (value) => setState(() => _level = value.round()),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '$_level',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Color(0xFF262321),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          _autoSettingRow('桁数', '$_levelDigits 桁', Icons.pin_rounded),
          _autoSettingRow(
            '表示速度',
            '${(_levelSpeedMs / 1000).toStringAsFixed(2)}秒',
            Icons.speed_rounded,
          ),
          _autoSettingRow(
            '計算数',
            '$_levelTermCount 個',
            Icons.format_list_numbered_rounded,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              '掛け算を加える',
              style: TextStyle(color: Color(0xFF262321), fontSize: 14),
            ),
            subtitle: const Text(
              '難易度が上がります',
              style: TextStyle(color: Color(0xFF958A81), fontSize: 11),
            ),
            value: _multiplication,
            activeColor: const Color(0xFFE05B3F),
            onChanged: (value) => setState(() => _multiplication = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              '割り算を加える',
              style: TextStyle(color: Color(0xFF262321), fontSize: 14),
            ),
            subtitle: const Text(
              '小数の答えも出題されます',
              style: TextStyle(color: Color(0xFF958A81), fontSize: 11),
            ),
            value: _division,
            activeColor: const Color(0xFFE05B3F),
            onChanged: (value) => setState(() => _division = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              '引き算を加える',
              style: TextStyle(color: Color(0xFF262321), fontSize: 14),
            ),
            subtitle: const Text(
              '負の答えが出題される場合があります',
              style: TextStyle(color: Color(0xFF958A81), fontSize: 11),
            ),
            value: _subtraction,
            activeColor: const Color(0xFFE05B3F),
            onChanged: (value) => setState(() => _subtraction = value),
          ),
        ],
      ),
    );
  }

  Widget _autoSettingRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFE05B3F), size: 19),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF766D66), fontSize: 13),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF262321),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildFlashingPage() {
    return Scaffold(
      backgroundColor: const Color(0xFF262321),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _backToHome,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _sessionLabel,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 100),
              child: Text(
                _visibleTerm,
                key: ValueKey(_visibleTerm),
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 78,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${_termIndex < 0 ? 0 : _termIndex + 1} / ${_question?.terms.length ?? 0}',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownPage() {
    return Scaffold(
      backgroundColor: const Color(0xFF262321),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _backToHome,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _sessionLabel,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              _visibleTerm,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 84,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'まもなくスタート',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerPage() {
    return _pageScaffold(
      title: '答えを入力',
      onBack: _backToHome,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
        child: Column(
          children: [
            const Text(
              'いくつになりましたか？',
              style: TextStyle(color: Color(0xFF766D66), fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _answerController,
              readOnly: true,
              showCursor: false,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF262321),
                fontSize: 34,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: '答え',
                hintStyle: const TextStyle(color: Color(0xFFC9BDB4)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE7DFD7)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE7DFD7)),
                ),
              ),
            ),
            Expanded(child: const SizedBox()),
            _buildAnswerKeypad(),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitAnswer,
                icon: const Icon(Icons.check_rounded),
                label: const Text('答え合わせ'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE05B3F),
                  minimumSize: const Size.fromHeight(74),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultPage() {
    final correct = _lastCorrect == true;
    return _pageScaffold(
      title: 'ラウンド結果',
      onBack: _backToHome,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(
          children: [
            Icon(
              correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: correct
                  ? const Color(0xFF168A7A)
                  : const Color(0xFFE05B3F),
              size: 76,
            ),
            const SizedBox(height: 14),
            Text(
              correct ? '正解！' : 'あと一歩',
              style: TextStyle(
                color: correct
                    ? const Color(0xFF168A7A)
                    : const Color(0xFFE05B3F),
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE7DFD7)),
              ),
              child: Column(
                children: [
                  Text(
                    _lastExpression,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF766D66),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '正解  ${_formatNumber(_lastAnswer ?? 0)}',
                    style: const TextStyle(
                      color: Color(0xFF262321),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!correct) ...[
                    const SizedBox(height: 5),
                    Text(
                      'あなたの答え  ${_formatNumber(_lastUserAnswer ?? 0)}',
                      style: const TextStyle(
                        color: Color(0xFFE05B3F),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('もう一度'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE05B3F),
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _backToHome,
              child: const Text(
                '設定に戻る',
                style: TextStyle(color: Color(0xFF766D66)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlashCustomConfig {
  final int digits;
  final int speedMs;
  final int termCount;
  final bool multiplication;
  final bool division;
  final bool subtraction;

  const _FlashCustomConfig({
    required this.digits,
    required this.speedMs,
    required this.termCount,
    required this.multiplication,
    required this.division,
    required this.subtraction,
  });
}

class _FlashCustomSettingsPage extends StatefulWidget {
  final int initialDigits;
  final int initialSpeedMs;
  final int initialTermCount;
  final bool initialMultiplication;
  final bool initialDivision;
  final bool initialSubtraction;

  const _FlashCustomSettingsPage({
    required this.initialDigits,
    required this.initialSpeedMs,
    required this.initialTermCount,
    required this.initialMultiplication,
    required this.initialDivision,
    required this.initialSubtraction,
  });

  @override
  State<_FlashCustomSettingsPage> createState() =>
      _FlashCustomSettingsPageState();
}

class _FlashCustomSettingsPageState extends State<_FlashCustomSettingsPage> {
  late int _digits;
  late int _speedMs;
  late int _termCount;
  late bool _multiplication;
  late bool _division;
  late bool _subtraction;

  @override
  void initState() {
    super.initState();
    _digits = widget.initialDigits.clamp(1, 6);
    _speedMs = widget.initialSpeedMs.clamp(250, 1200);
    _termCount = widget.initialTermCount.clamp(3, 30);
    _multiplication = widget.initialMultiplication;
    _division = widget.initialDivision;
    _subtraction = widget.initialSubtraction;
  }

  void _start() {
    Navigator.pop(
      context,
      _FlashCustomConfig(
        digits: _digits,
        speedMs: _speedMs,
        termCount: _termCount,
        multiplication: _multiplication,
        division: _division,
        subtraction: _subtraction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF262321),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'カスタム設定',
          style: TextStyle(
            color: Color(0xFF262321),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          children: [
            const Text(
              '桁数・表示速度・計算数を自由に設定',
              style: TextStyle(color: Color(0xFF766D66), fontSize: 14),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE7DFD7)),
              ),
              child: Column(
                children: [
                  _customSliderRow(
                    label: '桁数',
                    value: '$_digits 桁',
                    slider: Slider(
                      value: _digits.toDouble(),
                      min: 1,
                      max: 6,
                      divisions: 5,
                      activeColor: const Color(0xFFE05B3F),
                      onChanged: (value) =>
                          setState(() => _digits = value.round()),
                    ),
                  ),
                  _customSliderRow(
                    label: '表示速度',
                    value: '${(_speedMs / 1000).toStringAsFixed(2)}秒',
                    slider: Slider(
                      value: _speedMs.toDouble(),
                      min: 250,
                      max: 1200,
                      divisions: 19,
                      activeColor: const Color(0xFFE05B3F),
                      onChanged: (value) =>
                          setState(() => _speedMs = (value / 50).round() * 50),
                    ),
                  ),
                  _customSliderRow(
                    label: '計算数',
                    value: '$_termCount 個',
                    slider: Slider(
                      value: _termCount.toDouble(),
                      min: 3,
                      max: 30,
                      divisions: 27,
                      activeColor: const Color(0xFFE05B3F),
                      onChanged: (value) =>
                          setState(() => _termCount = value.round()),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      '掛け算を加える',
                      style: TextStyle(color: Color(0xFF262321), fontSize: 14),
                    ),
                    value: _multiplication,
                    activeColor: const Color(0xFFE05B3F),
                    onChanged: (value) =>
                        setState(() => _multiplication = value),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      '割り算を加える',
                      style: TextStyle(color: Color(0xFF262321), fontSize: 14),
                    ),
                    value: _division,
                    activeColor: const Color(0xFFE05B3F),
                    onChanged: (value) => setState(() => _division = value),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      '引き算を加える',
                      style: TextStyle(color: Color(0xFF262321), fontSize: 14),
                    ),
                    value: _subtraction,
                    activeColor: const Color(0xFFE05B3F),
                    onChanged: (value) => setState(() => _subtraction = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('この設定で始める'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE05B3F),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customSliderRow({
    required String label,
    required String value,
    required Slider slider,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Color(0xFF766D66), fontSize: 13),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF262321),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        slider,
      ],
    );
  }
}

class FlashMathStatsPage extends StatefulWidget {
  const FlashMathStatsPage({super.key});

  @override
  State<FlashMathStatsPage> createState() => _FlashMathStatsPageState();
}

class _FlashMathStatsPageState extends State<FlashMathStatsPage> {
  @override
  void initState() {
    super.initState();
    FlashMathStore.instance.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  String _formatDate(DateTime date) =>
      '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final plays = FlashMathStore.instance.plays;
    final correct = plays.where((play) => play.isCorrect).length;
    final accuracy = plays.isEmpty ? 0 : (correct / plays.length * 100).round();
    final average = plays.isEmpty
        ? 0
        : plays.fold<int>(0, (sum, play) => sum + play.responseMs) ~/
              plays.length;
    final bestStreak = plays.fold<int>(
      0,
      (best, play) => math.max(best, play.streak),
    );
    final maxLevel = plays
        .where((play) => !play.isCustom && play.isCorrect)
        .fold<int>(0, (best, play) => math.max(best, play.level));
    final grouped = <String, List<FlashMathPlay>>{};
    for (final play in plays) {
      final key = play.isCustom
          ? 'custom:${play.digits}:${play.speedMs}:${play.termCount}:${play.multiplication}:${play.division}:${play.subtraction}'
          : 'level:${play.level}';
      grouped.putIfAbsent(key, () => []).add(play);
    }
    final groups = grouped.entries.toList()
      ..sort((a, b) {
        final aCustom = a.value.first.isCustom;
        final bCustom = b.value.first.isCustom;
        if (aCustom != bCustom) return aCustom ? 1 : -1;
        if (aCustom)
          return b.value.first.playedAt.compareTo(a.value.first.playedAt);
        return b.value.first.level.compareTo(a.value.first.level);
      });
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF262321),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '詳しい統計',
          style: TextStyle(
            color: Color(0xFF262321),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          children: [
            Row(
              children: [
                _statValue('総プレイ', '${plays.length}回'),
                const SizedBox(width: 8),
                _statValue('正答率', '$accuracy%'),
                const SizedBox(width: 8),
                _statValue('平均回答', '${(average / 1000).toStringAsFixed(1)}秒'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _statValue('最高レベル', '$maxLevel'),
                const SizedBox(width: 8),
                _statValue('最長連続', '$bestStreak問'),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              '設定別成績',
              style: TextStyle(
                color: Color(0xFF262321),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (groups.isEmpty)
              const Text(
                'プレイするとレベル別の成績が表示されます',
                style: TextStyle(color: Color(0xFF766D66), fontSize: 13),
              )
            else
              ...groups.map(
                (group) => _statsGroupTile(
                  group.value.first.configurationLabel,
                  group.value,
                ),
              ),
            const SizedBox(height: 22),
            const Text(
              'プレイ履歴（最新50件）',
              style: TextStyle(
                color: Color(0xFF262321),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (plays.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'まだプレイ履歴がありません',
                    style: TextStyle(color: Color(0xFF766D66)),
                  ),
                ),
              )
            else
              ...plays.take(50).map(_historyTile),
          ],
        ),
      ),
    );
  }

  Widget _statValue(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7DFD7)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF262321),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF766D66), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsGroupTile(String label, List<FlashMathPlay> group) {
    final correct = group.where((play) => play.isCorrect).toList();
    final accuracy = (correct.length / group.length * 100).round();
    final bestMs = correct.isEmpty
        ? null
        : correct.map((play) => play.responseMs).reduce(math.min);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7DFD7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF262321),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${group.length}回',
                style: const TextStyle(
                  color: Color(0xFFE05B3F),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '正解 ${correct.length}回  /  不正解 ${group.length - correct.length}回  /  正答率 $accuracy%',
            style: const TextStyle(color: Color(0xFF766D66), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            bestMs == null
                ? 'クリア記録なし'
                : '最短クリア ${(bestMs / 1000).toStringAsFixed(1)}秒',
            style: TextStyle(
              color: bestMs == null
                  ? const Color(0xFF958A81)
                  : const Color(0xFF168A7A),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyTile(FlashMathPlay play) {
    final color = play.isCorrect
        ? const Color(0xFF168A7A)
        : const Color(0xFFE05B3F);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7DFD7)),
      ),
      child: Row(
        children: [
          Icon(
            play.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 23,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  play.expression,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF262321),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${play.configurationLabel}  ·  ${_formatDate(play.playedAt)}  ·  ${(play.responseMs / 1000).toStringAsFixed(1)}秒',
                  style: const TextStyle(
                    color: Color(0xFF958A81),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            play.isCorrect ? '正解' : '不正解',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

String _formatNumber(double value) {
  if (value.isNaN || value.isInfinite) return '0';
  final isNegative = value < 0;
  final absolute = value.abs();
  final raw = (absolute - absolute.roundToDouble()).abs() < 0.0000001
      ? absolute.round().toString()
      : absolute
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
  final parts = raw.split('.');
  final integerPart = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return '${isNegative ? '-' : ''}$integerPart${parts.length > 1 ? '.${parts[1]}' : ''}';
}
