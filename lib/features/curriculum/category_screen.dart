import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/curriculum_data.dart';
import '../../core/providers.dart';
import '../../core/widgets/widgets.dart';

class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.categoryId});
  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cat = categoryOf(categoryId);
    final progress = ref.watch(progressProvider);
    final questions = ref.watch(questionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(cat.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          GlassCard(
            color: cat.color,
            child: Row(
              children: [
                IconBadge(icon: cat.icon, color: cat.color, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      Text(cat.exams.map((e) => e.label).join(' · '),
                          style: const TextStyle(color: AppColors.textSoft)),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => context.push('/quiz?category=${cat.id}'),
                  child: const Text('Karışık çöz'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final t in cat.topics) ...[
            Builder(builder: (context) {
              final r = topicReadiness(progress, t.id);
              final stat = progress.topics[t.id];
              final count = questions.where((q) => q.topicId == t.id).length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  radius: 18,
                  color: cat.color,
                  onTap: () => context.push('/quiz?topic=${t.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(t.name,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                          Text('$count soru',
                              style: const TextStyle(color: AppColors.textSoft)),
                          IconButton(
                            tooltip: 'Gemini ile üret',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                            onPressed: () => context.push('/generator?topic=${t.id}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: r ?? 0,
                          minHeight: 6,
                          backgroundColor: Colors.white12,
                          color: AppColors.success,
                        ),
                      ),
                      if (stat != null) ...[
                        const SizedBox(height: 6),
                        Text('${stat.correct}/${stat.total} doğru',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSoft)),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
