import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/tts.dart';
import '../../core/vocab.dart';
import '../../core/widgets/widgets.dart';

/// Testten önce: bu testteki kelimeleri gösterir, istenenleri kelime defterine ekler.
class WordPrep extends ConsumerWidget {
  const WordPrep({super.key, required this.questions, required this.onStart});
  final List<Question> questions;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebook = ref.watch(vocabProvider);

    // Testin kelimeleri ve sorulardaki diğer zor kelimeler (tekrarsız).
    final tested = <String, _Item>{};
    final others = <String, _Item>{};
    for (final q in questions) {
      if (q.word.isNotEmpty) {
        tested.putIfAbsent(
            vocabId(q.word), () => _Item(q.word, q.meaning, q.example, q.topicId));
      }
    }
    for (final q in questions) {
      for (final g in q.glossary) {
        final id = vocabId(g.word);
        if (!tested.containsKey(id)) {
          others.putIfAbsent(id, () => _Item(g.word, g.meaning, '', q.topicId));
        }
      }
    }
    final all = [...tested.values, ...others.values];
    final unsaved = all.where((i) => !notebook.containsKey(vocabId(i.word))).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Text('Önce kelimelere göz at',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                'Bu testte geçen kelimeler. Bilmediklerini işaretle, kelime defterine girsin ve aralıklı tekrarla sana tekrar sorulsun.',
                style: TextStyle(color: AppColors.textSoft, height: 1.4),
              ),
              const SizedBox(height: 16),
              if (tested.isNotEmpty) ...[
                const _Header('Testin kelimeleri'),
                for (final i in tested.values) _Row(i, notebook.containsKey(vocabId(i.word))),
              ],
              if (others.isNotEmpty) ...[
                const SizedBox(height: 8),
                const _Header('Sorulardaki diğer kelimeler'),
                for (final i in others.values) _Row(i, notebook.containsKey(vocabId(i.word))),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              if (unsaved.isNotEmpty)
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        final n = ref.read(vocabProvider.notifier);
                        for (final i in unsaved) {
                          n.add(i.word, i.meaning, example: i.example, topicId: i.topicId);
                        }
                      },
                      child: Text('Hepsini ekle (${unsaved.length})'),
                    ),
                  ),
                ),
              if (unsaved.isNotEmpty) const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(onPressed: onStart, child: const Text('Teste başla')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Item {
  _Item(this.word, this.meaning, this.example, this.topicId);
  final String word, meaning, example, topicId;
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSoft)),
      );
}

class _Row extends ConsumerWidget {
  const _Row(this.item, this.saved);
  final _Item item;
  final bool saved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        radius: 16,
        color: saved ? AppColors.success : Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(item.word,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                      SpeakerButton(item.word, size: 20),
                    ],
                  ),
                  if (item.meaning.isNotEmpty)
                    Text(item.meaning, style: const TextStyle(fontSize: 15)),
                  if (item.example.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(item.example,
                          style: const TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSoft)),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: saved ? 'Defterden çıkar' : 'Deftere ekle',
              icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                  color: saved ? AppColors.success : null),
              onPressed: () {
                final n = ref.read(vocabProvider.notifier);
                saved
                    ? n.remove(vocabId(item.word))
                    : n.add(item.word, item.meaning,
                        example: item.example, topicId: item.topicId);
              },
            ),
          ],
        ),
      ),
    );
  }
}
