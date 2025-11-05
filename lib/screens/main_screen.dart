import 'package:flutter/material.dart';
import '../token_storage.dart';
import '../bottom_nav.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';
import '../services/local_database.dart';
import '../models/user_model.dart';
import 'home_content.dart';
import 'users_content.dart';
import 'admin_content.dart';
import 'organisation_content.dart';
import 'profile_content.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  String userRole = 'Chargement...';
  String userName = '';
  bool loading = true;
  bool isOnline = true;
  List<UserModel> users = [];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadUsers();
    _setupConnectivityListener();
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
        // Afficher un message de reconnexion
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Connexion rétablie - Synchronisation...'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // Afficher un message de déconnexion
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Mode hors ligne - Données locales'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadUserInfo() async {
    try {
    final token = await TokenStorage.read();
      if (token == null || !TokenStorage.isTokenValid(token)) {
        setState(() {
          userRole = 'Non connecté';
          loading = false;
        });
        // Si le token est expiré, nettoyer
        if (token != null && !TokenStorage.isTokenValid(token)) {
          await TokenStorage.clearAll();
        }
        return;
      }

      // Récupérer les données depuis le cache local ou l'API
      final currentUser = await SyncService.getCurrentUser();
      if (currentUser != null) {
        setState(() {
          userRole = currentUser.role;
          userName = '${currentUser.name} ${currentUser.surname}'.trim();
          loading = false;
        });
      } else {
        // Fallback vers le stockage sécurisé
        final storedUserData = await TokenStorage.readUserData();
        if (storedUserData != null) {
          setState(() {
            userRole = storedUserData['role'] ?? 'user';
            userName = '${storedUserData['name'] ?? ''} ${storedUserData['surname'] ?? ''}'.trim();
            loading = false;
          });
        } else {
          setState(() {
            userRole = 'Données non disponibles';
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
      await _loadUsers();
    } catch (e) {
      print('Erreur de synchronisation: $e');
    }
  }

  Future<void> _loadUsers() async {
    try {
      final usersList = await SyncService.getUsers();
      setState(() {
        users = usersList;
      });
    } catch (e) {
      print('Erreur de chargement des utilisateurs: $e');
    }
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _logout() async {
    // Si on est en mode offline, afficher un popup d'avertissement
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

      // Si l'utilisateur annule, ne pas déconnecter
      if (shouldLogout != true) {
        return;
      }
    }

    try {
      // Vider complètement le stockage sécurisé (tous les tokens)
      print('🚪 Déconnexion en cours...');
      await TokenStorage.clearAll();
      
      // Vérifier que tous les tokens sont bien supprimés
      final tokenAfterLogout = await TokenStorage.read();
      final refreshTokenAfterLogout = await TokenStorage.readRefreshToken();
      
      if (tokenAfterLogout != null || refreshTokenAfterLogout != null) {
        print('⚠️ ATTENTION: Des tokens sont encore présents après la déconnexion !');
        // Forcer la suppression
        await TokenStorage.clear();
        await TokenStorage.clearRefreshToken();
      } else {
        print('✅ Tous les tokens ont été supprimés avec succès');
      }
      
      // Vider le cache local
      await LocalDatabase.clearAllUsers();
      
      // Afficher un message selon le mode
      if (!isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Déconnexion effectuée. En mode offline, vous ne pourrez plus vous reconnecter ni créer de compte.'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Déconnexion effectuée avec succès.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Widget _buildContent() {
    switch (_currentIndex) {
      case 0:
        return HomeContent(
          userName: userName,
          userRole: userRole,
          loading: loading,
        );
      case 1:
        return UsersContent(
          users: users,
          isOnline: isOnline,
        );
      case 2:
        return const AdminContent();
      case 3:
        return const OrganisationContent();
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
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade400,
        elevation: 0,
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          // Indicateur de connectivité stylisé
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isOnline ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOnline ? Colors.green.shade300 : Colors.orange.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOnline ? Icons.wifi : Icons.wifi_off,
                  color: isOnline ? Colors.green.shade700 : Colors.orange.shade700,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? 'En ligne' : 'Hors ligne',
                  style: TextStyle(
                    color: isOnline ? Colors.green.shade700 : Colors.orange.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Bouton debug
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/debug'),
            icon: const Icon(Icons.bug_report),
            color: Colors.black87,
            tooltip: 'Debug - Base de données',
          ),
          if (_currentIndex == 4) // Seulement sur la page profil
            IconButton(
              onPressed: _logout,
              icon: Icon(
                Icons.logout,
                color: !isOnline ? Colors.orange.shade700 : Colors.black87,
              ),
              tooltip: !isOnline ? 'Déconnexion (Attention: mode offline)' : 'Se déconnecter',
            ),
        ],
      ),
      body: _buildContent(),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Accueil';
      case 1:
        return 'Utilisateurs';
      case 2:
        return 'Administration';
      case 3:
        return 'Organisation';
      case 4:
        return 'Profil';
      default:
        return 'App';
    }
  }
}

