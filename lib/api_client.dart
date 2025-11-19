import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Client HTTP pour communiquer avec l'API backend
class ApiClient {
  static String get baseUrl {
    var ip = dotenv.env['API_IP'] ?? 'localhost';
    final port = dotenv.env['API_PORT'] ?? '8080';
    final protocol = dotenv.env['API_PROTOCOL'] ?? 'http';
    
    // Nettoyer l'IP si elle contient http:// ou https://
    ip = ip.replaceFirst(RegExp(r'^https?://'), '');
    // Nettoyer les slashes en fin
    ip = ip.replaceAll(RegExp(r'/+$'), '');
    final defaultPort = protocol == 'https' ? '443' : '80';
    final shouldIncludePort = port != defaultPort && port.isNotEmpty;
    
    if (shouldIncludePort) {
      return '$protocol://$ip:$port';
    } else {
      return '$protocol://$ip';
    }
  }
  
  static String get apiBaseUrl => baseUrl;
  
  /// Construit une URL complète à partir d'un chemin relatif
  static String buildUrl(String path) {
    // Nettoyer le chemin (enlever les slashes en début si nécessaire)
    var cleanPath = path.trim();
    if (!cleanPath.startsWith('/')) {
      cleanPath = '/$cleanPath';
    }
    // Enlever les slashes multiples
    cleanPath = cleanPath.replaceAll(RegExp(r'/+'), '/');
    
    // Construire l'URL complète
    return '$baseUrl$cleanPath';
  }
  
  /// Nettoie une URL pour s'assurer qu'elle est valide
  static String cleanUrl(String url) {
    if (url.isEmpty) return url;
    
    var cleanedUrl = url.trim();
    
    // Supprimer les protocoles en double (https://https:// -> https://)
    cleanedUrl = cleanedUrl.replaceFirst(RegExp(r'^https?://https?://'), 'https://');
    cleanedUrl = cleanedUrl.replaceFirst(RegExp(r'^http://https://'), 'https://');
    cleanedUrl = cleanedUrl.replaceFirst(RegExp(r'^https://http://'), 'https://');
    
    if (cleanedUrl.contains('://')) {
      final parts = cleanedUrl.split('://');
      if (parts.length == 2) {
        final protocol = parts[0];
        final path = parts[1].replaceAll(RegExp(r'/+'), '/');
        cleanedUrl = '$protocol://$path';
      }
    } else {
      // Pas de protocole, nettoyer les slashes
      cleanedUrl = cleanedUrl.replaceAll(RegExp(r'/+'), '/');
    }
    
    // Si l'URL ne commence pas par http:// ou https://, c'est une URL relative
    if (!cleanedUrl.startsWith('http://') && !cleanedUrl.startsWith('https://')) {
      // Si c'est une URL relative, on la combine avec baseUrl
      if (cleanedUrl.startsWith('/')) {
        return '$baseUrl$cleanedUrl';
      } else {
        return '$baseUrl/$cleanedUrl';
      }
    }
    
    return cleanedUrl;
  }
  
  /// Timeout par défaut pour toutes les requêtes HTTP (20 secondes)
  static const Duration timeout = Duration(seconds: 20);
  
  /// Timeout court pour vérifier rapidement si l'API est accessible (1 seconde pour démarrage rapide)
  static const Duration quickTimeout = Duration(seconds: 1);
  
  /// Vérifie rapidement si l'API est accessible en testant l'endpoint des événements
  static Future<bool> isApiAccessible() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/events?page=1&pageSize=1'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(quickTimeout);
      
