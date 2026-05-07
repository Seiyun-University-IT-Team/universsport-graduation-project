import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('unisport.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Users Table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        role TEXT NOT NULL,
        password TEXT NOT NULL,
        student_id TEXT,
        college TEXT,
        department TEXT,
        academic_level TEXT
      )
    ''');

    // Create a default Admin
    await db.rawInsert('''
      INSERT INTO users (id, name, email, role, password) 
      VALUES ('admin_1', 'مدير النظام', 'admin@seiyun.edu.ye', 'admin', 'admin123')
    ''');

    // Sports Table
    await db.execute('''
      CREATE TABLE sports (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT
      )
    ''');

    // Default Sports
    await db.rawInsert("INSERT INTO sports (id, name) VALUES ('sport_1', 'كرة القدم')");
    await db.rawInsert("INSERT INTO sports (id, name) VALUES ('sport_2', 'كرة السلة')");
    await db.rawInsert("INSERT INTO sports (id, name) VALUES ('sport_3', 'الكرة الطائرة')");

    // Competitions Table
    await db.execute('''
      CREATE TABLE competitions (
        id TEXT PRIMARY KEY,
        sport_id TEXT NOT NULL,
        name TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (sport_id) REFERENCES sports (id) ON DELETE CASCADE
      )
    ''');

    // Teams Table
    await db.execute('''
      CREATE TABLE teams (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        college TEXT NOT NULL
      )
    ''');

    // Matches Table
    await db.execute('''
      CREATE TABLE matches (
        id TEXT PRIMARY KEY,
        competition_id TEXT NOT NULL,
        team_a_id TEXT NOT NULL,
        team_b_id TEXT NOT NULL,
        match_time TEXT NOT NULL,
        status TEXT NOT NULL,
        score_a INTEGER,
        score_b INTEGER,
        FOREIGN KEY (competition_id) REFERENCES competitions (id) ON DELETE CASCADE,
        FOREIGN KEY (team_a_id) REFERENCES teams (id),
        FOREIGN KEY (team_b_id) REFERENCES teams (id)
      )
    ''');

    // Registrations Table
    await db.execute('''
      CREATE TABLE registrations (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        sport_id TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (sport_id) REFERENCES sports (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
