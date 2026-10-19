import 'dart:convert';

import 'package:dio/dio.dart';

import '../models.dart';

const geminiKey = String.fromEnvironment('GEMINI_API_KEY');

/// Güncel model adını Google dokümantasyonundan kontrol et.
const geminiModel = 'gemini-flash-lite-latest';

class GeminiException implements Exception {
  GeminiException(this.message);
  final String message;
  @override
  String toString() => message;
}

List<Gloss> parseGlossary(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final g in raw)
      if (g is Map && '${g['word']}'.trim().isNotEmpty && '${g['meaning']}'.trim().isNotEmpty)
        Gloss('${g['word']}'.trim(), '${g['meaning']}'.trim())
  ];
}

class GeminiClient {
  GeminiClient([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 90),
            ));

  final Dio _dio;

  bool get hasKey => geminiKey.isNotEmpty;

  /// Doğrulamadan geçen soruları döndürür. Geçersizler atılır.
  Future<List<Question>> generateQuestions({
    required Exam exam,
    required Category category,
    required Topic topic,
    required int level,
    int count = 5,
    Set<String> existingStems = const {},
    String focus = '',
  }) async {
    if (!hasKey) {
      throw GeminiException(
        'Gemini API anahtarı yok. env.json içine GEMINI_API_KEY ekleyip '
        '--dart-define-from-file=env.json ile çalıştır.',
      );
    }

    final prompt = _prompt(exam, category, topic, level, count, focus);
    final Response<dynamic> res;
    try {
      res = await _dio.post(
        '/models/$geminiModel:generateContent',
        options: Options(headers: {'x-goog-api-key': geminiKey}),
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {'responseMimeType': 'application/json'},
        },
      );
    } on DioException catch (e) {
      throw GeminiException('Gemini isteği başarısız: ${e.message}');
    }

    final text = res.data['candidates']?[0]?['content']?['parts']?[0]?['text'];
    if (text is! String) throw GeminiException('Gemini boş cevap döndürdü.');

    final List raw;
    try {
      raw = (jsonDecode(text) as Map<String, dynamic>)['questions'] as List;
    } catch (_) {
      throw GeminiException('Gemini cevabı çözümlenemedi.');
    }

    final out = <Question>[];
    final seen = {...existingStems};
    for (final item in raw) {
      final q = _validate(item, topic, level);
      if (q != null && seen.add(q.stem)) out.add(q);
    }
    return out;
  }

  Question? _validate(dynamic item, Topic topic, int level) {
    if (item is! Map) return null;
    final stem = item['stem'];
    final options = item['options'];
    final correct = item['correct_index'];
    final explanation = item['explanation'];
    if (stem is! String || stem.trim().isEmpty) return null;
    if (options is! List || options.length != 5) return null;
    final opts = options
        .map((e) => '$e'.replaceFirst(RegExp(r'^\s*\(?[A-Ea-e][\).]\s+'), '').trim())
        .toList();
    if (opts.toSet().length != 5) return null;
    if (correct is! int || correct < 0 || correct > 4) return null;
    if (explanation is! String || explanation.trim().isEmpty) return null;

    return Question(
      id: 'ai_${DateTime.now().microsecondsSinceEpoch}_${stem.hashCode}',
      topicId: topic.id,
      stem: stem.trim(),
      options: opts,
      correctIndex: correct,
      explanation: explanation.trim(),
      level: level,
      source: 'ai',
      word: '${item['word'] ?? ''}'.trim(),
      meaning: '${item['meaning'] ?? ''}'.trim(),
      example: '${item['example'] ?? ''}'.trim(),
      glossary: parseGlossary(item['glossary']),
    );
  }

  String _prompt(Exam exam, Category c, Topic t, int level, int count, String focus) => '''
Sen ÖSYM YDS/YÖKDİL tarzında soru hazırlayan deneyimli bir İngilizce öğretmenisin.

Görev: $count adet çoktan seçmeli soru üret.
Sınav: ${exam.label}
Alan: ${c.field}
Kategori: ${c.name}
Konu: ${t.name}
Zorluk: $level (3 = gerçek sınav ortalaması)

Kurallar:
- Her soruda tam 5 şık olsun, yalnızca biri doğru olsun.
- Çeldiriciler makul ve sınav tarzında olsun.
- Soru metni akademik/resmi İngilizce olsun (boşluk için "-------" kullan).
- Açıklamayı Türkçe yaz; neden doğru, neden diğerleri yanlış kısaca belirt.
- Özgün üret, bilinen kitaplardan kopyalama.
- "word": sorunun test ettiği kelime/ifade/yapı (genelde doğru şık). "meaning": Türkçe anlamı veya kısa kural. "example": bu kelimeyi kullanan farklı bir İngilizce örnek cümle.
${focus.isEmpty ? '' : "- Şu kelime/yapılara odaklan, bunlarla BENZER ama farklı cümleli sorular yaz: $focus\n"}- "glossary": SORU METNİNDEKİ (şıklar hariç) B2+ zor kelimeler, en fazla 5, "word" hariç; sözlük hâliyle, bağlamdaki kısa Türkçe anlamıyla. Yoksa boş liste.
- Çıktı YALNIZCA şu JSON şemasında olsun:
{"questions":[{"stem":"string","options":["A","B","C","D","E"],"correct_index":0,"explanation":"string","word":"string","meaning":"string","example":"string","glossary":[{"word":"string","meaning":"string"}]}]}
''';
}
