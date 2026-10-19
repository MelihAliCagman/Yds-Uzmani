// "İkiz" (yedek) soru üretici: her soru için AYNI kelime/yapıyı test eden ama farklı
// cümle ve çeldiricili bir yedek soru yazar. Sonuç assets/seed/twins.json dosyasına
// (questions.json'a değil) kaydedilir, böylece soru üretici ile çakışmaz.
//
// Uygulamada: yanlış defteri testi, yanlış yapılan sorunun yanında ikizini de sorar.
//
// Çalıştırma:  dart run tool/generate_twins.dart [--watch]
//   --watch  Günlük kota dolunca 15 dk'da bir dener, yenilenince devam eder.
import 'dart:convert';
import 'dart:io';

const model = 'gemini-flash-lite-latest';
const batch = 5;
const pauseBetween = Duration(seconds: 7);

final questionsFile = File('assets/seed/questions.json');
final twinsFile = File('assets/seed/twins.json');
final stripPrefix = RegExp(r'^\s*\(?[A-Ea-e][\).]\s+');

String prompt(List<Map<String, dynamic>> qs) => '''
Sen ÖSYM YDS/YÖKDİL tarzında soru hazırlayan deneyimli bir İngilizce öğretmenisin.

Aşağıdaki her soru için bir "İKİZ" soru yaz: AYNI kelimeyi/yapıyı ("word") test etsin ama
tamamen FARKLI bir cümle, FARKLI çeldiriciler ve doğru cevap FARKLI bir şık sırasında olsun.
Zorluk ve soru tipi aynı kalsın.

Kurallar:
- Her ikizde tam 5 şık olsun, yalnızca biri doğru olsun, şıklara "A)" gibi harf ekleme.
- Açıklamayı Türkçe yaz; neden doğru, neden diğerleri yanlış kısaca belirt.
- "example": "word" için yeni bir İngilizce örnek cümle (soru cümlesinden farklı).
- "glossary": soru metnindeki (şıklar hariç) B2+ zor kelimeler, en fazla 5, "word" hariç, sözlük hâliyle ve kısa Türkçe anlamıyla; yoksa boş liste.
- Çıktı YALNIZCA şu JSON olsun:
{"items":[{"id":"orijinal soru id","stem":"string","options":["","","","",""],"correct_index":0,"explanation":"string","example":"string","glossary":[{"word":"string","meaning":"string"}]}]}

Orijinal sorular:
${jsonEncode(qs.map((q) => {'id': q['id'], 'stem': q['stem'], 'options': q['options'], 'correct_index': q['correctIndex'], 'word': q['word']}).toList())}
''';

Map<String, dynamic>? validate(dynamic i, Map<String, dynamic> orig) {
  if (i is! Map) return null;
  final stem = i['stem'], options = i['options'], c = i['correct_index'], ex = i['explanation'];
  if (stem is! String || stem.trim().isEmpty) return null;
  if (options is! List || options.length != 5) return null;
  final opts = options.map((e) => '$e'.replaceFirst(stripPrefix, '').trim()).toList();
  if (opts.toSet().length != 5) return null;
  if (c is! int || c < 0 || c > 4) return null;
  if (ex is! String || ex.trim().isEmpty) return null;
  if (stem.trim() == orig['stem']) return null;
  return {
    'id': 't_${orig['id']}',
    'topicId': orig['topicId'],
    'stem': stem.trim(),
    'options': opts,
    'correctIndex': c,
    'explanation': ex.trim(),
    'level': orig['level'] ?? 3,
    'source': 'ai',
    'word': orig['word'] ?? '',
    'meaning': orig['meaning'] ?? '',
    'example': '${i['example'] ?? orig['example'] ?? ''}'.trim(),
    'twinOf': orig['id'],
    'glossary': [
      if (i['glossary'] is List)
        for (final g in i['glossary'] as List)
          if (g is Map && '${g['word']}'.trim().isNotEmpty && '${g['meaning']}'.trim().isNotEmpty)
            {'word': '${g['word']}'.trim(), 'meaning': '${g['meaning']}'.trim()}
    ],
  };
}

