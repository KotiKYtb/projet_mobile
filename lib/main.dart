import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/connectivity_service.dart';
import 'services/theme_service.dart';
import 'utils/app_colors.dart';
import 'token_storage.dart';
import 'api_client.dart';
import 'dart:convert';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'not_service.dart';
import 'screens/test_notification_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ On attend bien l'initialisation des notifications avant de lancer l'app
  await NotService.initNotifications();

  // ✅ Initialisation du service de connectivité
  await ConnectivityService.initialize();
  
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});
  
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  String? initialRoute;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      // Vérifier la connectivité
      final isOnline = await ConnectivityService.checkConnectivity();
      
      if (isOnline) {
        // Mode online - vérifier la session normale
        await _checkOnlineSession();
      } else {
        // Mode offline - vérifier le cache local
        await _checkOfflineSession();
      }
    } catch (e) {
      // Erreur, essayer le mode offline
      await _checkOfflineSession();
    }
  }

  Future<void> _checkOnlineSession() async {
    final token = await TokenStorage.read();
    final refreshToken = await TokenStorage.readRefreshToken();
    final sessionValid = await TokenStorage.isSessionValid();
    
    print('🔍 Vérification de session:');
    print('  - Token: ${token != null ? "présent" : "absent"}');
    print('  - RefreshToken: ${refreshToken != null ? "présent" : "absent"}');
    print('  - SessionValid: $sessionValid');
    
    // Si on a un token, vérifier s'il est valide
    if (token != null) {
      final isTokenValidLocally = TokenStorage.isTokenValid(token);
      print('  - Token valide localement: $isTokenValidLocally');
      
      if (isTokenValidLocally && sessionValid) {
        // Token valide et session valide, continuer la session
        print('✅ Token valide et session valide, connexion automatique');
        setState(() {
          initialRoute = '/main';
          isLoading = false;
        });
        return;
      } else if (isTokenValidLocally && !sessionValid) {
        // Token valide mais session non marquée comme valide - la marquer
        print('⚠️ Token valide mais session non marquée, correction...');
        await TokenStorage.setSessionValid(true);
        setState(() {
          initialRoute = '/main';
          isLoading = false;
        });
        return;
      } else if (!isTokenValidLocally && refreshToken != null) {
        // Token expiré, vérifier si le refresh token est encore valide
        final isRefreshTokenValid = TokenStorage.isRefreshTokenValid(refreshToken);
        print('  - RefreshToken valide: $isRefreshTokenValid');
        
        if (isRefreshTokenValid) {
          // Refresh token valide, essayer de rafraîchir le token
          print('🔄 Token expiré mais refresh token valide, tentative de rafraîchissement...');
          final newToken = await _refreshToken(refreshToken);
          if (newToken != null) {
            await TokenStorage.save(newToken);
            await TokenStorage.setSessionValid(true);
            print('✅ Token rafraîchi avec succès');
            setState(() {
              initialRoute = '/main';
              isLoading = false;
            });
            return;
          } else {
            print('❌ Échec du rafraîchissement du token');
          }
        } else {
          print('❌ Token et refresh token expirés, connexion requise');
        }
      }
    }
    
    // Pas de session valide, aller au login
    // Nettoyer les tokens expirés
    if (token != null && !TokenStorage.isTokenValid(token)) {
      print('🧹 Nettoyage des tokens expirés');
      await TokenStorage.clearAll();
    } else if (token == null) {
      print('❌ Aucun token trouvé, redirection vers login');
    }
    
    setState(() {
      initialRoute = '/login';
      isLoading = false;
    });
  }

  Future<void> _checkOfflineSession() async {
    // Vérifier s'il y a un utilisateur en cache local
    final sessionValid = await TokenStorage.isSessionValid();
    if (sessionValid) {
      // Session valide en cache, aller à la page principale
      setState(() {
        initialRoute = '/main';
        isLoading = false;
      });
      return;
    }
    
    // Pas d'utilisateur en cache, aller au login
    setState(() {
      initialRoute = '/login';
      isLoading = false;
    });
  }

  Future<String?> _refreshToken(String refreshToken) async {
    try {
      final response = await ApiClient.refreshToken(refreshToken: refreshToken);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['accessToken'] as String?;
      }
    } catch (e) {
      print('Erreur refresh token: $e');
    }
    return null;
  }
  
  @override
  Widget build(BuildContext context) {
    // Afficher un loader simple pendant la vérification de session
    if (isLoading) {
      return MaterialApp(
        title: 'Nocta',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.darkPrimaryBackground,
        ),
        home: const Scaffold(
          backgroundColor: AppColors.darkPrimaryBackground,
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          final themeMode = themeService.themeMode;
          return MaterialApp(
            title: 'Nocta',
            debugShowCheckedModeBanner: false,
            themeMode: themeMode,
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
            initialRoute: initialRoute ?? '/login',
            routes: {
              '/register': (_) => const RegisterPage(),
              '/login': (_) => const LoginPage(),
              '/main': (_) => const MainPage(),
              '/testNotif': (_) => const TestNotificationScreen(),
            },
          );
        },
      ),
    );
  }
}