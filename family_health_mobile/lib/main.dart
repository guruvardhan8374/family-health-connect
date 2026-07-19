import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/health_screen.dart';
import 'screens/family_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/emergency_screen.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/sync_service.dart';
import 'services/offline_queue_service.dart';

class ThemeController {
  static final ThemeController instance = ThemeController._internal();

  ThemeController._internal() {
    SyncService.instance.stream.listen((event) {
      if (event['type'] == 'settings.update' && event['section'] == 'theme') {
        final data = event['data'];
        if (data != null) {
          final isDark = data['dark_mode'] as bool? ?? false;
          final colorName = data['theme_color'] as String? ?? 'emerald';
          themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
          themeColor.value = colorFromString(colorName);
        }
      }
    });
  }

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
  final ValueNotifier<Color> themeColor = ValueNotifier<Color>(const Color(0xFF14B8A6));

  static const Map<String, Color> colorMap = {
    'blue': Color(0xFF3B82F6),
    'emerald': Color(0xFF10B981),
    'indigo': Color(0xFF6366F1),
    'rose': Color(0xFFF43F5E),
    'violet': Color(0xFF8B5CF6),
    'orange': Color(0xFFF97316),
  };

  Color colorFromString(String colorName) {
    return colorMap[colorName.toLowerCase()] ?? const Color(0xFF14B8A6);
  }

  String stringFromColor(Color color) {
    return colorMap.entries
        .firstWhere((entry) => entry.value.toARGB32() == color.toARGB32(), orElse: () => const MapEntry('emerald', Color(0xFF10B981)))
        .key;
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    
    final String? mode = prefs.getString('theme_mode');
    final String? colorName = prefs.getString('theme_color');

    if (mode != null) {
      themeMode.value = mode == 'dark' ? ThemeMode.dark : ThemeMode.light;
    }
    if (colorName != null) {
      themeColor.value = colorFromString(colorName);
    }

    try {
      final loggedIn = await AuthService.isLoggedIn();
      if (loggedIn) {
        final serverTheme = await ApiService.getThemeSettings();
        if (serverTheme != null) {
          final isDark = serverTheme['dark_mode'] as bool? ?? false;
          final serverColor = serverTheme['theme_color'] as String? ?? 'emerald';
          
          themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
          themeColor.value = colorFromString(serverColor);

          await prefs.setString('theme_mode', isDark ? 'dark' : 'light');
          await prefs.setString('theme_color', serverColor);
        }
      }
    } catch (_) {}
  }

  Future<void> loadThemeFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? mode = prefs.getString('theme_mode');
      final String? colorName = prefs.getString('theme_color');
      if (mode != null) {
        themeMode.value = mode == 'dark' ? ThemeMode.dark : ThemeMode.light;
      }
      if (colorName != null) {
        themeColor.value = colorFromString(colorName);
      }
    } catch (_) {}
  }


  Future<void> updateTheme({required bool dark, required String colorName}) async {
    themeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
    themeColor.value = colorFromString(colorName);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', dark ? 'dark' : 'light');
    await prefs.setString('theme_color', colorName);

    try {
      final loggedIn = await AuthService.isLoggedIn();
      if (loggedIn) {
        await ApiService.updateThemeSettings({
          'dark_mode': dark,
          'theme_color': colorName,
        });
      }
    } catch (_) {}
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  await Hive.initFlutter();
  await OfflineQueueService.instance.init();
  await ThemeController.instance.loadTheme();
  runApp(const FamilyHealthApp());
}

class FamilyHealthApp extends StatelessWidget {
  const FamilyHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.themeMode,
      builder: (context, mode, child) {
        return ValueListenableBuilder<Color>(
          valueListenable: ThemeController.instance.themeColor,
          builder: (context, primaryColor, child) {
            return MaterialApp(
              title: 'Family Health Connect',
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              theme: ThemeData(
                useMaterial3: true,
                fontFamily: 'SF Pro Display',
                brightness: Brightness.light,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: primaryColor,
                  brightness: Brightness.light,
                ),
                scaffoldBackgroundColor: const Color(0xFFF1F5F9),
                cardColor: Colors.white,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFF0F172A),
                  elevation: 0,
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                fontFamily: 'SF Pro Display',
                brightness: Brightness.dark,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: primaryColor,
                  brightness: Brightness.dark,
                ),
                scaffoldBackgroundColor: const Color(0xFF0F172A),
                cardColor: const Color(0xFF1E293B),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
              home: const AuthGate(),
            );
          },
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // ── isLoggedIn() reads from in-memory cache or local SharedPreferences ──
    // ── No network calls here — auth gate resolves in < 50ms ──────────────
    final loggedIn = await AuthService.isLoggedIn();
    if (loggedIn) {
      // Load theme from local prefs only (ThemeController caches locally)
      ThemeController.instance.loadThemeFromCache();
      // WebSocket starts non-blocking — UI doesn't wait for it
      SyncService.instance.connect();
    }
    setState(() {
      _isLoggedIn = loggedIn;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
        ),
      );
    }
    return _isLoggedIn ? const MainShell() : const LoginScreen();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    HealthScreen(),
    FamilyScreen(),
    ChatScreen(),
    EmergencyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.dashboard_rounded, 'Home'),
                _navItem(1, Icons.favorite_rounded, 'Health'),
                _navItem(2, Icons.people_rounded, 'Family'),
                _navItem(3, Icons.chat_bubble_rounded, 'Chat'),
                _navItem(4, Icons.shield_rounded, 'SOS'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = index == 4
        ? const Color(0xFFEF4444)
        : const Color(0xFF14B8A6);

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
              color: isSelected ? color : const Color(0xFF94A3B8),
              size: 24),
            const SizedBox(height: 4),
            Text(label,
              style: TextStyle(
                color: isSelected ? color : const Color(0xFF94A3B8),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              )),
          ],
        ),
      ),
    );
  }
}
