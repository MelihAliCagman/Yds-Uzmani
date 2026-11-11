import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// "Kendi sınavlarım": kullanıcının kendi hazırlık setinden (assets/own/midterm.json)
/// gelen kelimeler, karışan kelimeler ve deneme sınavları.

class OwnWord {
  const OwnWord(this.word, this.tr, this.example, {this.week = 0, this.group = ''});
  final String word;
  final String tr;
  final String example;

  /// Kelimenin geçtiği hafta (ek kelimelerde 0).
  final int week;
  final String group;

  /// "to rust" ile "rust" gibi biçimleri aynı kelime sayar.
  String get key => word
      .toLowerCase()
      .replaceFirst(RegExp(r'^(to|a|an)\s+'), '')
      .replaceAll(RegExp(r'\(.*?\)'), '')
      .trim();
}

class OwnWeekSection {
  const OwnWeekSection(this.week, this.title, this.words);
  final int week;
  final String title;
  final List<OwnWord> words;
}

class OwnConfusable {
  const OwnConfusable(this.words, this.diff);
  final String words;
  final String diff;
}

class OwnPassage {
  const OwnPassage(this.id, this.title, this.text);
  final String id;
  final String title;
  final String text;
}

class OwnQuestion {
  const OwnQuestion({
    required this.n,
    required this.section,
    required this.stem,
    required this.options,
    required this.correct,
    this.passageId,
  });
  final int n;
  final String section; // vocabulary / situations / reading
  final String stem;
  final List<String> options;
  final int correct;
  final String? passageId;
}

class OwnExam {
  const OwnExam(this.id, this.title, this.minutes, this.passages, this.questions);
  final int id;
  final String title;
  final int minutes;
  final List<OwnPassage> passages;
  final List<OwnQuestion> questions;

  OwnPassage? passageOf(OwnQuestion q) {
    if (q.passageId == null) return null;
    for (final p in passages) {
      if (p.id == q.passageId) return p;
    }
    return null;
  }
}

String sectionLabel(String s) => switch (s) {
      'vocabulary' => 'Vocabulary',
      'situations' => 'Situations',
      _ => 'Reading',
    };

class OwnPack {
  const OwnPack({
    required this.source,
    required this.weeks,
    required this.confusables,
    required this.extra,
    required this.exams,
  });

  final String source;
  final List<OwnWeekSection> weeks;
  final List<OwnConfusable> confusables;
  final List<OwnWord> extra;
  final List<OwnExam> exams;

  /// Haftalardaki kelimeler + ek kelimeler.
  List<OwnWord> get allWords => [for (final w in weeks) ...w.words, ...extra];

  List<int> get weekNumbers => ({for (final w in weeks) w.week}.toList()..sort());

  factory OwnPack.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        [for (final e in j[k] as List) f(e as Map<String, dynamic>)];

    return OwnPack(
      source: j['source'] as String,
      weeks: list('weeks', (w) {
        final week = w['week'] as int;
        return OwnWeekSection(
          week,
          w['title'] as String,
          [
            for (final x in w['words'] as List)
              OwnWord(x['word'] as String, x['tr'] as String, x['example'] as String,
                  week: week)
          ],
        );
      }),
      confusables: list('confusables', (c) => OwnConfusable(c['words'] as String, c['diff'] as String)),
      extra: list('extra', (e) =>
          OwnWord(e['word'] as String, e['tr'] as String, '', group: e['group'] as String)),
      exams: list('exams', (e) {
        return OwnExam(
          e['id'] as int,
          e['title'] as String,
          e['minutes'] as int,
          [
            for (final p in e['passages'] as List)
              OwnPassage(p['id'] as String, p['title'] as String, p['text'] as String)
          ],
          [
            for (final q in e['questions'] as List)
              OwnQuestion(
                n: q['n'] as int,
                section: q['section'] as String,
                stem: q['stem'] as String,
                options: [for (final o in q['options'] as List) '$o'],
                correct: q['correct'] as int,
                passageId: q['passage'] as String?,
              )
          ],
        );
      }),
    );
  }
}

