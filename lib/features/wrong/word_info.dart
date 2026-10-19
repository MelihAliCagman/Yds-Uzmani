import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models.dart';

/// Sorunun test ettiği kelime, anlamı ve örnek cümle.
class WordInfo extends StatelessWidget {
  const WordInfo(this.q, {super.key});
  final Question q;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(q.word,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.accent)),
        if (q.meaning.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(q.meaning, style: const TextStyle(fontSize: 16)),
        ],
        if (q.example.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(q.example,
              style: const TextStyle(
                  fontStyle: FontStyle.italic, color: AppColors.textSoft, height: 1.4)),
        ],
      ],
    );
  }
}
