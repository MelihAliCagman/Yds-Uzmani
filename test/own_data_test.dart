import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yds_uzmani/core/own/own_data.dart';

void main() {
  final pack = OwnPack.fromJson(
      jsonDecode(File('assets/own/midterm.json').readAsStringSync()) as Map<String, dynamic>);

  test('set eksiksiz yüklenir', () {
    expect(pack.exams.length, 10);
    for (final e in pack.exams) {
      expect(e.questions.length, 42);
      for (final q in e.questions) {
        expect(q.options.length, 4);
        expect(q.correct, inInclusiveRange(0, 3));
        if (q.section == 'reading') expect(e.passageOf(q), isNotNull);
      }
    }
    expect(pack.weeks.fold<int>(0, (a, w) => a + w.words.length), 153);
    expect(pack.extra.length, 43);
    expect(pack.confusables.length, 21);
  });

  test('kelime testi: 4 farklı şık, doğru anlam şıklar arasında', () {
    final rnd = Random(1);
    for (var i = 0; i < 20; i++) {
      final qs = buildWordQuiz(pack.allWords, pack.allWords, 999, rnd);
      expect(qs.length, greaterThan(150));
      for (final q in qs) {
        expect(q.options.toSet().length, 4);
        expect(q.options[q.correct], q.word.tr);
      }
    }
  });
}
