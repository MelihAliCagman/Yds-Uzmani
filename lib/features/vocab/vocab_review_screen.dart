import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/srs/fsrs.dart';
import '../../core/tts.dart';
import '../../core/vocab.dart';
import '../../core/widgets/widgets.dart';

/// Kelime defteri tekrarı. 10 dk sonrası için planlanan kelimeler aynı oturumda
/// yeniden gelir; kalan kelimeler yarına/ilerisine planlanır.
class VocabReviewScreen extends ConsumerStatefulWidget {
  const VocabReviewScreen({super.key});

  @override
  ConsumerState<VocabReviewScreen> createState() => _VocabReviewScreenState();
}

class _VocabReviewScreenState extends ConsumerState<VocabReviewScreen> {
  late final List<String> queue;
  int done = 0;
  bool flipped = false;

  @override
  void initState() {
    super.initState();
    queue = ref.read(vocabProvider.notifier).dueEntries().map((e) => e.id).toList();
  }

  void rate(Grade g) {
    final n = ref.read(vocabProvider.notifier);
    final id = queue.first;
    n.review(id, g);
    queue.removeAt(0);
    final next = ref.read(vocabProvider)[id]!.srs.due!;
    // Kısa adımlı (aynı gün) kelime bu oturumda tekrar gelsin.
    if (next.difference(DateTime.now()).inMinutes < 30) queue.add(id);
    setState(() {
      done++;
      flipped = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(vocabProvider);
    final scheduler = ref.read(vocabProvider.notifier).scheduler;

    return Scaffold(
      appBar: AppBar(title: const Text('Kelime tekrarı')),
      body: SafeArea(
        child: queue.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.task_alt_rounded, size: 64, color: AppColors.success),
                    const SizedBox(height: 16),
                    Text(done == 0 ? 'Şu an tekrar yok.' : 'Tekrar bitti, $done cevap!',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 24),
                    FilledButton(onPressed: () => context.pop(), child: const Text('Geri dön')),
                  ],
                ),
              )
            : _card(entries[queue.first]!, scheduler),
      ),
    );
  }

  Widget _card(VocabEntry e, Fsrs scheduler) {
    final options = scheduler.options(e.srs);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text('Kalan: ${queue.length}',
                style: const TextStyle(color: AppColors.textSoft)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => flipped = true),
              child: SizedBox.expand(
                child: GlassCard(
                  radius: 28,
                  color: flipped ? AppColors.success : AppColors.accent,
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: flipped
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(e.word,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 22, color: AppColors.textSoft)),
                                  SpeakerButton(e.word),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(e.meaning,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 30, fontWeight: FontWeight.w800)),
                              if (e.example.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Text(e.example,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.textSoft)),
                              ],
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(e.word,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 38, fontWeight: FontWeight.w900)),
                              SpeakerButton(e.word, size: 32),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!flipped)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => setState(() => flipped = true),
                child: const Text('Cevabı göster'),
              ),
            )
          else
            Row(
              children: [
                for (final g in Grade.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 58),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => rate(g),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(g.label),
                            Text(intervalLabel(options[g]!.due!),
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textSoft)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
