import 'package:flutter/material.dart';

import '../../core/ble/ble_manager.dart';

class SetupDeviceTab extends StatefulWidget {
  const SetupDeviceTab({super.key});

  @override
  State<SetupDeviceTab> createState() => _SetupDeviceTabState();
}

class _SetupDeviceTabState extends State<SetupDeviceTab> {
  final _ble = BleManager();
  final _deviceNameCtrl = TextEditingController();
  bool _loading = false;
  String? _status;

  void _log(String msg) {
    // ignore: avoid_print
    print('[SETUP] $msg');
  }

  Future<void> _provision() async {
    setState(() {
      _loading = true;
      _status = null;
    });

    try {
      final name = _deviceNameCtrl.text.trim();
      _log('Provisioning device $name');

      await _ble.scanAndConnect(name);
      await _ble.sendProvisioningData({
        'deviceName': name,
      });

      _status = 'Provisioning sent successfully';
    } catch (e) {
      _log('Provisioning failed: $e');
      _status = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _deviceNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Device Name (BLE)',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _provision,
            child: const Text('Provision Device'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(_status!),
          ],
        ],
      ),
    );
  }
}
