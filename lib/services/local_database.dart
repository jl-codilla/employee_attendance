import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._internal();

  static Database? _database;

  LocalDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();

    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();

    final path = join(
      databasePath,
      'employee_attendance.db',
    );

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(
    Database db,
    int version,
  ) async {
    await db.execute('''
      CREATE TABLE pending_attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_uid TEXT NOT NULL,
        action TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<int> insertPendingAttendance({
    required String userUid,
    required String action,
    required double latitude,
    required double longitude,
    required DateTime createdAt,
  }) async {
    final db = await database;

    return await db.insert(
      'pending_attendance',
      {
        'user_uid': userUid,
        'action': action,
        'latitude': latitude,
        'longitude': longitude,
        'created_at': createdAt.toIso8601String(),
        'synced': 0,
      },
    );
  }

  Future<List<Map<String, dynamic>>>
      getPendingAttendance() async {
    final db = await database;

    return await db.query(
      'pending_attendance',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> deletePendingAttendance(int id) async {
    final db = await database;

    await db.delete(
      'pending_attendance',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearPendingAttendance() async {
    final db = await database;

    await db.delete('pending_attendance');
  }
}

