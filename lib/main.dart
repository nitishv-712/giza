// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'db/hive_helper.dart';
import 'services/audio_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'providers/audio_provider.dart';
import 'providers/auth_provider.dart';
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

  // 5. Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 6. Dark system UI
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF080810),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const GizaApp(),
    ),
  );
}

class GizaApp extends StatelessWidget {
  const GizaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Giza',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080810),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          surface: Color(0xFF18182A),
          onSurface: Color(0xFFECECFF),
        ),
        splashFactory: InkRipple.splashFactory,
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: const CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
            );
          }
          return authProvider.isAuthenticated ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}