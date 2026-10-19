import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/data/curriculum_data.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets/widgets.dart';

class GeneratorScreen extends ConsumerStatefulWidget {
  const GeneratorScreen({super.key, this.topicId});
  final String? topicId;

  @override
  ConsumerState<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends ConsumerState<GeneratorScreen> {
  Exam exam = Exam.yds;
  late Category category;
  late Topic topic;
  int level = 3;
  int count = 5;
  bool loading = false;
  String? message;
  bool error = false;

  @override
  void initState() {
    super.initState();
    if (widget.topicId != null) {
      category = categoryOfTopic(widget.topicId!);
      topic = topicById(widget.topicId!);
    } else {
      category = categoriesFor(exam).first;
      topic = category.topics.first;
    }
  }

  Future<void> generate() async {
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final existing = ref.read(questionsProvider).map((q) => q.stem).toSet();
      final qs = await ref.read(geminiProvider).generateQuestions(
            exam: exam,
            category: category,
            topic: topic,
            level: level,
            count: count,
            existingStems: existing,
          );
      ref.read(questionsProvider.notifier).addGenerated(qs);
      setState(() {
        error = false;
        message = '${qs.length} soru eklendi.';
      });
    } catch (e) {
      setState(() {
        error = true;
        message = '$e';
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = categoriesFor(exam);
    return Scaffold(
      appBar: AppBar(title: const Text('Gemini ile soru üret')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<Exam>(
            showSelectedIcon: false,
            segments: [
              for (final e in Exam.values) ButtonSegment(value: e, label: Text(e.label)),
            ],
            selected: {exam},
            onSelectionChanged: (s) => setState(() {
              exam = s.first;
              if (!category.exams.contains(exam)) {
                category = categoriesFor(exam).first;
                topic = category.topics.first;
              }
            }),
          ),
          const SizedBox(height: 16),
          _dropdown<Category>(
            label: 'Kategori',
            value: category,
            items: cats,
            text: (c) => c.name,
            onChanged: (c) => setState(() {
              category = c;
              topic = c.topics.first;
            }),
          ),
          const SizedBox(height: 12),
          _dropdown<Topic>(
            label: 'Konu',
            value: topic,
            items: category.topics,
            text: (t) => t.name,
            onChanged: (t) => setState(() => topic = t),
          ),
          const SizedBox(height: 20),
          Text('Zorluk: $level / 5'),
          Slider(
            value: level.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            onChanged: (v) => setState(() => level = v.round()),
          ),
          Text('Soru sayısı: $count'),
          Slider(
            value: count.toDouble(),
            min: 3,
            max: 10,
            divisions: 7,
            onChanged: (v) => setState(() => count = v.round()),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: loading ? null : generate,
              icon: loading
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(loading ? 'Üretiliyor…' : 'Üret'),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            GlassCard(
              color: error ? AppColors.danger : AppColors.success,
              child: Text(message!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) text,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      items: [
        for (final i in items) DropdownMenuItem(value: i, child: Text(text(i))),
      ],
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }
}