Future<void> main(List<String> args) async {
  final watch = args.contains('--watch');
  final key = (jsonDecode(File('env.json').readAsStringSync()) as Map)['GEMINI_API_KEY'] as String;
  if (key.isEmpty) {
    stderr.writeln('env.json içinde GEMINI_API_KEY yok.');
    exit(1);
  }

  final lock = File('tool/.twins.lock').openSync(mode: FileMode.write);
  try {
    lock.lockSync(FileLock.exclusive);
  } on FileSystemException {
    stderr.writeln('Başka bir ikiz üretici zaten çalışıyor.');
    exit(1);
  }

  twinsFile.createSync(recursive: true);
  var twins = <Map<String, dynamic>>[];
  if (twinsFile.lengthSync() > 0) {
    twins = (jsonDecode(twinsFile.readAsStringSync()) as List).cast<Map<String, dynamic>>();
  }
  final client = HttpClient();
  var failStreak = 0;

  while (true) {
    // Soru bankası büyüyor olabilir: her turda yeniden oku.
    final all = (jsonDecode(questionsFile.readAsStringSync()) as List).cast<Map<String, dynamic>>();
    final done = twins.map((t) => t['twinOf']).toSet();
    // Kelimesi olmayan sorular ikiz için uygun değil; denenip başarısız olanlar tekrar denenmez.
    final todo = all
        .where((q) =>
            (q['twinOf'] ?? '') == '' &&
            '${q['word'] ?? ''}'.isNotEmpty &&
            !done.contains(q['id']) &&
            !_failed.contains(q['id']))
        .take(batch)
        .toList();
    if (todo.isEmpty) {
      stdout.writeln('Tüm sorular için ikiz var (${twins.length}).');
      if (!watch) break;
      // Yeni soru gelirse devam etmek için bekle.
      await Future<void>.delayed(const Duration(minutes: 15));
      continue;
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
        stdout.writeln('Günlük kota doldu (${twins.length} ikiz kayıtlı).');
        if (!watch) break;
        stdout.writeln('${DateTime.now()}: 15 dk sonra yeniden denenecek.');
        await Future<void>.delayed(const Duration(minutes: 15));
        continue;
      }
      stdout.writeln('Dakikalık limit, 65 sn bekleniyor…');
      await Future<void>.delayed(const Duration(seconds: 65));
      continue;
    }
    if (res.statusCode != 200) {
      failStreak++;
      stdout.writeln('HTTP ${res.statusCode}, tekrar.');
      if (failStreak >= 8) {
        if (!watch) break;
        failStreak = 0;
        await Future<void>.delayed(const Duration(minutes: 15));
        continue;
      }
      await Future<void>.delayed(Duration(seconds: 10 * failStreak));
      continue;
    }
    failStreak = 0;

    var added = 0;
    try {
      final text = jsonDecode(body)['candidates'][0]['content']['parts'][0]['text'] as String;
      final items = (jsonDecode(text) as Map)['items'] as List;
      final byId = {for (final q in todo) q['id']: q};
      for (final item in items) {
        final orig = byId[(item as Map)['id']];
        if (orig == null) continue;
        final t = validate(item, orig);
        if (t != null) {
          twins.add(t);
          added++;
        }
      }
    } catch (e) {
      stdout.writeln('Çözümleme hatası: $e');
    }
    // Bu turda ikizi çıkmayan sorular tekrar tekrar denenip kotayı yemesin.
    final gotNow = twins.map((t) => t['twinOf']).toSet();
    for (final q in todo) {
      if (!gotNow.contains(q['id'])) _failed.add(q['id'] as String);
    }
    final tmp = File('${twinsFile.path}.tmp')..writeAsStringSync(jsonEncode(twins));
    tmp.renameSync(twinsFile.path);
    stdout.writeln('+$added ikiz (toplam ${twins.length})');
    await Future<void>.delayed(pauseBetween);
  }
  client.close();
}

final _failed = <String>{};
