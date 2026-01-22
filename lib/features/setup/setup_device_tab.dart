import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ble/ble_manager.dart';
import '../auth/auth_provider.dart';

class SetupDeviceTab extends StatelessWidget {
  const SetupDeviceTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleManager>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Setup Device')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(onPressed: ble.scanAndConnect, child: const Text('Scan & Connect')),
            ElevatedButton(
              onPressed: ble.writeChar == null
                  ? null
                  : () => ble.sendJson({
                'userUuid': auth.userUuid,
                'password': auth.passwordCtrl.text,
                'deviceName': auth.deviceName,
                'wifiSsid': auth.ssid,
                'wifiPassword': auth.wifiPassword,
              }),
              child: const Text('Provision'),
            ),
          ],
        ),
      ),
    );
  }
}
