import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai/gemini_client.dart';
import 'data/seed_data.dart';
import 'models.dart';
import 'srs/sm2.dart';

final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());

/// assets/seed/questions.json içeriği (main'de yüklenip verilir).
final seedAssetProvider = Provider<List<Question>>((_) => const []);

final geminiProvider = Provider((_) => GeminiClient());

String _today() => DateTime.now().toIso8601String().substring(0, 10);

// ---------------------------------------------------------------- Sorular

class QuestionsNotifier extends Notifier<List<Question>> {
  static const _key = 'generated_questions';

  @override
  List<Question> build() {
    final raw = ref.read(prefsProvider).getString(_key);
    final generated = raw == null
        ? <Question>[]
        : (jsonDecode(raw) as List)
            .map((e) => Question.fromJson(e as Map<String, dynamic>))
            .toList();
    final byId = <String, Question>{};
    for (final q in [...seedQuestions, ...ref.read(seedAssetProvider), ...generated]) {
      byId[q.id] = q;
    }
    return byId.values.toList();
  }

  void addGenerated(List<Question> qs) {
    state = [...state, ...qs];
    final generated = state.where((q) => q.source == 'ai').map((q) => q.toJson()).toList();
    ref.read(prefsProvider).setString(_key, jsonEncode(generated));
  }
}

final questionsProvider =
    NotifierProvider<QuestionsNotifier, List<Question>>(QuestionsNotifier.new);

// ---------------------------------------------------------------- İlerleme

class TopicStat {
  const TopicStat(this.correct, this.total, [this.ms = 0]);
  final int correct;
  final int total;

  /// Bu konuda cevaplamaya harcanan toplam süre (ms).
  final int ms;
  double get rate => total == 0 ? 0 : correct / total;
  double get avgSeconds => total == 0 ? 0 : ms / total / 1000;
}

class Progress {
  const Progress({
    this.topics = const {},
    this.xp = 0,
    this.streak = 0,
    this.lastDay = '',
    this.todayAnswered = 0,
    this.todayDay = '',
    this.todayTopics = const {},
    this.wrongIds = const {},
  });

  final Map<String, TopicStat> topics;
  final int xp;
  final int streak;
  final String lastDay;
  final int todayAnswered;
  final String todayDay;

  /// Bugün konu başına çözülen soru sayısı (günlük plan için).
  final Map<String, int> todayTopics;
  final Set<String> wrongIds;

  int get answeredToday => todayDay == _today() ? todayAnswered : 0;
  Map<String, int> get topicsToday => todayDay == _today() ? todayTopics : const {};

  Progress copyWith({
    Map<String, TopicStat>? topics,
    int? xp,
    int? streak,
    String? lastDay,
    int? todayAnswered,
    String? todayDay,
    Map<String, int>? todayTopics,
    Set<String>? wrongIds,
  }) =>
      Progress(
        topics: topics ?? this.topics,
        xp: xp ?? this.xp,
        streak: streak ?? this.streak,
        lastDay: lastDay ?? this.lastDay,
        todayAnswered: todayAnswered ?? this.todayAnswered,
        todayDay: todayDay ?? this.todayDay,
        todayTopics: todayTopics ?? this.todayTopics,
        wrongIds: wrongIds ?? this.wrongIds,
      );

  Map<String, dynamic> toJson() => {
        'topics': topics.map((k, v) => MapEntry(k, [v.correct, v.total, v.ms])),
        'xp': xp,
        'streak': streak,
        'lastDay': lastDay,
        'todayAnswered': todayAnswered,
        'todayDay': todayDay,
        'todayTopics': todayTopics,
        'wrongIds': wrongIds.toList(),
      };

  factory Progress.fromJson(Map<String, dynamic> j) => Progress(
        topics: (j['topics'] as Map<String, dynamic>).map((k, v) {
          final l = v as List;
          return MapEntry(k, TopicStat(l[0] as int, l[1] as int, l.length > 2 ? l[2] as int : 0));
        }),
        xp: j['xp'] as int,
        streak: j['streak'] as int,
        lastDay: j['lastDay'] as String,
        todayAnswered: j['todayAnswered'] as int,
        todayDay: j['todayDay'] as String,
        todayTopics: (j['todayTopics'] as Map<String, dynamic>? ?? const {})
            .map((k, v) => MapEntry(k, v as int)),
        wrongIds: Set<String>.from(j['wrongIds'] as List),
      );
}

