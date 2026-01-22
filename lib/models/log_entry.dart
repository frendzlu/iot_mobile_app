import 'package:flutter/material.dart';

enum LogLevel {
  debug(Colors.grey),
  info(Colors.blue),
  warning(Colors.orange),
  error(Colors.red),
  success(Colors.green);

  const LogLevel(this.color);
  final Color color;
}

class LogEntry {
  final DateTime timestamp;
  final String module;
  final String message;
  final LogLevel level;

  LogEntry({
    required this.timestamp,
    required this.module,
    required this.message,
    this.level = LogLevel.info,
  });

  @override
  String toString() {
    final timeStr = timestamp.toLocal().toString().substring(11, 23);
    return '[$timeStr] [$module] ${level.name.toUpperCase()}: $message';
  }
}