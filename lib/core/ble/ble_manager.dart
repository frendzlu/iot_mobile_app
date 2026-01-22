import 'dart:convert';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleManager {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;

  void _log(String msg) {
    print('[BLE] $msg');
  }

  /// Requests all necessary permissions for BLE scanning and connecting
  Future<void> requestPermissions() async {
    if (!Platform.isAndroid) return; // iOS handles this differently

    final List<Permission> permissions = [];

    if (Platform.isAndroid && (await _androidVersion() >= 31)) {
      // Android 12+
      permissions.add(Permission.bluetoothScan);
      permissions.add(Permission.bluetoothConnect);
    } else {
      // Android < 12
      permissions.add(Permission.location);
    }

    for (final permission in permissions) {
      if (!await permission.isGranted) {
        final result = await permission.request();
        if (!result.isGranted) {
          throw Exception('Required permission denied: $permission');
        }
      }
    }
  }

  /// Returns Android SDK version
  Future<int> _androidVersion() async {
    if (!Platform.isAndroid) return 0;
    // Use Platform.version as a quick fallback
    final versionString = Platform.version.split(" ").first;
    return int.tryParse(versionString) ?? 0;
  }

  /// Scans for a BLE device by name and connects
  Future<void> scanAndConnect(String deviceName) async {
    _log('Requesting permissions...');
    await requestPermissions();

    _log('Starting BLE scan for "$deviceName"');
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    await for (final results in FlutterBluePlus.scanResults) {
      for (final r in results) {
        if (r.device.name == deviceName) {
          _log('Found device ${r.device.id}');
          _device = r.device;
          await FlutterBluePlus.stopScan();
          await _device!.connect(license: License.free);
          _log('Connected to BLE device');
          await _discoverServices();
          return;
        }
      }
    }

    throw Exception('Device "$deviceName" not found');
  }

  Future<void> _discoverServices() async {
    if (_device == null) throw Exception('No device connected');

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
    if (_writeChar == null) throw Exception('BLE not ready');

    final payload = utf8.encode(jsonEncode(data));
    _log('Sending provisioning payload: $payload');
    await _writeChar!.write(payload, withoutResponse: true);
  }

  Future<void> disconnect() async {
    if (_device != null) {
      _log('Disconnecting BLE');
      await _device!.disconnect();
      _device = null;
      _writeChar = null;
    }
  }
}
