import 'package:flutter/material.dart';

enum Exam {
  yds('YDS'),
  yokdil('YÖKDİL');

  const Exam(this.label);
  final String label;
}

class Topic {
  const Topic(this.id, this.name, {this.level = 1});
  final String id;
  final String name;
  final int level;
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.exams,
    required this.topics,
    this.field = 'general',
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final Set<Exam> exams;
  final List<Topic> topics;

  /// general / science / health / social
  final String field;
}

/// Soru metnindeki zor kelime ve Türkçe anlamı.
class Gloss {
  const Gloss(this.word, this.meaning);
  final String word;
  final String meaning;
}

/// Bazı üretilmiş şıklarda "A) " gibi önekler olabiliyor; gösterimde temizlenir.
final _optionPrefix = RegExp(r'^\s*\(?[A-Ea-e][\).]\s+');

class Question {
  const Question({
    required this.id,
    required this.topicId,
    required this.stem,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.level = 3,
    this.source = 'seed',
    this.word = '',
    this.meaning = '',
    this.example = '',
    this.glossary = const [],
  });

  final String id;
  final String topicId;
  final String stem;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final int level;
  final String source; // ai / manual / seed

  /// Sorunun test ettiği kelime / yapı, Türkçe anlamı ve örnek cümle.
  /// Yanlış defterinde gösterilir.
  final String word;
  final String meaning;
  final String example;

  /// Soru metnindeki (şıklar hariç) zor kelimeler.
  final List<Gloss> glossary;

  Map<String, dynamic> toJson() => {
        'id': id,
        'topicId': topicId,
        'stem': stem,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
        'level': level,
        'source': source,
        'word': word,
        'meaning': meaning,
        'example': example,
        'glossary': [
          for (final g in glossary) {'word': g.word, 'meaning': g.meaning}
        ],
      };

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as String,
        topicId: j['topicId'] as String,
        stem: j['stem'] as String,
        options: [
          for (final o in j['options'] as List) '$o'.replaceFirst(_optionPrefix, '').trim()
        ],
        correctIndex: j['correctIndex'] as int,
        explanation: j['explanation'] as String,
        level: (j['level'] as int?) ?? 3,
        source: (j['source'] as String?) ?? 'seed',
        word: (j['word'] as String?) ?? '',
        meaning: (j['meaning'] as String?) ?? '',
        example: (j['example'] as String?) ?? '',
        glossary: [
          for (final g in (j['glossary'] as List? ?? const []))
            Gloss('${g['word']}', '${g['meaning']}')
        ],
      );
}

class Flashcard {
  const Flashcard({
    required this.id,
    required this.front,
    required this.back,
    required this.example,
    this.field = 'general',
  });

  final String id;
  final String front;
  final String back;
  final String example;
  final String field;
}

/// Bir kartın aralıklı tekrar (SM-2) durumu.
class CardSrs {
  const CardSrs({
    this.ease = 2.5,
    this.interval = 0,
    this.repetitions = 0,
    this.dueAt,
  });

  final double ease;
  final int interval;
  final int repetitions;
  final DateTime? dueAt;

  bool get isNew => dueAt == null;
  bool get isDue => dueAt == null || !dueAt!.isAfter(DateTime.now());

  Map<String, dynamic> toJson() => {
        'ease': ease,
        'interval': interval,
        'repetitions': repetitions,
        'dueAt': dueAt?.toIso8601String(),
      };

  factory CardSrs.fromJson(Map<String, dynamic> j) => CardSrs(
        ease: (j['ease'] as num).toDouble(),
        interval: j['interval'] as int,
        repetitions: j['repetitions'] as int,
        dueAt: j['dueAt'] == null ? null : DateTime.parse(j['dueAt'] as String),
      );
}
