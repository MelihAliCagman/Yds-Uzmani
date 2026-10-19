import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/tts.dart';

/// Sorunun test ettiği kelime, anlamı ve örnek cümle.
class WordInfo extends StatelessWidget {
  const WordInfo(this.q, {super.key});
  final Question q;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(q.word,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.accent)),
            ),
            SpeakerButton(q.word),
          ],
        ),
        if (q.meaning.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(q.meaning, style: const TextStyle(fontSize: 16)),
        ],
        if (q.example.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(q.example,
                    style: const TextStyle(
                        fontStyle: FontStyle.italic, color: AppColors.textSoft, height: 1.4)),
              ),
              SpeakerButton(q.example, size: 20),
            ],
          ),
        ],
      ],
    );
  }
}
