import 'package:flutter/material.dart';
import '../setup/setup_device_tab.dart';
import '../setup/device_inspector_tab.dart';
import '../logs/logs_tab.dart';
import '../stats/statistics_tab.dart';
import '../profile/profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  final tabs = const [
    SetupDeviceTab(),
    DeviceInspectorTab(),
    StatisticsTab(),
    LogsTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) {
          if (i >= 0 && i < tabs.length) {
            setState(() => index = i);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_bluetooth), 
            label: 'Setup'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.developer_board), 
            label: 'Inspector'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart), 
            label: 'Stats'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment), 
            label: 'Logs'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person), 
            label: 'Profile'
          ),
        ],
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
