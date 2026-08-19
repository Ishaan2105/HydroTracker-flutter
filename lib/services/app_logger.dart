import 'dart:async';
import 'package:flutter/foundation.dart';
import 'db_helper.dart';

enum LogLevel { info, warn, error, crash }

class LogEntry {
  final int? id;
  final LogLevel level;
  final String tag;
  final String message;
  final String? stackTrace;
  final DateTime timestamp;

  LogEntry({
    this.id,
    required this.level,
    required this.tag,
    required this.message,
    this.stackTrace,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'level': level.name.toUpperCase(),
    'tag': tag,
    'message': message,
    'stack_trace': stackTrace,
    'timestamp': timestamp.toIso8601String(),
  };

  factory LogEntry.fromMap(Map<String, dynamic> map) => LogEntry(
    id: map['id'] as int?,
    level: _parseLevel(map['level'] as String?),
    tag: map['tag'] as String? ?? 'App',
    message: map['message'] as String? ?? '',
    stackTrace: map['stack_trace'] as String?,
    timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
  );

  static LogLevel _parseLevel(String? val) {
    switch (val?.toUpperCase()) {
      case 'WARN':
        return LogLevel.warn;
      case 'ERROR':
        return LogLevel.error;
      case 'CRASH':
        return LogLevel.crash;
      default:
        return LogLevel.info;
    }
  }

  String formatLine() {
    final timeStr = "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}";
    final lvl = level.name.toUpperCase().padRight(5);
    final text = '[$timeStr] [$lvl] [$tag] $message';
    if (stackTrace != null && stackTrace!.isNotEmpty) {
      return '$text\nStack:\n$stackTrace';
    }
    return text;
  }
}

/// Offline-first Error Logging & Diagnostics Service
class AppLogger {
  static const int _maxInMemory = 150;
  static final List<LogEntry> _inMemoryLogs = [];

  static List<LogEntry> get inMemoryLogs => List.unmodifiable(_inMemoryLogs);

  static void info(String tag, String message) {
    _record(LogLevel.info, tag, message);
  }

  static void warn(String tag, String message, [dynamic error]) {
    final msg = error != null ? '$message: $error' : message;
    _record(LogLevel.warn, tag, msg);
  }

  static void error(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
    final msg = error != null ? '$message: $error' : message;
    _record(LogLevel.error, tag, msg, stackTrace?.toString());
  }

  static void crash(String tag, dynamic error, [StackTrace? stackTrace]) {
    _record(
      LogLevel.crash,
      tag,
      'CRASH/UNHANDLED: $error',
      stackTrace?.toString() ?? StackTrace.current.toString(),
    );
  }

  static void _record(LogLevel level, String tag, String message, [String? stackTrace]) {
    final entry = LogEntry(
      level: level,
      tag: tag,
      message: message,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
    );

    // 1. In-memory buffer
    _inMemoryLogs.insert(0, entry);
    if (_inMemoryLogs.length > _maxInMemory) {
      _inMemoryLogs.removeLast();
    }

    // 2. Also print to console for debug
    debugPrint('[${level.name.toUpperCase()}] [$tag] $message');

    // 3. Asynchronously persist to SQLite app_logs table
    DBHelper.instance.insertAppLog(entry).catchError((e) {
      debugPrint('AppLogger DB persist error: $e');
      return -1;
    });
  }

  /// Get all persisted logs from SQLite database
  static Future<List<LogEntry>> getHistoricalLogs() async {
    try {
      return await DBHelper.instance.getAppLogs();
    } catch (e) {
      debugPrint('Failed to get historical logs: $e');
      return _inMemoryLogs;
    }
  }

  /// Clear all logs in memory and SQLite
  static Future<void> clearAllLogs() async {
    _inMemoryLogs.clear();
    try {
      await DBHelper.instance.clearAppLogs();
    } catch (_) {}
  }

  /// Export logs as a single shareable formatted string
  static Future<String> exportLogsString() async {
    final logs = await getHistoricalLogs();
    final buffer = StringBuffer();
    buffer.writeln('=== HYDRO TRACKER DIAGNOSTIC LOGS ===');
    buffer.writeln('Generated at: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total Log Entries: ${logs.length}');
    buffer.writeln('=====================================\n');

    for (final log in logs) {
      buffer.writeln(log.formatLine());
      buffer.writeln('-------------------------------------');
    }
    return buffer.toString();
  }
}