final ownPackProvider = FutureProvider<OwnPack>((ref) async {
  final raw = await rootBundle.loadString('assets/own/midterm.json');
  return OwnPack.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});

// ------------------------------------------------------------ Kelime testi

/// "inspect nedir?" tipi soru: 4 Türkçe anlam şıkkı.
class OwnWordQ {
  const OwnWordQ(this.word, this.options, this.correct);
  final OwnWord word;
  final List<String> options;
  final int correct;
}

Set<String> _tokens(String s) => RegExp(r'[a-zçğıöşü]{4,}')
    .allMatches(s.toLowerCase())
    .map((m) => m.group(0)!)
    .toSet();

/// Aynı kelimenin tekrarlarını (ör. iki hafta geçen "injury") tek sayar.
List<OwnWord> dedupeWords(Iterable<OwnWord> words) {
  final seen = <String>{};
  return [
    for (final w in words)
      if (seen.add(w.key)) w
  ];
}

/// [pool] içinden [count] kelime seçer; çeldiriciler [all] içindeki diğer kelimelerin
/// anlamlarıdır. Doğru anlamla aynı sözcüğü paylaşan (ör. "kaldıraç" / "kaldıraç kuvveti")
/// anlamlar çeldirici olarak seçilmez, böylece tek doğru şık kalır.
List<OwnWordQ> buildWordQuiz(List<OwnWord> pool, List<OwnWord> all, int count, Random rnd) {
  final words = dedupeWords(pool)..shuffle(rnd);
  final candidates = dedupeWords(all);
  final out = <OwnWordQ>[];
  for (final w in words.take(count)) {
    final own = _tokens(w.tr);
    final distractors = <String>[];
    final shuffled = [...candidates]..shuffle(rnd);
    for (final c in shuffled) {
      if (c.key == w.key || distractors.contains(c.tr)) continue;
      if (c.tr.toLowerCase() == w.tr.toLowerCase()) continue;
      if (_tokens(c.tr).intersection(own).isNotEmpty) continue;
      distractors.add(c.tr);
      if (distractors.length == 3) break;
    }
    if (distractors.length < 3) continue;
    final options = [w.tr, ...distractors]..shuffle(rnd);
    out.add(OwnWordQ(w, options, options.indexOf(w.tr)));
  }
  return out;
}

// ------------------------------------------------------------ Sonuçlar

class OwnExamResult {
  const OwnExamResult({
    required this.examId,
    required this.date,
    required this.correct,
    required this.wrong,
    required this.total,
    required this.seconds,
  });
  final int examId;
  final DateTime date;
  final int correct;
  final int wrong;
  final int total;
  final int seconds;

  double get percent => total == 0 ? 0 : correct / total * 100;

  Map<String, dynamic> toJson() => {
        'examId': examId,
        'date': date.toIso8601String(),
        'correct': correct,
        'wrong': wrong,
        'total': total,
        'seconds': seconds,
      };

  factory OwnExamResult.fromJson(Map<String, dynamic> j) => OwnExamResult(
        examId: j['examId'] as int,
        date: DateTime.parse(j['date'] as String),
        correct: j['correct'] as int,
        wrong: j['wrong'] as int,
        total: j['total'] as int,
        seconds: j['seconds'] as int,
      );
}

class OwnResultsNotifier extends Notifier<List<OwnExamResult>> {
  static const _key = 'own_exam_results';

  @override
  List<OwnExamResult> build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => OwnExamResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void add(OwnExamResult r) {
    state = [r, ...state].take(100).toList();
    ref.read(prefsProvider).setString(_key, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  List<OwnExamResult> of(int examId) => state.where((r) => r.examId == examId).toList();
}

final ownResultsProvider =
    NotifierProvider<OwnResultsNotifier, List<OwnExamResult>>(OwnResultsNotifier.new);
