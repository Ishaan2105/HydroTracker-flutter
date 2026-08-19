import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/water_log.dart';
import 'app_logger.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('hydro_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE water_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount_ml INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        date_string TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        level TEXT NOT NULL,
        tag TEXT NOT NULL,
        message TEXT NOT NULL,
        stack_trace TEXT,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          level TEXT NOT NULL,
          tag TEXT NOT NULL,
          message TEXT NOT NULL,
          stack_trace TEXT,
          timestamp TEXT NOT NULL
        )
      ''');
    }
  }

  Future<int> insertLog(WaterLog log) async {
    final db = await instance.database;
    return await db.insert('water_logs', log.toMap());
  }

  Future<List<WaterLog>> getLogsForDate(String dateString) async {
    final db = await instance.database;
    final result = await db.query(
      'water_logs',
      where: 'date_string = ?',
      whereArgs: [dateString],
      orderBy: 'timestamp DESC',
    );
    return result.map((json) => WaterLog.fromMap(json)).toList();
  }

  Future<int> getTotalIntakeForDate(String dateString) async {
    final logs = await getLogsForDate(dateString);
    int total = 0;
    for (var log in logs) {
      total += log.amountMl;
    }
    return total;
  }

  Future<WaterLog?> getLastLogForDate(String dateString) async {
    final db = await instance.database;
    final result = await db.query(
      'water_logs',
      where: 'date_string = ?',
      whereArgs: [dateString],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return WaterLog.fromMap(result.first);
    }
    return null;
  }

  Future<int> deleteLog(int id) async {
    final db = await instance.database;
    return await db.delete(
      'water_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<WaterLog>> getAllLogs() async {
    final db = await instance.database;
    final result = await db.query('water_logs', orderBy: 'timestamp DESC');
    return result.map((json) => WaterLog.fromMap(json)).toList();
  }

  Future<int> getLifetimeVolume() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT SUM(amount_ml) as total FROM water_logs');
    if (result.isNotEmpty && result.first['total'] != null) {
      return result.first['total'] as int;
    }
    return 0;
  }

  Future<Map<String, int>> getDailyTotalsMap() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT date_string, SUM(amount_ml) as total FROM water_logs GROUP BY date_string',
    );

    final Map<String, int> map = {};
    for (var row in result) {
      final dateStr = row['date_string'] as String;
      final total = row['total'] as int;
      map[dateStr] = total;
    }
    return map;
  }

  Future<int> clearAllLogs() async {
    final db = await instance.database;
    return await db.delete('water_logs');
  }

  // ---------------------------------------------------------------------------
  // App Diagnostic & Crash Logs (app_logs table)
  // ---------------------------------------------------------------------------

  Future<int> insertAppLog(LogEntry log) async {
    final db = await instance.database;
    return await db.insert('app_logs', log.toMap());
  }

  Future<List<LogEntry>> getAppLogs({int limit = 200}) async {
    final db = await instance.database;
    final result = await db.query(
      'app_logs',
      orderBy: 'id DESC',
      limit: limit,
    );
    return result.map((json) => LogEntry.fromMap(json)).toList();
  }

  Future<int> clearAppLogs() async {
    final db = await instance.database;
    return await db.delete('app_logs');
  }
}

