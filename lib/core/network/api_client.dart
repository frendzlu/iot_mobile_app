import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../logging/log_service.dart';
import '../../models/log_entry.dart';

class ApiClient {
  final String baseUrl;
  final LogService _logService = LogService();

  ApiClient(this.baseUrl);

  void _log(String msg, {LogLevel level = LogLevel.info}) {
    _logService.log('REST', msg, level: level);
  }

  /// Try to auto-detect backend on local network.
  /// Strategy: use current IP with /24 mask and port 3001
  static Future<String?> autodetectBackend() async {
    final logService = LogService();
    
    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              !addr.address.startsWith('169.254')) { // Skip link-local
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              // Use /24 mask (255.255.255.0) - replace last octet with 1
              final candidate = 'http://${parts[0]}.${parts[1]}.${parts[2]}.1:3001';
              logService.debug('REST', 'Autodetect probing $candidate');
              try {
                final res = await http
                    .get(Uri.parse(candidate))
                    .timeout(const Duration(seconds: 3));
                if (res.statusCode == 200) {
                  logService.success('REST', 'Backend detected at $candidate');
                  return candidate;
                }
              } catch (e) {
                logService.debug('REST', 'No response from $candidate: $e');
              }
            }
          }
        }
      }
      logService.warning('REST', 'No backend found on local network');
    } catch (e) {
      logService.error('REST', 'Autodetect failed: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> login(
      String username, String password) async {
    final url = Uri.parse('$baseUrl/login');
    _log('POST $url (username: $username)');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    _log('Response ${res.statusCode}: ${res.body}');

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      _log('Login successful for user: ${data['username']} (${data['uuid']})', level: LogLevel.success);
      return data;
    } else if (res.statusCode == 401) {
      final error = jsonDecode(res.body);
      _log('Login failed: ${error['error']}', level: LogLevel.warning);
      throw Exception(error['error'] ?? 'Invalid credentials');
    } else {
      _log('Login failed with status ${res.statusCode}', level: LogLevel.error);
      throw Exception('Login failed: HTTP ${res.statusCode}');
    }
  }

  Future<List<dynamic>> fetchStatistics({
    required String userUuid,
    String? deviceId,
    String? deviceName,
    int hours = 24,
    int limit = 100,
  }) async {
    // Use device-specific endpoint if deviceId is provided, otherwise user-wide
    final url = deviceId != null 
        ? Uri.parse('$baseUrl/telemetry/$userUuid/$deviceId?hours=$hours&limit=$limit')
        : Uri.parse('$baseUrl/telemetry/$userUuid?hours=$hours&limit=$limit');

    _log('GET $url');

    final res = await http.get(url);
    _log('Response ${res.statusCode}: ${res.body.length > 500 ? '${res.body.substring(0, 500)}...' : res.body}');

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch statistics: HTTP ${res.statusCode}');
    }
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> register(
      String username, String password) async {
    final url = Uri.parse('$baseUrl/register');
    _log('POST $url (username: $username)');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    _log('Response ${res.statusCode}: ${res.body}');

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      _log('Registration successful for user: ${data['username']} (${data['uuid']})', level: LogLevel.success);
      return data;
    } else if (res.statusCode == 400) {
      final error = jsonDecode(res.body);
      _log('Registration failed: ${error['error']}', level: LogLevel.warning);
      throw Exception(error['error'] ?? 'Registration failed');
    } else {
      _log('Registration failed with status ${res.statusCode}', level: LogLevel.error);
      throw Exception('Registration failed: HTTP ${res.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> getUserDevices(String uuid) async {
    final url = Uri.parse('$baseUrl/devices/$uuid');
    _log('GET $url');

    try {
      final res = await http.get(url);
      _log('Response ${res.statusCode}');
      
      if (res.statusCode == 200) {
        final devices = jsonDecode(res.body);
        // Backend returns array of devices, wrap it in object for consistency
        return {'devices': devices};
      } else if (res.statusCode == 404) {
        _log('No devices found for user', level: LogLevel.info);
        return {'devices': []};
      } else {
        throw Exception('Failed to get user devices: HTTP ${res.statusCode}');
      }
    } catch (e) {
      _log('Error fetching user devices: $e', level: LogLevel.error);
      throw e;
    }
  }
}
