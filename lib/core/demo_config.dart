import '../models/user_model.dart';
import '../models/competition_model.dart';
import '../models/match_model.dart';
import '../models/registration_model.dart';
import '../models/sport_model.dart';
import '../models/team_model.dart';
import '../models/app_notification_model.dart';
import '../models/app_announcement_model.dart';
import '../models/admin_report_model.dart';

class AppDemoConfig {
  static bool useMockData = false;

  static UserModel studentUser = UserModel(
    id: 'mock_student_id',
    name: 'أحمد علي السقاف',
    email: 'ahmed@student.su.edu.ye',
    role: UserRole.student,
    college: 'كلية الحاسبات والمعلومات',
    department: 'تقنية المعلومات',
    academicLevel: 'المستوى الرابع',
    studentId: '202210045',
  );

  static UserModel supervisorUser = UserModel(
    id: 'mock_supervisor_id',
    name: 'أ. د. عبد الله باحشوان',
    email: 'bachwan@su.edu.ye',
    role: UserRole.supervisor,
    college: 'كلية الحاسبات والمعلومات',
  );

  static UserModel adminUser = UserModel(
    id: 'mock_admin_id',
    name: 'م. عمر بن حفيظ',
    email: 'admin@su.edu.ye',
    role: UserRole.admin,
  );

  static List<SportModel> mockSports = [
    SportModel(id: 'sport_1', name: 'كرة القدم', description: 'بطولات كرة القدم العشبية والخماسية بالكليات', iconName: 'sports_soccer'),
    SportModel(id: 'sport_2', name: 'كرة السلة', description: 'دوري كرة السلة في الصالة الرياضية المغطاة', iconName: 'sports_basketball'),
    SportModel(id: 'sport_3', name: 'الكرة الطائرة', description: 'مباريات كرة الطائرة الشاطئية والمغلقة', iconName: 'sports_volleyball'),
    SportModel(id: 'sport_4', name: 'الشطرنج', description: 'بطولة الشطرنج السنوية لطلاب كليات الجامعة', iconName: 'casino'),
    SportModel(id: 'sport_5', name: 'تنس الطاولة', description: 'مسابقات فردي وزوجي تنس الطاولة للطلاب', iconName: 'sports_tennis'),
  ];

