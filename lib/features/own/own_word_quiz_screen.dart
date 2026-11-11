import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/own/own_data.dart';
import '../../core/tts.dart';
import '../../core/vocab.dart';
import '../../core/widgets/widgets.dart';
import 'own_words_screen.dart' show WordCard;

/// Kelime testi: "inspect nedir?" (4 şıklı anlam sorusu). Yanlışlar kelime defterine girer.
class OwnWordQuizScreen extends ConsumerStatefulWidget {
  const OwnWordQuizScreen({super.key});

  @override
  ConsumerState<OwnWordQuizScreen> createState() => _OwnWordQuizScreenState();
}

enum _Stage { setup, quiz, result }

class _OwnWordQuizScreenState extends ConsumerState<OwnWordQuizScreen> {
  _Stage stage = _Stage.setup;

  /// null = tüm kelimeler, 0 = ek kelimeler, diğerleri hafta numarası.
  int? scope;
  int count = 20;

  List<OwnWordQ> questions = [];
  int index = 0;
  int? picked;
  final wrong = <OwnWordQ>[];
  int correct = 0;

  List<OwnWord> _pool(OwnPack p) => switch (scope) {
        null => p.allWords,
        0 => p.extra,
        final w => [for (final s in p.weeks) if (s.week == w) ...s.words],
      };

  void _start(OwnPack p) {
    final qs = buildWordQuiz(_pool(p), p.allWords, count, Random());
    if (qs.isEmpty) return;
    setState(() {
      questions = qs;
      index = 0;
      picked = null;
      correct = 0;
      wrong.clear();
      stage = _Stage.quiz;
    });
  }

  void _pick(int i) {
    if (picked != null) return;
    final q = questions[index];
    final ok = i == q.correct;
    ref
        .read(vocabProvider.notifier)
        .recordWord(q.word.word, q.word.tr, ok, example: q.word.example, topicId: 'own');
    setState(() {
      picked = i;
      if (ok) {
        correct++;
      } else {
        wrong.add(q);
      }
    });
  }

  void _next() {
    if (index == questions.length - 1) {
      setState(() => stage = _Stage.result);
    } else {
      setState(() {
        index++;
        picked = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pack = ref.watch(ownPackProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kelime testi')),
      body: SafeArea(
        child: pack.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
          data: (p) => switch (stage) {
            _Stage.setup => _setup(p),
            _Stage.quiz => _quiz(),
            _Stage.result => _result(p),
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Kurulum

  Widget _setup(OwnPack p) {
    final available = dedupeWords(_pool(p)).length;
    Widget chip(String label, int? value) => ChoiceChip(
          label: Text(label),
          selected: scope == value,
          onSelected: (_) => setState(() => scope = value),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text('Kelimenin anlamını bul',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text(
          'Her soruda bir kelime ve 4 Türkçe anlam gelir. Yanlış yaptığın kelime kelime defterine eklenir ve tekrar sorulur.',
          style: TextStyle(color: AppColors.textSoft, height: 1.4),
        ),
        const SizedBox(height: 18),
        const Text('Hangi kelimeler?', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            chip('Tümü', null),
            for (final w in p.weekNumbers) chip('$w. hafta', w),
            chip('Ek kelimeler', 0),
          ],
        ),
        const SizedBox(height: 18),
        const Text('Kaç soru?', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 10, label: Text('10')),
              ButtonSegment(value: 20, label: Text('20')),
              ButtonSegment(value: 40, label: Text('40')),
              ButtonSegment(value: 999, label: Text('Hepsi')),
            ],
            selected: {count},
            onSelectionChanged: (s) => setState(() => count = s.first),
          ),
        ),
        const SizedBox(height: 8),
        Text('Seçili grupta $available kelime var.',
            style: const TextStyle(color: AppColors.textSoft)),
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: available < 4 ? null : () => _start(p),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Başla'),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ Soru

  Widget _quiz() {
    final q = questions[index];
    final done = picked != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Text('${index + 1}/${questions.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (index + (done ? 1 : 0)) / questions.length,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$correct doğru', style: const TextStyle(color: AppColors.success)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              GlassCard(
                child: Column(
                  children: [
                    const Text('Bu kelime ne demek?',
                        style: TextStyle(color: AppColors.textSoft)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(q.word.word,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                        ),
                        SpeakerButton(q.word.word),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < q.options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    radius: 16,
                    color: !done
                        ? Colors.white
                        : i == q.correct
                            ? AppColors.success
                            : i == picked
                                ? AppColors.danger
                                : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    onTap: done ? null : () => _pick(i),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          child: Text('ABCD'[i],
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(q.options[i], style: const TextStyle(fontSize: 16))),
                      ],
                    ),
                  ),
                ),
              if (done && q.word.example.isNotEmpty)
                GlassCard(
                  radius: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(q.word.example,
                            style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: AppColors.textSoft,
                                height: 1.4)),
                      ),
                      SpeakerButton(q.word.example),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: done ? _next : null,
              child: Text(index == questions.length - 1 ? 'Bitir' : 'Sonraki'),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ Sonuç

  Widget _result(OwnPack p) {
    final pct = (correct / questions.length * 100).round();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Center(
          child: Text('%$pct',
              style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900)),
        ),
        Center(
          child: Text('$correct doğru · ${wrong.length} yanlış',
              style: const TextStyle(color: AppColors.textSoft)),
        ),
        if (wrong.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Yanlış yaptığın kelimeler (${wrong.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Kelime defterine eklendi, bugün tekrar sorulacak.',
              style: TextStyle(color: AppColors.textSoft)),
          const SizedBox(height: 10),
          for (final q in wrong) WordCard(q.word),
        ],
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: () => setState(() => stage = _Stage.setup),
          child: const Text('Yeni test'),
        ),
      ],
    );
  }
}
