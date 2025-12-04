
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 Config',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      home: LoginAndConfigScreen(),
    );
  }
}

class LoginAndConfigScreen extends StatefulWidget {
  @override
  _LoginAndConfigScreenState createState() => _LoginAndConfigScreenState();
}

class _LoginAndConfigScreenState extends State<LoginAndConfigScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _serverCtrl = TextEditingController(text: 'http://192.168.4.1:3001');

  // Device fields
  final _deviceUuidCtrl = TextEditingController();
  final _deviceNameCtrl = TextEditingController();

  // ESP/Network fields
  final _espIpCtrl = TextEditingController();
  final _espPortCtrl = TextEditingController(text: '80');
  final _espRouteCtrl = TextEditingController(text: '/config');
  String _espMethod = 'POST';

  final _ssidCtrl = TextEditingController();
  final _wifiPassCtrl = TextEditingController();

  String _savedUserUuid = '';
  String _status = '';

  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _autoDetectGateway();
  }

  Future<void> _loadSaved() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _usernameCtrl.text = _prefs?.getString('username') ?? '';
      _passwordCtrl.text = _prefs?.getString('password') ?? '';
      _savedUserUuid = _prefs?.getString('userUuid') ?? '';
      _deviceUuidCtrl.text = _prefs?.getString('deviceUuid') ?? '';
      _deviceNameCtrl.text = '';
      _espIpCtrl.text = _prefs?.getString('espIp') ?? '';
      _espPortCtrl.text = _prefs?.getString('espPort') ?? '80';
      _espRouteCtrl.text = _prefs?.getString('espRoute') ?? '/config';
      _espMethod = _prefs?.getString('espMethod') ?? 'POST';
      _ssidCtrl.text = _prefs?.getString('ssid') ?? '';
      _wifiPassCtrl.text = _prefs?.getString('wifiPass') ?? '';
      _serverCtrl.text = _prefs?.getString('serverBase') ?? _serverCtrl.text;
    });
  }

  Future<void> _saveAll() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('username', _usernameCtrl.text);
    await _prefs!.setString('password', _passwordCtrl.text);
    await _prefs!.setString('userUuid', _savedUserUuid);
    await _prefs!.setString('deviceUuid', _deviceUuidCtrl.text);
    await _prefs!.setString('espIp', _espIpCtrl.text);
    await _prefs!.setString('espPort', _espPortCtrl.text);
    await _prefs!.setString('espRoute', _espRouteCtrl.text);
    await _prefs!.setString('espMethod', _espMethod);
    await _prefs!.setString('ssid', _ssidCtrl.text);
    await _prefs!.setString('wifiPass', _wifiPassCtrl.text);
    await _prefs!.setString('serverBase', _serverCtrl.text);
  }

  Future<void> _autoDetectGateway() async {
    // Try to detect gateway from WiFi IP: replace last octet with 1 (typical esp32 AP)
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      if (ip != null && ip.isNotEmpty) {
        final parts = ip.split('.');
        if (parts.length == 4) {
          parts[3] = '1';
          final gw = parts.join('.');
          // Only set if esp ip not already set
          if (_espIpCtrl.text.isEmpty) {
            setState(() {
              _espIpCtrl.text = gw;
            });
          }
        }
      }
    } catch (e) {
      // ignore
    }
  }

  bool _isUuidV4(String s) {
    final re = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\$');
    return re.hasMatch(s);
  }

  Future<void> _register() async {
    // Call server /register
    final base = _serverCtrl.text.trim();
    final url = Uri.parse('$base/register');
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      _setStatus('Username and password required');
      return;
    }
    try {
      final resp = await http.post(url,
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'username': username, 'password': password}));
      final jsonResp = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        setState(() {
          _savedUserUuid = jsonResp['uuid'] ?? '';
        });
        await _saveAll();
        _setStatus('Registered. UUID: ${_savedUserUuid}');
      } else {
        _setStatus('Register failed: ${jsonResp['error'] ?? resp.body}');
      }
    } catch (e) {
      _setStatus('Register error: $e');
    }
  }

  Future<void> _login() async {
    final base = _serverCtrl.text.trim();
    final url = Uri.parse(base + '/login');
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      _setStatus('Username and password required');
      return;
    }
    try {
      final resp = await http.post(url,
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'username': username, 'password': password}));
      final jsonResp = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        setState(() {
          _savedUserUuid = jsonResp['uuid'] ?? '';
        });
        await _saveAll();
        _setStatus('Login OK. UUID: ${_savedUserUuid}');
      } else {
        _setStatus('Login failed: ${jsonResp['error'] ?? resp.body}');
      }
    } catch (e) {
      _setStatus('Login error: $e');
    }
  }

  Future<void> _addDevice() async {
    final base = _serverCtrl.text.trim();
    final url = Uri.parse(base + '/add-device');
    final deviceName = _deviceNameCtrl.text.trim();
    if (deviceName.isEmpty) {
      _setStatus('Device name required');
      return;
    }
    if (_savedUserUuid.isEmpty) {
      _setStatus('You must be logged in (have user uuid) to add a device');
      return;
    }
    try {
      final resp = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userUuid': _savedUserUuid, 'deviceName': deviceName}));
      final jsonResp = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        final deviceId = jsonResp['id'] ?? jsonResp['uuid'] ?? '';
        setState(() {
          _deviceUuidCtrl.text = deviceId;
        });
        await _saveAll();
        _setStatus('Device registered: $deviceId');
      } else {
        _setStatus('Add device failed: ${jsonResp['error'] ?? resp.body}');
      }
    } catch (e) {
      _setStatus('Add device error: $e');
    }
  }

  Future<void> _configureEsp() async {
    if (_savedUserUuid.isEmpty) {
      _setStatus('No user UUID saved. Login or register first.');
      return;
    }
    final ip = _espIpCtrl.text.trim();
    final port = _espPortCtrl.text.trim();
    final route = _espRouteCtrl.text.trim();
    final method = _espMethod;
    if (ip.isEmpty) {
      _setStatus('ESP IP required (auto-detected or enter manually)');
      return;
    }
    final base = 'http://$ip${port.isNotEmpty ? ':$port' : ''}';
    String urlStr = base + (route.startsWith('/') ? route : '/$route');

    final bodyMap = {
      'userUuid': _savedUserUuid,
      'password': _passwordCtrl.text,
      'deviceUuid': _deviceUuidCtrl.text,
      'wifiPassword': _wifiPassCtrl.text,
      'wifiSsid': _ssidCtrl.text,
    };

    try {
      http.Response resp;
      if (method == 'POST' || method == 'PUT') {
        resp = await (method == 'POST'
            ? http.post(Uri.parse(urlStr), headers: {'Content-Type': 'application/json'}, body: jsonEncode(bodyMap))
            : http.put(Uri.parse(urlStr), headers: {'Content-Type': 'application/json'}, body: jsonEncode(bodyMap)));
      } else {
        // GET -> send as query params
        final uri = Uri.parse(urlStr).replace(queryParameters: bodyMap.map((k, v) => MapEntry(k, v)));
        resp = await http.get(uri);
      }

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _setStatus('ESP configured successfully: ${resp.statusCode}');
      } else {
        _setStatus('ESP response ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setStatus('ESP configure error: $e');
    }
  }

  void _setStatus(String s) {
    setState(() {
      _status = s;
    });
  }

  Future<void> _logout() async {
    setState(() {
      _savedUserUuid = '';
      _usernameCtrl.text = '';
      _passwordCtrl.text = '';
    });
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove('userUuid');
    await _prefs!.remove('username');
    await _prefs!.remove('password');
    _setStatus('Logged out');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ESP32 Config')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Backend server base URL (e.g. http://192.168.4.1:3001)', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              TextField(controller: _serverCtrl, decoration: InputDecoration(border: OutlineInputBorder())),
              SizedBox(height: 14),

              Text('Login / Register', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              TextField(controller: _usernameCtrl, decoration: InputDecoration(labelText: 'Username')),
              SizedBox(height: 8),
              TextField(controller: _passwordCtrl, decoration: InputDecoration(labelText: 'Password')),
              SizedBox(height: 8),
              Row(children: [
                ElevatedButton(onPressed: () async { await _login(); await _saveAll(); }, child: Text('Login')),
                SizedBox(width: 12),
                ElevatedButton(onPressed: () async { await _register(); await _saveAll(); }, child: Text('Register')),
                SizedBox(width: 12),
                ElevatedButton(onPressed: () async { await _logout(); await _saveAll(); }, child: Text('Logout')),
              ]),

              Divider(height: 30),

              Text('User info (always visible)', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              SelectableText('User UUID: ${_savedUserUuid.isNotEmpty ? _savedUserUuid : "(not set)"}'),
              SizedBox(height: 4),
              SelectableText('Password (debug): ${_passwordCtrl.text}'),

              Divider(height: 30),

              Text('Device', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              TextField(controller: _deviceUuidCtrl, decoration: InputDecoration(labelText: 'Device UUID (v4)'), onChanged: (v) async { await _saveAll(); }),
              SizedBox(height: 8),
              TextField(controller: _deviceNameCtrl, decoration: InputDecoration(labelText: 'Device name (to register)')),
              SizedBox(height: 8),
              ElevatedButton(onPressed: () async { await _addDevice(); }, child: Text('Register the device')),
              SizedBox(height: 12),
              Text(_deviceUuidCtrl.text.isNotEmpty && !_isUuidV4(_deviceUuidCtrl.text) ? 'Device UUID looks invalid (not v4)' : '' , style: TextStyle(color: Colors.red)),

              Divider(height: 30),

              Text('ESP / Network (auto-detected but editable)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _espIpCtrl, decoration: InputDecoration(labelText: 'ESP IP'))),
                SizedBox(width: 8),
                Container(width: 100, child: TextField(controller: _espPortCtrl, decoration: InputDecoration(labelText: 'Port'))),
              ]),
              SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _espRouteCtrl, decoration: InputDecoration(labelText: 'Route (e.g. /config)'))),
                SizedBox(width: 8),
                DropdownButton<String>(value: _espMethod, items: ['POST', 'GET', 'PUT'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) { setState(() { _espMethod = v!; _saveAll(); }); }),
              ]),

              SizedBox(height: 12),
              TextField(controller: _ssidCtrl, decoration: InputDecoration(labelText: 'WiFi SSID')),
              SizedBox(height: 8),
              TextField(controller: _wifiPassCtrl, decoration: InputDecoration(labelText: 'WiFi password')),

              SizedBox(height: 12),
              ElevatedButton(onPressed: () async { await _configureEsp(); await _saveAll(); }, child: Text('Configure')),

              SizedBox(height: 18),
              Text('Status:', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text(_status),

              SizedBox(height: 20),
              Text('Note: All input values are persisted locally between restarts and app updates using SharedPreferences.'),
            ],
          ),
        ),
      ),
    );
  }
}
