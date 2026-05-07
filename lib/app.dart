import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/dashboard/admin_dashboard_screen.dart';
import 'features/home/student_home_screen.dart';
import 'features/dashboard/add_sport_screen.dart';
import 'features/dashboard/create_competition_screen.dart';
import 'features/dashboard/manage_teams_screen.dart';
import 'features/dashboard/manage_registrations_screen.dart';
import 'features/dashboard/manage_competitions_screen.dart';
import 'features/dashboard/competition_details_screen.dart';
import 'models/competition_model.dart';

class UniSportApp extends StatelessWidget {
  UniSportApp({super.key});

  final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/admin_dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
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
        path: '/competition_details',
        builder: (context, state) {
          final comp = state.extra as CompetitionModel;
          return CompetitionDetailsScreen(competition: comp);
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
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
