import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:device_frame/device_frame.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:unisport/core/theme.dart';
import 'package:unisport/core/demo_config.dart';
import 'package:unisport/providers/auth_provider.dart';
import 'package:unisport/models/user_model.dart';
import 'package:unisport/models/competition_model.dart';
import 'package:unisport/models/team_model.dart';

import 'package:unisport/features/auth/login_screen.dart';
import 'package:unisport/features/auth/register_screen.dart';
import 'package:unisport/features/home/student_home_screen.dart';
import 'package:unisport/features/winners/winners_screen.dart';
import 'package:unisport/features/notifications/notifications_screen.dart';
import 'package:unisport/features/dashboard/admin_dashboard_screen.dart';
import 'package:unisport/features/dashboard/manage_competitions_screen.dart';
import 'package:unisport/features/dashboard/create_competition_screen.dart';
import 'package:unisport/features/dashboard/manage_teams_screen.dart';
import 'package:unisport/features/dashboard/manage_registrations_screen.dart';
import 'package:unisport/features/dashboard/announcements_screen.dart';
import 'package:unisport/features/dashboard/reports_screen.dart';
import 'package:unisport/features/dashboard/add_admin_screen.dart';
import 'package:unisport/features/dashboard/add_sport_screen.dart';

// Imports for screens that require parameters (imported with prefixes so we can wrap them)
import 'package:unisport/features/auth/onboarding_screen.dart';
import 'package:unisport/features/home/student_tournament_bracket_screen.dart' as real_bracket;
import 'package:unisport/features/dashboard/competition_details_screen.dart' as real_comp;
import 'package:unisport/features/dashboard/team_details_screen.dart' as real_team;

// Mock Auth Provider implementation
class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isAuthReady = true;
  bool _seenOnboarding = true;

  @override
  UserModel? get currentUser => _currentUser;
  set currentUser(UserModel? val) {
    _currentUser = val;
    notifyListeners();
  }

  @override
  bool get isAuthenticated => _currentUser != null;

  @override
  bool get isLoading => _isLoading;
  set isLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  @override
  bool get isAuthReady => _isAuthReady;
  set isAuthReady(bool val) {
    _isAuthReady = val;
    notifyListeners();
  }

  @override
  bool get seenOnboarding => _seenOnboarding;
  set seenOnboarding(bool val) {
    _seenOnboarding = val;
    notifyListeners();
  }

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> registerStudent({
    required String email,
    required String name,
    required String studentId,
    required String college,
    required String department,
    required String academicLevel,
    required String password,
  }) async {}

  @override
  Future<void> createAdminAccount({
    required String email,
    required String name,
    required String password,
    UserRole role = UserRole.admin,
    String? college,
  }) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> completeOnboarding() async {}
}

// Local wrappers to satisfy parameterless const constructor requirement
class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => const OnboardingScreen();
}

class OnboardingFeaturesScreen extends StatelessWidget {
  const OnboardingFeaturesScreen({super.key});
  @override
  Widget build(BuildContext context) => const OnboardingScreen();
}

class OnboardingStatsScreen extends StatelessWidget {
  const OnboardingStatsScreen({super.key});
  @override
  Widget build(BuildContext context) => const OnboardingScreen();
}

class StudentTournamentBracketScreen extends StatelessWidget {
  const StudentTournamentBracketScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return real_bracket.StudentTournamentBracketScreen(
      competition: CompetitionModel(
        id: 'comp_1',
        sportId: 'sport_1',
        name: 'كأس رئيس الجامعة لكرة القدم',
        type: 'team',
        status: 'active',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
      ),
    );
  }
}

class CompetitionDetailsScreen extends StatelessWidget {
  const CompetitionDetailsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return real_comp.CompetitionDetailsScreen(
      competition: CompetitionModel(
        id: 'comp_1',
        sportId: 'sport_1',
        name: 'كأس رئيس الجامعة لكرة القدم',
        type: 'team',
        status: 'active',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
      ),
    );
  }
}

class TeamDetailsScreen extends StatelessWidget {
  const TeamDetailsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return real_team.TeamDetailsScreen(
      team: TeamModel(
        id: 'team_1',
        name: 'فريق كلية الحاسبات (أ)',
        college: 'كلية الحاسبات والمعلومات',
        players: const ['mock_student_id', 'player_2', 'player_3'],
      ),
    );
  }
}

