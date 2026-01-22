import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;

  ApiClient(this.baseUrl);

  void _log(String msg) {
    // REST logs are intentionally verbose
    // ignore: avoid_print
    print('[REST] $msg');
  }

  /// Try to auto-detect backend on local network.
  /// Strategy: use gateway IP (x.x.x.1:3001)
  static Future<String?> autodetectBackend() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final candidate =
                  'http://${parts[0]}.${parts[1]}.${parts[2]}.1:3001';
              // ignore: avoid_print
              print('[REST] Autodetect probing $candidate');
              try {
                final res = await http
                    .get(Uri.parse(candidate))
                    .timeout(const Duration(seconds: 2));
                if (res.statusCode == 200) {
                  // ignore: avoid_print
                  print('[REST] Backend detected at $candidate');
                  return candidate;
                }
              } catch (_) {
                // ignore
              }
            }
          }
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[REST] Autodetect failed: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> login(
      String username, String password) async {
    final url = Uri.parse('$baseUrl/login');
    _log('POST $url');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    _log('Response ${res.statusCode}: ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('Login failed');
    }
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> fetchStatistics({
    required String userUuid,
    required String deviceName,
    int hours = 24,
    int limit = 100,
  }) async {
    // Device name is used as identifier
    final url = Uri.parse(
      '$baseUrl/telemetry/$userUuid'
          '?hours=$hours&limit=$limit&deviceName=$deviceName',
    );

    _log('GET $url');

    final res = await http.get(url);
    _log('Response ${res.statusCode}: ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch statistics');
    }
    return jsonDecode(res.body);
  }
}
