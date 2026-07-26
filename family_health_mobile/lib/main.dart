import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'services/pedometer_service.dart';
import 'services/health_service.dart';
import 'services/app_config.dart';
import 'services/translation_service.dart';
import 'services/firebase_options.dart';

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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AppConfig.initialize();
  await Hive.initFlutter();
  await TranslationService.instance.init();
  await OfflineQueueService.instance.init();
  await ThemeController.instance.loadTheme();
  runApp(const FamilyHealthApp());
}

class FamilyHealthApp extends StatelessWidget {
  const FamilyHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TranslationService.instance,
      builder: (context, _) {
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

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (loggedIn) {
      ThemeController.instance.loadThemeFromCache();
      SyncService.instance.connect();
    }
    setState(() {
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
    return ValueListenableBuilder<bool>(
      valueListenable: AuthService.isLoggedInNotifier,
      builder: (context, isLoggedIn, child) {
        return isLoggedIn ? const MainShell() : const LoginScreen();
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  StreamSubscription? _sosSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForSOS();
    _triggerAutoHealthSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sosSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[Lifecycle] App resumed — triggering automatic Health Connect sync...');
      _triggerAutoHealthSync();
    }
  }

  Future<void> _triggerAutoHealthSync() async {
    try {
      final snapshot = await HealthService.instance.fetchTodaySnapshot();
      await ApiService.syncHealthSnapshot(snapshot);
      debugPrint('[AutoSync] Background/Resume sync completed successfully');
    } catch (e) {
      debugPrint('[AutoSync] Sync error: $e');
    }
  }

  void _listenForSOS() {
    _sosSub = SyncService.instance.stream.listen((event) {
      if (!mounted) return;
      if (event['type'] == 'emergency.alert') {
        final data = event['data'] as Map<String, dynamic>?;
        if (data == null) return;

        final isResolved = data['is_resolved'] == true ||
            data['status'] == 'RESOLVED' ||
            data['status'] == 'FALSE_ALARM';

        if (!isResolved) {
          _showGlobalSOSDialog(data);
        }
      }
    });
  }

  void _showGlobalSOSDialog(Map<String, dynamic> data) {
    if (!mounted) return;

    // Trigger urgent haptic pattern
    HapticFeedback.vibrate();
    Future.delayed(const Duration(milliseconds: 400), () => HapticFeedback.vibrate());
    Future.delayed(const Duration(milliseconds: 800), () => HapticFeedback.vibrate());

    final triggeredBy = data['triggered_by'] ?? 'Family Member';
    final message = data['message'] ?? 'Emergency! I need help immediately.';
    final lat = data['location_lat'];
    final lng = data['location_lng'];
    final mapsLink = (lat != null && lng != null)
        ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
        : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emergency_share_rounded, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🚨 SOS ALERT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          )),
                        Text(triggeredBy,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          )),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 28),
              const Text('EMERGENCY MESSAGE',
                style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 2)),
              const SizedBox(height: 6),
              Text(message,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
              if (lat != null && lng != null) ...[
                const SizedBox(height: 16),
                const Text('LOCATION',
                  style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 2)),
                const SizedBox(height: 6),
                Text('$lat, $lng',
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  if (mapsLink != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFDC2626),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.map_rounded, size: 18),
                        label: const Text('Open Map', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final url = Uri.parse(mapsLink);
                          Navigator.pop(ctx);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ),
                  if (mapsLink != null) const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  final List<Widget> _screens = const [
    DashboardScreen(),
    HealthScreen(),
    FamilyScreen(),
    ChatScreen(),
    EmergencyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Left Sidebar for Web / Desktop
            Container(
              width: 250,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // App Brand Logo & Name
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite_rounded, color: Color(0xFF14B8A6), size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Family Health',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  const SizedBox(height: 16),
                  // Navigation Items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _sidebarNavItem(0, Icons.dashboard_rounded, TranslationService.translate('home')),
                        _sidebarNavItem(1, Icons.favorite_rounded, TranslationService.translate('health')),
                        _sidebarNavItem(2, Icons.people_rounded, TranslationService.translate('family')),
                        _sidebarNavItem(3, Icons.chat_bubble_rounded, TranslationService.translate('chat')),
                        _sidebarNavItem(4, Icons.shield_rounded, TranslationService.translate('sos')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Right Main Content Viewport
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
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
                _navItem(0, Icons.dashboard_rounded, TranslationService.translate('home')),
                _navItem(1, Icons.favorite_rounded, TranslationService.translate('health')),
                _navItem(2, Icons.people_rounded, TranslationService.translate('family')),
                _navItem(3, Icons.chat_bubble_rounded, TranslationService.translate('chat')),
                _navItem(4, Icons.shield_rounded, TranslationService.translate('sos')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebarNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = index == 4 ? const Color(0xFFEF4444) : const Color(0xFF14B8A6);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
        leading: Icon(icon, color: isSelected ? color : const Color(0xFF64748B)),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : const Color(0xFF64748B),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: () => setState(() => _currentIndex = index),
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

