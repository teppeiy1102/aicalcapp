import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AiModel { local, openrouter }

class AiCountResult {
  final int count;
  final List<List<double>> points; // Normalized coordinates [x, y] (0.0 to 1.0)
  AiCountResult({required this.count, required this.points});
}

class GemmaAi {
  bool _isInit = false;
  static const _channel = MethodChannel('com.newluncher/litert_lm');
  AiModel _currentModel = AiModel.openrouter;
  String get _openRouterKey => dotenv.env['OPENROUTER_KEY'] ?? '';

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
      final sp =
          systemPrompt ?? "You are a helpful assistant. Reply concisely.";
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
      final sp =
          systemPrompt ?? "You are a helpful assistant. Reply concisely.";
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
          'model': '~google/gemini-flash-latest',
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
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final msg = 'OpenRouter エラー ($status): $body';
      if (kDebugMode) print(msg);
      throw Exception(msg);
    } catch (e) {
      if (kDebugMode) print('OpenRouter error: $e');
      rethrow;
    }
  }

  /// 画像内の指定物体をカウントする（OpenRouter ビジョン LLM を使用）
  Future<AiCountResult?> countInImage(
    Uint8List imageBytes,
    String instruction,
  ) async {
    if (_currentModel == AiModel.openrouter) {
      return await _countInImageOpenRouter(imageBytes, instruction);
    }
    return await _countInImageLocal(imageBytes, instruction);
  }

  Future<AiCountResult?> _countInImageLocal(
    Uint8List imageBytes,
    String instruction,
  ) async {
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
      final count = match != null ? int.tryParse(match.group(0)!) : null;
      if (count == null) return null;
      return AiCountResult(count: count, points: []);
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

  Future<AiCountResult?> _countInImageOpenRouter(
    Uint8List imageBytes,
    String instruction,
  ) async {
    final dio = Dio();
    try {
      final base64Image = base64Encode(imageBytes);
      if (kDebugMode) print('countInImage (OpenRouter): 送信中...');

      final prompt =
          '''
あなたは野鳥の会のベテランバードウォッチャーです。
この画像の中にある「$instruction」を見つけてください。
精度を高めるために、以下のステップで思考してください：
1. 画像内のすべての対象物を左上から順に番号を振り、それぞれの中心座標 [x, y] (0から1000の正規化座標) を特定してください。
2. 重なり合っているものも個別に見つけてください。
3. 背景の模様や無関係な物体をカウントに含めないよう注意してください。
4. 20個以上の場合や、あいまいな場合は正確に数えるためにズームインして確認してください。
5. 3度数えても同じ結果が出ない場合は、3度目の結果を採用してください。

最後に、以下の形式のJSONのみを返してください。他の説明やテキストは一切含めないでください。
{
  "count": 総数(整数),
  "points": [[x1, y1], [x2, y2], ...]
}
''';

      final response = await dio
          .post(
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
              'model': '~google/gemini-flash-latest',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:image/jpeg;base64,$base64Image',
                      },
                    },
                    {'type': 'text', 'text': prompt},
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 60));

      final body = response.data is String
          ? jsonDecode(response.data as String) as Map
          : response.data as Map;
      final choice = (body['choices'] as List?)?.first as Map?;
      final content =
          (choice?['message'] as Map?)?['content']?.toString().trim() ?? '';
      if (kDebugMode) print('countInImage (OpenRouter) response: $content');

      // JSONの抽出
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final data = jsonDecode(jsonStr);
        final count = data['count'] as int;
        final pointsRaw = data['points'] as List;
        final points = pointsRaw.map((p) {
          final lp = p as List;
          return [
            (lp[0] as num).toDouble() / 1000.0,
            (lp[1] as num).toDouble() / 1000.0,
          ];
        }).toList();
        return AiCountResult(count: count, points: points);
      }

      // フォールバック: 以前の単純なパース
      final match = RegExp(r'\d+').firstMatch(content);
      final count = match != null ? int.tryParse(match.group(0)!) : null;
      if (count != null) {
        return AiCountResult(count: count, points: []);
      }
      return null;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('countInImage OpenRouter error: ${e.response?.statusCode}');
        print('response: ${e.response?.data}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('countInImage error: $e');
      return null;
    }
  }
}
