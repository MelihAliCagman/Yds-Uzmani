import '../models.dart';

/// UI'daki 4 buton → SM-2 kalite değeri (0-5).
enum Rating {
  again('Tekrar', 1),
  hard('Zor', 3),
  good('İyi', 4),
  easy('Kolay', 5);

  const Rating(this.label, this.quality);
  final String label;
  final int quality;
}

/// SM-2 algoritması. İleride FSRS'e geçmek için bu sınıf soyutlanabilir.
CardSrs sm2(CardSrs s, Rating rating, {DateTime? now}) {
  final q = rating.quality;
  final today = now ?? DateTime.now();

  if (q < 3) {
    return CardSrs(
      ease: s.ease,
      interval: 1,
      repetitions: 0,
      dueAt: today.add(const Duration(days: 1)),
    );
  }

  final interval = switch (s.repetitions) {
    0 => 1,
    1 => 6,
    _ => (s.interval * s.ease).round(),
  };
  final ease = (s.ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)))
      .clamp(1.3, double.infinity)
      .toDouble();

  return CardSrs(
    ease: ease,
    interval: interval,
    repetitions: s.repetitions + 1,
    dueAt: today.add(Duration(days: interval)),
  );
}
