import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../services/local_database.dart';
import '../api_client.dart';
import '../token_storage.dart';

class SyncService {
  static bool _isOnline = true;
  static DateTime? _lastSync;

  static bool get isOnline => _isOnline;
  static DateTime? get lastSync => _lastSync;

  static Future<bool> syncUsersFromApi() async {
    try {
      _isOnline = true;

      final token = await TokenStorage.read();
      if (token == null) {
        print(' Aucun token trouvé, pas de synchronisation');
        return false;
      }

      if (!TokenStorage.isTokenValid(token)) {
        print(' Token expiré, pas de synchronisation');
        return false;
      }

      // Utiliser un timeout plus long pour la synchronisation
      final response = await ApiClient.getUser(token: token)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        print(' Timeout lors de la synchronisation de l\'utilisateur');
        throw TimeoutException('Timeout lors de la synchronisation de l\'utilisateur');
      });
      
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body) as Map<String, dynamic>;
        final user = UserModel.fromApi(userData);

        await LocalDatabase.insertOrUpdateUser(user);
        
        // Synchroniser aussi les favoris de l'utilisateur (sans bloquer si ça échoue)
        try {
          await syncFavoritesFromApi(user.userId);
        } catch (e) {
          print(' Erreur lors de la synchronisation des favoris, mais utilisateur synchronisé: $e');
        }
        
        // Synchroniser aussi les notifications de l'utilisateur (sans bloquer si ça échoue)
        try {
          await syncUserNotificationsFromApi(user.userId);
        } catch (e) {
          print(' Erreur lors de la synchronisation des notifications, mais utilisateur synchronisé: $e');
        }
        
        _lastSync = DateTime.now();
        print(' Utilisateur connecté synchronisé: ${user.email}');
        return true;
      }
      print(' Erreur API lors de la synchronisation de l\'utilisateur: ${response.statusCode}');
      return false;
    } on TimeoutException catch (e) {
      _isOnline = false;
      print(' Timeout lors de la synchronisation: $e');
      print(' Utilisation du cache local en attendant...');
      return false;
    } catch (e) {
      _isOnline = false;
      print(' Erreur de synchronisation: $e');
      print(' Utilisation du cache local en attendant...');
      return false;
    }
  }

  /// Synchronise les favoris depuis l'API et les met en cache local
  static Future<bool> syncFavoritesFromApi(int userId) async {
    try {
      final token = await TokenStorage.read();
      if (token == null || !TokenStorage.isTokenValid(token)) {
        print(' Pas de token valide pour synchroniser les favoris');
        return false;
      }

      // Utiliser un timeout plus long pour la synchronisation
      final response = await ApiClient.getFavorites(token: token)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        print(' Timeout lors de la synchronisation des favoris');
        throw TimeoutException('Timeout lors de la synchronisation des favoris');
      });
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final favoritesData = data['favorites'] as List<dynamic>? ?? [];
        
        final favoriteEventIds = favoritesData
            .map((f) => (f as Map<String, dynamic>)['event_id'] as int)
            .toList();

        await LocalDatabase.syncFavorites(
          userId: userId,
          eventIds: favoriteEventIds,
        );
        
        print(' Favoris synchronisés: ${favoriteEventIds.length} favoris');
        return true;
      }
      print(' Erreur API lors de la synchronisation des favoris: ${response.statusCode}');
      return false;
    } on TimeoutException catch (e) {
      print(' Timeout lors de la synchronisation des favoris: $e');
      print(' Utilisation du cache local en attendant...');
      _isOnline = false; // Marquer comme offline pour utiliser le cache
      return false;
    } catch (e) {
      print(' Erreur synchronisation favoris: $e');
      print(' Utilisation du cache local en attendant...');
      _isOnline = false; // Marquer comme offline pour utiliser le cache
      return false;
    }
  }

  static Future<List<UserModel>> getUsers() async {
    if (_isOnline) {

      final syncSuccess = await syncUsersFromApi();
      if (syncSuccess) {

        final currentUser = await LocalDatabase.getCurrentUser();
        return currentUser != null ? [currentUser] : [];
      }
    }

    final currentUser = await LocalDatabase.getCurrentUser();
    return currentUser != null ? [currentUser] : [];
  }

  static Future<UserModel?> getCurrentUser() async {
    if (_isOnline) {

      await syncUsersFromApi();
    }
    
    return await LocalDatabase.getCurrentUser();
  }

  static Future<bool> updateUserRole(int userId, String newRole) async {
    try {
      if (_isOnline) {

        final token = await TokenStorage.read();
        if (token != null && TokenStorage.isTokenValid(token)) {
          final response = await ApiClient.updateUserRole(
            token: token,
            userId: userId,
            role: newRole,
          );
          
          if (response.statusCode == 200) {

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

  static Future<bool> forceSync() async {
    return await syncUsersFromApi();
  }

  /// Synchronise toutes les données depuis l'API vers la base de données locale
  /// Inclut : événements, favoris, notifications reçues, notifications créées (si organisateur)
  static Future<bool> syncAllData() async {
    try {
      final token = await TokenStorage.read();
      if (token == null || !TokenStorage.isTokenValid(token)) {
        print(' Pas de token valide pour synchroniser toutes les données');
        return false;
      }

      final userId = await getCurrentUserId();
      if (userId == null) {
        print(' Impossible de récupérer l\'ID utilisateur pour la synchronisation');
        return false;
      }

      print(' Début de la synchronisation complète des données...');
      _isOnline = true;

      // 1. Synchroniser l'utilisateur
      await syncUsersFromApi();

      // 2. Synchroniser TOUS les événements (pas seulement les favoris)
      try {
        print(' Synchronisation de tous les événements...');
        final eventsResponse = await ApiClient.getEvents(page: 1, pageSize: 1000)
            .timeout(const Duration(seconds: 30), onTimeout: () {
          print(' Timeout lors de la synchronisation des événements');
          throw TimeoutException('Timeout lors de la synchronisation des événements');
        });
        
        if (eventsResponse.statusCode == 200) {
          final data = jsonDecode(eventsResponse.body) as Map<String, dynamic>;
          final eventsData = data['data'] as List<dynamic>;
          
          final eventsList = eventsData
              .map((e) => e is Map<String, dynamic> ? e : e as Map<String, dynamic>)
              .toList();
          
          await LocalDatabase.saveEvents(eventsList);
          print(' ${eventsList.length} événements synchronisés');
        } else {
          print(' Erreur API lors de la synchronisation des événements: ${eventsResponse.statusCode}');
        }
      } catch (e) {
        print(' Erreur lors de la synchronisation des événements: $e');
      }

      // 3. Synchroniser les favoris
      try {
        await syncFavoritesFromApi(userId);
      } catch (e) {
        print(' Erreur lors de la synchronisation des favoris: $e');
      }

      // 4. Synchroniser les notifications reçues (pour tous les utilisateurs)
      try {
        await syncUserNotificationsFromApi(userId);
      } catch (e) {
        print(' Erreur lors de la synchronisation des notifications reçues: $e');
      }

      // 5. Synchroniser les notifications créées (pour les organisateurs)
      try {
        final currentUser = await LocalDatabase.getCurrentUser();
        if (currentUser != null && 
            (currentUser.role.toLowerCase() == 'organizer' || 
             currentUser.role.toLowerCase() == 'organisateur' ||
             currentUser.role.toLowerCase() == 'admin')) {
          await syncCreatedNotificationsFromApi();
        }
      } catch (e) {
        print(' Erreur lors de la synchronisation des notifications créées: $e');
      }

      _lastSync = DateTime.now();
      print(' Synchronisation complète terminée avec succès');
      return true;
    } on TimeoutException catch (e) {
      _isOnline = false;
      print(' Timeout lors de la synchronisation complète: $e');
      return false;
    } catch (e) {
      _isOnline = false;
      print(' Erreur lors de la synchronisation complète: $e');
      return false;
    }
  }

  /// Synchronise les notifications créées par l'utilisateur (pour les organisateurs)
  static Future<bool> syncCreatedNotificationsFromApi() async {
    try {
      final token = await TokenStorage.read();
      if (token == null || !TokenStorage.isTokenValid(token)) {
        print(' Pas de token valide pour synchroniser les notifications créées');
        return false;
      }

      final response = await ApiClient.getNotifications(token: token)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        print(' Timeout lors de la synchronisation des notifications créées');
        throw TimeoutException('Timeout lors de la synchronisation des notifications créées');
      });
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final notificationsData = data['notifications'] as List<dynamic>? ?? [];
        
        final notificationsList = notificationsData
            .map((n) => n as Map<String, dynamic>)
            .toList();

        await LocalDatabase.saveNotifications(notificationsList);
        
        print(' Notifications créées synchronisées: ${notificationsList.length} notifications');
        return true;
      }
      print(' Erreur API lors de la synchronisation des notifications créées: ${response.statusCode}');
      return false;
    } on TimeoutException catch (e) {
      print(' Timeout lors de la synchronisation des notifications créées: $e');
      return false;
    } catch (e) {
      print(' Erreur synchronisation notifications créées: $e');
      return false;
    }
  }

  /// Synchronise les notifications reçues par l'utilisateur depuis l'API
  static Future<bool> syncUserNotificationsFromApi(int userId) async {
    try {
      final token = await TokenStorage.read();
      if (token == null || !TokenStorage.isTokenValid(token)) {
        print(' Pas de token valide pour synchroniser les notifications');
        return false;
      }

      // Utiliser un timeout plus long pour la synchronisation
      final response = await ApiClient.getReceivedNotifications(token: token)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        print(' Timeout lors de la synchronisation des notifications');
        throw TimeoutException('Timeout lors de la synchronisation des notifications');
      });
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final notificationsData = data['notifications'] as List<dynamic>? ?? [];
        
        final notificationsList = notificationsData
            .map((n) => n as Map<String, dynamic>)
            .toList();

        await LocalDatabase.saveUserNotifications(
          userId: userId,
          userNotificationsJson: notificationsList,
        );
        
        print(' Notifications synchronisées: ${notificationsList.length} notifications');
        return true;
      }
      print(' Erreur API lors de la synchronisation des notifications: ${response.statusCode}');
      return false;
    } on TimeoutException catch (e) {
      print(' Timeout lors de la synchronisation des notifications: $e');
      print(' Utilisation du cache local en attendant...');
      _isOnline = false; // Marquer comme offline pour utiliser le cache
      return false;
    } catch (e) {
      print(' Erreur synchronisation notifications: $e');
      print(' Utilisation du cache local en attendant...');
      _isOnline = false; // Marquer comme offline pour utiliser le cache
      return false;
    }
  }

  /// Récupère les notifications depuis le cache local ou l'API selon la connectivité
  static Future<List<Map<String, dynamic>>> getUserNotifications(int userId) async {
    if (_isOnline) {
      // Tenter de synchroniser depuis l'API
      final syncSuccess = await syncUserNotificationsFromApi(userId);
      if (syncSuccess) {
        return await LocalDatabase.getUserNotifications(userId);
      }
    }
    
    // En mode offline ou si la sync échoue, utiliser le cache local
    return await LocalDatabase.getUserNotifications(userId);
  }

  static Future<void> clearCache() async {
    await LocalDatabase.clearAllUsers();
    await LocalDatabase.clearAllFavorites();
    await LocalDatabase.clearAllEvents();
    await LocalDatabase.clearAllNotifications();
    await LocalDatabase.clearAllUserNotifications();
    _lastSync = null;
  }

  /// Récupère les favoris depuis le cache local ou l'API selon la connectivité
  static Future<List<int>> getFavoriteEventIds(int userId) async {
    if (_isOnline) {
      // Tenter de synchroniser depuis l'API
      final syncSuccess = await syncFavoritesFromApi(userId);
      if (syncSuccess) {
        return await LocalDatabase.getFavoriteEventIds(userId);
      }
    }
    
    // En mode offline ou si la sync échoue, utiliser le cache local
    return await LocalDatabase.getFavoriteEventIds(userId);
  }

  /// Vérifie si un événement est en favori (cache local ou API)
  static Future<bool> isFavorite({
    required int userId,
    required int eventId,
  }) async {
    if (_isOnline) {
      // Tenter de synchroniser d'abord
      await syncFavoritesFromApi(userId);
    }
    
    return await LocalDatabase.isFavorite(userId: userId, eventId: eventId);
  }

  static bool get isDataFresh {
    if (_lastSync == null) return false;
    return DateTime.now().difference(_lastSync!).inMinutes < 5;
  }

  /// Récupère l'ID de l'utilisateur actuel depuis le token ou le cache local
  static Future<int?> getCurrentUserId() async {
    try {
      // Essayer depuis le token JWT
      final token = await TokenStorage.read();
      if (token != null) {
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            final payload = parts[1];
            String normalizedPayload = payload;
            switch (payload.length % 4) {
              case 1:
                normalizedPayload += '===';
                break;
              case 2:
                normalizedPayload += '==';
                break;
              case 3:
                normalizedPayload += '=';
                break;
            }
            normalizedPayload = normalizedPayload.replaceAll('-', '+').replaceAll('_', '/');
            final decodedBytes = base64Decode(normalizedPayload);
            final decodedString = utf8.decode(decodedBytes);
            final payloadMap = jsonDecode(decodedString) as Map<String, dynamic>;
            final userId = payloadMap['id'] as int?;
            print('SyncService.getCurrentUserId: ID récupéré depuis le token JWT: $userId');
            print('SyncService.getCurrentUserId: Payload complet: $payloadMap');
            if (userId != null) return userId;
          }
        } catch (e) {
          print('Erreur décodage token: $e');
        }
      }

      // Si pas de token valide, essayer depuis le cache local
      final currentUser = await LocalDatabase.getCurrentUser();
      if (currentUser != null) {
        print('SyncService.getCurrentUserId: ID récupéré depuis le cache local (userId): ${currentUser.userId}');
        print('SyncService.getCurrentUserId: currentUser.id = ${currentUser.id}, currentUser.userId = ${currentUser.userId}');
      }
      return currentUser?.userId;
    } catch (e) {
      print('Erreur récupération userId: $e');
      return null;
    }
  }
}
