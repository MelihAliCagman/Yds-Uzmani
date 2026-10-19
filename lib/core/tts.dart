import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../app/theme.dart';

/// İngilizce telaffuz (cihazın metin okuma motoru ile, internet gerekmez).
class Speaker {
  static final FlutterTts _tts = FlutterTts();
  static bool _ready = false;

  static Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      if (!_ready) {
        await _tts.setLanguage('en-US');
        await _tts.setSpeechRate(0.42);
        _ready = true;
      }
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Cihazda TTS yoksa sessizce geç.
    }
  }
}

class SpeakerButton extends StatelessWidget {
  const SpeakerButton(this.text, {super.key, this.size = 22});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Dinle',
      visualDensity: VisualDensity.compact,
      iconSize: size,
      color: AppColors.accent,
      icon: const Icon(Icons.volume_up_rounded),
      onPressed: () => Speaker.speak(text),
    );
  }
}
