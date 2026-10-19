import 'dart:math' as math;

/// FSRS-4.5 (Free Spaced Repetition Scheduler) — SM-2'ye göre aynı hatırlama
/// oranı için daha az tekrar gerektirir. Varsayılan ağırlıklar resmi
/// open-spaced-repetition wiki'sinden alınmıştır.
///
/// Üstüne Anki tarzı "öğrenme adımı" eklenmiştir: unutulan/yeni kelime aynı gün
/// 10 dk sonra tekrar sorulur, hatırlanınca ertesi güne planlanır.
enum Grade {
  again(1, 'Tekrar'),
  hard(2, 'Zor'),
  good(3, 'İyi'),
  easy(4, 'Kolay');

  const Grade(this.value, this.label);
  final int value;
  final String label;
}

enum CardState { fresh, learning, review, relearning }

class WordSrs {
  const WordSrs({
    this.state = CardState.fresh,
    this.stability = 0,
    this.difficulty = 0,
    this.reps = 0,
    this.lapses = 0,
    this.due,
    this.last,
  });

  final CardState state;
  final double stability; // gün; R=%90'a düşene kadar geçen süre
  final double difficulty; // 1-10
  final int reps;
  final int lapses;
  final DateTime? due;
  final DateTime? last;

  bool isDue([DateTime? now]) => due == null || !due!.isAfter(now ?? DateTime.now());

  Map<String, dynamic> toJson() => {
        'state': state.index,
        'stability': stability,
        'difficulty': difficulty,
        'reps': reps,
        'lapses': lapses,
        'due': due?.toIso8601String(),
        'last': last?.toIso8601String(),
      };

  factory WordSrs.fromJson(Map<String, dynamic> j) => WordSrs(
        state: CardState.values[j['state'] as int],
        stability: (j['stability'] as num).toDouble(),
        difficulty: (j['difficulty'] as num).toDouble(),
        reps: j['reps'] as int,
        lapses: j['lapses'] as int,
        due: j['due'] == null ? null : DateTime.parse(j['due'] as String),
        last: j['last'] == null ? null : DateTime.parse(j['last'] as String),
      );
}

class Fsrs {
  const Fsrs({this.retention = 0.9, this.maxDays});

  /// Hedef hatırlama oranı. 0.9 = tekrar zamanı geldiğinde %90 hatırlama.
  final double retention;

  /// Sınav tarihine göre üst sınır: aralıklar sınavı aşmasın.
  final int? maxDays;

  static const _w = [
    0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.031, 1.6474,
    0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.587, 0.2272, 2.8755, //
  ];
  static const _decay = -0.5;
  static const _factor = 19 / 81;
  static const _learningStep = Duration(minutes: 10);

  static double retrievability(double days, double s) =>
      math.pow(1 + _factor * days / s, _decay).toDouble();

  int _interval(double s) {
    final days = s / _factor * (math.pow(retention, 1 / _decay) - 1);
    return days.round().clamp(1, math.max(1, maxDays ?? 36500));
  }

  double _d0(int g) => (_w[4] - (g - 3) * _w[5]).clamp(1.0, 10.0);

  double _nextD(double d, int g) =>
      (_w[7] * _d0(3) + (1 - _w[7]) * (d - _w[6] * (g - 3))).clamp(1.0, 10.0);

  /// Dört puan için de bir sonraki durumu hesaplar (buton önizlemesi için).
  Map<Grade, WordSrs> options(WordSrs c, [DateTime? at]) {
    final now = at ?? DateTime.now();
    final out = <Grade, WordSrs>{};

    WordSrs make(CardState st, double s, double d, DateTime due, {bool lapse = false}) =>
        WordSrs(
          state: st,
          stability: s,
          difficulty: d,
          reps: c.reps + 1,
          lapses: c.lapses + (lapse ? 1 : 0),
          due: due,
          last: now,
        );

    DateTime inDays(int n) => now.add(Duration(days: n));

    if (c.state == CardState.fresh) {
      for (final g in Grade.values) {
        final s = _w[g.value - 1];
        final d = _d0(g.value);
        out[g] = g.value <= 2
            ? make(CardState.learning, s, d, now.add(_learningStep))
            : make(CardState.review, s, d, inDays(_interval(s)));
      }
    } else if (c.state == CardState.learning || c.state == CardState.relearning) {
      for (final g in Grade.values) {
        out[g] = g.value <= 2
            ? make(c.state, c.stability, c.difficulty, now.add(_learningStep))
            : make(CardState.review, c.stability, c.difficulty,
                inDays(_interval(c.stability)));
      }
    } else {
      final elapsed = c.last == null ? 0.0 : now.difference(c.last!).inMinutes / 1440;
      final r = retrievability(elapsed, c.stability);
      final s = c.stability;
      final d = c.difficulty;

      double recall(double h) =>
          s *
          (1 +
              math.exp(_w[8]) *
                  (11 - d) *
                  math.pow(s, -_w[9]) *
                  (math.exp(_w[10] * (1 - r)) - 1) *
                  h);

      final forgot = (_w[11] *
              math.pow(d, -_w[12]) *
              (math.pow(s + 1, _w[13]) - 1) *
              math.exp(_w[14] * (1 - r)))
          .clamp(0.1, s);

      out[Grade.again] =
          make(CardState.relearning, forgot, _nextD(d, 1), now.add(_learningStep), lapse: true);

      final hardI = _interval(recall(_w[15]));
      // Sıralama garanti: zor < iyi < kolay (sınır dolsa bile).
      final goodI = math.max(hardI + 1, _interval(recall(1)));
      final easyI = math.max(goodI + 1, _interval(recall(_w[16])));
      out[Grade.hard] = make(CardState.review, recall(_w[15]), _nextD(d, 2), inDays(hardI));
      out[Grade.good] = make(CardState.review, recall(1), _nextD(d, 3), inDays(goodI));
      out[Grade.easy] = make(CardState.review, recall(_w[16]), _nextD(d, 4), inDays(easyI));
    }
    return out;
  }

  WordSrs schedule(WordSrs c, Grade g, [DateTime? at]) => options(c, at)[g]!;
}

/// "10 dk", "1 g", "3 g" gibi kısa etiket.
String intervalLabel(DateTime due, [DateTime? from]) {
  final d = due.difference(from ?? DateTime.now());
  if (d.inMinutes < 60) return '${math.max(1, d.inMinutes)} dk';
  if (d.inHours < 24) return '${d.inHours} sa';
  final days = (d.inHours / 24).round();
  if (days < 30) return '$days g';
  if (days < 365) return '${(days / 30).round()} ay';
  return '${(days / 365).toStringAsFixed(1)} yıl';
}
