import 'package:flutter/material.dart';

class LogsTab extends StatelessWidget {
  const LogsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Logs are printed to console.\n'
            'All subsystems log verbosely:\n\n'
            '[AUTH]\n[REST]\n[BLE]\n[SETUP]\n[STATS]\n[ERROR]',
        textAlign: TextAlign.center,
      ),
    );
  }
}
