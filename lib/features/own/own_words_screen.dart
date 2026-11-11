import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/own/own_data.dart';
import '../../core/tts.dart';
import '../../core/vocab.dart';
import '../../core/widgets/widgets.dart';

/// Konu anlatımı: haftalara göre kelime, Türkçesi ve örnek cümle; karışan ve ek kelimeler.
class OwnWordsScreen extends ConsumerStatefulWidget {
  const OwnWordsScreen({super.key});

  @override
  ConsumerState<OwnWordsScreen> createState() => _OwnWordsScreenState();
}

class _OwnWordsScreenState extends ConsumerState<OwnWordsScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final pack = ref.watch(ownPackProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: const Text('Konu anlatımı · Kelimeler')),
        body: SafeArea(
          child: pack.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
            data: (p) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Kelime ara (İngilizce veya Türkçe)',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                if (query.isEmpty)
                  const TabBar(tabs: [
                    Tab(text: 'Haftalar'),
                    Tab(text: 'Karışanlar'),
                    Tab(text: 'Ek kelimeler'),
                  ]),
                Expanded(
                  child: query.isEmpty
                      ? TabBarView(children: [
                          _Weeks(p),
                          _Confusables(p),
                          _Extra(p),
                        ])
                      : _Search(p, query),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Weeks extends StatelessWidget {
  const _Weeks(this.pack);
  final OwnPack pack;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        for (final s in pack.weeks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              radius: 20,
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  title: Text('${s.week}. Hafta',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  subtitle: Text('${s.title} · ${s.words.length} kelime',
                      style: const TextStyle(color: AppColors.textSoft)),
                  children: [for (final w in s.words) WordCard(w)],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Confusables extends StatelessWidget {
  const _Confusables(this.pack);
  final OwnPack pack;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('Sınavda birbirine karıştırılan kelimeler ve aralarındaki fark.',
              style: TextStyle(color: AppColors.textSoft)),
        ),
        for (final c in pack.confusables)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              radius: 16,
              color: AppColors.warning,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.words,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(c.diff, style: const TextStyle(height: 1.4)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Extra extends StatelessWidget {
  const _Extra(this.pack);
  final OwnPack pack;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<OwnWord>>{};
    for (final w in pack.extra) {
      groups.putIfAbsent(w.group, () => []).add(w);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('Hocanın örnek sınavında geçen, haftalık listede olmayan kelimeler.',
              style: TextStyle(color: AppColors.textSoft)),
        ),
        for (final e in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(e.key,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSoft)),
          ),
          for (final w in e.value) WordCard(w),
        ],
      ],
    );
  }
}

class _Search extends StatelessWidget {
  const _Search(this.pack, this.query);
  final OwnPack pack;
  final String query;

  @override
  Widget build(BuildContext context) {
    final hits = dedupeWords(pack.allWords)
        .where((w) =>
            w.word.toLowerCase().contains(query) || w.tr.toLowerCase().contains(query))
        .toList();
    if (hits.isEmpty) {
      return const Center(child: Text('Sonuç yok', style: TextStyle(color: AppColors.textSoft)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [for (final w in hits) WordCard(w)],
    );
  }
}

/// Kelime, Türkçesi, örnek cümle ve "deftere ekle" düğmesi.
class WordCard extends ConsumerWidget {
  const WordCard(this.w, {super.key});
  final OwnWord w;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(vocabProvider).containsKey(vocabId(w.word));
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
                        child: Text(w.word,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                      SpeakerButton(w.word, size: 20),
                    ],
                  ),
                  Text(w.tr, style: const TextStyle(fontSize: 15)),
                  if (w.example.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: GestureDetector(
                        onTap: () => Speaker.speak(w.example),
                        child: Text(w.example,
                            style: const TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textSoft)),
                      ),
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
                    ? n.remove(vocabId(w.word))
                    : n.add(w.word, w.tr, example: w.example, topicId: 'own');
              },
            ),
          ],
        ),
      ),
    );
  }
}
