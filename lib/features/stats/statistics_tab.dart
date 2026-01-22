import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../auth/auth_provider.dart';

class StatisticsTab extends StatefulWidget {
  const StatisticsTab({super.key});

  @override
  State<StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends State<StatisticsTab> {
  final _deviceNameCtrl = TextEditingController();
  List<dynamic> _data = [];
  bool _loading = false;
  String? _error;

  void _log(String msg) {
    // ignore: avoid_print
    print('[STATS] $msg');
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final api = ApiClient(auth.backendUrl!);

      _log('Fetching stats for ${_deviceNameCtrl.text}');

      _data = await api.fetchStatistics(
        userUuid: auth.uuid!,
        deviceName: _deviceNameCtrl.text.trim(),
      );
    } catch (e) {
      _log('Stats error: $e');
      _error = e.toString();
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
            decoration:
            const InputDecoration(labelText: 'Device Name'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loading ? null : _load,
            child: const Text('Load Statistics'),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          Expanded(
            child: ListView.builder(
              itemCount: _data.length,
              itemBuilder: (_, i) {
                final row = _data[i];
                return ListTile(
                  title: Text(
                      '${row['sensor_name']} = ${row['value']} ${row['unit'] ?? ''}'),
                  subtitle: Text(row['timestamp']),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
