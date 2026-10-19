import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/models.dart';
import 'core/providers.dart';
import 'core/reminders.dart';
import 'core/widgets/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Soru bankası + ikiz (yedek) sorular.
  final seed = <Question>[];
  for (final file in ['assets/seed/questions.json', 'assets/seed/twins.json']) {
    final raw = await rootBundle.loadString(file);
    seed.addAll((jsonDecode(raw) as List).map((e) => Question.fromJson(e as Map<String, dynamic>)));
  }
  runApp(ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      seedAssetProvider.overrideWithValue(seed),
    ],
    child: const YdsApp(),
  ));
}

class YdsApp extends ConsumerStatefulWidget {
  const YdsApp({super.key});

  @override
  ConsumerState<YdsApp> createState() => _YdsAppState();
}

class _YdsAppState extends ConsumerState<YdsApp> {
  @override
  void initState() {
    super.initState();
    // Telefon yeniden başlamış olabilir: günlük hatırlatmayı yeniden planla.
    ref.read(reminderProvider.notifier).restore();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'YDS Uzmanı',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
      builder: (context, child) => GradientBackground(child: child!),
    );
  }
}
