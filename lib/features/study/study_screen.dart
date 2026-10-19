import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../core/widgets/widgets.dart';

class StudyScreen extends ConsumerWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = ref.watch(questionsProvider);
    final wrong = ref.watch(progressProvider).wrongIds.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        const ScreenTitle('Çalış', subtitle: 'Bir çalışma modu seç.'),
        const SizedBox(height: 20),
        _Mode(
          icon: Icons.shuffle_rounded,
          color: const Color(0xFF7B52C4),
          title: 'Karışık soru çöz',
          subtitle: '${questions.length} soru havuzunda',
          onTap: () => context.push('/quiz'),
        ),
        _Mode(
          icon: Icons.style_rounded,
          color: const Color(0xFF3B9BEA),
          title: 'Hafıza kartları',
          subtitle: 'Aralıklı tekrar (SM-2)',
          onTap: () => context.push('/flashcards'),
        ),
        _Mode(
          icon: Icons.replay_rounded,
          color: const Color(0xFFEFA02A),
          title: 'Yanlış defteri',
          subtitle: '$wrong soru bekliyor',
          onTap: () => context.push('/wrong'),
        ),
        _Mode(
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFF1FB8CC),
          title: 'Gemini ile soru üret',
          subtitle: 'Konu, seviye ve adet seç',
          onTap: () => context.push('/generator'),
        ),
        _Mode(
          icon: Icons.timer_rounded,
          color: AppColors.danger,
          title: 'Deneme sınavı',
          subtitle: 'Süreli, kategori analizli',
          onTap: () => context.push('/mock'),
        ),
      ],
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
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
      ),
    );
  }
}
