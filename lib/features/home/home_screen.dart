import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/curriculum_data.dart';
import '../../core/providers.dart';
import '../../core/vocab.dart';
import '../../core/widgets/widgets.dart';
import 'daily_plan.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
    ref.watch(cardsProvider);
    ref.watch(vocabProvider);
    final dueCards = ref.read(vocabProvider.notifier).dueEntries().length;
    final left = daysUntilExam(ref.watch(examDateProvider));
    final goal = ProgressNotifier.dailyGoal;
    final done = p.answeredToday;

    // Zayıf alanlar: en az 3 soru çözülmüş, başarı oranı en düşük konular.
    final weak = p.topics.entries.where((e) => e.value.total >= 3).toList()
      ..sort((a, b) => a.value.rate.compareTo(b.value.rate));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        ScreenTitle('Merhaba 👋', subtitle: left == null
                ? 'Profilden sınav tarihini seçersen tekrarlar ona göre planlanır.'
                : (left < 0 ? 'Sınav geçti, umarım güzel geçmiştir!' : 'Sınava $left gün var. Bugün biraz ilerleyelim.')),
        const SizedBox(height: 20),
        Row(
          children: [
            StatTile(value: '🔥 ${p.streak}', label: 'Seri'),
            const SizedBox(width: 12),
            StatTile(value: '${p.xp}', label: 'XP'),
            const SizedBox(width: 12),
            StatTile(value: '$dueCards', label: 'Tekrar'),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          color: AppColors.accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Günlük hedef',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Pill('${done.clamp(0, goal)}/$goal soru',
                      color: done >= goal ? AppColors.success : AppColors.accent),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (done / goal).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: Colors.white12,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.push('/quiz'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Çalışmaya başla'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const DailyPlan(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Shortcut(
                icon: Icons.style_rounded,
                color: const Color(0xFF3B9BEA),
                title: 'Kelime tekrarı',
                subtitle: '$dueCards kelime bekliyor',
                onTap: () => context.push('/vocab'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Shortcut(
                icon: Icons.menu_book_rounded,
                color: const Color(0xFFEFA02A),
                title: 'Yanlış defteri',
                subtitle: '${p.wrongIds.length} soru',
                onTap: () => context.push('/wrong'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text('Zayıf alanlar',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            if (weak.isNotEmpty)
              TextButton.icon(
                onPressed: () => context.push('/quiz?weak=1'),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Zayıflarımdan test'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (weak.isEmpty)
          const GlassCard(
            radius: 18,
            child: Text(
              'Biraz soru çözdükçe zayıf konuların burada önerilecek.',
              style: TextStyle(color: AppColors.textSoft),
            ),
          )
        else
          for (final e in weak.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                radius: 18,
                color: categoryOfTopic(e.key).color,
                onTap: () => context.push('/quiz?topic=${e.key}'),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(topicById(e.key).name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    Pill('%${(e.value.rate * 100).round()}',
                        color: e.value.rate < 0.5 ? AppColors.danger : AppColors.warning),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
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
    return GlassCard(
      color: color,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, color: color, size: 44),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Text(subtitle, style: const TextStyle(color: AppColors.textSoft)),
        ],
      ),
    );
  }
}
