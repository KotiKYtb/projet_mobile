import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

/// Gestionnaire de stockage sécurisé pour les tokens JWT et données de session
class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _key = 'token';
  static const _rolesKey = 'roles';
  static const _userDataKey = 'user_data';

  static Future<void> save(String token) => _storage.write(key: _key, value: token);
  static Future<String?> read() => _storage.read(key: _key);
  static Future<void> clear() => _storage.delete(key: _key);

  /// Vérifie si un token JWT est valide en décodant le payload et vérifiant l'expiration
  static bool isTokenValid(String? token) {
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return false;
      }

      final payload = parts[1];
      
      /// Base64URL nécessite un padding pour être décodé correctement
      /// Le padding doit être un multiple de 4 caractères
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

      /// Conversion de Base64URL vers Base64 standard
      /// Base64URL utilise - et _ au lieu de + et /
      normalizedPayload = normalizedPayload.replaceAll('-', '+').replaceAll('_', '/');

      final decodedBytes = base64Decode(normalizedPayload);
      final decodedString = utf8.decode(decodedBytes);
      final payloadMap = jsonDecode(decodedString) as Map<String, dynamic>;

      /// Le champ 'exp' contient le timestamp Unix (en secondes) de l'expiration
      final exp = payloadMap['exp'] as int?;
      if (exp == null) {
        return false;
      }

      /// Comparaison avec l'heure actuelle (convertie en secondes)
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final isValid = exp > now;

      if (!isValid) {
        print(' Token expiré. Exp: $exp, Now: $now');
      }

      return isValid;
    } catch (e) {
      print(' Erreur lors de la vérification du token: $e');
      return false;
    }
  }

  static bool isRefreshTokenValid(String? refreshToken) {
    return isTokenValid(refreshToken);
  }

  static Future<void> saveRoles(List<String> roles) =>
      _storage.write(key: _rolesKey, value: roles.join(','));
  static Future<List<String>> readRoles() async {
    final v = await _storage.read(key: _rolesKey);
    if (v == null || v.isEmpty) return <String>[];
    return v.split(',');
  }
  static Future<void> clearRoles() => _storage.delete(key: _rolesKey);

  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _storage.write(key: _userDataKey, value: jsonEncode(userData));
  }

  static Future<Map<String, dynamic>?> readUserData() async {
    final data = await _storage.read(key: _userDataKey);
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<void> clearUserData() async {
    await _storage.delete(key: _userDataKey);
  }

  static const _refreshTokenKey = 'refresh_token';
  
  static Future<void> saveRefreshToken(String refreshToken) async {
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }
  
  static Future<String?> readRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }
  
  static Future<void> clearRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
  }

  static const _sessionValidKey = 'session_valid';

  static Future<void> setSessionValid(bool valid) async {
    await _storage.write(key: _sessionValidKey, value: valid.toString());
  }

  static Future<bool> isSessionValid() async {
    final value = await _storage.read(key: _sessionValidKey);
    return value == 'true';
  }

  /// Supprime complètement tous les tokens et données de session
  /// Utilisé lors de la déconnexion pour garantir un nettoyage complet
  /// et éviter que des données sensibles restent en mémoire
  static Future<void> clearAll() async {
    print('🧹 Suppression complète de tous les tokens et données de session...');
    
    await clear();
    print('   Token principal supprimé');
    
    await clearRoles();
    print('   Rôles supprimés');
    
    await clearUserData();
    print('   Données utilisateur supprimées');
    
    await clearRefreshToken();
    print('   Refresh token supprimé');
    
    await _storage.delete(key: _sessionValidKey);
    print('   Session supprimée');
    
    print(' Tous les tokens et données de session ont été supprimés');
  }

  static const _cachedNotificationsKey = 'cached_notifications';

  static Future<void> saveCachedNotifications(String jsonStr) async {
    await _storage.write(key: _cachedNotificationsKey, value: jsonStr);
  }

  static Future<String?> readCachedNotifications() async {
    return await _storage.read(key: _cachedNotificationsKey);
  }

  static Future<void> clearCachedNotifications() async {
    await _storage.delete(key: _cachedNotificationsKey);
  }
}