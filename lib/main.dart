import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/connectivity_service.dart';
import 'services/theme_service.dart';
import 'services/local_database.dart';
import 'utils/app_colors.dart';
import 'token_storage.dart';
import 'api_client.dart';
import 'dart:convert';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/event_details_screen.dart';
import 'screens/events_content.dart';
import 'services/map_service.dart';
import 'services/firebase_messaging_service.dart';
import 'widgets/home_widget_service.dart';

/// Handler pour les notifications en background
/// Cette fonction doit être une fonction top-level (pas une méthode de classe)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print(' Notification reçue en background: ${message.messageId}');
  print('   Titre: ${message.notification?.title}');
  print('   Corps: ${message.notification?.body}');
  print('   Données: ${message.data}');
  
  // Les notifications en background sont automatiquement affichées par Android
  // Vous pouvez ajouter ici du traitement supplémentaire si nécessaire
}

/// Point d'entrée de l'application
/// Initialise tous les services nécessaires avant de lancer l'interface utilisateur
/// L'ordre d'initialisation est important pour garantir que les dépendances sont prêtes
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Charger les variables d'environnement depuis .env
  await dotenv.load(fileName: ".env");

  /// Configurer le handler pour les notifications en background (doit être fait avant Firebase.initializeApp)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  /// Initialisation de Firebase Core
  await Firebase.initializeApp();

  /// Initialisation de Firebase Cloud Messaging (inclut les notifications locales)
  await FirebaseMessagingService.initialize();

  /// Initialisation du service de connectivité pour gérer le mode online/offline
  await ConnectivityService.initialize();
  
  /// Initialisation du service de carte (chargement unique pour optimiser les performances)
  await MapService().initialize();
  
  /// Initialisation du widget d'application Android (home widget)
  await HomeWidgetService.initialize();
  
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
  final MethodChannel _channel = const MethodChannel('com.example.angers_mobile_app/widget');
  int? _pendingEventId;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _checkSession();
    _checkWidgetIntent();
    _setupIntentListener();
  }

  Future<void> _checkWidgetIntent() async {
    try {
      final result = await _channel.invokeMethod('getInitialIntent');
      if (result != null && result is Map) {
        final eventIdStr = result['event_id'] as String?;
        final openEventDetails = result['open_event_details'] as bool? ?? false;
        if (eventIdStr != null && openEventDetails) {
          _pendingEventId = int.tryParse(eventIdStr);
        }
      }
    } catch (e) {
      print('Erreur lors de la vérification de l\'intent: $e');
    }
  }

  void _setupIntentListener() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewIntent') {
        final data = call.arguments as Map?;
        if (data != null) {
          final eventIdStr = data['event_id'] as String?;
          final openEventDetails = data['open_event_details'] as bool? ?? false;
          if (eventIdStr != null && openEventDetails) {
            _pendingEventId = int.tryParse(eventIdStr);
            _handlePendingEvent();
          }
        }
      }
    });
  }

  void _handlePendingEvent() {
    if (_pendingEventId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateToEventDetails(_pendingEventId!);
          _pendingEventId = null;
        });
      });
    }
  }

  Future<void> _navigateToEventDetails(int eventId) async {
    try {
      final token = await TokenStorage.read();
      if (token == null) {
        print(' Pas de token, impossible de charger l\'événement');
        return;
      }

      print(' Chargement de l\'événement $eventId...');
      final response = await ApiClient.getEvents(page: 1, pageSize: 100);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final events = data['data'] as List<dynamic>;
        
        final eventJson = events.firstWhere(
          (e) => (e as Map<String, dynamic>)['event_id'] == eventId,
          orElse: () => null,
        );

        if (eventJson != null) {
          final event = EventItem.fromJson(eventJson as Map<String, dynamic>);
          print(' Événement trouvé: ${event.title}');
          
          await Future.delayed(const Duration(milliseconds: 1000));
          
          final navigator = _navigatorKey.currentState;
          if (navigator == null) {
            print(' Navigator non disponible, nouvelle tentative...');
            await Future.delayed(const Duration(milliseconds: 500));
            final navigator2 = _navigatorKey.currentState;
            if (navigator2 == null) {
              print(' Navigator toujours non disponible');
              return;
            }
          }
          
          final finalNavigator = _navigatorKey.currentState!;
          
          if (initialRoute != '/main') {
            print(' Navigation vers /main...');
            finalNavigator.pushReplacementNamed('/main');
            await Future.delayed(const Duration(milliseconds: 800));
          }
          
          final navigatorAfterDelay = _navigatorKey.currentState;
          if (navigatorAfterDelay == null) {
            print(' Navigator perdu après délai');
            return;
          }
          
          print(' Navigation vers EventDetailsScreen...');
          navigatorAfterDelay.push(
            MaterialPageRoute(
              builder: (context) => EventDetailsScreen(event: event),
            ),
          );
        } else {
          print(' Événement $eventId non trouvé');
        }
      } else {
        print(' Erreur API: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print(' Erreur lors de la navigation vers l\'événement: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Vérifie l'état de la session utilisateur
  /// Adapte le comportement selon la connectivité: mode online ou offline
  /// En cas d'erreur, bascule automatiquement en mode offline pour garantir l'accessibilité
  Future<void> _checkSession() async {
    try {
      final isOnline = await ConnectivityService.checkConnectivity();
      
      if (isOnline) {
        await _checkOnlineSession();
      } else {
        await _checkOfflineSession();
      }
    } catch (e) {
      await _checkOfflineSession();
    }
  }

  /// Vérifie la session en mode online
  /// Valide le token JWT, tente un refresh si nécessaire, ou redirige vers le login
  Future<void> _checkOnlineSession() async {
    final token = await TokenStorage.read();
    final refreshToken = await TokenStorage.readRefreshToken();
    final sessionValid = await TokenStorage.isSessionValid();
    
    print(' Vérification de session:');
    print('  - Token: ${token != null ? "présent" : "absent"}');
    print('  - RefreshToken: ${refreshToken != null ? "présent" : "absent"}');
    print('  - SessionValid: $sessionValid');
    
    if (token != null) {
      final isTokenValidLocally = TokenStorage.isTokenValid(token);
      print('  - Token valide localement: $isTokenValidLocally');
      
      if (isTokenValidLocally && sessionValid) {
        print(' Token valide et session valide, connexion automatique');
        setState(() {
          initialRoute = '/main';
          isLoading = false;
        });
        return;
      } else if (isTokenValidLocally && !sessionValid) {
        print(' Token valide mais session non marquée, correction...');
        await TokenStorage.setSessionValid(true);
        setState(() {
          initialRoute = '/main';
          isLoading = false;
        });
        return;
      } else if (!isTokenValidLocally && refreshToken != null) {
        final isRefreshTokenValid = TokenStorage.isRefreshTokenValid(refreshToken);
        print('  - RefreshToken valide: $isRefreshTokenValid');
        
        if (isRefreshTokenValid) {
          print(' Token expiré mais refresh token valide, tentative de rafraîchissement...');
          final newToken = await _refreshToken(refreshToken);
          if (newToken != null) {
            await TokenStorage.save(newToken);
            await TokenStorage.setSessionValid(true);
            print(' Token rafraîchi avec succès');
            setState(() {
              initialRoute = '/main';
              isLoading = false;
            });
            return;
          } else {
            print(' Échec du rafraîchissement du token');
          }
        } else {
          print(' Token et refresh token expirés, connexion requise');
        }
      }
    }
    
    
    if (token != null && !TokenStorage.isTokenValid(token)) {
      print('🧹 Nettoyage des tokens expirés');
      await TokenStorage.clearAll();
    } else if (token == null) {
      print(' Aucun token trouvé, redirection vers login');
    }
    
    setState(() {
      initialRoute = '/login';
      isLoading = false;
    });
  }

  /// Vérifie la session en mode offline
  Future<void> _checkOfflineSession() async {
    final sessionValid = await TokenStorage.isSessionValid();
    
    // Vérifier qu'il y a un utilisateur en cache ET que la session était valide
    if (sessionValid) {
      // Vérifier qu'un utilisateur est bien en cache
      final currentUser = await LocalDatabase.getCurrentUser();
      if (currentUser != null) {
        print(' Auto-login offline: utilisateur trouvé en cache (${currentUser.email})');
        setState(() {
          initialRoute = '/main';
          isLoading = false;
        });
        return;
      } else {
        print(' Session valide mais aucun utilisateur en cache, nettoyage...');
        await TokenStorage.clearAll();
      }
    }
    
    // Si pas de session valide ou pas d'utilisateur en cache, rediriger vers login
    print(' Pas de session valide ou utilisateur non trouvé en cache, redirection vers login');
    setState(() {
      initialRoute = '/login';
      isLoading = false;
    });
  }

  /// Tente de rafraîchir le token d'accès en utilisant le refresh token
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
    if (isLoading) {
      return MediaQuery(
        data: MediaQueryData.fromView(WidgetsBinding.instance.platformDispatcher.views.first).copyWith(textScaleFactor: 1.0),
        child: MaterialApp(
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
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          final themeMode = themeService.themeMode;
          return MediaQuery(
            data: MediaQueryData.fromView(WidgetsBinding.instance.platformDispatcher.views.first).copyWith(textScaleFactor: 1.0),
            child: MaterialApp(
              navigatorKey: _navigatorKey,
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
              },
              navigatorObservers: [
                _AppNavigatorObserver(
                  onRouteChanged: () {
                    if (_pendingEventId != null) {
                      _handlePendingEvent();
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AppNavigatorObserver extends NavigatorObserver {
  final VoidCallback onRouteChanged;

  _AppNavigatorObserver({required this.onRouteChanged});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    onRouteChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    onRouteChanged();
  }
}