// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:giza/models/custom_theme.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'db/hive_helper.dart';
import 'services/audio_service.dart';
import 'services/notification_service.dart';
import 'services/connectivity_service.dart';
import 'providers/audio_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Init Firebase
  await Firebase.initializeApp();

  // 2. Init Hive on-device storage
  await HiveHelper.instance.init();

  // 3. Init Notification Service
  await NotificationService.instance.init();

  // 4. Init Audio Service
  AudioService.instance.init();

  // 5. Init Connectivity Service
  await ConnectivityService.instance.init();

  // 6. Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 7. Dark system UI
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF080810),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const GizaApp(),
    ),
  );
}

class GizaApp extends StatefulWidget {
  const GizaApp({super.key});

  @override
  State<GizaApp> createState() => _GizaAppState();
}

class _GizaAppState extends State<GizaApp> {
  bool _showNoNetwork = false;

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.statusStream.listen((isConnected) {
      if (mounted) {
        setState(() => _showNoNetwork = !isConnected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final theme = themeProvider.currentTheme ?? CustomTheme.darkTheme;
        return MaterialApp(
          title: 'Giza',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.buildThemeData(theme),
          home: Stack(
            children: [
              Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  if (authProvider.isLoading) {
                    return const Scaffold(
                      body: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF00E5FF))),
                    );
                  }
                  return authProvider.isAuthenticated
                      ? const HomeScreen()
                      : const LoginScreen();
                },
              ),
              if (_showNoNetwork)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Material(
                    color: Colors.red.shade700,
                    child: SafeArea(
                      bottom: false,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'No Internet Connection',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}