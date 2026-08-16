import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AiModel { local, openrouter }

String _imageMimeType(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return 'image/png';
  }
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    return 'image/gif';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return 'image/jpeg';
}

bool isImageCategoryCountRequest(String instruction) => RegExp(
  r'色|割合|比率|構成比|内訳|種類|カテゴリ|男女|人数|個数|合計|count|ratio|percentage|proportion|color|category|total|number|people',
  caseSensitive: false,
).hasMatch(instruction);

String compactAiTitle(String value, {required String fallback}) {
  final title = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (title.isEmpty) return fallback;
  return title.length > 12 ? title.substring(0, 12) : title;
}

String _buildCountPrompt(String instruction) =>
    '''画像内の対象物を、計算に使える個数データへ変換してください。
依頼: 「$instruction」

次の手順を守って画像を解析してください。
1. 依頼文から「何を1個と数えるか」を特定し、対象物だけを数える。背景、文字、模様、影、反射、同じ物体の写り込みは数えない。
2. 画像全体を左上から右下まで走査し、見えている各対象物を1回だけ数える。重なっていても、別の物体として確認できるものはそれぞれ数える。部分的に見える物体は、実在すると確認できる場合だけ1個として数え、推測で補わない。
3. 色・種類・カテゴリの指定がある場合は、依頼に必要なカテゴリだけを使う。カテゴリは互いに重ならないようにし、1つの物体を複数カテゴリへ重複計上しない。カテゴリを求められた場合は、画像内で確認できる各カテゴリをitemsに分ける。
4. 最後に別の走査を行い、各itemsのcountと、対象物を全体で数えた数を照合する。見落としや二重計上を修正してから返す。

countは必ず0以上の整数にしてください。判別できない対象を想像で追加しないでください。
pointsには、数えた各対象物の中心点を対象物ごとに1点ずつ入れてください。座標は必ず画像左上を原点とする0〜1000の整数で、[x, y]（xは左から右、yは上から下）としてください。座標の順番はcountと一致させ、確実に特定できない場合だけ空配列にしてください。説明、計算式、Markdownは出力しないでください。

JSONのみで返してください。形式は {"items":[{"target":"色または対象カテゴリ","count":整数,"points":[]}]} です。''';

double _normalizePointCoordinate(num value, {required bool usesThousandScale}) {
  final coordinate = value.toDouble();
  final normalized = usesThousandScale ? coordinate / 1000.0 : coordinate;
  return normalized.clamp(0.0, 1.0).toDouble();
}

List<List<double>> _normalizePoints(List<dynamic>? rawPoints) {
  final points =
      rawPoints
          ?.whereType<List>()
          .where(
            (point) => point.length >= 2 && point[0] is num && point[1] is num,
          )
          .toList() ??
      [];
  final usesThousandScale = points.any(
    (point) => (point[0] as num).abs() > 1 || (point[1] as num).abs() > 1,
  );
  return points
      .map(
        (point) => [
          _normalizePointCoordinate(
            point[0] as num,
            usesThousandScale: usesThousandScale,
          ),
          _normalizePointCoordinate(
            point[1] as num,
            usesThousandScale: usesThousandScale,
          ),
        ],
      )
      .toList();
}

class AiCountItem {
  final String target;
  final int count;
  final List<List<double>> points;

  const AiCountItem({
    required this.target,
    required this.count,
    required this.points,
  });

  factory AiCountItem.fromJson(Map<String, dynamic> json) {
    final points = _normalizePoints(json['points'] as List<dynamic>?);
    return AiCountItem(
      target:
          json['target'] as String? ??
          json['label'] as String? ??
          json['instruction'] as String? ??
          '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      points: points,
    );
  }

  Map<String, dynamic> toJson() => {
    'target': target,
    'count': count,
    'points': points,
  };
}

class AiCountResult {
  final List<AiCountItem> items;

  const AiCountResult({required this.items});

  int get count => items.fold(0, (total, item) => total + item.count);
  String get additionExpression => items.map((item) => item.count).join(' + ');
  List<List<double>> get points => [for (final item in items) ...item.points];
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

  Future<String> queryWithImage(
    String prompt,
    Uint8List imageBytes, {
    String? systemPrompt,
  }) async {
    if (_currentModel == AiModel.openrouter) {
      return await _queryWithImageOpenRouter(
        prompt,
        imageBytes,
        systemPrompt: systemPrompt,
      );
    }
    return await _queryWithImageLocal(
      prompt,
      imageBytes,
      systemPrompt: systemPrompt,
    );
  }

