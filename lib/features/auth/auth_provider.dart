import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AuthProvider extends ChangeNotifier {
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  String userUuid = '';
  String deviceName = '';
  String ssid = '';
  String wifiPassword = '';

  final List<String> logs = [];

  Future<bool> login() async {
    logs.add('[AUTH] Login attempt for ${usernameCtrl.text}');
    notifyListeners();

    try {
      final resp = await http.post(
        Uri.parse('http://YOUR_BACKEND/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': usernameCtrl.text,
          'password': passwordCtrl.text,
        }),
      );

      logs.add('[AUTH] Response ${resp.statusCode}: ${resp.body}');

      if (resp.statusCode == 200) {
        userUuid = jsonDecode(resp.body)['uuid'];
        logs.add('[AUTH] Login successful. UUID=$userUuid');
        notifyListeners();
        return true;
      }
    } catch (e) {
      logs.add('[AUTH][ERROR] $e');
      notifyListeners();
    }

    return false;
  }

  void setDeviceName(String name) {
    deviceName = name;
    logs.add('[STATE] Device name set: $name');
    notifyListeners();
  }

}
