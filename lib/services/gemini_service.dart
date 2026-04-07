import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/clip_timeline.dart';

/// Gemini AI 服務 — 串接 Google Gemini 1.5 Flash API
///
/// 功能：
/// - 影片語音分析（去冗言）
/// - 影片字幕生成
/// - 智能成片分析（找出最佳片段）
/// - 名片文案生成
///
/// 檔案大小策略：
/// - < 20MB：inline base64 直接送
/// - >= 20MB：File API 上傳後送
class GeminiService {
  static const _baseUrl = 'https://generativelanguage.googleapis.com';
  static const _model = 'gemini-1.5-flash';
  static const _maxInlineSize = 20 * 1024 * 1024; // 20MB

  final String apiKey;

  GeminiService({required this.apiKey});

  bool get isConfigured => apiKey.isNotEmpty;

  // ========== 底層 API 呼叫 ==========

  /// 分析影片（自動選擇 inline 或 File API）
  Future<String> analyzeVideo(String videoPath, String prompt) async {
    final file = File(videoPath);
    if (!await file.exists()) {
      throw GeminiException('影片檔案不存在: $videoPath');
    }

    final fileSize = await file.length();
    final mimeType = _getMimeType(videoPath);

    if (fileSize <= _maxInlineSize) {
      return _generateInline(file, mimeType, prompt);
    } else {
      return _generateWithFileApi(videoPath, mimeType, prompt);
    }
  }

