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
  const QuizScreen({super.key, this.topicId, this.categoryId, this.wrongOnly = false});
  final String? topicId;
  final String? categoryId;
  final bool wrongOnly;

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

  static const quizSize = 10;

  String get _sessionKey {
    if (widget.wrongOnly) return 'session_wrong';
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
    if (widget.wrongOnly) {
      // Önce yanlış yapılanlar, kalan yer aynı konulardan benzer sorularla dolar.
      final wrongIds = ref.read(progressProvider).wrongIds;
      final wrong = all.where((q) => wrongIds.contains(q.id)).toList()..shuffle();
      if (wrong.isEmpty) return [];
      final topics = wrong.map((q) => q.topicId).toSet();
      final similar = all
          .where((q) => !wrongIds.contains(q.id) && topics.contains(q.topicId))
          .toList()
        ..shuffle();
      final head = wrong.take(quizSize ~/ 2 + (quizSize % 2)).toList();
      final rest = [...wrong.skip(head.length), ...similar];
      return [...head, ...rest.take(quizSize - head.length)]..shuffle();
    }
    final list = all.where((q) {
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
    if (widget.topicId != null) return topicById(widget.topicId!).name;
    if (widget.categoryId != null) return categoryOf(widget.categoryId!).name;
    return 'Karışık sorular';
  }

  void answer(int i) {
    if (selected != null) return;
    final q = questions[index];
    final ok = i == q.correctIndex;
    setState(() {
      selected = i;
      if (ok) score++;
    });
    ref.read(progressProvider.notifier).recordAnswer(q, ok);
    ref.read(vocabProvider.notifier).recordQuiz(q, ok);
    _save();
  }

  void next() {
    setState(() {
      index++;
      selected = null;
    });
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
                    onStart: () => setState(() => studying = false),
                  )
                : index >= questions.length
                    ? _Result(score: score, total: questions.length)
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

class _Result extends StatelessWidget {
  const _Result({required this.score, required this.total});
  final int score;
  final int total;

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
            const SizedBox(height: 28),
            FilledButton(onPressed: () => context.pop(), child: const Text('Tamam')),
          ],
        ),
      ),
    );
  }
}