  Future<String> _queryWithImageLocal(
    String prompt,
    Uint8List imageBytes, {
    String? systemPrompt,
  }) async {
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

      final response = await _channel
          .invokeMethod<String>('queryWithImage', {
            'prompt': formattedPrompt,
            'imageBytes': imageBytes,
          })
          .timeout(const Duration(seconds: 120));

      return response?.trim() ?? "";
    } catch (e) {
      if (kDebugMode) print("Query with image error: $e");
      return "";
    } finally {
      final lock = _queryLock;
      _queryLock = null;
      lock?.complete();
    }
  }

  Future<String> _queryWithImageOpenRouter(
    String prompt,
    Uint8List imageBytes, {
    String? systemPrompt,
  }) async {
    final dio = Dio();
    try {
      final base64Image = base64Encode(imageBytes);
      final mimeType = _imageMimeType(imageBytes);
      final sp =
          systemPrompt ?? "You are a helpful assistant. Reply concisely.";

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
          //    'model': 'moonshotai/kimi-k3',
          'model': 'google/gemini-3.6-flash',
          //'model': 'openai/gpt-5.6-luna',
          //    'model': '~anthropic/claude-fable-latest',
          'messages': [
            {'role': 'system', 'content': sp},
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:$mimeType;base64,$base64Image',
                    'detail': 'high',
                  },
                },
                {'type': 'text', 'text': prompt},
              ],
            },
          ],
        }),
      );

      final body = response.data is String
          ? jsonDecode(response.data as String) as Map
          : response.data as Map;
      final choice = (body['choices'] as List?)?.first as Map?;
      if (choice == null) return '';
      final content = (choice['message'] as Map?)?['content'];
      return content?.toString().trim() ?? '';
    } catch (e) {
      if (kDebugMode) print('OpenRouter query with image error: $e');
      return '';
    }
  }

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
          'model': 'google/gemini-3.6-flash',
          //'model': 'moonshotai/kimi-k3',
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
    String instruction, {
    bool requireCategories = false,
  }) async {
    if (_currentModel == AiModel.openrouter) {
      return await _countInImageOpenRouter(
        imageBytes,
        instruction,
        requireCategories: requireCategories,
      );
    }
    return await _countInImageLocal(
      imageBytes,
      instruction,
      requireCategories: requireCategories,
    );
  }

  Future<AiCountResult?> _countInImageLocal(
    Uint8List imageBytes,
    String instruction, {
    bool requireCategories = false,
  }) async {
    if (!_isInit) return null;

    while (_queryLock != null) {
      await _queryLock!.future;
    }
    _queryLock = Completer<void>();

    try {
      final prompt = _buildCountPrompt(instruction);
      final response = await _channel
          .invokeMethod<String>('queryWithImage', {
            'prompt': prompt,
            'imageBytes': imageBytes,
          })
          .timeout(const Duration(seconds: 120));
      final trimmed = response?.trim() ?? '';
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(trimmed);
      if (jsonMatch != null) {
        try {
          final data = jsonDecode(jsonMatch.group(0)!);
          final rawItems = data['items'] as List?;
          if (rawItems != null && rawItems.isNotEmpty) {
            final items = rawItems
                .whereType<Map>()
                .map((item) {
                  final target =
                      item['target'] as String? ??
                      item['label'] as String? ??
                      item['instruction'] as String? ??
                      '';
                  if (requireCategories && target.trim().isEmpty) return null;
                  final parsed = AiCountItem.fromJson(
                    Map<String, dynamic>.from(item),
                  );
                  return AiCountItem(
                    target: parsed.target.isEmpty ? instruction : parsed.target,
                    count: parsed.count,
                    points: parsed.points,
                  );
                })
                .whereType<AiCountItem>()
                .toList();
            if (items.isNotEmpty) return AiCountResult(items: items);
          }
        } catch (_) {}
      }
      if (requireCategories) return null;
      final match = RegExp(r'\d+').firstMatch(trimmed);
      final count = match != null ? int.tryParse(match.group(0)!) : null;
      if (count == null) return null;
      return AiCountResult(
        items: [AiCountItem(target: instruction, count: count, points: [])],
      );
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
    String instruction, {
    bool requireCategories = false,
  }) async {
    final dio = Dio();
    try {
      final base64Image = base64Encode(imageBytes);
      final mimeType = _imageMimeType(imageBytes);
      if (kDebugMode) print('countInImage (OpenRouter): 送信中...');

      final prompt = _buildCountPrompt(instruction);

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
              'response_format': {'type': 'json_object'},
              'temperature': 0,
              //'model': 'openai/gpt-5.6-luna',
              'model': 'google/gemini-3.6-flash',
              //'model': 'moonshotai/kimi-k3',
              //  'model': 'anthropic/claude-fable-latest',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:$mimeType;base64,$base64Image',
                        'detail': 'high',
                      },
                    },
                    {'type': 'text', 'text': prompt},
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 120));

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
        final rawItems = data['items'] as List?;
        if (rawItems != null) {
          final items = rawItems
              .whereType<Map>()
              .map((item) {
                final target =
                    item['target'] as String? ??
                    item['label'] as String? ??
                    item['instruction'] as String? ??
                    '';
                if (requireCategories && target.trim().isEmpty) return null;
                final parsed = AiCountItem.fromJson(
                  Map<String, dynamic>.from(item),
                );
                return AiCountItem(
                  target: parsed.target.isEmpty ? instruction : parsed.target,
                  count: parsed.count,
                  points: parsed.points,
                );
              })
              .whereType<AiCountItem>()
              .toList();
          if (items.isNotEmpty) return AiCountResult(items: items);
        }

        if (requireCategories) return null;
        final count = (data['count'] as num?)?.toInt();
        if (count != null) {
          final pointsRaw = data['points'] as List? ?? [];
          final points = _normalizePoints(pointsRaw);
          return AiCountResult(
            items: [
              AiCountItem(target: instruction, count: count, points: points),
            ],
          );
        }
      }

      // フォールバック: 以前の単純なパース
      if (requireCategories) return null;
      final match = RegExp(r'\d+').firstMatch(content);
      final count = match != null ? int.tryParse(match.group(0)!) : null;
      if (count != null) {
        return AiCountResult(
          items: [AiCountItem(target: instruction, count: count, points: [])],
        );
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
