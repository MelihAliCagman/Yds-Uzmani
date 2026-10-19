// Mevcut sorulara "glossary" (soru metnindeki zor kelimeler + Türkçe anlam) ekler.
// Çalıştırma: dart run tool/enrich_glossary.dart
import 'dart:convert';
import 'dart:io';

const model = 'gemini-flash-lite-latest';
const batch = 10;
final file = File('assets/seed/questions.json');

String prompt(List<Map<String, dynamic>> qs) => '''
Sen YDS/YÖKDİL hazırlık öğretmenisin. Aşağıdaki her soru için SORU METNİNDEKİ (şıklar hariç) B2 ve üzeri, öğrencinin bilmeyebileceği akademik kelime veya ifadeleri listele.

Kurallar:
- Soru başına en fazla 5 madde. Basit/temel kelimeleri alma.
- "word" alanındaki test edilen kelimeyi/yapıyı listeye ALMA.
- Kelimeyi metinde geçtiği biçimin sözlük hâliyle yaz (ör. "undermined" → "undermine").
- "meaning": bağlamdaki kısa Türkçe anlam.
- Listelenecek uygun kelime yoksa boş liste ver.
- Çıktı YALNIZCA şu JSON olsun:
{"items":[{"id":"string","glossary":[{"word":"string","meaning":"string"}]}]}

Sorular:
${jsonEncode(qs.map((q) => {'id': q['id'], 'stem': q['stem'], 'word': q['word'] ?? ''}).toList())}
''';

Future<void> main() async {
  final key = (jsonDecode(File('env.json').readAsStringSync()) as Map)['GEMINI_API_KEY'] as String;
  final all = (jsonDecode(file.readAsStringSync()) as List).cast<Map<String, dynamic>>();
  final client = HttpClient();
  var failStreak = 0;

  while (true) {
    final todo = all.where((q) => !q.containsKey('glossary')).take(batch).toList();
    if (todo.isEmpty) {
      stdout.writeln('Bitti. Tüm sorularda glossary var.');
      break;
    }
    final req = await client.postUrl(Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'));
    req.headers
      ..set('x-goog-api-key', key)
      ..contentType = ContentType.json;
    req.write(jsonEncode({
      'contents': [
        {'parts': [{'text': prompt(todo)}]}
      ],
      'generationConfig': {'responseMimeType': 'application/json'},
    }));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();

    if (res.statusCode == 429) {
      if (body.contains('PerDay') || body.contains('per day')) {
        stdout.writeln('Günlük kota doldu.');
        break;
      }
      stdout.writeln('Dakikalık limit, 65 sn bekleniyor…');
      await Future<void>.delayed(const Duration(seconds: 65));
      continue;
    }
    if (res.statusCode != 200) {
      failStreak++;
      stdout.writeln('HTTP ${res.statusCode}, tekrar.');
      if (failStreak >= 8) break;
      await Future<void>.delayed(Duration(seconds: 10 * failStreak));
      continue;
    }
    failStreak = 0;

    try {
      final text = jsonDecode(body)['candidates'][0]['content']['parts'][0]['text'] as String;
      final items = (jsonDecode(text) as Map)['items'] as List;
      final byId = {for (final i in items) (i as Map)['id']: i['glossary']};
      for (final q in todo) {
        final g = byId[q['id']];
        final list = <Map<String, String>>[];
        if (g is List) {
          for (final x in g) {
            if (x is Map && '${x['word']}'.trim().isNotEmpty && '${x['meaning']}'.trim().isNotEmpty) {
              list.add({'word': '${x['word']}'.trim(), 'meaning': '${x['meaning']}'.trim()});
            }
          }
        }
        // Cevapta olmayan soru da işaretlenir, sonsuz döngü olmasın.
        q['glossary'] = list;
      }
      file.writeAsStringSync(jsonEncode(all));
      stdout.writeln('Kalan: ${all.where((q) => !q.containsKey('glossary')).length}');
    } catch (e) {
      // Bozuk JSON: bu partiyi boş geçme, tekrar dene (farklı çıktı gelebilir).
      stdout.writeln('Çözümleme hatası: $e');
      failStreak++;
      if (failStreak >= 8) break;
    }
    await Future<void>.delayed(const Duration(seconds: 7));
  }
  client.close();
}
