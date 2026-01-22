import 'package:flutter/material.dart';
import '../setup/setup_device_tab.dart';
import '../logs/logs_tab.dart';
import '../stats/statistics_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  final tabs = const [
    SetupDeviceTab(),
    LogsTab(),
    StatisticsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: tabs[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Setup'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Logs'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Stats'),
        ],
      ),
    );
  }
}