  /// 純文字生成（不需要影片）
  Future<String> generateText(String prompt) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/v1beta/models/$_model:generateContent?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'responseMimeType': 'application/json',
        },
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw GeminiException('API 錯誤 (${response.statusCode}): ${_parseError(response.body)}');
    }

    return _extractText(response.body);
  }

  /// 小檔案：base64 inline 直送
  Future<String> _generateInline(
      File file, String mimeType, String prompt) async {
    _log('使用 inline 模式（檔案 < 20MB）');
    final bytes = await file.readAsBytes();
    final base64Data = base64Encode(bytes);

    final response = await http
        .post(
          Uri.parse(
              '$_baseUrl/v1beta/models/$_model:generateContent?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'inlineData': {
                      'mimeType': mimeType,
                      'data': base64Data,
                    }
                  },
                  {'text': prompt},
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.2,
              'responseMimeType': 'application/json',
            },
          }),
        )
        .timeout(const Duration(minutes: 3));

    if (response.statusCode != 200) {
      throw GeminiException(
          'API 錯誤 (${response.statusCode}): ${_parseError(response.body)}');
    }

    return _extractText(response.body);
  }

  /// 大檔案：File API 上傳後分析
  Future<String> _generateWithFileApi(
      String filePath, String mimeType, String prompt) async {
    _log('使用 File API 模式（檔案 >= 20MB）');
    final file = File(filePath);
    final fileSize = await file.length();
    final displayName = filePath.split('/').last;

    // Step 1: 開始上傳
    _log('Step 1: 初始化上傳...');
    final initResponse = await http.post(
      Uri.parse('$_baseUrl/upload/v1beta/files?key=$apiKey'),
      headers: {
        'X-Goog-Upload-Protocol': 'resumable',
        'X-Goog-Upload-Command': 'start',
        'X-Goog-Upload-Header-Content-Length': fileSize.toString(),
        'X-Goog-Upload-Header-Content-Type': mimeType,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'file': {'displayName': displayName}
      }),
    );

    if (initResponse.statusCode != 200) {
      throw GeminiException('上傳初始化失敗: ${_parseError(initResponse.body)}');
    }

    final uploadUrl = initResponse.headers['x-goog-upload-url'];
    if (uploadUrl == null) {
      throw GeminiException('無法取得上傳 URL');
    }

    // Step 2: 上傳檔案位元組
    _log('Step 2: 上傳影片（${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB）...');
    final fileBytes = await file.readAsBytes();
    final uploadResponse = await http
        .put(
          Uri.parse(uploadUrl),
          headers: {
            'Content-Length': fileSize.toString(),
            'X-Goog-Upload-Offset': '0',
            'X-Goog-Upload-Command': 'upload, finalize',
          },
          body: fileBytes,
        )
        .timeout(const Duration(minutes: 5));

    if (uploadResponse.statusCode != 200) {
      throw GeminiException('上傳失敗: ${_parseError(uploadResponse.body)}');
    }

    final fileInfo = jsonDecode(uploadResponse.body);
    final fileUri = fileInfo['file']['uri'] as String;
    final fileName = fileInfo['file']['name'] as String;

    // Step 3: 等待處理完成
    _log('Step 3: 等待 Gemini 處理影片...');
    await _waitForActive(fileName);

    // Step 4: 生成分析內容
    _log('Step 4: Gemini 分析中...');
    try {
      final genResponse = await http
          .post(
            Uri.parse(
                '$_baseUrl/v1beta/models/$_model:generateContent?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {
                      'fileData': {
                        'mimeType': mimeType,
                        'fileUri': fileUri,
                      }
                    },
                    {'text': prompt},
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.2,
                'responseMimeType': 'application/json',
              },
            }),
          )
          .timeout(const Duration(minutes: 3));

      if (genResponse.statusCode != 200) {
        throw GeminiException(
            '分析失敗 (${genResponse.statusCode}): ${_parseError(genResponse.body)}');
      }

      return _extractText(genResponse.body);
    } finally {
      // 清理已上傳的檔案
      _deleteFile(fileName);
    }
  }

  /// 等待已上傳檔案處理完成
  Future<void> _waitForActive(String fileName) async {
    for (int i = 0; i < 30; i++) {
      final response = await http.get(
        Uri.parse('$_baseUrl/v1beta/$fileName?key=$apiKey'),
      );
      if (response.statusCode == 200) {
        final info = jsonDecode(response.body);
        final state = info['state'];
        if (state == 'ACTIVE') {
          _log('檔案處理完成');
          return;
        }
        if (state == 'FAILED') throw GeminiException('Gemini 檔案處理失敗');
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    throw GeminiException('Gemini 檔案處理逾時（超過 60 秒）');
  }

  /// 刪除已上傳的檔案
  Future<void> _deleteFile(String fileName) async {
    try {
      await http.delete(
        Uri.parse('$_baseUrl/v1beta/$fileName?key=$apiKey'),
      );
      _log('已清理上傳檔案: $fileName');
    } catch (_) {
      // 清理失敗不影響主流程
    }
  }

  // ========== 高階 AI 功能 ==========

  /// AI 去冗言 — 分析影片中的口頭禪和冗言贅詞
  Future<Map<String, dynamic>> analyzeFillerWords(String videoPath) async {
    const prompt = '你是一位專業的影片語音分析師。請仔細聆聽這段影片中的語音，找出所有冗言贅詞。\n\n'
        '冗言贅詞包括但不限於：嗯、啊、呃、那個、就是、就是說、然後、然後呢、對、對對對、'
        '基本上、所以說、怎麼說呢 等口頭禪和無意義填充詞。\n\n'
        '請以以下 JSON 格式回傳結果：\n'
        '{"fillerWords":[{"word":"嗯","startTime":1.2,"endTime":1.5}],'
        '"totalFound":3,"summary":"共找到 3 處冗言贅詞"}';

    final text = await analyzeVideo(videoPath, prompt);
    return jsonDecode(_cleanJson(text)) as Map<String, dynamic>;
  }

  /// AI 字幕 — 將影片語音轉為逐句中文字幕
  Future<Map<String, dynamic>> generateSubtitles(String videoPath) async {
    const prompt = '你是一位專業的字幕生成師。請將這段影片的語音內容轉為逐句中文字幕。\n\n'
        '規則：\n'
        '- 每句字幕不超過 20 個字\n'
        '- 時間精確到小數點後一位\n'
        '- 如果語音是中文就用中文；其他語言請翻譯成中文\n\n'
        '請以以下 JSON 格式回傳結果：\n'
        '{"subtitles":[{"index":1,"startTime":0.0,"endTime":2.5,"text":"歡迎來到這間房子"}],'
        '"totalLines":5}';

    final text = await analyzeVideo(videoPath, prompt);
    return jsonDecode(_cleanJson(text)) as Map<String, dynamic>;
  }

  /// 智能成片 — 分析影片找出最佳片段
  Future<List<ClipTimeline>> analyzeForAutoEdit(String videoPath) async {
    const prompt = '你是一位專業的房地產影片剪輯師。請分析這段房地產影片素材。\n\n'
        '請找出最精華、最適合保留的片段，考慮：\n'
        '1. 畫面穩定度（優先保留不晃動的片段）\n'
        '2. 內容重要性（房屋特色、空間展示、環境介紹）\n'
        '3. 語音清晰度（說話清楚的片段優先）\n\n'
        '規則：\n'
        '- 每個片段建議 3~8 秒\n'
        '- 按時間順序排列\n'
        '- label 用繁體中文描述片段內容\n\n'
        '請以以下 JSON 格式回傳：\n'
        '{"clips":[{"startTime":1.0,"endTime":4.5,"label":"客廳全景"}]}';

    final text = await analyzeVideo(videoPath, prompt);
    final data = jsonDecode(_cleanJson(text)) as Map<String, dynamic>;
    final clips = (data['clips'] as List?) ?? [];

    return clips
        .map((c) => ClipTimeline(
              videoPath: videoPath,
              startSeconds: (c['startTime'] as num).toDouble(),
              endSeconds: (c['endTime'] as num).toDouble(),
              label: c['label'] as String? ?? '',
            ))
        .toList();
  }

  /// 名片文案 — 生成專業的影片片尾文案
  Future<String> generateBusinessCardScript({
    required String agentName,
    required String title,
    required String company,
    required String phone,
  }) async {
    final prompt = '你是一位專業的房地產行銷文案師。請為以下房仲人員生成一段專業的影片片尾文案。\n\n'
        '房仲資訊：\n'
        '- 姓名：$agentName\n'
        '- 職稱：$title\n'
        '- 公司：$company\n'
        '- 電話：$phone\n\n'
        '請以以下 JSON 格式回傳：\n'
        '{"script":"文案內容","duration":5}\n\n'
        '文案要簡短有力，適合影片結尾 5 秒內展示。';

    final text = await generateText(prompt);
    return _cleanJson(text);
  }

  // ========== 工具方法 ==========

  /// 取得影片 MIME type
  String _getMimeType(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      case 'avi':
        return 'video/x-msvideo';
      default:
        return 'video/mp4';
    }
  }

  /// 從 API 回應中提取文字
  String _extractText(String responseBody) {
    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      // 檢查是否有錯誤訊息
      final error = data['error'];
      if (error != null) {
        throw GeminiException('${error['message'] ?? '未知錯誤'}');
      }
      throw GeminiException('API 回應無內容');
    }
    final parts = candidates[0]['content']['parts'] as List;
    return parts[0]['text'] as String;
  }

  /// 從錯誤回應中提取訊息
  String _parseError(String body) {
    try {
      final data = jsonDecode(body);
      return data['error']?['message'] ?? body;
    } catch (_) {
      return body;
    }
  }

  /// 清理 JSON（移除 markdown code block 包裝）
  String _cleanJson(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```\w*\n?'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\n?```$'), '');
    }
    return cleaned.trim();
  }

  /// 除錯日誌
  void _log(String msg) {
    // ignore: avoid_print
    print('[GeminiService] $msg');
  }
}

/// Gemini API 例外
class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);

  @override
  String toString() => message;
}
