// Toplu soru üretici. Ücretsiz kota dolana kadar konuları sırayla dolaşır,
// sonuçları assets/seed/questions.json dosyasına kaydeder (her istekten sonra).
//
// Çalıştırma:  dart run tool/generate_questions.dart [konu başına en fazla soru]
// Durdurma:    Ctrl+C (o ana kadarki sorular dosyada kalır)
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const model = 'gemini-flash-lite-latest';
const perRequest = 10;
const pauseBetween = Duration(seconds: 7); // ~8 istek/dk, ücretsiz limitin altında

final out = File('assets/seed/questions.json');

class T {
  T(this.id, this.name, this.category, this.categoryName, this.field, this.exam);
  final String id, name, category, categoryName, field, exam;
}

/// curriculum_data.dart dosyasından konuları okur (tek doğruluk kaynağı).
List<T> readTopics() {
  final src = File('lib/core/data/curriculum_data.dart').readAsStringSync();
  final topics = <T>[];
  final blocks = src.split('  Category(').skip(1);
  for (final b in blocks) {
    String g(String key) => RegExp("$key: '([^']*)'").firstMatch(b)!.group(1)!;
    final id = g('id');
    final name = g('name');
    final field = RegExp("field: '([^']*)'").firstMatch(b)?.group(1) ?? 'general';
    final exam = b.contains('exams: _both')
        ? 'YDS/YÖKDİL'
        : b.contains('Exam.yokdil') ? 'YÖKDİL' : 'YDS';
    for (final m in RegExp("Topic\\('([^']*)', '([^']*)'").allMatches(b)) {
      topics.add(T(m.group(1)!, m.group(2)!, id, name, field, exam));
    }
  }
  return topics;
}

String prompt(T t, int level) => '''
Sen ÖSYM YDS/YÖKDİL tarzında soru hazırlayan deneyimli bir İngilizce öğretmenisin.

Görev: $perRequest adet çoktan seçmeli soru üret.
Sınav: ${t.exam}
Alan: ${t.field}
Kategori: ${t.categoryName}
Konu: ${t.name}
Zorluk: $level (3 = gerçek sınav ortalaması)

Kurallar:
- Her soruda tam 5 şık olsun, yalnızca biri doğru olsun.
- Çeldiriciler makul ve sınav tarzında olsun.
- Soru metni akademik/resmi İngilizce olsun (boşluk için "-------" kullan).
- Açıklamayı Türkçe yaz; neden doğru, neden diğerleri yanlış kısaca belirt.
- Özgün üret, bilinen kitaplardan kopyalama. Konu içinde çeşitli alt başlıklar ve farklı kelimeler kullan.
- "word": sorunun test ettiği kelime/ifade/yapı (genelde doğru şık). "meaning": Türkçe anlamı veya kısa kural. "example": bu kelimeyi kullanan farklı bir İngilizce örnek cümle.
- "glossary": SORU METNİNDEKİ (şıklar hariç) B2+ zor kelimeler, en fazla 5, "word" hariç; sözlük hâliyle, bağlamdaki kısa Türkçe anlamıyla. Yoksa boş liste.
- Çıktı YALNIZCA şu JSON şemasında olsun:
{"questions":[{"stem":"string","options":["A","B","C","D","E"],"correct_index":0,"explanation":"string","word":"string","meaning":"string","example":"string","glossary":[{"word":"string","meaning":"string"}]}]}
''';

