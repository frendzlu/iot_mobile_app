import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'features/auth/auth_provider.dart';
import 'core/ble/bluetooth_service.dart';
import 'core/logging/log_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => IoTBluetoothService()),
        ChangeNotifierProvider(create: (_) => LogService()),
      ],
      child: const App(),
    ),
  );
}
