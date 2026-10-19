import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/data/curriculum_data.dart';
import '../../core/mock_history.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/vocab.dart';
import '../../core/widgets/widgets.dart';
import '../wrong/word_info.dart';

/// Deneme sınavı: süreli, anında geri bildirim yok, sonunda analiz.
class MockScreen extends ConsumerStatefulWidget {
  const MockScreen({super.key});

  @override
  ConsumerState<MockScreen> createState() => _MockScreenState();
}

enum _Stage { setup, exam, result }

class _MockScreenState extends ConsumerState<MockScreen> {
  _Stage stage = _Stage.setup;
  Exam exam = Exam.yds;
  int size = 20;

  List<Question> questions = [];
  List<int?> answers = [];
  int index = 0;
  late int totalSeconds;
  int remaining = 0;
  Timer? timer;
  int usedSeconds = 0;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  /// Kategoriler arasında dengeli (sırayla) soru seçer.
  List<Question> _pick(int n) {
    final cats = categoriesFor(exam);
    final pools = <List<Question>>[];
    final all = ref.read(questionsProvider).where((q) => q.twinOf.isEmpty);
    for (final c in cats) {
      final ids = c.topics.map((t) => t.id).toSet();
      pools.add(all.where((q) => ids.contains(q.topicId)).toList()..shuffle());
    }
    final out = <Question>[];
    var i = 0;
    while (out.length < n && pools.any((p) => p.isNotEmpty)) {
      final pool = pools[i % pools.length];
      if (pool.isNotEmpty) out.add(pool.removeLast());
      i++;
    }
    return out..shuffle();
  }

