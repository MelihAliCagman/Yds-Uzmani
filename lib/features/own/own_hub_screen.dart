import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/own/own_data.dart';
import '../../core/widgets/widgets.dart';

/// Profil > Kendi sınavlarım: kendi hazırlık setindeki kelimeler ve denemeler.
class OwnHubScreen extends ConsumerWidget {
  const OwnHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pack = ref.watch(ownPackProvider);
    final results = ref.watch(ownResultsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kendi sınavlarım')),
      body: SafeArea(
        child: pack.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Set yüklenemedi: $e'),
          ),
          data: (p) {
            final words = dedupeWords(p.allWords).length;
            final done = {for (final r in results) r.examId}.length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(p.source,
                    style: const TextStyle(color: AppColors.textSoft, height: 1.4)),
                const SizedBox(height: 16),
                _Mode(
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFF3B9BEA),
                  title: 'Konu anlatımı · Kelimeler',
                  subtitle:
                      '$words kelime, Türkçesi ve örnek cümleler · hafta hafta, karışan ve ek kelimeler',
                  onTap: () => context.push('/own/words'),
                ),
                _Mode(
                  icon: Icons.quiz_rounded,
                  color: const Color(0xFF1FB8CC),
                  title: 'Kelime testi',
                  subtitle: '"inspect nedir?" gibi, 4 şıklı anlam soruları',
                  onTap: () => context.push('/own/words/quiz'),
                ),
                _Mode(
                  icon: Icons.timer_rounded,
                  color: AppColors.danger,
                  title: 'Deneme sınavları',
                  subtitle:
                      '${p.exams.length} deneme · her biri ${p.exams.first.questions.length} soru, ${p.exams.first.minutes} dk · $done/${p.exams.length} çözüldü',
                  onTap: () => context.push('/own/exams'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Mode extends StatelessWidget {
  const _Mode({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        color: color,
        onTap: onTap,
        child: Row(
          children: [
            IconBadge(icon: icon, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSoft)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
