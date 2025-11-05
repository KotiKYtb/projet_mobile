import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../services/local_database.dart';
import '../api_client.dart';
import '../token_storage.dart';

class SyncService {
  static bool _isOnline = true;
  static DateTime? _lastSync;

  // Vérifier la connectivité
  static bool get isOnline => _isOnline;
  static DateTime? get lastSync => _lastSync;

  // Synchroniser seulement l'utilisateur connecté depuis l'API
  static Future<bool> syncUsersFromApi() async {
    try {
      _isOnline = true;
      
      // Récupérer le token de l'utilisateur connecté
      final token = await TokenStorage.read();
      if (token == null) {
        print('Aucun token trouvé, pas de synchronisation');
        return false;
      }
      
      // Vérifier si le token est encore valide localement
      if (!TokenStorage.isTokenValid(token)) {
        print('⚠️ Token expiré, pas de synchronisation');
        return false;
      }
      
      // Récupérer les informations de l'utilisateur connecté depuis l'API
      final response = await ApiClient.getUser(token: token);
      
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body) as Map<String, dynamic>;
        final user = UserModel.fromApi(userData);
        
        // Sauvegarder seulement cet utilisateur en local
        await LocalDatabase.insertOrUpdateUser(user);
        
        _lastSync = DateTime.now();
        print('Utilisateur connecté synchronisé: ${user.email}');
        return true;
      }
      return false;
    } catch (e) {
      _isOnline = false;
      print('Erreur de synchronisation: $e');
      return false;
    }
  }

  // Récupérer seulement l'utilisateur connecté
  static Future<List<UserModel>> getUsers() async {
    if (_isOnline) {
      // Essayer de synchroniser l'utilisateur connecté depuis l'API
      final syncSuccess = await syncUsersFromApi();
      if (syncSuccess) {
        // Retourner seulement l'utilisateur connecté
        final currentUser = await LocalDatabase.getCurrentUser();
        return currentUser != null ? [currentUser] : [];
      }
    }
    
    // Retourner seulement l'utilisateur connecté depuis le cache local
    final currentUser = await LocalDatabase.getCurrentUser();
    return currentUser != null ? [currentUser] : [];
  }

  // Récupérer l'utilisateur connecté
  static Future<UserModel?> getCurrentUser() async {
    if (_isOnline) {
      // Essayer de synchroniser
      await syncUsersFromApi();
    }
    
    return await LocalDatabase.getCurrentUser();
  }

  // Mettre à jour le rôle d'un utilisateur
  static Future<bool> updateUserRole(int userId, String newRole) async {
    try {
      if (_isOnline) {
        // Mettre à jour via l'API
        final token = await TokenStorage.read();
        if (token != null && TokenStorage.isTokenValid(token)) {
          final response = await ApiClient.updateUserRole(
            token: token,
            userId: userId,
            role: newRole,
          );
          
          if (response.statusCode == 200) {
            // Mettre à jour en local
            final user = await LocalDatabase.getUserById(userId);
            if (user != null) {
              final updatedUser = user.copyWith(role: newRole);
              await LocalDatabase.insertOrUpdateUser(updatedUser);
              await LocalDatabase.updateLastSync(userId);
            }
            return true;
          }
        }
      }
      
      // Mode offline : mettre à jour seulement en local
      final user = await LocalDatabase.getUserById(userId);
      if (user != null) {
        final updatedUser = user.copyWith(role: newRole);
        await LocalDatabase.insertOrUpdateUser(updatedUser);
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  // Forcer la synchronisation
  static Future<bool> forceSync() async {
    return await syncUsersFromApi();
  }

  // Vider le cache local
  static Future<void> clearCache() async {
    await LocalDatabase.clearAllUsers();
    _lastSync = null;
  }

  // Vérifier si les données sont récentes (moins de 5 minutes)
  static bool get isDataFresh {
    if (_lastSync == null) return false;
    return DateTime.now().difference(_lastSync!).inMinutes < 5;
  }
}
