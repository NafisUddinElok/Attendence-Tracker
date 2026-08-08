import 'package:flutter/material.dart';
import 'attendence_service.dart';
import 'role_select_screen.dart';

// App-wide theme mode, held outside the widget tree in a ValueNotifier so
// any screen can flip it (see the toggle buttons in teacher/student course
// screens) without threading state through every route. Loaded once at
// startup from AttendanceService.getThemeMode() (defaults to "system" —
// follow the phone's own light/dark setting — until the user picks one).
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

void main() {
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatefulWidget {
  const AttendanceApp({super.key});

  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp> {
  @override
  void initState() {
    super.initState();
    AttendanceService.getThemeMode().then((mode) => themeModeNotifier.value = mode);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Geofence Attendance',
          themeMode: mode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.blue.shade900,
              foregroundColor: Colors.white,
            ),
          ),
          home: const RoleSelectScreen(),
        );
      },
    );
  }
}

/// Cycles system -> light -> dark -> system, persists the choice, and
/// updates the notifier so the change is instant app-wide. Shared by the
/// teacher and student course screens' theme toggle button.
Future<void> cycleThemeMode() async {
  final next = switch (themeModeNotifier.value) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  };
  themeModeNotifier.value = next;
  await AttendanceService.setThemeMode(next);
}

IconData themeModeIcon(ThemeMode mode) => switch (mode) {
      ThemeMode.system => Icons.brightness_auto,
      ThemeMode.light => Icons.light_mode,
      ThemeMode.dark => Icons.dark_mode,
    };

String themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.system => 'Theme: System',
      ThemeMode.light => 'Theme: Light',
      ThemeMode.dark => 'Theme: Dark',
    };