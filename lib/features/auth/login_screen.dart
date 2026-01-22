import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:network_info_plus/network_info_plus.dart';

import 'auth_provider.dart';
import '../../core/logging/log_service.dart';
import '../../models/log_entry.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _backendCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  
  // Autodetection state
  bool _isAutodetecting = false;
  String? _autodetectStatus;
  bool _autodetectSuccess = false;
  
  final LogService _logService = LogService();

  void _log(String msg, {LogLevel level = LogLevel.info}) {
    _logService.log('UI', msg, level: level);
  }

  /// Get the device's current IP address for default backend URL
  Future<String> _getDefaultBackendUrl() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      if (wifiIP != null && wifiIP.isNotEmpty) {
        return 'http://$wifiIP:3001';
      }
    } catch (e) {
      _log('Failed to get WiFi IP: $e', level: LogLevel.warning);
    }
    return 'http://192.168.1.100:3001';
  }

  bool get _canLogin {
    final backendUrl = _backendCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    
    return backendUrl.isNotEmpty && 
           username.isNotEmpty && 
           password.isNotEmpty && 
           !_loading && 
           !_isAutodetecting;
  }

  @override
  void initState() {
    super.initState();
    _startAutodetect();
  }

  Future<void> _startAutodetect() async {
    final auth = context.read<AuthProvider>();
    
    // If we already have a backend URL, use it
    if (auth.backendUrl != null && auth.backendUrl!.isNotEmpty) {
      _backendCtrl.text = auth.backendUrl!;
      _log('Using existing backend URL: ${auth.backendUrl}');
      return;
    }

    if (!mounted) return;
    setState(() {
      _autodetectStatus = 'Detecting backend...';
      _isAutodetecting = true;
    });

    try {
      await auth.autodetectBackend();
      if (!mounted) return; // Check again after async operation
      
      if (auth.backendUrl != null) {
        _backendCtrl.text = auth.backendUrl!;
        setState(() {
          _autodetectStatus = 'Backend detected automatically';
          _autodetectSuccess = true;
        });
      } else {
        // If autodetection fails, use device IP as default
        final defaultUrl = await _getDefaultBackendUrl();
        _backendCtrl.text = defaultUrl;
        setState(() {
          _autodetectStatus = 'Using device IP as default. Please verify.';
          _autodetectSuccess = false;
        });
      }
    } catch (e) {
      _log('Autodetect error: $e', level: LogLevel.error);
      if (!mounted) return; // Check again after async operation
      
      // If autodetection fails, use device IP as default
      final defaultUrl = await _getDefaultBackendUrl();
      _backendCtrl.text = defaultUrl;
      setState(() {
        _autodetectStatus = 'Using device IP as default. Please verify.';
        _autodetectSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isAutodetecting = false);
      }
    }
  }

  Future<void> _retryAutodetect() async {
    if (!mounted) return;
    setState(() {
      _autodetectStatus = null;
      _autodetectSuccess = false;
    });
    await _startAutodetect();
  }

  Future<void> _login() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      await auth.setBackendUrl(_backendCtrl.text.trim());
      await auth.login(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
      );
    } catch (e) {
      _log('Login error: $e', level: LogLevel.error);
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _register() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      await auth.setBackendUrl(_backendCtrl.text.trim());
      await auth.register(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
      );
      
      // After successful registration, try to login
      await auth.login(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
      );
    } catch (e) {
      _log('Register error: $e', level: LogLevel.error);
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Manager Login'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.router,
              size: 64,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 32),
            
            // Backend URL Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud),
                        const SizedBox(width: 8),
                        const Text(
                          'Backend Server',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_isAutodetecting) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _backendCtrl,
                      decoration: InputDecoration(
                        labelText: 'Backend URL',
                        hintText: 'http://192.168.1.1:3001',
                        prefixIcon: const Icon(Icons.link),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _isAutodetecting ? null : _retryAutodetect,
                          tooltip: 'Retry auto-detection',
                        ),
                      ),
                      enabled: !_loading,
                      onChanged: (value) {
                        context.read<AuthProvider>().setBackendUrl(value.trim());
                        setState(() {}); // Trigger rebuild for login button state
                      },
                    ),
                    if (_autodetectStatus != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _autodetectSuccess ? Icons.check_circle : Icons.warning,
                            size: 16,
                            color: _autodetectSuccess ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _autodetectStatus!,
                              style: TextStyle(
                                fontSize: 12,
                                color: _autodetectSuccess ? Colors.green : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Login Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person),
                        const SizedBox(width: 8),
                        const Text(
                          'User Credentials',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      enabled: !_loading,
                      textInputAction: TextInputAction.next,
                      onChanged: (value) => setState(() {}), // Update login button state
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      enabled: !_loading,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _canLogin ? _login() : null,
                      onChanged: (value) => setState(() {}), // Update login button state
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Login Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _canLogin ? _login : null,
                icon: _loading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(_loading ? 'Logging in...' : 'Login'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Register Button for testing
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _canLogin ? _register : null,
                icon: const Icon(Icons.person_add),
                label: const Text('Create Account'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            
            if (!_canLogin && _backendCtrl.text.trim().isEmpty && !_isAutodetecting) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please enter a backend URL or wait for auto-detection to complete before logging in.',
                        style: TextStyle(
                          color: Colors.orange[300],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
