import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'constants.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/history_screen.dart';
import 'models/user_model.dart';
import 'models/history_entry.dart';
import 'services/database_service.dart';
import 'services/config_service.dart';
import 'services/tracker_service.dart';
import 'providers/connectivity_provider.dart';
import 'widgets/connectivity_overlay.dart';

const String _kTaskLogPosition = 'log-device-position';
const String _kDeviceImei = '359339078106061';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _kTaskLogPosition) {
      try {
        final config = await ConfigService.getTraccarConfig();
        final username = config['username'] ?? '';
        final password = config['password'] ?? '';

        if (username.isEmpty || password.isEmpty) {
          return false;
        }

        final trackerService = TrackerService(username: username, password: password);
        final position = await trackerService.getDevicePosition(_kDeviceImei);

        if (position['lat'] != null && position['lng'] != null) {
          final entry = HistoryEntry(
            timestamp: DateTime.now(),
            latitude: position['lat']!,
            longitude: position['lng']!,
            accuracy: position['accuracy'],
            batteryLevel: position['batteryLevel'],
            rssi: position['rssi']?.toInt(),
          );

          final dbService = DatabaseService();
          await dbService.insertHistoryEntry(entry);
        }

        return true;
      } catch (e) {
        return false;
      }
    }
    return false;
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  runApp(const SentraApp());
}

class SentraApp extends StatelessWidget {
  const SentraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: MaterialApp(
        title: 'Sentra',
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: AppColors.background,
          primaryColor: AppColors.primary,
          useMaterial3: true,
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            surface: AppColors.cardBackground,
            onSurface: AppColors.textPrimary,
          ),
        ),
        home: const LoginScreen(),
      ),
    );
  }
}

class MainLayout extends StatefulWidget {
  final User user;
  const MainLayout({super.key, required this.user});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [const HomeScreen(), const HistoryScreen(), SettingsScreen(user: widget.user)];

    if (Platform.isAndroid) {
      Workmanager().registerPeriodicTask(
        'history-logging-task',
        _kTaskLogPosition,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConnectivityOverlay(
      child: Scaffold(
        body: _screens[_currentIndex],
        floatingActionButton: null,
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: AppColors.cardBackground,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