class ProgressNotifier extends Notifier<Progress> {
  static const _key = 'progress';
  static const dailyGoal = 20;

  @override
  Progress build() {
    final raw = ref.read(prefsProvider).getString(_key);
    return raw == null ? const Progress() : Progress.fromJson(jsonDecode(raw));
  }

  /// [ms]: soruya harcanan süre (0 ise süre kaydedilmez).
  void recordAnswer(Question q, bool correct, {int ms = 0}) {
    final today = _today();
    final yesterday =
        DateTime.now().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);

    var streak = state.streak;
    if (state.lastDay != today) {
      streak = state.lastDay == yesterday ? streak + 1 : 1;
    }

    final old = state.topics[q.topicId] ?? const TopicStat(0, 0);
    final topics = {
      ...state.topics,
      q.topicId: TopicStat(old.correct + (correct ? 1 : 0), old.total + 1, old.ms + ms),
    };
    final wrong = {...state.wrongIds};
    correct ? wrong.remove(q.id) : wrong.add(q.id);

    final todayTopics = {...state.topicsToday};
    todayTopics[q.topicId] = (todayTopics[q.topicId] ?? 0) + 1;

    state = state.copyWith(
      topics: topics,
      xp: state.xp + (correct ? 10 : 2),
      streak: streak,
      lastDay: today,
      todayAnswered: state.answeredToday + 1,
      todayDay: today,
      todayTopics: todayTopics,
      wrongIds: wrong,
    );
    _save();
  }

  void addXp(int amount) {
    final today = _today();
    state = state.copyWith(
      xp: state.xp + amount,
      streak: state.lastDay == today ? state.streak : (state.streak == 0 ? 1 : state.streak),
      lastDay: state.lastDay.isEmpty ? today : state.lastDay,
    );
    _save();
  }

  void _save() => ref.read(prefsProvider).setString(_key, jsonEncode(state.toJson()));
}

final progressProvider =
    NotifierProvider<ProgressNotifier, Progress>(ProgressNotifier.new);

/// Bir konu için "hazır" yüzdesi (0-1). Hiç çözülmediyse null.
double? topicReadiness(Progress p, String topicId) {
  final s = p.topics[topicId];
  if (s == null || s.total == 0) return null;
  // Az veri varsa orana güvenme: 10 soruda tam güven.
  return s.rate * (s.total / 10).clamp(0.0, 1.0);
}

double? categoryReadiness(Progress p, Category c) {
  final vals = c.topics.map((t) => topicReadiness(p, t.id)).whereType<double>().toList();
  if (vals.isEmpty) return null;
  final sum = vals.fold<double>(0, (a, b) => a + b);
  return sum / c.topics.length;
}

// ---------------------------------------------------------------- Kartlar

class CardsNotifier extends Notifier<Map<String, CardSrs>> {
  static const _key = 'card_srs';

  @override
  Map<String, CardSrs> build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, CardSrs.fromJson(v as Map<String, dynamic>)));
  }

  CardSrs of(String id) => state[id] ?? const CardSrs();

  void rate(String id, Rating r) {
    state = {...state, id: sm2(of(id), r)};
    ref
        .read(prefsProvider)
        .setString(_key, jsonEncode(state.map((k, v) => MapEntry(k, v.toJson()))));
    ref.read(progressProvider.notifier).addXp(r == Rating.again ? 1 : 3);
  }

  /// Bugün çalışılacak kartlar: vadesi gelenler + günlük limit kadar yeni.
  List<Flashcard> queue({String? field, int newLimit = 10}) {
    final cards = seedCards.where((c) => field == null || c.field == field);
    final due = cards.where((c) => !of(c.id).isNew && of(c.id).isDue);
    final fresh = cards.where((c) => of(c.id).isNew).take(newLimit);
    return [...due, ...fresh];
  }
}

final cardsProvider =
    NotifierProvider<CardsNotifier, Map<String, CardSrs>>(CardsNotifier.new);
