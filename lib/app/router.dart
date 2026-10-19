import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/curriculum/category_screen.dart';
import '../features/curriculum/curriculum_screen.dart';
import '../features/decks/decks_screen.dart';
import '../features/flashcards/flashcards_screen.dart';
import '../features/generator/generator_screen.dart';
import '../features/home/home_screen.dart';
import '../features/mock/mock_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/study/study_screen.dart';
import '../features/vocab/vocab_review_screen.dart';
import '../features/vocab/vocab_screen.dart';
import '../features/wrong/wrong_screen.dart';

final router = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _Shell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/curriculum', builder: (_, __) => const CurriculumScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/study', builder: (_, __) => const StudyScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/decks', builder: (_, __) => const DecksScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ]),
      ],
    ),
    GoRoute(
      path: '/category/:id',
      builder: (_, s) => CategoryScreen(categoryId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/quiz',
      builder: (_, s) => QuizScreen(
        topicId: s.uri.queryParameters['topic'],
        categoryId: s.uri.queryParameters['category'],
        wrongOnly: s.uri.queryParameters['wrong'] == '1',
        weakOnly: s.uri.queryParameters['weak'] == '1',
      ),
    ),
    GoRoute(path: '/mock', builder: (_, __) => const MockScreen()),
    GoRoute(path: '/wrong', builder: (_, __) => const WrongScreen()),
    GoRoute(path: '/vocab', builder: (_, __) => const VocabScreen()),
    GoRoute(path: '/vocab/review', builder: (_, __) => const VocabReviewScreen()),
    GoRoute(
      path: '/flashcards',
      builder: (_, s) => FlashcardsScreen(field: s.uri.queryParameters['field']),
    ),
    GoRoute(
      path: '/generator',
      builder: (_, s) => GeneratorScreen(topicId: s.uri.queryParameters['topic']),
    ),
  ],
);

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        // Geniş ekranda (web) içerik ortalanır.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: shell,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Ana Sayfa'),
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route_rounded), label: 'Müfredat'),
          NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt_rounded), label: 'Çalış'),
          NavigationDestination(icon: Icon(Icons.style_outlined), selectedIcon: Icon(Icons.style_rounded), label: 'Setlerim'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}
