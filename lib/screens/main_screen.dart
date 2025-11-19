import 'package:flutter/material.dart';
import '../token_storage.dart';
import '../bottom_nav.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';
import '../services/local_database.dart';
import '../utils/app_colors.dart';
import '../api_client.dart';
import 'events_content.dart';
import 'map_content.dart';
import 'home_content.dart';
import 'infos_content.dart';
import 'profile_content.dart';
import 'orga/notification_screen.dart';
import 'orga/event_editor.dart';
import '../widgets/home_widget_service.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 2;
  String userRole = 'Chargement...';
  String userName = '';
  int? organizerId; // ID de l'organisateur pour les fonctionnalités orga
  bool loading = true;
  bool isOnline = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _checkInitialConnectivity();
    _setupConnectivityListener();

    // Synchroniser toutes les données et mettre à jour le widget si en ligne
    ConnectivityService.checkConnectivity().then((isOnline) {
      if (isOnline) {
        // Synchroniser toutes les données en arrière-plan
        SyncService.syncAllData().catchError((e) {
          print(' Erreur lors de la synchronisation complète au démarrage: $e');
        });
        
        HomeWidgetService.updateWidgetWithFavoriteEvents().catchError((e) {
          print(' Erreur mise à jour widget au démarrage: $e');
        });
      }
    });
  }

  /// Vérifie l'état de connectivité au démarrage de l'application
  /// Évite d'afficher un indicateur vert alors que l'app est en mode offline
  Future<void> _checkInitialConnectivity() async {
    try {
      final isConnected = await ConnectivityService.checkConnectivity();
      if (mounted) {
        setState(() {
          isOnline = isConnected;
        });
        print('📡 État de connectivité au démarrage: ${isConnected ? "ONLINE" : "OFFLINE"}');
      }
    } catch (e) {
      print('Erreur lors de la vérification de connectivité: $e');
      // En cas d'erreur, considérer comme offline pour être sûr
      if (mounted) {
        setState(() {
          isOnline = false;
        });
      }
    }
  }

  @override
  void dispose() {
    ConnectivityService.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _setupConnectivityListener() {
    ConnectivityService.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged(bool online) {
    if (mounted) {
      setState(() {
        isOnline = online;
      });
      
      if (online) {
        _syncData();
        // Synchroniser toutes les données en arrière-plan quand la connexion est rétablie
        _syncAllDataInBackground();
      }

    }
  }

  void _syncAllDataInBackground() {
    // Vérifier la connectivité et synchroniser toutes les données si en ligne
    ConnectivityService.checkConnectivity().then((isOnline) {
      if (isOnline) {
        SyncService.syncAllData().catchError((e) {
          print(' Erreur lors de la synchronisation complète: $e');
        });
      }
    });
  }

  Future<void> _loadUserInfo() async {
    try {
    final token = await TokenStorage.read();
      if (token == null || !TokenStorage.isTokenValid(token)) {
        setState(() {
          userRole = 'Non connecté';
          loading = false;
        });

        if (token != null && !TokenStorage.isTokenValid(token)) {
          await TokenStorage.clearAll();
        }
        return;
      }

      // Récupérer l'ID directement depuis le token JWT pour être sûr
      final userIdFromToken = await SyncService.getCurrentUserId();
      print('MainScreen: userIdFromToken = $userIdFromToken');
      
      final currentUser = await SyncService.getCurrentUser();
      if (currentUser != null) {
        print('MainScreen: currentUser.userId = ${currentUser.userId}, currentUser.id = ${currentUser.id}');
        setState(() {
          userRole = currentUser.role.toLowerCase(); // Normaliser en lowercase
          userName = '${currentUser.name} ${currentUser.surname}'.trim();
          // Utiliser l'ID du token en priorité, sinon userId de currentUser
          organizerId = userIdFromToken ?? currentUser.userId;
          print('MainScreen: organizerId final = $organizerId');
          loading = false;
        });
      } else {

        final storedUserData = await TokenStorage.readUserData();
        if (storedUserData != null) {
          setState(() {
            userRole = (storedUserData['role'] ?? 'user').toLowerCase();
            userName = '${storedUserData['name'] ?? ''} ${storedUserData['surname'] ?? ''}'.trim();
            organizerId = storedUserData['id']; // Si présent dans le cache
            loading = false;
          });
        } else {
          setState(() {
            userRole = 'user';
            userName = 'Utilisateur';
            loading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        userRole = 'Erreur: $e';
        loading = false;
      });
    }
  }

  Future<void> _syncData() async {
    try {
      await SyncService.syncUsersFromApi();
    } catch (e) {
      print('Erreur de synchronisation: $e');
    }
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// Gère la déconnexion de l'utilisateur
  /// Affiche un avertissement en mode offline car la reconnexion sera impossible
  /// Nettoie complètement tous les tokens et données de session
  Future<void> _logout() async {

    /// En mode offline, avertir l'utilisateur des conséquences de la déconnexion
    if (!isOnline) {
      final shouldLogout = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('Attention !'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vous êtes actuellement hors ligne.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Si vous vous déconnectez maintenant, vous ne pourrez plus :',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Vous reconnecter en mode offline'),
                Text('• Créer un nouveau compte'),
                SizedBox(height: 8),
                Text(
                  'Vous devrez attendre d\'être reconnecté au réseau pour pouvoir vous reconnecter.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                SizedBox(height: 8),
                Text(
                  'Êtes-vous sûr de vouloir continuer ?',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Déconnexion'),
              ),
            ],
          );
        },
      );

      if (shouldLogout != true) {
        return;
      }
    }

    try {

      print('🚪 Déconnexion en cours...');
      await TokenStorage.clearAll();

      final tokenAfterLogout = await TokenStorage.read();
      final refreshTokenAfterLogout = await TokenStorage.readRefreshToken();
      
      if (tokenAfterLogout != null || refreshTokenAfterLogout != null) {
        print(' ATTENTION: Des tokens sont encore présents après la déconnexion !');

        await TokenStorage.clear();
        await TokenStorage.clearRefreshToken();
      } else {
        print(' Tous les tokens ont été supprimés avec succès');
      }

      await LocalDatabase.clearAllUsers();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Widget _buildContent() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Router selon le rôle de l'utilisateur
    switch (userRole) {
      case 'organisation':
        return _buildOrgaContent();
      // case 'admin':
      //   return _buildAdminContent();
      case 'user':
      default:
        return _buildUserContent();
    }
  }

  /// Contenu USER (par défaut)
  Widget _buildUserContent() {
    // Créer MapContent avec une clé pour forcer sa création
    final mapContent = MapContent(
      key: const ValueKey('map_content'),
      isActive: _currentIndex == 1,
    );
    
    print(' MainScreen: Création de MapContent avec isActive=${_currentIndex == 1}');
    debugPrint(' MainScreen: Création de MapContent avec isActive=${_currentIndex == 1}');
    
    return IndexedStack(
      index: _currentIndex,
      children: [
        const EventsContent(),
        mapContent,
        HomeContent(
          userName: userName,
          userRole: userRole,
          loading: loading,
          isActive: _currentIndex == 2,
        ),
        const InfosContent(),
        ProfileContent(
          userName: userName,
          userRole: userRole,
          loading: loading,
          isOnline: isOnline,
          onLogout: _logout,
        ),
      ],
    );
  }

  /// Contenu ORGANISATEUR
  Widget _buildOrgaContent() {
    switch (_currentIndex) {
      case 0:
        return const EventEditor();
      case 1:
        return const NotificationScreen();
      case 2:
        return HomeContent(
          userName: userName,
          userRole: userRole,
          loading: loading,
          isActive: _currentIndex == 2,
        );
      case 3:
        return const InfosContent();
      case 4:
        return ProfileContent(
          userName: userName,
          userRole: userRole,
          loading: loading,
          isOnline: isOnline,
          onLogout: _logout,
        );
      default:
        return HomeContent(
          userName: userName,
          userRole: userRole,
          loading: loading,
          isActive: _currentIndex == 2,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getPrimaryBackground(context),
      extendBody: true,
      body: _buildContent(),
      bottomNavigationBar: loading
          ? null
          : BottomNav(
              currentIndex: _currentIndex,
              onTap: _onBottomNavTap,
              userRole: userRole,
            ),
    );
  }
}

