import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/water_log.dart';
import 'app_logger.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  /// Current SQLite schema version.
  /// Increment this when modifying database schema.
  static const int currentDatabaseVersion = 2;
  static const String databaseFileName = 'hydro_tracker.db';

  DBHelper._init();

  bool get isReady => _database != null && _database!.isOpen;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDB(databaseFileName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: currentDatabaseVersion,
      onConfigure: _configureDB,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onDowngrade: onDatabaseDowngradeDelete,
    );
  }

  /// Configure SQLite pragmas (foreign keys, WAL mode where applicable)
  Future<void> _configureDB(Database db) async {
    try {
      await db.execute('PRAGMA foreign_keys = ON');
    } catch (_) {}
  }

  /// Called when database is created for the first time
  Future<void> _createDB(Database db, int version) async {
    debugPrint('[DBHelper] Creating new database schema version $version...');

    // 1. Water Intake Logs Table
    await db.execute('''
      CREATE TABLE water_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount_ml INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        date_string TEXT NOT NULL
      )
    ''');

    // 2. Diagnostics & Error Logs Table
    await db.execute('''
      CREATE TABLE app_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        level TEXT NOT NULL,
        tag TEXT NOT NULL,
        message TEXT NOT NULL,
        stack_trace TEXT,
        timestamp TEXT NOT NULL
      )
    ''');

    // 3. Performance Indexes
    await _createIndices(db);
    debugPrint('[DBHelper] Database tables and indices created successfully.');
  }

  /// Create search & sorting indices for fast queries
  Future<void> _createIndices(Database db) async {
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_water_date ON water_logs (date_string)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_water_time ON water_logs (timestamp)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_app_logs_time ON app_logs (timestamp)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_app_logs_level ON app_logs (level)');
    } catch (e) {
      debugPrint('[DBHelper] Index creation note: $e');
    }
  }

  /// Sequential, versioned schema migration pipeline
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    debugPrint('[DBHelper] Migrating database from version $oldVersion to $newVersion...');

    for (int targetVersion = oldVersion + 1; targetVersion <= newVersion; targetVersion++) {
      try {
        await _applyMigration(db, targetVersion);
        debugPrint('[DBHelper] Successfully migrated database to version $targetVersion.');
      } catch (e) {
        debugPrint('[DBHelper] Migration to version $targetVersion failed: $e');
        rethrow;
      }
    }
  }

  /// Individual migration steps
  Future<void> _applyMigration(Database db, int targetVersion) async {
    switch (targetVersion) {
      case 2:
        // Migration v1 -> v2: Add app_logs table and performance indices
        if (!await tableExists(db, 'app_logs')) {
          await db.execute('''
            CREATE TABLE app_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              level TEXT NOT NULL,
              tag TEXT NOT NULL,
              message TEXT NOT NULL,
              stack_trace TEXT,
              timestamp TEXT NOT NULL
            )
          ''');
        }
        await _createIndices(db);
        break;

      // Future schema versions (v3, v4, etc.) are registered here cleanly:
      // case 3:
      //   if (!await columnExists(db, 'water_logs', 'container_type')) {
      //     await db.execute('ALTER TABLE water_logs ADD COLUMN container_type TEXT DEFAULT "glass"');
      //   }
      //   break;

      default:
        AppLogger.info('DBHelper', 'No custom migration step defined for version $targetVersion');
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Schema Inspection & Health Utilities
  // ---------------------------------------------------------------------------

  /// Checks whether a table exists in the database
  Future<bool> tableExists(Database db, String tableName) async {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
  }

  /// Checks whether a column exists in a specific table
  Future<bool> columnExists(Database db, String tableName, String columnName) async {
    final result = await db.rawQuery("PRAGMA table_info($tableName)");
    for (final row in result) {
      if (row['name'] == columnName) return true;
    }
    return false;
  }

  /// Runs SQLite PRAGMA integrity_check
  Future<bool> checkIntegrity() async {
    try {
      final db = await database;
      final result = await db.rawQuery('PRAGMA integrity_check');
      if (result.isNotEmpty && result.first.values.first == 'ok') {
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('DBHelper', 'Integrity check error', e);
      return false;
    }
  }

  /// Returns the current runtime database user_version
  Future<int> getDatabaseVersion() async {
    try {
      final db = await database;
      final result = await db.rawQuery('PRAGMA user_version');
      if (result.isNotEmpty) {
        return (result.first.values.first as int?) ?? currentDatabaseVersion;
      }
      return currentDatabaseVersion;
    } catch (_) {
      return currentDatabaseVersion;
    }
  }

  // ---------------------------------------------------------------------------
  // Water Logs CRUD
  // ---------------------------------------------------------------------------

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
      final val = result.first['total'];
      return val is num ? val.toInt() : (int.tryParse(val.toString()) ?? 0);
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
      final dateStr = row['date_string']?.toString() ?? '';
      if (dateStr.isNotEmpty) {
        final val = row['total'];
        final total = val is num ? val.toInt() : (int.tryParse(val?.toString() ?? '') ?? 0);
        map[dateStr] = total;
      }
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
    if (!isReady) return -1;
    final db = _database!;
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
