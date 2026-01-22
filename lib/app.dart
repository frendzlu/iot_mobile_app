import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/ble/ble_manager.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BleManager()),
      ],
      child: MaterialApp(
        title: 'ESP32 BLE',
        theme: ThemeData(primarySwatch: Colors.indigo),
        home: const LoginScreen(),
      ),
    );
  }
}
