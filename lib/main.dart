import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/models.dart';
import 'core/providers.dart';
import 'core/widgets/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final raw = await rootBundle.loadString('assets/seed/questions.json');
  final seed = (jsonDecode(raw) as List)
      .map((e) => Question.fromJson(e as Map<String, dynamic>))
      .toList();
  runApp(ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      seedAssetProvider.overrideWithValue(seed),
    ],
    child: const YdsApp(),
  ));
}

class YdsApp extends StatelessWidget {
  const YdsApp({super.key});

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
