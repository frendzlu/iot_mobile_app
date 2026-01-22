import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_provider.dart';

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

  void _log(String msg) {
    // ignore: avoid_print
    print('[UI] $msg');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (auth.backendUrl != null && _backendCtrl.text.isEmpty) {
      _backendCtrl.text = auth.backendUrl!;
    }
  }

  Future<void> _login() async {
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
      _log('Login error: $e');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _autodetect() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      await auth.autodetectBackend();
      _backendCtrl.text = auth.backendUrl ?? '';
    } catch (e) {
      _log('Autodetect error: $e');
      setState(() => _error = 'Autodetect failed');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _backendCtrl,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                hintText: 'http://192.168.1.1:3001',
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : _autodetect,
              child: const Text('Auto-detect Backend'),
            ),
            const Divider(),
            TextField(
              controller: _usernameCtrl,
              decoration:
              const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _passwordCtrl,
              decoration:
              const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              child:
              _loading ? const CircularProgressIndicator() : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
