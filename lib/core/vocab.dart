import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'providers.dart';
import 'srs/fsrs.dart';

/// Kullanıcının kelime defterindeki bir kelime (FSRS ile tekrar edilir).
class VocabEntry {
  const VocabEntry({
    required this.id,
    required this.word,
    required this.meaning,
    this.example = '',
    this.topicId = '',
    this.srs = const WordSrs(),
  });

  final String id;
  final String word;
  final String meaning;
  final String example;
  final String topicId;
  final WordSrs srs;

  VocabEntry withSrs(WordSrs s) => VocabEntry(
        id: id,
        word: word,
        meaning: meaning,
        example: example,
        topicId: topicId,
        srs: s,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'meaning': meaning,
        'example': example,
        'topicId': topicId,
        'srs': srs.toJson(),
      };

  factory VocabEntry.fromJson(Map<String, dynamic> j) => VocabEntry(
        id: j['id'] as String,
        word: j['word'] as String,
        meaning: j['meaning'] as String,
        example: (j['example'] as String?) ?? '',
        topicId: (j['topicId'] as String?) ?? '',
        srs: WordSrs.fromJson(j['srs'] as Map<String, dynamic>),
      );
}

String vocabId(String word) => word.toLowerCase().trim();

// ------------------------------------------------------------ Sınav tarihi

class ExamDateNotifier extends Notifier<DateTime?> {
  static const _key = 'exam_date';

  @override
  DateTime? build() {
    final raw = ref.read(prefsProvider).getString(_key);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  void set(DateTime? d) {
    state = d;
    final prefs = ref.read(prefsProvider);
    d == null ? prefs.remove(_key) : prefs.setString(_key, d.toIso8601String());
  }
}

final examDateProvider =
    NotifierProvider<ExamDateNotifier, DateTime?>(ExamDateNotifier.new);

int? daysUntilExam(DateTime? exam) {
  if (exam == null) return null;
  final today = DateTime.now();
  return DateTime(exam.year, exam.month, exam.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
}

// ------------------------------------------------------------ Kelime defteri

class VocabNotifier extends Notifier<Map<String, VocabEntry>> {
  static const _key = 'vocab';
  static const newPerSession = 20;

  @override
  Map<String, VocabEntry> build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, VocabEntry.fromJson(v as Map<String, dynamic>)));
  }

  /// Sınav tarihi varsa aralıklar sınavın yarısından uzun olamaz,
  /// böylece sınava kadar en az birkaç tekrar yapılır.
  Fsrs get _fsrs {
    final left = daysUntilExam(ref.read(examDateProvider));
    return Fsrs(maxDays: left == null ? null : (left <= 2 ? 1 : left ~/ 2));
  }

  Fsrs get scheduler => _fsrs;

  void _save() => ref
      .read(prefsProvider)
      .setString(_key, jsonEncode(state.map((k, v) => MapEntry(k, v.toJson()))));

  /// Kelimeyi deftere ekler (yoksa). Yeni kelime hemen çalışılabilir durumdadır.
  void add(String word, String meaning, {String example = '', String topicId = ''}) {
    final id = vocabId(word);
    if (id.isEmpty || state.containsKey(id)) return;
    state = {
      ...state,
      id: VocabEntry(
          id: id, word: word.trim(), meaning: meaning, example: example, topicId: topicId),
    };
    _save();
  }

  void remove(String id) {
    state = {...state}..remove(id);
    _save();
  }

  void review(String id, Grade grade) {
    final e = state[id];
    if (e == null) return;
    state = {...state, id: e.withSrs(_fsrs.schedule(e.srs, grade))};
    _save();
    ref.read(progressProvider.notifier).addXp(grade == Grade.again ? 1 : 3);
  }

  /// Testte bir sorunun kelimesi: yanlışsa deftere girer ve bugün tekrar çıkar,
  /// doğruysa (defterdeyse) aralığı uzar.
  void recordQuiz(Question q, bool correct) {
    if (q.word.trim().isEmpty) return;
    final id = vocabId(q.word);
    if (!state.containsKey(id)) {
      if (correct) return;
      add(q.word, q.meaning, example: q.example, topicId: q.topicId);
    }
    review(id, correct ? Grade.good : Grade.again);
  }

  List<VocabEntry> dueEntries({DateTime? now}) {
    final t = now ?? DateTime.now();
    final due = state.values
        .where((e) => e.srs.state != CardState.fresh && e.srs.isDue(t))
        .toList()
      ..sort((a, b) => a.srs.due!.compareTo(b.srs.due!));
    final fresh = state.values
        .where((e) => e.srs.state == CardState.fresh)
        .take(newPerSession);
    return [...due, ...fresh];
  }
}

final vocabProvider =
    NotifierProvider<VocabNotifier, Map<String, VocabEntry>>(VocabNotifier.new);
