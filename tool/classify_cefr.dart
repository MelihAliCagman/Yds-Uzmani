// Soru ve kelimelere CEFR seviyesi (A1-C2) ve kelimelere sınavda çıkma olasılığı ekler.
// Sonuç assets/seed/cefr.json dosyasına yazılır (sorular/ikizler dosyalarına dokunmaz,
// o yüzden üreticiler çalışırken de güvenle çalıştırılabilir).
//
// Çalıştırma:  dart run tool/classify_cefr.dart [--watch]
//   --watch  Günlük kota dolunca 15 dk'da bir dener; yeni sorular gelince onları da işler.
//
// cefr.json: {"q": {"<soru id>": "B2"}, "w": {"<kelime>": {"l": "C1", "r": 2}}}
//   r (sınavda çıkma olasılığı, model tahmini): 1 = düşük, 2 = orta, 3 = yüksek
import 'dart:convert';
import 'dart:io';

const model = 'gemini-flash-lite-latest';
const qBatch = 30;
const wBatch = 60;
const pauseBetween = Duration(seconds: 7);
const levels = {'A1', 'A2', 'B1', 'B2', 'C1', 'C2'};

final out = File('assets/seed/cefr.json');

String qPrompt(List<Map<String, dynamic>> qs) => '''
Sen YDS/YÖKDİL hazırlık uzmanısın. Aşağıdaki her sorunun İngilizce metnini ve test ettiği kelimeyi/yapıyı CEFR düzeyine göre sınıflandır: A1, A2, B1, B2, C1 veya C2.
Soruyu çözmek için gereken genel dil düzeyini baz al (kelime hazinesi, cümle yapısı, test edilen konu birlikte).
Çıktı YALNIZCA şu JSON olsun: {"items":[{"id":"string","cefr":"B2"}]}

Sorular:
${jsonEncode(qs.map((q) => {'id': q['id'], 'stem': q['stem'], 'word': q['word'] ?? ''}).toList())}
''';

String wPrompt(List<String> ws) => '''
Sen YDS/YÖKDİL hazırlık uzmanısın. Aşağıdaki her İngilizce kelime/ifade için:
- "l": CEFR düzeyi (A1, A2, B1, B2, C1, C2)
- "r": ÖSYM YDS/YÖKDİL sınavlarında çıkma olasılığı: 3 = sık çıkan akademik kelime, 2 = ara sıra, 1 = sınavda çıkma ihtimali düşük (çok nadir, çok teknik veya günlük konuşma kelimesi)
Çıktı YALNIZCA şu JSON olsun: {"items":[{"word":"string","l":"C1","r":2}]}
Her kelimeyi girişte verildiği yazımla geri ver.

Kelimeler:
${jsonEncode(ws)}
''';

Future<String> ask(HttpClient c, String key, String prompt) async {
  final req = await c.postUrl(Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'));
  req.headers
    ..set('x-goog-api-key', key)
    ..contentType = ContentType.json;
  req.write(jsonEncode({
    'contents': [
      {'parts': [{'text': prompt}]}
    ],
    'generationConfig': {'responseMimeType': 'application/json'},
  }));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode == 429) {
    throw (body.contains('PerDay') || body.contains('per day')) ? 'day' : 'minute';
  }
  if (res.statusCode != 200) throw 'http ${res.statusCode}';
  final text = jsonDecode(body)['candidates'][0]['content']['parts'][0]['text'] as String;
  return text;
}

List<Map<String, dynamic>> readList(String path) {
  final f = File(path);
  if (!f.existsSync() || f.lengthSync() == 0) return [];
  return (jsonDecode(f.readAsStringSync()) as List).cast<Map<String, dynamic>>();
}

void save(Map<String, dynamic> data) {
  final tmp = File('${out.path}.tmp')..writeAsStringSync(jsonEncode(data));
  tmp.renameSync(out.path);
}

