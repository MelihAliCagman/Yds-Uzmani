import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/own/own_data.dart';
import '../../core/widgets/widgets.dart';

/// Kendi denemelerimin listesi.
class OwnExamListScreen extends ConsumerWidget {
  const OwnExamListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pack = ref.watch(ownPackProvider);
    final results = ref.watch(ownResultsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Deneme sınavları')),
      body: SafeArea(
        child: pack.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
          data: (p) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const Text(
                'Her deneme 25 Vocabulary, 5 Situations ve 12 Reading sorusundan oluşur. Süre işler, cevaplar sonunda gösterilir.',
                style: TextStyle(color: AppColors.textSoft, height: 1.4),
              ),
              const SizedBox(height: 14),
              for (final e in p.exams)
                Builder(builder: (_) {
                  final mine = results.where((r) => r.examId == e.id).toList();
                  final best = mine.isEmpty
                      ? null
                      : mine.map((r) => r.correct).reduce((a, b) => a > b ? a : b);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      radius: 18,
                      color: AppColors.danger,
                      onTap: () => context.push('/own/exam/${e.id}'),
                      child: Row(
                        children: [
                          IconBadge(icon: Icons.assignment_rounded, color: AppColors.danger, size: 44),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.title,
                                    style: const TextStyle(
                                        fontSize: 17, fontWeight: FontWeight.w800)),
                                Text(
                                    '${e.questions.length} soru · ${e.minutes} dk'
                                    '${mine.isEmpty ? '' : ' · ${mine.length} kez çözüldü'}',
                                    style: const TextStyle(color: AppColors.textSoft)),
                              ],
                            ),
                          ),
                          if (best != null)
                            Pill('$best/${e.questions.length}',
                                color: best / e.questions.length >= 0.6
                                    ? AppColors.success
                                    : AppColors.warning),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tek bir deneme: kurulum, sınav, sonuç.
class OwnExamScreen extends ConsumerStatefulWidget {
  const OwnExamScreen({super.key, required this.examId});
  final int examId;

  @override
  ConsumerState<OwnExamScreen> createState() => _OwnExamScreenState();
}

enum _Stage { setup, exam, result }

class _OwnExamScreenState extends ConsumerState<OwnExamScreen> {
  _Stage stage = _Stage.setup;
  List<int?> answers = [];
  int index = 0;
  int totalSeconds = 0;
  int remaining = 0;
  int usedSeconds = 0;
  Timer? timer;
  OwnExam? exam;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _start(OwnExam e) {
    setState(() {
      exam = e;
      answers = List.filled(e.questions.length, null);
      index = 0;
      totalSeconds = e.minutes * 60;
      remaining = totalSeconds;
      stage = _Stage.exam;
    });
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remaining <= 1) {
        _finish();
      } else {
        setState(() => remaining--);
      }
    });
  }