Map<String, dynamic>? validate(dynamic i, T t, int level) {
  if (i is! Map) return null;
  final stem = i['stem'], options = i['options'], c = i['correct_index'], ex = i['explanation'];
  if (stem is! String || stem.trim().isEmpty) return null;
  if (options is! List || options.length != 5) return null;
  final opts = options.map((e) => '$e'.replaceFirst(RegExp(r'^\s*\(?[A-Ea-e][\).]\s+'), '').trim()).toList();
  if (opts.toSet().length != 5) return null;
  if (c is! int || c < 0 || c > 4) return null;
  if (ex is! String || ex.trim().isEmpty) return null;
  return {
    'id': 'g_${stem.hashCode.toUnsigned(32).toRadixString(36)}',
    'topicId': t.id,
    'stem': stem.trim(),
    'options': opts,
    'correctIndex': c,
    'explanation': ex.trim(),
    'level': level,
    'source': 'ai',
    'word': '${i['word'] ?? ''}'.trim(),
    'meaning': '${i['meaning'] ?? ''}'.trim(),
    'example': '${i['example'] ?? ''}'.trim(),
    'glossary': [
      if (i['glossary'] is List)
        for (final g in i['glossary'] as List)
          if (g is Map && '${g['word']}'.trim().isNotEmpty && '${g['meaning']}'.trim().isNotEmpty)
            {'word': '${g['word']}'.trim(), 'meaning': '${g['meaning']}'.trim()}
    ],
  };
}

Future<void> main(List<String> args) async {
  final cap = args.isNotEmpty ? int.parse(args.first) : 100;
  final env = jsonDecode(File('env.json').readAsStringSync()) as Map;
  final key = env['GEMINI_API_KEY'] as String;
  if (key.isEmpty) {
    stderr.writeln('env.json içinde GEMINI_API_KEY yok.');
    exit(1);
  }

  out.createSync(recursive: true);
  var all = <Map<String, dynamic>>[];
  if (out.lengthSync() > 0) {
    all = (jsonDecode(out.readAsStringSync()) as List).cast<Map<String, dynamic>>();
  }
  final stems = all.map((q) => q['stem'] as String).toSet();
  int countOf(String id) => all.where((q) => q['topicId'] == id).length;

  final topics = readTopics();
  stdout.writeln('${topics.length} konu, mevcut ${all.length} soru, konu başına hedef $cap.');

  final client = HttpClient();
  final rnd = Random();
  var round = 0;
  var failStreak = 0;

  while (true) {
    final todo = topics.where((t) => countOf(t.id) < cap).toList();
    if (todo.isEmpty) {
      stdout.writeln('Tüm konular hedefe ulaştı.');
      break;
    }
    round++;
    for (final t in todo) {
      final level = 2 + rnd.nextInt(3); // 2-4
      final req = await client.postUrl(Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'));
      req.headers
        ..set('x-goog-api-key', key)
        ..contentType = ContentType.json;
      req.write(jsonEncode({
        'contents': [
          {'parts': [{'text': prompt(t, level)}]}
        ],
        'generationConfig': {'responseMimeType': 'application/json'},
      }));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();

      if (res.statusCode == 429) {
        // Dakikalık limit mi, günlük kota mı?
        if (body.contains('PerDay') || body.contains('per day')) {
          stdout.writeln('Günlük kota doldu. Toplam ${all.length} soru kaydedildi.');
          client.close();
          return;
        }
        stdout.writeln('Dakikalık limit, 65 sn bekleniyor…');
        await Future<void>.delayed(const Duration(seconds: 65));
        continue;
      }
      if (res.statusCode != 200) {
        failStreak++;
        stdout.writeln('HTTP ${res.statusCode} (${t.id}), tekrar denenecek.');
        if (failStreak >= 8) {
          stdout.writeln('Üst üste çok hata, duruyorum. Toplam ${all.length} soru.');
          client.close();
          return;
        }
        await Future<void>.delayed(Duration(seconds: 10 * failStreak));
        continue;
      }
      failStreak = 0;

      var added = 0;
      try {
        final text = jsonDecode(body)['candidates'][0]['content']['parts'][0]['text'] as String;
        final list = (jsonDecode(text) as Map)['questions'] as List;
        for (final item in list) {
          final q = validate(item, t, level);
          if (q != null && stems.add(q['stem'] as String)) {
            all.add(q);
            added++;
          }
        }
      } catch (e) {
        stdout.writeln('Çözümleme hatası (${t.id}): $e');
      }
      out.writeAsStringSync(jsonEncode(all));
      stdout.writeln('[tur $round] ${t.id}: +$added (toplam ${all.length})');
      await Future<void>.delayed(pauseBetween);
    }
  }
  client.close();
}
