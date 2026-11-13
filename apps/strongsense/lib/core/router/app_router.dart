import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/checkin/checkin_screen.dart';
import '../../features/coach/coach_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/history/session_detail_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/program/program_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/summary/summary_screen.dart';
import '../../features/workout/workout_screen.dart';
import '../../state/providers.dart';
import '../widgets/ss_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final settings = ref.read(initialSettingsProvider);

  return GoRouter(
    initialLocation: settings.onboardingComplete ? '/' : '/onboarding',
    routes: <RouteBase>[
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            SsShell(location: state.uri.path, child: child),
        routes: <RouteBase>[
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/coach',
            builder: (context, state) => const CoachScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/history/:id',
            builder: (context, state) =>
                SessionDetailScreen(sessionId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/program',
            builder: (context, state) => const ProgramScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/checkin',
        builder: (context, state) =>
            CheckinScreen(initialDayId: state.uri.queryParameters['day']),
      ),
      GoRoute(
        path: '/workout/:id',
        builder: (context, state) =>
            WorkoutScreen(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/summary/:id',
        builder: (context, state) =>
            SummaryScreen(sessionId: state.pathParameters['id']!),
      ),
    ],
  );
});