Future<void> main(List<String> args) async {
  final watch = args.contains('--watch');
  final key = (jsonDecode(File('env.json').readAsStringSync()) as Map)['GEMINI_API_KEY'] as String;
  if (key.isEmpty) {
    stderr.writeln('env.json içinde GEMINI_API_KEY yok.');
    exit(1);
  }
  final lock = File('tool/.cefr.lock').openSync(mode: FileMode.write);
  try {
    lock.lockSync(FileLock.exclusive);
  } on FileSystemException {
    stderr.writeln('Başka bir sınıflandırıcı zaten çalışıyor.');
    exit(1);
  }

  var data = <String, dynamic>{'q': <String, dynamic>{}, 'w': <String, dynamic>{}};
  if (out.existsSync() && out.lengthSync() > 0) {
    data = jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
  }
  final qMap = (data['q'] as Map).cast<String, dynamic>();
  final wMap = (data['w'] as Map).cast<String, dynamic>();
  data = {'q': qMap, 'w': wMap};

  final client = HttpClient();
  var failStreak = 0;
  final skippedQ = <String>{};
  final skippedW = <String>{};

  while (true) {
    final qs = [...readList('assets/seed/questions.json'), ...readList('assets/seed/twins.json')];
    // Kelimeler: test edilen kelime + soru metnindeki glossary kelimeleri.
    final words = <String>{};
    for (final q in qs) {
      final w = '${q['word'] ?? ''}'.trim();
      if (w.isNotEmpty) words.add(w.toLowerCase());
      for (final g in (q['glossary'] as List? ?? const [])) {
        final gw = '${(g as Map)['word']}'.trim().toLowerCase();
        if (gw.isNotEmpty) words.add(gw);
      }
    }
    final todoQ =
        qs.where((q) => !qMap.containsKey(q['id']) && !skippedQ.contains(q['id'])).toList();
    final todoW =
        words.where((w) => !wMap.containsKey(w) && !skippedW.contains(w)).toList();

    if (todoQ.isEmpty && todoW.isEmpty) {
      stdout.writeln('Hepsi sınıflandırıldı: ${qMap.length} soru, ${wMap.length} kelime.');
      if (!watch) break;
      await Future<void>.delayed(const Duration(minutes: 15));
      continue;
    }

    final doQ = todoQ.isNotEmpty;
    final batchQ = todoQ.take(qBatch).toList();
    final batchW = todoW.take(wBatch).toList();
    try {
      final text = await ask(client, key, doQ ? qPrompt(batchQ) : wPrompt(batchW));
      final items = (jsonDecode(text) as Map)['items'] as List;
      var added = 0;
      if (doQ) {
        for (final i in items) {
          final id = '${(i as Map)['id']}';
          final l = '${i['cefr']}'.toUpperCase();
          if (batchQ.any((q) => q['id'] == id) && levels.contains(l)) {
            qMap[id] = l;
            added++;
          }
        }
        skippedQ.addAll(batchQ.map((q) => q['id'] as String).where((id) => !qMap.containsKey(id)));
      } else {
        for (final i in items) {
          final w = '${(i as Map)['word']}'.trim().toLowerCase();
          final l = '${i['l']}'.toUpperCase();
          final r = i['r'];
          if (batchW.contains(w) && levels.contains(l) && r is int && r >= 1 && r <= 3) {
            wMap[w] = {'l': l, 'r': r};
            added++;
          }
        }
        skippedW.addAll(batchW.where((w) => !wMap.containsKey(w)));
      }
      failStreak = 0;
      save(data);
      stdout.writeln('+$added ${doQ ? 'soru' : 'kelime'} (toplam ${qMap.length} soru, ${wMap.length} kelime)');
    } on String catch (e) {
      if (e == 'day') {
        stdout.writeln('Günlük kota doldu.');
        if (!watch) break;
        stdout.writeln('${DateTime.now()}: 15 dk sonra yeniden denenecek.');
        await Future<void>.delayed(const Duration(minutes: 15));
        continue;
      }
      if (e == 'minute') {
        stdout.writeln('Dakikalık limit, 65 sn bekleniyor…');
        await Future<void>.delayed(const Duration(seconds: 65));
        continue;
      }
      failStreak++;
      stdout.writeln('Hata: $e');
      if (failStreak >= 8) {
        if (!watch) break;
        failStreak = 0;
        await Future<void>.delayed(const Duration(minutes: 15));
      } else {
        await Future<void>.delayed(Duration(seconds: 10 * failStreak));
      }
      continue;
    } catch (e) {
      // Bozuk JSON vb.: bu partiyi atla, sonsuz döngüye girme.
      stdout.writeln('Yanıt işlenemedi ($e), parti atlandı.');
      if (doQ) {
        skippedQ.addAll(batchQ.map((q) => q['id'] as String));
      } else {
        skippedW.addAll(batchW);
      }
    }
    await Future<void>.delayed(pauseBetween);
  }
  client.close();
}
