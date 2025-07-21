import 'package:flutter/material.dart';
import 'package:theme_provider/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:yaammy/screens/splash_screen.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  try {
    await FirebaseAppCheck.instance.activate(androidProvider: AndroidProvider.playIntegrity);
    debugPrint('App Check initialized with Play Integrity');
    String? token = await FirebaseAppCheck.instance.getToken(true);
    debugPrint('App Check token: $token');
  } catch (e) {
    debugPrint('Play Integrity initialization failed: $e');
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      themes: [
        AppTheme(
          id: 'light',
          description: 'Light Theme',
          data: ThemeData(
            primarySwatch: Colors.red,
            brightness: Brightness.light,
          ),
        ),
        AppTheme(
          id: 'dark',
          description: 'Dark Theme',
          data: ThemeData(
            primarySwatch: Colors.red,
            brightness: Brightness.dark,
          ),
        ),
      ],
      child: ThemeConsumer(
        child: Builder(
          builder: (themeContext) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Yaammy Food Delivery',
              theme: ThemeProvider.themeOf(themeContext).data,
              home: SplashScreenWidget(),
            );
          },
        ),
      ),
    );
  }
}