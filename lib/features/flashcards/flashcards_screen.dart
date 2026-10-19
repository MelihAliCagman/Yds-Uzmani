import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/srs/sm2.dart';
import '../../core/widgets/widgets.dart';

class FlashcardsScreen extends ConsumerStatefulWidget {
  const FlashcardsScreen({super.key, this.field});
  final String? field;

  @override
  ConsumerState<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends ConsumerState<FlashcardsScreen> {
  late final List<Flashcard> queue;
  int index = 0;
  bool flipped = false;

  @override
  void initState() {
    super.initState();
    queue = ref.read(cardsProvider.notifier).queue(field: widget.field);
  }

  void rate(Rating r) {
    ref.read(cardsProvider.notifier).rate(queue[index].id, r);
    setState(() {
      index++;
      flipped = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = index >= queue.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Hafıza kartları')),
      body: SafeArea(
        child: done
            ? _Done(empty: queue.isEmpty)
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: index / queue.length,
                        minHeight: 8,
                        backgroundColor: Colors.white12,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => flipped = !flipped),
                        child: _FlipCard(card: queue[index], flipped: flipped),
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
                          for (final r in Rating.values)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 52),
                                    padding: EdgeInsets.zero,
                                  ),
                                  onPressed: () => rate(r),
                                  child: Text(r.label),
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({required this.card, required this.flipped});
  final Flashcard card;
  final bool flipped;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: flipped ? math.pi : 0),
      duration: const Duration(milliseconds: 350),
      builder: (context, angle, _) {
        final showBack = angle > math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: SizedBox.expand(
            child: GlassCard(
              radius: 28,
              color: showBack ? AppColors.success : AppColors.accent,
              padding: const EdgeInsets.all(24),
              // Arka yüz aynalanmasın diye ters çeviriyoruz.
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..rotateY(showBack ? math.pi : 0),
                child: Center(
                  child: showBack
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(card.back,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 30, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 20),
                            Text(card.example,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.textSoft)),
                          ],
                        )
                      : Text(card.front,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 38, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.empty});
  final bool empty;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.task_alt_rounded, size: 64, color: AppColors.success),
          const SizedBox(height: 16),
          Text(empty ? 'Bugün çalışılacak kart yok.' : 'Oturum tamam!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => context.pop(), child: const Text('Geri dön')),
        ],
      ),
    );
  }
}
