import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import '../../core/ble/ble_manager.dart';

class LogsTab extends StatelessWidget {
  const LogsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authLogs = context.watch<AuthProvider>().logs;
    final bleLogs = context.watch<BleManager>().logs;

    final allLogs = [...authLogs, ...bleLogs].reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Logs')),
      body: ListView.builder(
        itemCount: allLogs.length,
        itemBuilder: (_, i) => Text(allLogs[i]),
      ),
    );
  }
}
