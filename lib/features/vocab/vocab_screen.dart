import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/srs/fsrs.dart';
import '../../core/vocab.dart';
import '../../core/widgets/widgets.dart';

class VocabScreen extends ConsumerWidget {
  const VocabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(vocabProvider);
    final notifier = ref.read(vocabProvider.notifier);
    final due = notifier.dueEntries().length;
    final mature =
        entries.values.where((e) => e.srs.state == CardState.review && e.srs.stability >= 21).length;

    final list = entries.values.toList()
      ..sort((a, b) {
        final ad = a.srs.due ?? DateTime(2000);
        final bd = b.srs.due ?? DateTime(2000);
        return ad.compareTo(bd);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Kelime defterim')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              StatTile(value: '${entries.length}', label: 'Kelime'),
              const SizedBox(width: 12),
              StatTile(value: '$due', label: 'Bugün'),
              const SizedBox(width: 12),
              StatTile(value: '$mature', label: 'Pekişmiş'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: due == 0 ? null : () => context.push('/vocab/review'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(due == 0 ? 'Bugünlük tekrar bitti 🎉' : 'Tekrara başla ($due)'),
            ),
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            const GlassCard(
              child: Text(
                'Defterin boş. Test öncesi kelime ekranından kelime ekleyebilir ya da yanlış yaptığın kelimeler otomatik buraya düşer.',
                style: TextStyle(color: AppColors.textSoft, height: 1.4),
              ),
            ),
          for (final e in list)
            Dismissible(
              key: ValueKey(e.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              ),
              onDismissed: (_) => notifier.remove(e.id),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  radius: 16,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.word,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w800)),
                            Text(e.meaning),
                          ],
                        ),
                      ),
                      _StatePill(e.srs),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill(this.srs);
  final WordSrs srs;

  @override
  Widget build(BuildContext context) {
    if (srs.state == CardState.fresh) return const Pill('Yeni', color: AppColors.accent);
    if (srs.isDue()) return const Pill('Şimdi', color: AppColors.warning);
    return Pill(intervalLabel(srs.due!), color: AppColors.success);
  }
}
