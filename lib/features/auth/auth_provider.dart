import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/prefs.dart';

class AuthProvider extends ChangeNotifier {
  bool _authenticated = false;
  String? _username;
  String? _uuid;
  String? _backendUrl;

  bool get isAuthenticated => _authenticated;
  String? get username => _username;
  String? get uuid => _uuid;
  String? get backendUrl => _backendUrl;

  AuthProvider() {
    _restore();
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[AUTH] $msg');
  }

  Future<void> _restore() async {
    _backendUrl = await Prefs.getBackendUrl();
    _username = await Prefs.getUsername();
    _uuid = await Prefs.getUuid();

    _authenticated =
        _backendUrl != null && _username != null && _uuid != null;

    _log('Restored auth state: $_authenticated');
    notifyListeners();
  }

  Future<void> setBackendUrl(String url) async {
    _log('Setting backend URL to $url');
    _backendUrl = url;
    await Prefs.setBackendUrl(url);
    notifyListeners();
  }

  Future<void> autodetectBackend() async {
    _log('Starting backend autodetect');
    final detected = await ApiClient.autodetectBackend();
    if (detected != null) {
      _log('Autodetected backend: $detected');
      await setBackendUrl(detected);
    } else {
      _log('Backend autodetect failed');
      throw Exception('Autodetect failed');
    }
  }

  Future<void> login(String username, String password) async {
    if (_backendUrl == null) {
      throw Exception('Backend URL not set');
    }

    _log('Attempting login for $username');
    final api = ApiClient(_backendUrl!);

    final result = await api.login(username, password);

    _username = result['username'];
    _uuid = result['uuid'];
    _authenticated = true;

    await Prefs.setUser(_username!, _uuid!);

    _log('Login successful (uuid=$_uuid)');
    notifyListeners();
  }

  Future<void> logout() async {
    _log('Logging out');
    _authenticated = false;
    _username = null;
    _uuid = null;

    await Prefs.clear();
    notifyListeners();
  }
}
