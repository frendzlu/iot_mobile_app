import 'package:flutter/foundation.dart';
import '../../models/log_entry.dart';

class LogService extends ChangeNotifier {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<LogEntry> _logs = [];
  final int maxLogs = 1000;

  List<LogEntry> get logs => List.unmodifiable(_logs);

  void log(String module, String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      module: module,
      message: message,
      level: level,
    );

    _logs.add(entry);
    
    // Keep only the most recent logs
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }

    // Also print to console for debugging
    if (kDebugMode) {
      print(entry.toString());
    }

    notifyListeners();
  }

  void debug(String module, String message) => log(module, message, level: LogLevel.debug);
  void info(String module, String message) => log(module, message, level: LogLevel.info);
  void warning(String module, String message) => log(module, message, level: LogLevel.warning);
  void error(String module, String message) => log(module, message, level: LogLevel.error);
  void success(String module, String message) => log(module, message, level: LogLevel.success);

  void clear() {
    _logs.clear();
    notifyListeners();
  }
}