  static List<CompetitionModel> mockCompetitions = [
    CompetitionModel(
      id: 'comp_1',
      sportId: 'sport_1',
      name: 'كأس رئيس الجامعة لكرة القدم',
      type: 'team',
      tournamentFormat: 'knockout',
      status: 'active',
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      endDate: DateTime.now().add(const Duration(days: 10)),
      college: 'كلية الحاسبات والمعلومات',
    ),
    CompetitionModel(
      id: 'comp_2',
      sportId: 'sport_4',
      name: 'البطولة السنوية الفردية للشطرنج',
      type: 'individual',
      tournamentFormat: 'league',
      status: 'active',
      startDate: DateTime.now().subtract(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      college: 'كلية الحاسبات والمعلومات',
    ),
    CompetitionModel(
      id: 'comp_3',
      sportId: 'sport_3',
      name: 'دوري الكليات للكرة الطائرة',
      type: 'team',
      tournamentFormat: 'league',
      status: 'completed',
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      endDate: DateTime.now().subtract(const Duration(days: 15)),
      championId: 'team_2',
      championName: 'فريق كلية الهندسة',
      college: 'كلية الهندسة',
    ),
    CompetitionModel(
      id: 'comp_4',
      sportId: 'sport_2',
      name: 'دوري كرة السلة الجامعي',
      type: 'team',
      tournamentFormat: 'league',
      status: 'registration',
      startDate: DateTime.now().add(const Duration(days: 10)),
      endDate: DateTime.now().add(const Duration(days: 20)),
      college: 'كلية العلوم',
    ),
  ];

  static List<TeamModel> mockTeams = [
    TeamModel(id: 'team_1', name: 'فريق كلية الحاسبات (أ)', college: 'كلية الحاسبات والمعلومات', captainId: 'mock_student_id', players: ['mock_student_id', 'player_2', 'player_3']),
    TeamModel(id: 'team_2', name: 'فريق كلية الهندسة', college: 'كلية الهندسة', captainId: 'player_4', players: ['player_4', 'player_5', 'player_6']),
    TeamModel(id: 'team_3', name: 'فريق كلية الطب والعلوم الصحية', college: 'كلية الطب والعلوم الصحية', captainId: 'player_7', players: ['player_7', 'player_8']),
    TeamModel(id: 'team_4', name: 'فريق كلية العلوم الإدارية', college: 'كلية العلوم الإدارية', captainId: 'player_9', players: ['player_9', 'player_10']),
  ];

  static List<RegistrationModel> mockRegistrations = [
    RegistrationModel(id: 'reg_1', userId: 'student_1', sportId: 'sport_1', competitionId: 'comp_1', status: 'approved', registrationDate: DateTime.now().subtract(const Duration(days: 4))),
    RegistrationModel(id: 'reg_2', userId: 'student_2', sportId: 'sport_1', competitionId: 'comp_1', status: 'pending', registrationDate: DateTime.now().subtract(const Duration(days: 3))),
    RegistrationModel(id: 'reg_3', userId: 'student_3', sportId: 'sport_4', competitionId: 'comp_2', status: 'rejected', registrationDate: DateTime.now().subtract(const Duration(days: 2))),
    RegistrationModel(id: 'reg_4', userId: 'student_4', sportId: 'sport_2', competitionId: 'comp_4', status: 'pending', registrationDate: DateTime.now()),
  ];

  static List<MatchModel> mockMatches = [
    MatchModel(
      id: 'match_1',
      competitionId: 'comp_1',
      sportId: 'sport_1',
      teamAId: 'team_1',
      teamBId: 'team_2',
      teamAName: 'فريق كلية الحاسبات (أ)',
      teamBName: 'فريق كلية الهندسة',
      matchTime: DateTime.now().add(const Duration(hours: 4)),
      status: 'scheduled',
      stage: 'دور المجموعات - الجولة الأولى',
      phase: 'group',
      groupName: 'المجموعة الأولى',
    ),
    MatchModel(
      id: 'match_2',
      competitionId: 'comp_1',
      sportId: 'sport_1',
      teamAId: 'team_3',
      teamBId: 'team_4',
      teamAName: 'فريق كلية الطب والعلوم الصحية',
      teamBName: 'فريق كلية العلوم الإدارية',
      matchTime: DateTime.now().subtract(const Duration(days: 1)),
      status: 'completed',
      scoreA: 3,
      scoreB: 1,
      winnerId: 'team_3',
      stage: 'دور المجموعات - الجولة الأولى',
      phase: 'group',
      groupName: 'المجموعة الأولى',
    ),
    MatchModel(
      id: 'match_3',
      competitionId: 'comp_1',
      sportId: 'sport_1',
      teamAId: 'team_1',
      teamBId: 'team_3',
      teamAName: 'فريق كلية الحاسبات (أ)',
      teamBName: 'فريق كلية الطب والعلوم الصحية',
      matchTime: DateTime.now().add(const Duration(days: 2)),
      status: 'scheduled',
      stage: 'نصف النهائي',
      phase: 'knockout',
      roundIndex: 0,
      matchIndex: 0,
    ),
    MatchModel(
      id: 'match_4',
      competitionId: 'comp_1',
      sportId: 'sport_1',
      teamAId: 'team_2',
      teamBId: 'team_4',
      teamAName: 'فريق كلية الهندسة',
      teamBName: 'فريق كلية العلوم الإدارية',
      matchTime: DateTime.now().add(const Duration(days: 2, hours: 2)),
      status: 'scheduled',
      stage: 'نصف النهائي',
      phase: 'knockout',
      roundIndex: 0,
      matchIndex: 1,
    ),
  ];

  static List<AppNotificationModel> mockNotifications = [
    AppNotificationModel(
      id: 'notif_1',
      recipientId: 'mock_student_id',
      title: 'تمت الموافقة على طلب التسجيل',
      body: 'لقد تمت الموافقة على طلب مشاركتك في كأس رئيس الجامعة لكرة القدم.',
      type: 'registration_approved',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      relatedId: 'comp_1',
      isRead: false,
    ),
    AppNotificationModel(
      id: 'notif_2',
      recipientId: 'mock_student_id',
      title: 'إضافة مباراة جديدة في الجدول',
      body: 'تم تحديد موعد مباراتكم القادمة ضد فريق كلية الهندسة اليوم الساعة 4:00 عصراً.',
      type: 'match_scheduled',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      relatedId: 'match_1',
      isRead: true,
    ),
    AppNotificationModel(
      id: 'notif_3',
      recipientId: 'mock_student_id',
      title: 'تنبيه هام من المشرف الرياضي',
      body: 'يرجى من جميع كباتن الفرق إحضار كشوفات اللاعبين مصدقة قبل موعد البطولة بيومين.',
      type: 'announcement',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: false,
    ),
  ];

  static AdminReportModel mockReport = const AdminReportModel(
    sportsCount: 5,
    activeSportsCount: 5,
    competitionsCount: 4,
    activeCompetitionsCount: 2,
    teamsCount: 12,
    playersCount: 86,
    studentsCount: 342,
    adminsCount: 6,
    matchesCount: 24,
    upcomingMatchesCount: 8,
    completedMatchesCount: 16,
    registrationsCount: 48,
    pendingRegistrationsCount: 12,
    approvedRegistrationsCount: 30,
    rejectedRegistrationsCount: 6,
    competitionsByType: {
      'بطولة جماعية': 3,
      'بطولة فردية': 1,
    },
    registrationsByStatus: {
      'مقبول': 30,
      'معلق': 12,
      'مرفوض': 6,
    },
    matchesByStatus: {
      'مكتملة': 16,
      'مجدولة': 8,
    },
    teamsByCollege: {
      'كلية الحاسبات': 4,
      'كلية الهندسة': 3,
      'كلية العلوم': 2,
      'كلية الطب': 3,
    },
  );

  static List<AppAnnouncementModel> mockAnnouncements = [
    AppAnnouncementModel(
      id: 'ann_1',
      title: 'تنبيه هام من المشرف الرياضي',
      body: 'يرجى من جميع كباتن الفرق إحضار كشوفات اللاعبين مصدقة قبل موعد البطولة بيومين.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      recipientsCount: 45,
      notificationIds: const ['notif_3'],
    ),
  ];
}
