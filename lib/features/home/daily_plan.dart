import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/curriculum_data.dart';
import '../../core/mock_history.dart';
import '../../core/providers.dart';
import '../../core/vocab.dart';
import '../../core/widgets/widgets.dart';

class _Task {
  const _Task(this.title, this.subtitle, this.done, this.route, this.icon);
  final String title;
  final String subtitle;
  final bool done;
  final String? route;
  final IconData icon;
}

/// Bugünün planı: kelime tekrarı → günlük soru → zayıf konu → (sınav yakınsa) deneme.
class DailyPlan extends ConsumerWidget {
  const DailyPlan({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(progressProvider);
    ref.watch(vocabProvider);
    final due = ref.read(vocabProvider.notifier).dueEntries().length;
    final notebookSize = ref.watch(vocabProvider).length;
    final left = daysUntilExam(ref.watch(examDateProvider));
    final mocks = ref.watch(mockHistoryProvider);

    final tasks = <_Task>[];

    if (notebookSize > 0) {
      tasks.add(_Task(
        'Kelime tekrarı',
        due == 0 ? 'Bugünlük bitti' : '$due kelime bekliyor',
        due == 0,
        due == 0 ? null : '/vocab/review',
        Icons.bookmark_rounded,
      ));
    }

    const goal = ProgressNotifier.dailyGoal;
    tasks.add(_Task(
      'Günlük soru hedefi',
      '${p.answeredToday.clamp(0, goal)}/$goal soru',
      p.answeredToday >= goal,
      '/quiz',
      Icons.quiz_rounded,
    ));

    // En zayıf konu: en az 3 soru çözülmüş, başarı oranı en düşük.
    final weak = p.topics.entries.where((e) => e.value.total >= 3).toList()
      ..sort((a, b) => a.value.rate.compareTo(b.value.rate));
    if (weak.isNotEmpty && weak.first.value.rate < 0.8) {
      final id = weak.first.key;
      final solved = p.topicsToday[id] ?? 0;
      tasks.add(_Task(
        'Zayıf konu: ${topicById(id).name}',
        solved >= 5 ? 'Tamam' : '$solved/5 soru · başarı %${(weak.first.value.rate * 100).round()}',
        solved >= 5,
        '/quiz?topic=$id',
        Icons.trending_up_rounded,
      ));
    }

    // Sınava 60 günden az kaldıysa haftada bir mini deneme.
    if (left != null && left >= 0 && left <= 60) {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final recent = mocks.any((m) => m.date.isAfter(weekAgo));
      tasks.add(_Task(
        'Haftalık deneme',
        recent ? 'Bu hafta yapıldı' : 'Bu hafta henüz yok',
        recent,
        '/mock',
        Icons.timer_rounded,
      ));
    }

    final doneCount = tasks.where((t) => t.done).length;

    return GlassCard(
      color: AppColors.success,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Bugünün planı',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Pill('$doneCount/${tasks.length}',
                  color: doneCount == tasks.length ? AppColors.success : AppColors.accent),
            ],
          ),
          const SizedBox(height: 6),
          for (final t in tasks)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: t.route == null ? null : () => context.push(t.route!),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      t.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: t.done ? AppColors.success : AppColors.textSoft,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  decoration: t.done ? TextDecoration.lineThrough : null)),
                          Text(t.subtitle,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSoft)),
                        ],
                      ),
                    ),
                    if (!t.done && t.route != null) const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
