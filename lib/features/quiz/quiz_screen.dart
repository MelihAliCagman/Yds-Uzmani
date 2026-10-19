import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/curriculum_data.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets/widgets.dart';
import '../../core/vocab.dart';
import '../wrong/word_info.dart';
import 'word_prep.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({
    super.key,
    this.topicId,
    this.categoryId,
    this.wrongOnly = false,
    this.weakOnly = false,
  });
  final String? topicId;
  final String? categoryId;
  final bool wrongOnly;
  final bool weakOnly;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  late List<Question> questions;
  int index = 0;
  int? selected;
  int score = 0;

  /// Test başlamadan önce kelime çalışma ekranı gösteriliyor mu?
  bool studying = false;

  /// Her soru için süre tutulur (özellikle okuma/paragraf sorularında zaman önemli).
  final Stopwatch watch = Stopwatch();
  Timer? ticker;
  int totalMs = 0;

  static const quizSize = 10;

  /// Hedef süre (sn): okuma/cloze/çeviri sorularında daha uzun.
  int _targetSeconds(Question q) {
    final c = categoryOfTopic(q.topicId).id;
    return (c == 'reading' || c == 'cloze' || c == 'translation') ? 150 : 60;
  }

  String get _sessionKey {
    if (widget.wrongOnly) return 'session_wrong';
    if (widget.weakOnly) return 'session_weak';
    if (widget.topicId != null) return 'session_topic_${widget.topicId}';
    if (widget.categoryId != null) return 'session_cat_${widget.categoryId}';
    return 'session_mix';
  }

  @override
  void initState() {
    super.initState();
    final all = ref.read(questionsProvider);
    if (!_restore(all)) {
      questions = _pick(all);
      studying = questions.any((q) => q.word.isNotEmpty || q.glossary.isNotEmpty);
    }
    _save();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !studying && selected == null) setState(() {});
    });
    if (!studying) watch.start();
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  /// Yarım kalan test varsa kaldığı yerden devam eder.
  bool _restore(List<Question> all) {
    final raw = ref.read(prefsProvider).getString(_sessionKey);
    if (raw == null) return false;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final byId = {for (final q in all) q.id: q};
      final qs = [for (final id in j['ids'] as List) byId[id]];
      if (qs.contains(null) || (j['index'] as int) >= qs.length) return false;
      questions = qs.cast<Question>();
      index = j['index'] as int;
      score = j['score'] as int;
      selected = j['selected'] as int?;
      return true;
    } catch (_) {
      return false;
    }
  }

  void _save() {
    final prefs = ref.read(prefsProvider);
    if (questions.isEmpty || index >= questions.length) {
      prefs.remove(_sessionKey);
      return;
    }
    prefs.setString(
      _sessionKey,
      jsonEncode({
        'ids': questions.map((q) => q.id).toList(),
        'index': index,
        'score': score,
        'selected': selected,
      }),
    );
  }

  List<Question> _pick(List<Question> all) {
    // İkiz (yedek) sorular normal testlerde çıkmaz; yanlış testinde çıkar.
    final base = all.where((q) => q.twinOf.isEmpty).toList();

    if (widget.wrongOnly) {
      // Yanlış yapılanlar + ikizleri (aynı kelime, farklı cümle), kalanı benzer sorularla dolar.
      final wrongIds = ref.read(progressProvider).wrongIds;
      final wrong = all.where((q) => wrongIds.contains(q.id)).toList()..shuffle();
      if (wrong.isEmpty) return [];
      final chosen = <Question>[];
      for (final w in wrong) {
        if (chosen.length >= quizSize) break;
        chosen.add(w);
        final twin = all.where((q) => q.twinOf == w.id && !chosen.contains(q)).firstOrNull;
        if (twin != null && chosen.length < quizSize) chosen.add(twin);
      }
      if (chosen.length < quizSize) {
        final topics = wrong.map((q) => q.topicId).toSet();
        final similar = base
            .where((q) => !wrongIds.contains(q.id) && topics.contains(q.topicId))
            .toList()
          ..shuffle();
        chosen.addAll(similar.take(quizSize - chosen.length));
      }
      return chosen..shuffle();
    }

    if (widget.weakOnly) {
      // En düşük başarılı 3 konu (en az 3 soru çözülmüş), yoksa karışık.
      final stats = ref
          .read(progressProvider)
          .topics
          .entries
          .where((e) => e.value.total >= 3)
          .toList()
        ..sort((a, b) => a.value.rate.compareTo(b.value.rate));
      final weak = stats.take(3).map((e) => e.key).toSet();
      final pool =
          (weak.isEmpty ? base : base.where((q) => weak.contains(q.topicId)).toList())..shuffle();
      return pool.take(quizSize).toList();
    }

    final list = base.where((q) {
      if (widget.topicId != null) return q.topicId == widget.topicId;
      if (widget.categoryId != null) {
        return categoryOf(widget.categoryId!).topics.any((t) => t.id == q.topicId);
      }
      return true;
    }).toList()
      ..shuffle();
    return list.take(quizSize).toList();
  }

  String get title {
    if (widget.wrongOnly) return 'Yanlış defteri testi';
    if (widget.weakOnly) return 'Zayıf konularım';
    if (widget.topicId != null) return topicById(widget.topicId!).name;
    if (widget.categoryId != null) return categoryOf(widget.categoryId!).name;
    return 'Karışık sorular';
  }

  void answer(int i) {
    if (selected != null) return;
    final q = questions[index];
    final ok = i == q.correctIndex;
    watch.stop();
    final ms = watch.elapsedMilliseconds;
    totalMs += ms;
    setState(() {
      selected = i;
      if (ok) score++;
    });
    ref.read(progressProvider.notifier).recordAnswer(q, ok, ms: ms);
    ref.read(vocabProvider.notifier).recordQuiz(q, ok);
    _save();
  }

  void next() {
    setState(() {
      index++;
      selected = null;
    });
    watch
      ..reset()
      ..start();
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: questions.isEmpty
            ? _Empty(topicId: widget.topicId, wrongOnly: widget.wrongOnly)
            : studying
                ? WordPrep(
                    questions: questions,
                    onStart: () {
                      watch
                        ..reset()
                        ..start();
                      setState(() => studying = false);
                    },
                  )
                : index >= questions.length
                    ? _Result(
                        score: score,
                        total: questions.length,
                        avgSeconds: totalMs / 1000 / questions.length,
                      )
                    : _body(),
      ),
    );
  }

  Widget _body() {
    final q = questions[index];
    final answered = selected != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (index + (answered ? 1 : 0)) / questions.length,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${index + 1}/${questions.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              _Clock(
                seconds: watch.elapsed.inSeconds,
                over: watch.elapsed.inSeconds > _targetSeconds(q),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              GlassCard(
                child: Text(q.stem, style: const TextStyle(fontSize: 18, height: 1.45)),
              ),
              if (q.glossary.isNotEmpty) _Glossary(q.glossary),
              const SizedBox(height: 14),
              for (var i = 0; i < q.options.length; i++) _option(q, i),
              if (answered) ...[
                const SizedBox(height: 6),
                GlassCard(
                  color: AppColors.accent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(
                          selected == q.correctIndex
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: selected == q.correctIndex
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          selected == q.correctIndex ? 'Doğru!' : 'Yanlış',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(q.explanation, style: const TextStyle(height: 1.4)),
                      if (q.word.isNotEmpty) ...[
                        const Divider(height: 24),
                        WordInfo(q),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (answered)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: next,
                child: Text(index + 1 == questions.length ? 'Bitir' : 'Sonraki'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _option(Question q, int i) {
    final answered = selected != null;
    Color color = Colors.white;
    if (answered && i == q.correctIndex) {
      color = AppColors.success;
    } else if (answered && i == selected) {
      color = AppColors.danger;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 16,
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () => answer(i),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              child: Text('ABCDE'[i], style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(q.options[i], style: const TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }
}

/// Soru metnindeki zor kelimeler (isteğe bağlı açılır).
class _Glossary extends StatelessWidget {
  const _Glossary(this.items);
  final List<Gloss> items;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        title: const Text('Sorudaki kelimeler',
            style: TextStyle(fontSize: 14, color: AppColors.textSoft)),
        children: [
          for (final g in items)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: g.word,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: AppColors.accent)),
                  TextSpan(text: '  —  ${g.meaning}'),
                ])),
              ),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({this.topicId, required this.wrongOnly});
  final String? topicId;
  final bool wrongOnly;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(wrongOnly ? Icons.celebration_rounded : Icons.inbox_rounded,
                size: 56, color: AppColors.accent),
            const SizedBox(height: 16),
            Text(
              wrongOnly
                  ? 'Yanlış defterin boş. Harika!'
                  : 'Bu konuda henüz soru yok.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (!wrongOnly) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.pushReplacement(
                    topicId == null ? '/generator' : '/generator?topic=$topicId'),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Gemini ile üret'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Clock extends StatelessWidget {
  const _Clock({required this.seconds, required this.over});
  final int seconds;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final t = '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    final color = over ? AppColors.warning : AppColors.textSoft;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 16, color: color),
        const SizedBox(width: 3),
        Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.score, required this.total, required this.avgSeconds});
  final int score;
  final int total;
  final double avgSeconds;

  @override
  Widget build(BuildContext context) {
    final pct = (score / total * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('%$pct',
                style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900)),
            Text('$score / $total doğru',
                style: const TextStyle(fontSize: 18, color: AppColors.textSoft)),
            const SizedBox(height: 6),
            Text('Soru başı ortalama ${avgSeconds.round()} sn',
                style: const TextStyle(color: AppColors.textSoft)),
            const SizedBox(height: 28),
            FilledButton(onPressed: () => context.pop(), child: const Text('Tamam')),
          ],
        ),
      ),
    );
  }
}
