import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

enum AiModel { local, openrouter }

class GemmaAi {
  bool _isInit = false;
  static const _channel = MethodChannel('com.newluncher/litert_lm');
  AiModel _currentModel = AiModel.openrouter;
  static const String _openRouterKey = "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";

  Completer<void>? _queryLock;

  static GemmaAi? _instance;
  factory GemmaAi() => _instance ??= GemmaAi._create();
  GemmaAi._create();

  bool get isInitialized => _isInit;
  AiModel get currentModel => _currentModel;

  Future<void> initWithPath(String modelPath) async {
    if (_isInit) return;
    try {
      await _channel.invokeMethod('initEngine', {'modelPath': modelPath});
      _isInit = true;
      _currentModel = AiModel.local;
    } catch (e) {
      if (kDebugMode) print("Engine init failed: $e");
    }
  }

  Future<void> close() async {
    if (_isInit) {
      await _channel.invokeMethod('closeEngine');
      _isInit = false;
    }
  }

  Future<String> query(String prompt, {String? systemPrompt}) async =>
      _query(prompt, systemPrompt: systemPrompt);

  Future<String> _query(String prompt, {String? systemPrompt}) async {
    if (_currentModel == AiModel.openrouter) {
      return await _queryOpenRouter(prompt, systemPrompt: systemPrompt);
    }
    if (!_isInit) return "";

    while (_queryLock != null) {
      await _queryLock!.future;
    }
    _queryLock = Completer<void>();

    try {
      final sp = systemPrompt ?? "You are a helpful assistant. Reply concisely.";
      final formattedPrompt =
          "<start_of_turn>user\n$sp\n$prompt<end_of_turn>\n<start_of_turn>model\n";

      if (kDebugMode) print("AI Prompt (Local):\n$formattedPrompt");

      final response = await _channel
          .invokeMethod<String>('query', {'prompt': formattedPrompt})
          .timeout(const Duration(seconds: 90));

      final trimmed = response?.trim() ?? "";
      if (kDebugMode) print("AI Response (Local):\n$trimmed");
      return trimmed;
    } on TimeoutException {
      if (kDebugMode) print("Query timed out");
      return "";
    } catch (e) {
      if (kDebugMode) print("Query error: $e");
      return "";
    } finally {
      final lock = _queryLock;
      _queryLock = null;
      lock?.complete();
    }
  }

  Future<String> _queryOpenRouter(String prompt, {String? systemPrompt}) async {
    final dio = Dio();
    try {
      final sp = systemPrompt ?? "You are a helpful assistant. Reply concisely.";
      if (kDebugMode) print("AI Prompt (OpenRouter):\n$prompt");

      final response = await dio.post(
        'https://openrouter.ai/api/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_openRouterKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://github.com/newluncher',
            'X-Title': 'aicalcapp',
          },
          responseType: ResponseType.json,
        ),
        data: jsonEncode({
          'model': 'tencent/hy3-preview:free',
          'messages': [
            {'role': 'system', 'content': sp},
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      final body = response.data is String
          ? jsonDecode(response.data as String) as Map
          : response.data as Map;
      final choice = (body['choices'] as List?)?.first as Map?;
      if (choice == null) return '';
      final content = (choice['message'] as Map?)?['content'];
      final result = content?.toString().trim() ?? '';
      if (kDebugMode) print("AI Response (OpenRouter):\n$result");
      return result;
    } on DioException catch (e) {
      if (kDebugMode) print("OpenRouter error: ${e.response?.statusCode}\n${e.response?.data}");
      return "";
    } catch (e) {
      if (kDebugMode) print("OpenRouter error: $e");
      return "";
    }
  }

  Future<int?> countInImage(Uint8List imageBytes, String instruction) async {
    if (_currentModel == AiModel.openrouter) {
      return await _countInImageOpenRouter(imageBytes, instruction);
    }
    return await _countInImageLocal(imageBytes, instruction);
  }

  Future<int?> _countInImageLocal(Uint8List imageBytes, String instruction) async {
    if (!_isInit) return null;

    while (_queryLock != null) {
      await _queryLock!.future;
    }
    _queryLock = Completer<void>();

    try {
      final prompt =
          'この画像の中にある「$instruction」を注意深く数えて、その個数を整数（数字のみ）で答えてください。説明・単位・記号は一切不要です。整数1つだけを返してください。';
      final response = await _channel
          .invokeMethod<String>('queryWithImage', {
            'prompt': prompt,
            'imageBytes': imageBytes,
          })
          .timeout(const Duration(seconds: 120));
      final trimmed = response?.trim() ?? '';
      final match = RegExp(r'\d+').firstMatch(trimmed);
      return match != null ? int.tryParse(match.group(0)!) : null;
    } on TimeoutException {
      return null;
    } catch (e) {
      if (kDebugMode) print('countInImage local error: $e');
      return null;
    } finally {
      final lock = _queryLock;
      _queryLock = null;
      lock?.complete();
    }
  }

  Future<int?> _countInImageOpenRouter(Uint8List imageBytes, String instruction) async {
    final dio = Dio();
    try {
      final base64Image = base64Encode(imageBytes);
      final response = await dio.post(
        'https://openrouter.ai/api/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_openRouterKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://github.com/newluncher',
            'X-Title': 'aicalcapp',
          },
          responseType: ResponseType.json,
        ),
        data: jsonEncode({
          'model': 'tencent/hy3-preview:free',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
                },
                {
                  'type': 'text',
                  'text':
                      'この画像の中にある「$instruction」を注意深く数えて、その個数を整数（数字のみ）で答えてください。説明・単位・記号は一切不要です。整数1つだけを返してください。',
                },
              ],
            },
          ],
        }),
      );
      final body = response.data is String
          ? jsonDecode(response.data as String) as Map
          : response.data as Map;
      final choice = (body['choices'] as List?)?.first as Map?;
      final content = (choice?['message'] as Map?)?['content']?.toString().trim() ?? '';
      final match = RegExp(r'\d+').firstMatch(content);
      return match != null ? int.tryParse(match.group(0)!) : null;
    } on DioException catch (e) {
      if (kDebugMode) print('countInImage OpenRouter error: ${e.response?.statusCode}');
      return null;
    } catch (e) {
      if (kDebugMode) print('countInImage error: $e');
      return null;
    }
  }
}