  void _start() {
    final qs = _pick(size);
    if (qs.isEmpty) return;
    setState(() {
      questions = qs;
      answers = List.filled(qs.length, null);
      index = 0;
      // YDS ortalaması: 80 soru / 180 dk ≈ 2,25 dk/soru
      totalSeconds = (qs.length * 135);
      remaining = totalSeconds;
      stage = _Stage.exam;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remaining <= 1) {
        _finish();
      } else {
        setState(() => remaining--);
      }
    });
  }

  void _finish() {
    if (stage != _Stage.exam) return;
    timer?.cancel();
    usedSeconds = totalSeconds - remaining;

    var correct = 0, wrong = 0;
    final progress = ref.read(progressProvider.notifier);
    final vocab = ref.read(vocabProvider.notifier);
    for (var i = 0; i < questions.length; i++) {
      final a = answers[i];
      if (a == null) continue;
      final ok = a == questions[i].correctIndex;
      ok ? correct++ : wrong++;
      progress.recordAnswer(questions[i], ok);
      vocab.recordQuiz(questions[i], ok);
    }
    ref.read(mockHistoryProvider.notifier).add(MockResult(
          date: DateTime.now(),
          exam: exam.label,
          total: questions.length,
          correct: correct,
          wrong: wrong,
          seconds: usedSeconds,
        ));
    setState(() => stage = _Stage.result);
  }

  Future<void> _confirmFinish() async {
    final blank = answers.where((a) => a == null).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sınavı bitir?'),
        content: Text(blank == 0 ? 'Tüm soruları cevapladın.' : '$blank soru boş.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Devam et')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Bitir')),
        ],
      ),
    );
    if (ok == true) _finish();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: stage != _Stage.exam,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Sınavdan çıkılsın mı?'),
            content: const Text('Cevapların kaydedilmez.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Kal')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Çık')),
            ],
          ),
        );
        if (leave == true && mounted) {
          timer?.cancel();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(stage == _Stage.exam ? 'Deneme sınavı' : 'Deneme sınavı'),
          actions: [
            if (stage == _Stage.exam)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: _Countdown(remaining, totalSeconds)),
              ),
          ],
        ),
        body: SafeArea(
          child: switch (stage) {
            _Stage.setup => _setup(),
            _Stage.exam => _exam(),
            _Stage.result => _result(),
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Kurulum

  Widget _setup() {
    final history = ref.watch(mockHistoryProvider);
    final available = ref
        .watch(questionsProvider)
        .where((q) => q.twinOf.isEmpty && categoriesFor(exam).any((c) => c.topics.any((t) => t.id == q.topicId)))
        .length;

    Widget sizeTile(int n, String label) {
      final enabled = available >= n;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: GlassCard(
            radius: 18,
            color: size == n ? AppColors.accent : Colors.white,
            onTap: enabled ? () => setState(() => size = n) : null,
            child: Row(
              children: [
                Expanded(
                    child: Text(label,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                Text('${(n * 135 / 60).round()} dk',
                    style: const TextStyle(color: AppColors.textSoft)),
                const SizedBox(width: 8),
                if (size == n) const Icon(Icons.check_circle_rounded, color: AppColors.accent),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text('Gerçek sınav gibi çöz',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text(
          'Süre işler, cevaplar sonunda gösterilir. İstediğin soruya dönebilirsin. Soru başı süre YDS ortalamasına (≈2,25 dk) göre ayarlanır.',
          style: TextStyle(color: AppColors.textSoft, height: 1.4),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<Exam>(
            showSelectedIcon: false,
            segments: [for (final e in Exam.values) ButtonSegment(value: e, label: Text(e.label))],
            selected: {exam},
            onSelectionChanged: (s) => setState(() => exam = s.first),
          ),
        ),
        const SizedBox(height: 16),
        sizeTile(20, 'Mini deneme · 20 soru'),
        sizeTile(40, 'Yarım deneme · 40 soru'),
        sizeTile(80, 'Tam deneme · 80 soru'),
        if (available < 80)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Soru bankasında bu sınav için $available soru var. Tam deneme için daha fazla soru üretilmeli.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSoft),
            ),
          ),
        const SizedBox(height: 6),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: available == 0 ? null : _start,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Sınava başla'),
          ),
        ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('Son denemeler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final r in history.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          '${r.date.day}.${r.date.month}.${r.date.year} · ${r.exam} · ${r.total} soru'),
                    ),
                    Pill('%${r.percent.round()}',
                        color: r.percent >= 60 ? AppColors.success : AppColors.warning),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------ Sınav

  Widget _exam() {
    final q = questions[index];
    final selected = answers[index];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Text('${index + 1}/${questions.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: _openGrid,
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: const Text('Sorular'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              GlassCard(child: Text(q.stem, style: const TextStyle(fontSize: 18, height: 1.45))),
              const SizedBox(height: 14),
              for (var i = 0; i < q.options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    radius: 16,
                    color: selected == i ? AppColors.accent : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    // Aynı şıkka tekrar dokununca cevap geri alınır (boş bırakma).
                    onTap: () => setState(() => answers[index] = selected == i ? null : i),
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
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: index == 0 ? null : () => setState(() => index--),
                  child: const Text('Önceki'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: index == questions.length - 1
                      ? _confirmFinish
                      : () => setState(() => index++),
                  child: Text(index == questions.length - 1 ? 'Bitir' : 'Sonraki'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openGrid() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgMid,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < questions.length; i++)
                  InkWell(
                    onTap: () {
                      Navigator.pop(c);
                      setState(() => index = i);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: answers[i] != null
                            ? AppColors.accent.withValues(alpha: 0.35)
                            : Colors.white10,
                        border: Border.all(
                            color: i == index ? AppColors.accent : Colors.white24, width: i == index ? 2 : 1),
                      ),
                      child: Text('${i + 1}'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(c);
                  _confirmFinish();
                },
                child: const Text('Sınavı bitir'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Sonuç

  Widget _result() {
    var correct = 0, wrong = 0;
    final byCat = <String, List<int>>{}; // kategori -> [doğru, toplam]
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final a = answers[i];
      final c = categoryOfTopic(q.topicId).name;
      byCat.putIfAbsent(c, () => [0, 0]);
      byCat[c]![1]++;
      if (a == null) continue;
      if (a == q.correctIndex) {
        correct++;
        byCat[c]![0]++;
      } else {
        wrong++;
      }
    }
    final blank = questions.length - correct - wrong;
    final pct = (correct / questions.length * 100).round();
    final mins = usedSeconds ~/ 60;

    final wrongList = [
      for (var i = 0; i < questions.length; i++)
        if (answers[i] != questions[i].correctIndex) i
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Center(
          child: Text('%$pct',
              style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900)),
        ),
        Center(
          child: Text('$correct doğru · $wrong yanlış · $blank boş · $mins dk',
              style: const TextStyle(color: AppColors.textSoft)),
        ),
        const SizedBox(height: 20),
        const Text('Kategori analizi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final e in byCat.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              radius: 16,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(e.key,
                              style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text('${e.value[0]}/${e.value[1]}'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: e.value[0] / e.value[1],
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      color: e.value[0] / e.value[1] >= 0.6 ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (wrongList.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Yanlış ve boş sorular (${wrongList.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Yanlışların kelime defterine ve yanlış defterine eklendi.',
              style: TextStyle(color: AppColors.textSoft)),
          const SizedBox(height: 10),
          for (final i in wrongList)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                color: AppColors.danger,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(questions[i].stem, style: const TextStyle(height: 1.4)),
                    const SizedBox(height: 8),
                    if (answers[i] != null)
                      Text('Senin cevabın: ${questions[i].options[answers[i]!]}',
                          style: const TextStyle(color: AppColors.danger)),
                    Text('Doğru: ${questions[i].options[questions[i].correctIndex]}',
                        style: const TextStyle(
                            color: AppColors.success, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(questions[i].explanation, style: const TextStyle(height: 1.4)),
                    if (questions[i].word.isNotEmpty) ...[
                      const Divider(height: 24),
                      WordInfo(questions[i]),
                    ],
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: () => setState(() => stage = _Stage.setup),
          child: const Text('Yeni deneme'),
        ),
      ],
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown(this.remaining, this.total);
  final int remaining;
  final int total;

  @override
  Widget build(BuildContext context) {
    final h = remaining ~/ 3600;
    final m = (remaining % 3600) ~/ 60;
    final s = remaining % 60;
    final t = h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    final low = remaining < total * 0.1;
    return Pill(t, color: low ? AppColors.danger : AppColors.accent);
  }
}
