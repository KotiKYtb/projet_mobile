import 'dart:async';
import 'package:flutter/material.dart';
import 'services/connectivity_service.dart';
import 'screens/splash_screen.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConnectivityService.initialize();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JWT Auth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/register': (_) => const RegisterPage(),
        '/login': (_) => const LoginPage(),
        '/main': (_) => const MainPage(),
      },
    );
  }
}