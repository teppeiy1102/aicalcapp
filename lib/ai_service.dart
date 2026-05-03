import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

enum AiModel { local, openrouter }

class GemmaAi {
  bool _isInit = false;
  static const _channel = MethodChannel('com.newluncher/litert_lm');
  AiModel _currentModel = AiModel.openrouter;
  static const String _openRouterKey = "";

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
          'model': 'deepseek/deepseek-v3-0324',
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
          'model': 'meta-llama/llama-4-maverick',
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
