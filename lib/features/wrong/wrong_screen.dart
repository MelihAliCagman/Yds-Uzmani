import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/curriculum_data.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets/widgets.dart';
import 'word_info.dart';

class WrongScreen extends ConsumerStatefulWidget {
  const WrongScreen({super.key});

  @override
  ConsumerState<WrongScreen> createState() => _WrongScreenState();
}

class _WrongScreenState extends ConsumerState<WrongScreen> {
  bool generating = false;
  String? message;

  /// Yanlış yapılan kelimelere benzer yeni sorular üretir (en fazla 3 istek).
  Future<void> generateSimilar(List<Question> wrong) async {
    setState(() {
      generating = true;
      message = null;
    });
    try {
      final byTopic = <String, List<Question>>{};
      for (final q in wrong) {
        byTopic.putIfAbsent(q.topicId, () => []).add(q);
      }
      final existing = ref.read(questionsProvider).map((q) => q.stem).toSet();
      var added = 0;
      for (final e in byTopic.entries.take(3)) {
        final words = e.value.map((q) => q.word).where((w) => w.isNotEmpty).take(8).join(', ');
        final qs = await ref.read(geminiProvider).generateQuestions(
              exam: Exam.yds,
              category: categoryOfTopic(e.key),
              topic: topicById(e.key),
              level: 3,
              count: 5,
              existingStems: existing,
              focus: words,
            );
        ref.read(questionsProvider.notifier).addGenerated(qs);
        added += qs.length;
      }
      setState(() => message = '$added benzer soru eklendi.');
    } catch (e) {
      setState(() => message = '$e');
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ids = ref.watch(progressProvider).wrongIds;
    final wrong = ref.watch(questionsProvider).where((q) => ids.contains(q.id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Yanlış defteri')),
      body: wrong.isEmpty
          ? const Center(
              child: Text('Yanlış defterin boş. Harika!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push('/quiz?wrong=1'),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Test çöz (10)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: generating ? null : () => generateSimilar(wrong),
                        icon: generating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Benzer üret'),
                      ),
                    ),
                  ],
                ),
                if (message != null) ...[
                  const SizedBox(height: 10),
                  Text(message!, style: const TextStyle(color: AppColors.textSoft)),
                ],
                const SizedBox(height: 16),
                for (final q in wrong)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      color: categoryOfTopic(q.topicId).color,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.stem, style: const TextStyle(height: 1.4)),
                          const SizedBox(height: 8),
                          Text('Doğru: ${q.options[q.correctIndex]}',
                              style: const TextStyle(
                                  color: AppColors.success, fontWeight: FontWeight.w700)),
                          if (q.word.isNotEmpty) ...[
                            const Divider(height: 24),
                            WordInfo(q),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
