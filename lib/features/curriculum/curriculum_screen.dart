import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/curriculum_data.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets/widgets.dart';

class CurriculumScreen extends ConsumerStatefulWidget {
  const CurriculumScreen({super.key});

  @override
  ConsumerState<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends ConsumerState<CurriculumScreen> {
  Exam exam = Exam.yds;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final cats = categoriesFor(exam);
    final topicCount = cats.fold<int>(0, (a, c) => a + c.topics.length);
    final questionCount = ref
        .watch(questionsProvider)
        .where((q) => cats.any((c) => c.topics.any((t) => t.id == q.topicId)))
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        const ScreenTitle('Müfredat',
            subtitle: 'YDS ve YÖKDİL konularını kategori ve konu konu takip et.'),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<Exam>(
            showSelectedIcon: false,
            segments: [
              for (final e in Exam.values)
                ButtonSegment(value: e, label: Text(e.label)),
            ],
            selected: {exam},
            onSelectionChanged: (s) => setState(() => exam = s.first),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            StatTile(value: '${cats.length}', label: 'Kategori'),
            const SizedBox(width: 12),
            StatTile(value: '$topicCount', label: 'Konu'),
            const SizedBox(width: 12),
            StatTile(value: '$questionCount', label: 'Soru'),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.05,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final c in cats) _CategoryCard(c, categoryReadiness(progress, c)),
          ],
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard(this.category, this.readiness);
  final Category category;
  final double? readiness;

  @override
  Widget build(BuildContext context) {
    final pct = readiness == null ? null : (readiness! * 100).round();
    return GlassCard(
      color: category.color,
      onTap: () => context.push('/category/${category.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconBadge(icon: category.icon, color: category.color, size: 48),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Pill(pct == null ? 'Yeni' : '%$pct hazır',
                      color: pct == null ? AppColors.accent : AppColors.success),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${category.topics.length} konu',
              style: const TextStyle(color: AppColors.textSoft)),
        ],
      ),
    );
  }
}