void main() {
  testGoldens('Capture all graduation project screens on Samsung Ultra device', (tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exceptionAsString();
      if (msg.contains('overflowed') || msg.contains('deactivated widget')) {
        debugPrint('Ignored expected test warning: $msg');
        return;
      }
      originalOnError?.call(details);
    };

    addTearDown(() {
      FlutterError.onError = originalOnError;
    });

    // 1. Enable mock data mode globally
    AppDemoConfig.useMockData = true;

    // 2. Load ThmanyahSans and other app fonts
    await loadAppFonts();

    final Map<String, Widget> appScreens = {
      '01_onboarding_welcome': const OnboardingWelcomeScreen(),
      '02_onboarding_features': const OnboardingFeaturesScreen(),
      '03_onboarding_stats': const OnboardingStatsScreen(),
      '04_login': const LoginScreen(),
      '05_register': const RegisterScreen(),
      '06_student_home': const StudentHomeScreen(),
      '07_tournament_bracket': const StudentTournamentBracketScreen(),
      '08_winners': const WinnersScreen(),
      '09_notifications': const NotificationsScreen(),
      '10_admin_dashboard': const AdminDashboardScreen(),
      '11_manage_competitions': const ManageCompetitionsScreen(),
      '12_competition_details': const CompetitionDetailsScreen(),
      '13_create_competition': const CreateCompetitionScreen(),
      '14_manage_teams': const ManageTeamsScreen(),
      '15_team_details': const TeamDetailsScreen(),
      '16_manage_registrations': const ManageRegistrationsScreen(),
      '17_announcements': const AnnouncementsScreen(),
      '18_reports': const ReportsScreen(),
      '19_add_admin': const AddAdminScreen(),
      '20_add_sport': const AddSportScreen(),
    };

    final mockAuth = FakeAuthProvider();

    for (var entry in appScreens.entries) {
      final screenName = entry.key;
      final screenWidget = entry.value;

      // Configure mockAuth roles for each screen
      if (screenName.startsWith('01_') || screenName.startsWith('02_') || screenName.startsWith('03_')) {
        mockAuth.seenOnboarding = false;
        mockAuth.currentUser = null;
      } else if (screenName.startsWith('04_') || screenName.startsWith('05_')) {
        mockAuth.seenOnboarding = true;
        mockAuth.currentUser = null;
      } else if (screenName.startsWith('06_') || screenName.startsWith('07_') || screenName.startsWith('08_') || screenName.startsWith('09_')) {
        mockAuth.seenOnboarding = true;
        mockAuth.currentUser = AppDemoConfig.studentUser;
      } else {
        mockAuth.seenOnboarding = true;
        mockAuth.currentUser = AppDemoConfig.adminUser;
      }

      // Build widget wrapped in ProviderScope, MultiProvider, and localized MaterialApp
      final widgetToRender = ProviderScope(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ar', 'YE'),
            ],
            locale: const Locale('ar', 'YE'),
            home: Scaffold(
              body: DeviceFrame(
                device: Devices.android.samsungGalaxyS20, // Samsung S20 device frame
                isFrameVisible: true,
                orientation: Orientation.portrait,
                screen: screenWidget,
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidgetBuilder(
        widgetToRender,
        surfaceSize: const Size(1000, 2000), 
      );

      // Handle PageView navigation for onboarding sub-screens
      if (screenName == '02_onboarding_features') {
        final PageView pageView = tester.widget<PageView>(find.byType(PageView));
        pageView.controller?.jumpToPage(1);
        await tester.pump(const Duration(milliseconds: 500));
      } else if (screenName == '03_onboarding_stats') {
        final PageView pageView = tester.widget<PageView>(find.byType(PageView));
        pageView.controller?.jumpToPage(2);
        await tester.pump(const Duration(milliseconds: 500));
      }

      await tester.pump(const Duration(seconds: 1)); // Wait for render and animations

      await screenMatchesGolden(
        tester,
        'mockups/$screenName',
        customPump: (tester) async => await tester.pump(const Duration(seconds: 1)),
      );
    }
  });
}