  void _finish() {
    final e = exam;
    if (stage != _Stage.exam || e == null) return;
    timer?.cancel();
    usedSeconds = totalSeconds - remaining;
    var correct = 0, wrong = 0;
    for (var i = 0; i < e.questions.length; i++) {
      final a = answers[i];
      if (a == null) continue;
      a == e.questions[i].correct ? correct++ : wrong++;
    }
    ref.read(ownResultsProvider.notifier).add(OwnExamResult(
          examId: e.id,
          date: DateTime.now(),
          correct: correct,
          wrong: wrong,
          total: e.questions.length,
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
    final pack = ref.watch(ownPackProvider);
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
        if (leave == true && context.mounted) {
          timer?.cancel();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(exam?.title ?? 'Deneme sınavı'),
          actions: [
            if (stage == _Stage.exam)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: _Countdown(remaining, totalSeconds)),
              ),
          ],
        ),
        body: SafeArea(
          child: pack.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
            data: (p) {
              final e = p.exams.firstWhere((x) => x.id == widget.examId);
              return switch (stage) {
                _Stage.setup => _setup(e),
                _Stage.exam => _exam(e),
                _Stage.result => _result(e),
              };
            },
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Kurulum

  Widget _setup(OwnExam e) {
    final mine = ref.watch(ownResultsProvider).where((r) => r.examId == e.id).toList();
    int count(String s) => e.questions.where((q) => q.section == s).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(e.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          '${e.questions.length} soru · ${e.minutes} dk · Vocabulary ${count('vocabulary')}, Situations ${count('situations')}, Reading ${count('reading')}. Süre işler, cevaplar sonunda gösterilir; istediğin soruya dönebilirsin.',
          style: const TextStyle(color: AppColors.textSoft, height: 1.4),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: () => _start(e),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Sınava başla'),
          ),
        ),
        if (mine.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('Önceki denemeler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final r in mine.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          '${r.date.day}.${r.date.month}.${r.date.year} · ${r.seconds ~/ 60} dk'),
                    ),
                    Pill('${r.correct}/${r.total}',
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

  Widget _exam(OwnExam e) {
    final q = e.questions[index];
    final passage = e.passageOf(q);
    final selected = answers[index];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Text('${index + 1}/${e.questions.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Pill(sectionLabel(q.section), color: AppColors.accent),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openGrid(e),
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
              if (passage != null) ...[
                GlassCard(
                  radius: 18,
                  color: AppColors.warning,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(passage.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(passage.text, style: const TextStyle(fontSize: 15, height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              GlassCard(
                child: Text(q.stem, style: const TextStyle(fontSize: 18, height: 1.45)),
              ),
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
                          child: Text('ABCD'[i],
                              style: const TextStyle(fontWeight: FontWeight.w800)),
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
                  onPressed: index == e.questions.length - 1
                      ? _confirmFinish
                      : () => setState(() => index++),
                  child: Text(index == e.questions.length - 1 ? 'Bitir' : 'Sonraki'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openGrid(OwnExam e) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgMid,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < e.questions.length; i++)
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
                              color: i == index ? AppColors.accent : Colors.white24,
                              width: i == index ? 2 : 1),
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
      ),
    );
  }

  // ------------------------------------------------------------ Sonuç

  Widget _result(OwnExam e) {
    var correct = 0, wrong = 0;
    final bySection = <String, List<int>>{}; // bölüm -> [doğru, toplam]
    for (var i = 0; i < e.questions.length; i++) {
      final q = e.questions[i];
      final a = answers[i];
      final s = bySection.putIfAbsent(sectionLabel(q.section), () => [0, 0]);
      s[1]++;
      if (a == null) continue;
      if (a == q.correct) {
        correct++;
        s[0]++;
      } else {
        wrong++;
      }
    }
    final blank = e.questions.length - correct - wrong;
    final wrongList = [
      for (var i = 0; i < e.questions.length; i++)
        if (answers[i] != e.questions[i].correct) i
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Center(
          child: Text('$correct/${e.questions.length}',
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900)),
        ),
        Center(
          child: Text('$correct doğru · $wrong yanlış · $blank boş · ${usedSeconds ~/ 60} dk',
              style: const TextStyle(color: AppColors.textSoft)),
        ),
        const SizedBox(height: 20),
        const Text('Bölüm analizi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final s in bySection.entries)
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
                          child: Text(s.key,
                              style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text('${s.value[0]}/${s.value[1]}'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: s.value[0] / s.value[1],
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      color: s.value[0] / s.value[1] >= 0.6
                          ? AppColors.success
                          : AppColors.warning,
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
          const SizedBox(height: 10),
          for (final i in wrongList)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                color: AppColors.danger,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e.questions[i].n}. ${e.questions[i].stem}',
                        style: const TextStyle(height: 1.4)),
                    const SizedBox(height: 8),
                    if (answers[i] != null)
                      Text('Senin cevabın: ${e.questions[i].options[answers[i]!]}',
                          style: const TextStyle(color: AppColors.danger)),
                    Text('Doğru: ${e.questions[i].options[e.questions[i].correct]}',
                        style: const TextStyle(
                            color: AppColors.success, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: () => setState(() => stage = _Stage.setup),
                child: const Text('Tekrar çöz'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: () => context.pop(),
                child: const Text('Listeye dön'),
              ),
            ),
          ],
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
    final m = remaining ~/ 60;
    final s = remaining % 60;
    final low = remaining < total * 0.1;
    return Pill('${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
        color: low ? AppColors.danger : AppColors.accent);
  }
}