      return response.statusCode == 200;
    } catch (e) {
      // Timeout, erreur de connexion, etc. -> API non accessible
      return false;
    }
  }
  
  /// Teste la connexion à l'API en effectuant une requête GET sur l'endpoint racine
  static Future<bool> testConnection() async {
    try {
      print(' Test de connexion à: $baseUrl');
      final response = await http
          .get(Uri.parse('$baseUrl/'))
          .timeout(timeout);
      
      print(' Réponse reçue: ${response.statusCode}');
      if (response.statusCode == 200) {
        print(' Connexion réussie!');
        return true;
      } else {
        print(' Réponse inattendue: ${response.statusCode}');
        return false;
      }
    } on TimeoutException catch (e) {
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<http.Response> signup({
    required String email,
    required String password,
    String? name,
    String? surname,
    String? role,
  }) {
    return http.post(
      Uri.parse('$baseUrl/api/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        if (name != null) 'name': name,
        if (surname != null) 'surname': surname,
        if (role != null) 'role': role,
      }),
    ).timeout(timeout);
  }

  static Future<http.Response> signin({
    required String email,
    required String password,
  }) {
    return http.post(
      Uri.parse('$baseUrl/api/auth/signin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(timeout);
  }

  static Future<http.Response> getUser({required String token}) {
    return http.get(
      Uri.parse('$baseUrl/api/users/me'),
      headers: {
        'Accept': 'application/json',
        'x-access-token': token,
      },
    ).timeout(timeout);
  }

  static Future<http.Response> getModerator({required String token}) {
    return http.get(
      Uri.parse('$baseUrl/api/test/mod'),
      headers: {'x-access-token': token},
    ).timeout(timeout);
  }

  static Future<http.Response> getAdmin({required String token}) {
    return http.get(
      Uri.parse('$baseUrl/api/test/admin'),
      headers: {'x-access-token': token},
    ).timeout(timeout);
  }

  static Future<http.Response> getDebugUsers() {
    return http.get(Uri.parse('$baseUrl/api/debug/users')).timeout(timeout);
  }

  static Future<http.Response> getAllUsers({required String token}) {
    return http.get(
      Uri.parse('$baseUrl/api/users'),
      headers: {
        'Accept': 'application/json',
        'x-access-token': token,
      },
    ).timeout(timeout);
  }

  static Future<http.Response> getAllUsersPublic() {
    return http.get(
      Uri.parse('$baseUrl/api/users/public'),
      headers: {
        'Accept': 'application/json',
      },
    ).timeout(timeout);
  }

  static Future<http.Response> updateUserRole({
    required String token,
    required int userId,
    required String role,
  }) {
    return http.put(
      Uri.parse('$baseUrl/api/users/$userId/role'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'x-access-token': token,
      },
      body: jsonEncode({'role': role}),
    ).timeout(timeout);
  }

  static Future<http.Response> refreshToken({
    required String refreshToken,
  }) {
    return http.post(
      Uri.parse('$baseUrl/api/auth/refresh'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'refreshToken': refreshToken}),
    ).timeout(timeout);
  }

  static Future<http.Response> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) {
    return http.put(
      Uri.parse('$baseUrl/api/users/change-password'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'x-access-token': token,
      },
      body: jsonEncode({
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    ).timeout(timeout);
  }

  static Future<http.Response> getEvents({
    int page = 1,
    int pageSize = 50,
  }) {
    return http.get(
      Uri.parse('$baseUrl/api/events?page=$page&pageSize=$pageSize'),
      headers: {
        'Accept': 'application/json',
      },
    ).timeout(timeout);
  }

  static Future<http.Response> getEventById(int eventId) {
    return http.get(
      Uri.parse('$baseUrl/api/events/$eventId'),
      headers: {
        'Accept': 'application/json',
      },
    ).timeout(timeout);
  }

  /// Crée un nouvel événement (Admin/Organisation uniquement)
  static Future<http.Response> createEvent({
    required String token,
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    String? description,
    String? location,
    String? category,
    String? imageUrl,
  }) {
    return http.post(
      Uri.parse('$baseUrl/api/events'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'x-access-token': token,
      },
      body: jsonEncode({
        'title': title,
        'startAt': startAt.toIso8601String(),
        if (endAt != null) 'endAt': endAt.toIso8601String(),
        if (description != null && description.isNotEmpty) 'description': description,
        if (location != null && location.isNotEmpty) 'location': location,
        if (category != null && category.isNotEmpty) 'category': category,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
      }),
    ).timeout(timeout);
  }

  /// Met à jour un événement existant (Admin/Organisation uniquement)
  static Future<http.Response> updateEvent({
    required String token,
    required int eventId,
    String? title,
    DateTime? startAt,
    DateTime? endAt,
    String? description,
    String? location,
    String? category,
    String? imageUrl,
  }) {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (startAt != null) body['startAt'] = startAt.toIso8601String();
    if (endAt != null) body['endAt'] = endAt.toIso8601String();
    if (description != null) body['description'] = description;
    if (location != null) body['location'] = location;
    if (category != null) body['category'] = category;
    if (imageUrl != null) body['image_url'] = imageUrl;

    return http.put(
      Uri.parse('$baseUrl/api/events/$eventId'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'x-access-token': token,
      },
      body: jsonEncode(body),
    ).timeout(timeout);
  }

  /// Supprime un événement (Admin/Organisation uniquement)
  static Future<http.Response> deleteEvent({
    required String token,
    required int eventId,
  }) {
    return http.delete(
      Uri.parse('$baseUrl/api/events/$eventId'),
      headers: {
        'Accept': 'application/json',
        'x-access-token': token,
      },
    ).timeout(timeout);
  }

  static Future<http.Response> addFavorite({
    required String token,
    required int eventId,
  }) {
    return http.post(
      Uri.parse('$baseUrl/api/favorites'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'x-access-token': token,
      },
      body: jsonEncode({
        'event_id': eventId,
      }),
    ).timeout(timeout);
  }

  static Future<http.Response> removeFavorite({
    required String token,
    required int eventId,
  }) {
    return http.delete(
      Uri.parse('$baseUrl/api/favorites/$eventId'),
      headers: {
        'Accept': 'application/json',
        'x-access-token': token,
      },
    ).timeout(timeout);
  }

  static Future<http.Response> getFavorites({
    required String token,
  }) {
    return http.get(
      Uri.parse('$baseUrl/api/favorites'),
      headers: {
        'Accept': 'application/json',
        'x-access-token': token,
      },
    ).timeout(timeout);
  }

  /// Enregistre un token FCM pour l'utilisateur connecté
  static Future<http.Response> registerFCMToken({
    required String token,
    required String fcmToken,
    String? deviceType,
  }) {
    return http.post(
      Uri.parse('$baseUrl/api/notifications/token'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'x-access-token': token,
      },
      body: jsonEncode({
        'token': fcmToken,
        if (deviceType != null) 'device_type': deviceType,
      }),
    ).timeout(timeout);
  }

  /// Supprime un token FCM
  static Future<http.Response> removeFCMToken({
    required String token,
    required String fcmToken,
  }) {
    return http.delete(
      Uri.parse('$baseUrl/api/notifications/token'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'x-access-token': token,
      },
      body: jsonEncode({
        'token': fcmToken,
      }),
    ).timeout(timeout);
  }

  /// Envoie une notification à tous les utilisateurs ayant les événements spécifiés en favoris
  static Future<http.Response> sendNotificationToEventFavorites({
    required String token,
    required String title,
    required String body,
    required List<int> eventIds,
    Map<String, dynamic>? data,
  }) {
    return http.post(
      Uri.parse('$baseUrl/api/notifications/events'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'x-access-token': token,
      },
      body: jsonEncode({
        'eventIds': eventIds,
        'title': title,
        'body': body,
        if (data != null) 'data': data,
      }),
    ).timeout(timeout);
  }

  /// Récupère toutes les notifications créées
  static Future<http.Response> getNotifications({
    required String token,
  }) {
    return http.get(
      Uri.parse('$baseUrl/api/notifications'),
      headers: {
        'Accept': 'application/json',
        'x-access-token': token,
      },
    ).timeout(timeout);
  }

  /// Crée une notification sans l'envoyer
  static Future<http.Response> createNotification({
    required String token,
    required String title,
    required String body,
    required List<int> eventIds,
  }) {
    return http.post(
      Uri.parse('$baseUrl/api/notifications'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'x-access-token': token,
      },
      body: jsonEncode({
        'title': title,
        'body': body,
        'eventIds': eventIds,
      }),
    ).timeout(timeout);
  }

  /// Met à jour une notification existante
  static Future<http.Response> updateNotification({
    required String token,
    required int notificationId,
    required String title,
    required String body,
    required List<int> eventIds,
  }) {
    return http.put(
      Uri.parse('$baseUrl/api/notifications/$notificationId'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'x-access-token': token,
      },
      body: jsonEncode({
        'title': title,
        'body': body,
        'eventIds': eventIds,
      }),
    ).timeout(timeout);
  }

  /// Envoie une notification existante par son ID
  static Future<http.Response> sendNotificationById({
    required String token,
    required int notificationId,
  }) {
    return http.post(
      Uri.parse('$baseUrl/api/notifications/$notificationId/send'),
      headers: {
        'Accept': 'application/json',
        'x-access-token': token,
      },
    ).timeout(timeout);
  }

  /// Supprime une notification
  static Future<http.Response> deleteNotification({
    required String token,
    required int notificationId,
  }) {
    return http.delete(
      Uri.parse('$baseUrl/api/notifications/$notificationId'),
      headers: {
        'Accept': 'application/json',
        'x-access-token': token,
      },
    ).timeout(timeout);
  }

  /// Récupère les notifications reçues par l'utilisateur connecté
  static Future<http.Response> getReceivedNotifications({
    required String token,
  }) {
    return http.get(
      Uri.parse('$baseUrl/api/notifications/received'),
      headers: {
        'Accept': 'application/json',
        'x-access-token': token,
      },
    ).timeout(timeout);
  }

  /// Marque une notification comme lue
  static Future<http.Response> markNotificationAsRead({
    required String token,
    required int userNotificationId,
  }) {
    return http.put(
      Uri.parse('$baseUrl/api/notifications/received/$userNotificationId/read'),
      headers: {
        'Accept': 'application/json',
        'x-access-token': token,
      },
    ).timeout(timeout);
  }

  /// Marque toutes les notifications comme lues
  static Future<http.Response> markAllNotificationsAsRead({
    required String token,
  }) {
    return http.put(
      Uri.parse('$baseUrl/api/notifications/received/read-all'),
      headers: {
        'Accept': 'application/json',
        'x-access-token': token,
      },
    ).timeout(timeout);
  }

  /// Masque une notification de l'affichage
  static Future<http.Response> hideNotification({
    required String token,
    required int userNotificationId,
  }) {
    return http.put(
      Uri.parse('$baseUrl/api/notifications/received/$userNotificationId/hide'),
      headers: {
        'Accept': 'application/json',
        'x-access-token': token,
      },
    ).timeout(timeout);
  }

  /// Upload une image d'événement sur le serveur
  /// Retourne l'URL de l'image uploadée
  static Future<http.Response> uploadEventImage({
    required String token,
    required File imageFile,
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/upload/image'),
    );

    request.headers['x-access-token'] = token;
    request.headers['Accept'] = 'application/json';

    // Ajouter le fichier image
    // Vérifier que le fichier existe
    if (!await imageFile.exists()) {
      throw Exception('Le fichier image n\'existe pas: ${imageFile.path}');
    }
    
    var multipartFile = await http.MultipartFile.fromPath(
      'image',
      imageFile.path,
    );
    request.files.add(multipartFile);
    
    print(' Upload image - Fichier: ${imageFile.path}');
    print(' Upload image - Taille: ${await imageFile.length()} bytes');

    // Envoyer la requête
    var streamedResponse = await request.send().timeout(timeout);
    var response = await http.Response.fromStream(streamedResponse);
    return response;
  }

  /// Upload une photo de profil sur le serveur
  /// Nécessite un token d'authentification et le rôle organisateur
  static Future<http.Response> uploadProfileImage({
    required String token,
    required File imageFile,
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/upload/profile'),
    );

    request.headers['x-access-token'] = token;
    request.headers['Accept'] = 'application/json';

    // Ajouter le fichier image
    // Vérifier que le fichier existe
    if (!await imageFile.exists()) {
      throw Exception('Le fichier image n\'existe pas: ${imageFile.path}');
    }
    
    var multipartFile = await http.MultipartFile.fromPath(
      'image',
      imageFile.path,
    );
    request.files.add(multipartFile);
    
    print(' Upload photo de profil - Fichier: ${imageFile.path}');
    print(' Upload photo de profil - Taille: ${await imageFile.length()} bytes');

    // Envoyer la requête avec un timeout plus long pour les uploads
    var streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        throw TimeoutException('Timeout lors de l\'upload de la photo de profil');
      },
    );
    var response = await http.Response.fromStream(streamedResponse);
    return response;
  }

  /// Met à jour le profil de l'utilisateur connecté (photo de profil)
  /// Nécessite un token d'authentification
  static Future<http.Response> updateProfile({
    required String token,
    String? profilePicture,
  }) async {
    final body = <String, dynamic>{};
    if (profilePicture != null) {
      body['profile_picture'] = profilePicture;
    }

    return await http
        .put(
          Uri.parse('$baseUrl/api/users/profile'),
          headers: {
            'Content-Type': 'application/json',
            'x-access-token': token,
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
  }
}