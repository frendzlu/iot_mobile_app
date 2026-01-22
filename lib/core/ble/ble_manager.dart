import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleManager {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;

  void _log(String msg) {
    // ignore: avoid_print
    print('[BLE] $msg');
  }

  Future<void> scanAndConnect(String deviceName) async {
    _log('Starting BLE scan for $deviceName');

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    FlutterBluePlus.scanResults.listen((results) async {
      for (final r in results) {
        if (r.device.name == deviceName) {
          _log('Found device ${r.device.id}');
          _device = r.device;
          await FlutterBluePlus.stopScan();
          await _device!.connect();
          _log('Connected to BLE device');
          await _discoverServices();
          return;
        }
      }
    });
  }

  Future<void> _discoverServices() async {
    final services = await _device!.discoverServices();
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.properties.write) {
          _writeChar = c;
          _log('Found writable characteristic ${c.uuid}');
          return;
        }
      }
    }
    throw Exception('No writable characteristic found');
  }

  Future<void> sendProvisioningData(Map<String, dynamic> data) async {
    if (_writeChar == null) {
      throw Exception('BLE not ready');
    }

    final payload = jsonEncode(data);
    _log('Sending provisioning payload: $payload');

    await _writeChar!.write(utf8.encode(payload), withoutResponse: true);
  }

  Future<void> disconnect() async {
    if (_device != null) {
      _log('Disconnecting BLE');
      await _device!.disconnect();
    }
  }
}
