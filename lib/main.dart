import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/connectivity_service.dart';
import 'services/theme_service.dart';
import 'utils/app_colors.dart';
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
    return ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            title: 'Nocta',
            debugShowCheckedModeBanner: false,
            themeMode: themeService.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: AppColors.lightPrimaryBackground,
              colorScheme: ColorScheme.light(
                primary: AppColors.primaryButton,
                secondary: AppColors.secondaryText,
                surface: AppColors.lightCardBackground,
                onSurface: AppColors.lightTextPrimary,
                onPrimary: Colors.white,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: AppColors.darkPrimaryBackground,
              colorScheme: ColorScheme.dark(
                primary: AppColors.primaryButton,
                secondary: AppColors.secondaryText,
                surface: AppColors.darkCardBackground,
                onSurface: AppColors.darkTextPrimary,
                onPrimary: Colors.white,
              ),
            ),
            initialRoute: '/splash',
            routes: {
              '/splash': (_) => const SplashScreen(),
              '/register': (_) => const RegisterPage(),
              '/login': (_) => const LoginPage(),
              '/main': (_) => const MainPage(),
            },
          );
        },
      ),
    );
  }
}