// ── Grounding DINO バウンディングボックス ──────────────────────────────────────
class BoundingBox {
  final double xmin, ymin, xmax, ymax;

  const BoundingBox({
    required this.xmin,
    required this.ymin,
    required this.xmax,
    required this.ymax,
  });

  double get width => xmax - xmin;
  double get height => ymax - ymin;
  double get area => width * height;

  /// IoU（Intersection over Union）計算
  double iou(BoundingBox other) {
    final xi1 = xmin > other.xmin ? xmin : other.xmin;
    final yi1 = ymin > other.ymin ? ymin : other.ymin;
    final xi2 = xmax < other.xmax ? xmax : other.xmax;
    final yi2 = ymax < other.ymax ? ymax : other.ymax;
    final interW = xi2 - xi1;
    final interH = yi2 - yi1;
    if (interW <= 0 || interH <= 0) return 0.0;
    final inter = interW * interH;
    return inter / (area + other.area - inter);
  }
}

// ── Grounding DINO 検出結果 ───────────────────────────────────────────────────
class GroundingDinoDetection {
  final double score;
  final String label;
  final BoundingBox box;

  const GroundingDinoDetection({
    required this.score,
    required this.label,
    required this.box,
  });
}

// ── Grounding DINO 1.5 Edge サービス ─────────────────────────────────────────
// HuggingFace Inference API で IDEA-Research/grounding-dino-base を呼び出す。
// 検出後に Dart 実装の NMS（OpenCV の NMSBoxes 相当）で重複除去してカウントする。
class GroundingDinoService {
  /// HuggingFace API トークン（hf_xxx...）。
  /// アプリ起動時または設定画面で GroundingDinoService.hfToken = '...' で設定する。
  static String hfToken = '';

  /// 使用するモデル ID（Grounding DINO base / HuggingFace 公開版）。
  /// Grounding DINO 1.5 Edge の HF 公開モデルが利用可能になった場合は差し替え可能。
  static const String modelId = 'IDEA-Research/grounding-dino-base';

  /// 検出スコアの閾値（0〜1）。
  static const double defaultConfidence = 0.25;

  /// NMS の IoU 閾値（これ以上重なるボックスを除去 = OpenCV NMSBoxes 相当）。
  static const double _nmsIouThreshold = 0.45;

  bool get hasToken => hfToken.isNotEmpty;

  /// 画像から指定ラベルの物体を検出し、NMS 適用済みの検出リストを返す。
  Future<List<GroundingDinoDetection>> detect(
    Uint8List imageBytes,
    String label, {
    double confidence = defaultConfidence,
  }) async {
    if (hfToken.isEmpty) {
      throw Exception(
        'HuggingFace APIトークンが未設定です。GroundingDinoService.hfToken を設定してください。',
      );
    }

    final dio = Dio();
    final base64Image = base64Encode(imageBytes);

    final response = await dio
        .post(
          'https://api-inference.huggingface.co/models/$modelId',
          options: Options(
            headers: {
              'Authorization': 'Bearer $hfToken',
              'Content-Type': 'application/json',
            },
            responseType: ResponseType.json,
          ),
          data: jsonEncode({
            'inputs': base64Image,
            'parameters': {
              'candidate_labels': [label],
              'threshold': confidence,
            },
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.data is! List) {
      throw Exception(
        'APIレスポンス形式が不正です: ${response.data.runtimeType}\n${response.data}',
      );
    }

    final raw = response.data as List;
    final detections =
        raw
            .map((d) {
              final map = Map<String, dynamic>.from(d as Map);
              final boxMap = Map<String, dynamic>.from(map['box'] as Map);
              return GroundingDinoDetection(
                score: (map['score'] as num).toDouble(),
                label: map['label']?.toString() ?? label,
                box: BoundingBox(
                  xmin: (boxMap['xmin'] as num).toDouble(),
                  ymin: (boxMap['ymin'] as num).toDouble(),
                  xmax: (boxMap['xmax'] as num).toDouble(),
                  ymax: (boxMap['ymax'] as num).toDouble(),
                ),
              );
            })
            .where((d) => d.score >= confidence)
            .toList();

    // NMS（OpenCV の cv2.NMSBoxes と同等）で重複検出を除去してカウントを正確にする
    return _applyNms(detections, _nmsIouThreshold);
  }

  /// Non-Maximum Suppression:
  /// スコア降順でソートし、IoU が閾値を超える低スコアのボックスを抑制する。
  List<GroundingDinoDetection> _applyNms(
    List<GroundingDinoDetection> detections,
    double iouThreshold,
  ) {
    if (detections.isEmpty) return [];
    final sorted = [...detections]..sort((a, b) => b.score.compareTo(a.score));
    final suppressed = List.filled(sorted.length, false);
    final result = <GroundingDinoDetection>[];
    for (int i = 0; i < sorted.length; i++) {
      if (suppressed[i]) continue;
      result.add(sorted[i]);
      for (int j = i + 1; j < sorted.length; j++) {
        if (!suppressed[j] &&
            sorted[i].box.iou(sorted[j].box) > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }
    return result;
  }
}
