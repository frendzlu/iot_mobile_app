import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../core/ble/bluetooth_service.dart';
import '../../models/sensor_data.dart';

class StatisticsTab extends StatefulWidget {
  const StatisticsTab({super.key});

  @override
  State<StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends State<StatisticsTab> {
  final List<SensorData> _sensorReadings = [];
  StreamSubscription<SensorData>? _sensorSubscription;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
  }

  void _startListening() {
    final bluetooth = context.read<IoTBluetoothService>();
    
    if (bluetooth.isConnected) {
      _sensorSubscription = bluetooth.sensorDataStream.listen((sensorData) {
        if (mounted) {
          setState(() {
            _sensorReadings.insert(0, sensorData);
            // Keep only recent readings (last 100)
            if (_sensorReadings.length > 100) {
              _sensorReadings.removeLast();
            }
          });
        }
      });
      setState(() => _isListening = true);
    }
  }

  void _stopListening() {
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    setState(() => _isListening = false);
  }

  void _clearReadings() {
    setState(() => _sensorReadings.clear());
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          Consumer<IoTBluetoothService>(
            builder: (context, bluetooth, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (bluetooth.isConnected)
                    Icon(
                      Icons.bluetooth_connected,
                      color: Colors.green,
                    ),
                  const SizedBox(width: 8),
                  if (_sensorReadings.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_all),
                      onPressed: _clearReadings,
                      tooltip: 'Clear readings',
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<IoTBluetoothService>(
        builder: (context, bluetooth, _) {
          if (!bluetooth.isConnected) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.bluetooth_disabled,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Bluetooth Device Connected',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Go to Setup tab to connect to a device\nand start receiving sensor data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Switch to setup tab (index 0) - navigate back
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Go to Setup'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Connection Status Card
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.bluetooth_connected, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connected to: ${bluetooth.connectedDevice?.name ?? 'Unknown Device'}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Device ID: ${bluetooth.connectedDevice?.id}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isListening)
                        const Icon(Icons.sensors, color: Colors.green)
                      else
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: _startListening,
                          tooltip: 'Start listening',
                        ),
                    ],
                  ),
                ),
              ),
              
              // Statistics Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sensor Readings (${_sensorReadings.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_sensorReadings.isNotEmpty)
                      Text(
                        'Latest: ${_sensorReadings.first.timestamp.toLocal().toString().substring(11, 19)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Sensor Readings List
              Expanded(
                child: _sensorReadings.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.sensors_off,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No sensor data received yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Waiting for device to send data...',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _sensorReadings.length,
                        itemBuilder: (context, index) {
                          final reading = _sensorReadings[index];
                          final isLatest = index == 0;
                          
                          return Card(
                            elevation: isLatest ? 4 : 1,
                            color: isLatest ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isLatest ? Colors.green : Colors.grey,
                                child: Icon(
                                  Icons.sensors,
                                  color: Colors.white,
                                  size: isLatest ? 24 : 20,
                                ),
                              ),
                              title: Text(
                                reading.sensor,
                                style: TextStyle(
                                  fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                reading.timestamp.toLocal().toString().substring(0, 19),
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${reading.value}',
                                    style: TextStyle(
                                      fontSize: isLatest ? 18 : 16,
                                      fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  if (reading.unit != null)
                                    Text(
                                      reading.unit!,
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
