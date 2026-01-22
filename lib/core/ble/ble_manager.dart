import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleManager extends ChangeNotifier {
  BluetoothDevice? device;
  BluetoothCharacteristic? writeChar;
  BluetoothCharacteristic? notifyChar;

  final List<String> logs = [];

  Stream<List<int>>? notificationStream;

  Future<void> scanAndConnect() async {
    logs.add('[BLE] Starting scan');
    notifyListeners();

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) async {
      for (final r in results) {
        if (r.device.name.startsWith('ESP32')) {
          logs.add('[BLE] Found ${r.device.name}');
          device = r.device;
          await FlutterBluePlus.stopScan();
          await device!.connect();
          await _discover();
          return;
        }
      }
    });
  }

  Future<void> _discover() async {
    final services = await device!.discoverServices();
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.properties.write) writeChar = c;
        if (c.properties.notify) {
          notifyChar = c;
          await c.setNotifyValue(true);
          notificationStream = c.value;
        }
      }
    }
    logs.add('[BLE] Services discovered');
    notifyListeners();
  }

  Future<void> sendJson(Map<String, dynamic> data) async {
    final bytes = utf8.encode(jsonEncode(data));
    for (int i = 0; i < bytes.length; i += 180) {
      await writeChar!.write(bytes.sublist(i, min(i + 180, bytes.length)));
    }
    logs.add('[BLE][TX] ${jsonEncode(data)}');
    notifyListeners();
  }
}
