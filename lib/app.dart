import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/dashboard/admin_dashboard_screen.dart';
import 'features/dashboard/add_admin_screen.dart';
import 'features/home/student_home_screen.dart';
import 'features/dashboard/add_sport_screen.dart';
import 'features/dashboard/create_competition_screen.dart';
import 'features/dashboard/manage_teams_screen.dart';
import 'features/dashboard/manage_registrations_screen.dart';
import 'features/dashboard/manage_competitions_screen.dart';
import 'features/dashboard/announcements_screen.dart';
import 'features/dashboard/competition_details_screen.dart';
import 'features/dashboard/team_details_screen.dart';
import 'features/dashboard/reports_screen.dart';
import 'features/winners/winners_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'models/competition_model.dart';
import 'models/team_model.dart';

class UniSportApp extends StatefulWidget {
  const UniSportApp({super.key});

  @override
  State<UniSportApp> createState() => _UniSportAppState();
}

class _UniSportAppState extends State<UniSportApp> {
  late final AuthProvider _authProvider;
  late final GoRouter _router;

  static const Set<String> _publicRoutes = {'/', '/register', '/auth_loading', '/onboarding'};

  static const Set<String> _studentRoutes = {
    '/student_home',
    '/winners',
    '/notifications',
  };

  static const Set<String> _sharedRoutes = {'/winners'};

  static const Set<String> _adminRoutes = {
    '/admin_dashboard',
    '/add_admin',
    '/add_sport',
    '/create_competition',
    '/manage_teams',
    '/manage_registrations',
    '/manage_competitions',
    '/announcements',
    '/competition_details',
    '/team_details',
    '/reports',
  };

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _router = GoRouter(
      initialLocation: '/',
      refreshListenable: _authProvider,
      redirect: _redirectByRole,
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/auth_loading',
          builder: (context, state) => const _AuthLoadingScreen(),
        ),
        GoRoute(
          path: '/admin_dashboard',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: '/add_admin',
          builder: (context, state) => const AddAdminScreen(),
        ),
        GoRoute(
          path: '/student_home',
          builder: (context, state) => const StudentHomeScreen(),
        ),
        GoRoute(
          path: '/add_sport',
          builder: (context, state) => const AddSportScreen(),
        ),
        GoRoute(
          path: '/create_competition',
          builder: (context, state) => const CreateCompetitionScreen(),
        ),
        GoRoute(
          path: '/manage_teams',
          builder: (context, state) => const ManageTeamsScreen(),
        ),
        GoRoute(
          path: '/manage_registrations',
          builder: (context, state) => const ManageRegistrationsScreen(),
        ),
        GoRoute(
          path: '/manage_competitions',
          builder: (context, state) => const ManageCompetitionsScreen(),
        ),
        GoRoute(
          path: '/announcements',
          builder: (context, state) => const AnnouncementsScreen(),
        ),
        GoRoute(
          path: '/competition_details',
          builder: (context, state) {
            final comp = state.extra as CompetitionModel;
            return CompetitionDetailsScreen(competition: comp);
          },
        ),
        GoRoute(
          path: '/team_details',
          builder: (context, state) {
            final team = state.extra as TeamModel;
            return TeamDetailsScreen(team: team);
          },
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: '/winners',
          builder: (context, state) => const WinnersScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
      ],
    );
  }

  String? _redirectByRole(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;
    final isPublicRoute = _publicRoutes.contains(location);
    final isAdminRoute = _adminRoutes.contains(location);
    final isStudentRoute = _studentRoutes.contains(location);
    final isSharedRoute = _sharedRoutes.contains(location);
    if (!_authProvider.isAuthReady) {
      return '/auth_loading';
    }

    final user = _authProvider.currentUser;

    if (user == null) {
      if (!_authProvider.seenOnboarding && location != '/onboarding') {
        return '/onboarding';
      }
      if (location == '/auth_loading' || location == '/onboarding') {
        if (_authProvider.seenOnboarding) return '/';
        return null;
      }
      return isPublicRoute ? null : '/';
    }

    if (location == '/' ||
        location == '/register' ||
        location == '/auth_loading') {
      return (user.isAdmin || user.isSupervisor)
          ? '/admin_dashboard'
          : '/student_home';
    }

    if (isSharedRoute) {
      return null;
    }

    if (isAdminRoute && !(user.isAdmin || user.isSupervisor)) {
      return '/student_home';
    }

    if (isStudentRoute && !user.isStudent) {
      return '/admin_dashboard';
    }

    return null;
  }

  @override
  void dispose() {
    _router.dispose();
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider.value(value: _authProvider)],
      child: MaterialApp.router(
        title: 'رياضة جامعة سيئون',
        theme: AppTheme.lightTheme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar', 'YE'), // Arabic (Yemen)
        ],
        locale: const Locale('ar', 'YE'),
      ),
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
