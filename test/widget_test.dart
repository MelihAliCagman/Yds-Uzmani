import 'package:flutter_test/flutter_test.dart';
import 'package:yds_uzmani/core/models.dart';
import 'package:yds_uzmani/core/srs/fsrs.dart';
import 'package:yds_uzmani/core/srs/sm2.dart';

void main() {
  fsrsTests();
  test('SM-2 aralıkları 1 → 6 → ease ile büyür', () {
    var s = const CardSrs();
    s = sm2(s, Rating.good);
    expect(s.interval, 1);
    s = sm2(s, Rating.good);
    expect(s.interval, 6);
    s = sm2(s, Rating.good);
    expect(s.interval, greaterThan(6));
  });

  test('Tekrar seçilirse kart sıfırlanır', () {
    final s = sm2(const CardSrs(repetitions: 4, interval: 20), Rating.again);
    expect(s.repetitions, 0);
    expect(s.interval, 1);
  });
}

void fsrsTests() {
  const f = Fsrs();
  final t0 = DateTime(2026, 1, 1, 10);

  test('FSRS: yeni kelime Tekrar → aynı gün 10 dk sonra', () {
    final s = f.schedule(const WordSrs(), Grade.again, t0);
    expect(s.state, CardState.learning);
    expect(s.due!.difference(t0), const Duration(minutes: 10));
  });

  test('FSRS: yeni kelime İyi → günler sonra, Kolay daha uzun', () {
    final o = f.options(const WordSrs(), t0);
    expect(o[Grade.good]!.due!.isAfter(t0.add(const Duration(days: 1))), true);
    expect(o[Grade.easy]!.due!.isAfter(o[Grade.good]!.due!), true);
  });

  test('FSRS: unutunca aralık kısalır, tekrar doğruysa uzar', () {
    var s = f.schedule(const WordSrs(), Grade.good, t0);
    final firstInterval = s.due!.difference(t0).inDays;
    final t1 = s.due!;
    final grown = f.schedule(s, Grade.good, t1);
    expect(grown.due!.difference(t1).inDays, greaterThan(firstInterval));
    final lapsed = f.schedule(s, Grade.again, t1);
    expect(lapsed.state, CardState.relearning);
    expect(lapsed.lapses, 1);
    expect(lapsed.stability, lessThan(s.stability));
  });

  test('FSRS: sınav tarihi aralığı sınırlar', () {
    const capped = Fsrs(maxDays: 3);
    var s = capped.schedule(const WordSrs(), Grade.easy, t0);
    expect(s.due!.difference(t0).inDays, lessThanOrEqualTo(3));
  });
}
