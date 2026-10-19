import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/seed_data.dart';
import '../../core/providers.dart';
import '../../core/vocab.dart';
import '../../core/widgets/widgets.dart';

class DecksScreen extends ConsumerWidget {
  const DecksScreen({super.key});

  static const _decks = [
    (null, 'Tüm kartlar', Icons.all_inclusive_rounded, Color(0xFF7B52C4)),
    ('general', 'Genel akademik', Icons.school_rounded, Color(0xFF3B9BEA)),
    ('science', 'Fen Bilimleri', Icons.biotech_rounded, Color(0xFF26A69A)),
    ('health', 'Sağlık Bilimleri', Icons.favorite_rounded, Color(0xFFEC6A9B)),
    ('social', 'Sosyal Bilimler', Icons.groups_rounded, Color(0xFF8D9DF0)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(cardsProvider);
    final notifier = ref.read(cardsProvider.notifier);
    final vocab = ref.watch(vocabProvider);
    final vocabDue = ref.read(vocabProvider.notifier).dueEntries().length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        const ScreenTitle('Setlerim', subtitle: 'Kelime kartı setlerin ve tekrar durumu.'),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            color: AppColors.warning,
            onTap: () => context.push('/vocab'),
            child: Row(
              children: [
                const IconBadge(icon: Icons.bookmark_rounded, color: Color(0xFFEFA02A)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kelime defterim',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('${vocab.length} kelime · aralıklı tekrar (FSRS)',
                          style: const TextStyle(color: AppColors.textSoft)),
                    ],
                  ),
                ),
                Pill('$vocabDue bugün', color: vocabDue == 0 ? AppColors.success : AppColors.warning),
              ],
            ),
          ),
        ),
        for (final (field, name, icon, color) in _decks)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              color: color,
              onTap: () =>
                  context.push(field == null ? '/flashcards' : '/flashcards?field=$field'),
              child: Row(
                children: [
                  IconBadge(icon: icon, color: color),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(
                          '${seedCards.where((c) => field == null || c.field == field).length} kart',
                          style: const TextStyle(color: AppColors.textSoft),
                        ),
                      ],
                    ),
                  ),
                  Pill('${notifier.queue(field: field).length} bugün',
                      color: AppColors.accent),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
