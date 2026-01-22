import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ble/ble_manager.dart';

class StatisticsTab extends StatelessWidget {
  const StatisticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleManager>();

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: StreamBuilder<List<int>>(
        stream: ble.notificationStream,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: Text('Waiting for sensor data...'));
          }
          try {
            final data = jsonDecode(utf8.decode(snap.data!));
            return Text(data.toString());
          } catch (_) {
            return const Text('Invalid sensor payload');
          }
        },
      ),
    );
  }
}
