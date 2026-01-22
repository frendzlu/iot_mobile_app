import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/prefs.dart';
import '../../core/logging/log_service.dart';
import '../../models/log_entry.dart';

class AuthProvider extends ChangeNotifier {
  bool _authenticated = false;
  String? _username;
  String? _uuid;
  String? _backendUrl;
  bool _sessionValidated = false;
  Map<String, dynamic>? _userDevices;

  bool get isAuthenticated => _authenticated && _backendUrl != null && _backendUrl!.isNotEmpty && _sessionValidated;
  String? get username => _username;
  String? get uuid => _uuid;
  String? get backendUrl => _backendUrl;
  bool get hasBackend => _backendUrl != null && _backendUrl!.isNotEmpty;
  bool get isSessionValid => _sessionValidated;
  Map<String, dynamic>? get userDevices => _userDevices;

  final LogService _logService = LogService();

  AuthProvider() {
    _restore();
  }

  void _log(String msg, {LogLevel level = LogLevel.info}) {
    _logService.log('AUTH', msg, level: level);
  }

  Future<void> _restore() async {
    _backendUrl = await Prefs.getBackendUrl();
    _username = await Prefs.getUsername();
    _uuid = await Prefs.getUuid();

    // Only set authenticated if we have all required data
    final hasStoredData = _backendUrl != null && _backendUrl!.isNotEmpty && _username != null && _uuid != null;
    
    if (hasStoredData) {
      _log('Found stored auth data, validating session...');
      try {
        await _validateSession();
        if (_sessionValidated) {
          _authenticated = true;
          _log('Session validated successfully for user $_username');
        } else {
          _log('Session validation failed, clearing stored data');
          await _clearStoredAuth();
        }
      } catch (e) {
        _log('Session validation error: $e', level: LogLevel.warning);
        await _clearStoredAuth();
      }
    } else {
      _log('No stored auth data found');
      _authenticated = false;
      _sessionValidated = false;
    }
    
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
      _log('Autodetected backend: $detected', level: LogLevel.success);
      await setBackendUrl(detected);
    } else {
      _log('Backend autodetection failed - no response from local network', level: LogLevel.warning);
      // Don't throw exception, just let user enter manually
    }
  }

  Future<void> login(String username, String password) async {
    if (_backendUrl == null || _backendUrl!.isEmpty) {
      throw Exception('Backend URL not set - please enter a valid backend URL or retry auto-detection');
    }

    _log('Attempting login for $username');
    final api = ApiClient(_backendUrl!);

    final result = await api.login(username, password);

    _username = result['username'];
    _uuid = result['uuid'];
    _authenticated = true;
    _sessionValidated = true;

    await Prefs.setUser(_username!, _uuid!);

    // Load user devices after login
    await _loadUserDevices();

    _log('Login successful (uuid=$_uuid)');
    notifyListeners();
  }

  Future<void> register(String username, String password) async {
    if (_backendUrl == null || _backendUrl!.isEmpty) {
      throw Exception('Backend URL not set - please enter a valid backend URL or retry auto-detection');
    }

    _log('Attempting registration for $username');
    final api = ApiClient(_backendUrl!);

    final result = await api.register(username, password);

    _log('Registration successful for $username (uuid=${result['uuid']})');
    // Don't set authentication here, let the caller handle login after registration
  }

  Future<void> _validateSession() async {
    if (_backendUrl == null || _uuid == null) {
      _sessionValidated = false;
      return;
    }

    try {
      final api = ApiClient(_backendUrl!);
      // Try to fetch user devices to validate session - this endpoint exists
      final userDevices = await api.getUserDevices(_uuid!);
      if (userDevices != null) {
        _sessionValidated = true;
        _userDevices = userDevices;
        _log('Session validated successfully');
      } else {
        _sessionValidated = false;
      }
    } catch (e) {
      _log('Session validation failed: $e', level: LogLevel.warning);
      _sessionValidated = false;
    }
  }

  Future<void> _loadUserDevices() async {
    if (_backendUrl == null || _uuid == null) return;

    try {
      final api = ApiClient(_backendUrl!);
      _userDevices = await api.getUserDevices(_uuid!);
      _log('Loaded ${_userDevices?['devices']?.length ?? 0} user devices');
    } catch (e) {
      _log('Failed to load user devices: $e', level: LogLevel.warning);
      _userDevices = null;
    }
  }

  Future<void> _clearStoredAuth() async {
    _authenticated = false;
    _sessionValidated = false;
    _username = null;
    _uuid = null;
    _userDevices = null;
    await Prefs.clear();
  }

  Future<void> refreshUserData() async {
    if (!_authenticated || !_sessionValidated) return;
    
    _log('Refreshing user data...');
    await _loadUserDevices();
    notifyListeners();
  }

  Future<void> logout() async {
    _log('Logging out user $_username');
    await _clearStoredAuth();
    notifyListeners();
  }
}
