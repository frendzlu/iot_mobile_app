import 'package:flutter/material.dart';
import '../setup/setup_device_tab.dart';
import '../logs/logs_tab.dart';
import '../stats/statistics_tab.dart';
import '../profile/profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int index = 0;
  late TabController _tabController;

  final tabs = const [
    SetupDeviceTab(),
    StatisticsTab(),
    LogsTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => index = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: tabs,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: index,
          onTap: (i) {
            setState(() => index = i);
            _tabController.animateTo(i);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_bluetooth), 
              label: 'Setup'
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
      ),
    );
  }
}
