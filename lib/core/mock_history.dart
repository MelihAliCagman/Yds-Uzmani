import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Biten bir deneme sınavının özeti.
class MockResult {
  const MockResult({
    required this.date,
    required this.exam,
    required this.total,
    required this.correct,
    required this.wrong,
    required this.seconds,
  });

  final DateTime date;
  final String exam;
  final int total;
  final int correct;
  final int wrong;
  final int seconds;

  int get blank => total - correct - wrong;
  double get percent => total == 0 ? 0 : correct / total * 100;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'exam': exam,
        'total': total,
        'correct': correct,
        'wrong': wrong,
        'seconds': seconds,
      };

  factory MockResult.fromJson(Map<String, dynamic> j) => MockResult(
        date: DateTime.parse(j['date'] as String),
        exam: j['exam'] as String,
        total: j['total'] as int,
        correct: j['correct'] as int,
        wrong: j['wrong'] as int,
        seconds: j['seconds'] as int,
      );
}

class MockHistoryNotifier extends Notifier<List<MockResult>> {
  static const _key = 'mock_history';

  @override
  List<MockResult> build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => MockResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void add(MockResult r) {
    state = [r, ...state].take(30).toList();
    ref.read(prefsProvider).setString(_key, jsonEncode(state.map((e) => e.toJson()).toList()));
  }
}

final mockHistoryProvider =
    NotifierProvider<MockHistoryNotifier, List<MockResult>>(MockHistoryNotifier.new);
