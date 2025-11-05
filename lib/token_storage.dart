import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _key = 'token';
  static const _rolesKey = 'roles';
  static const _userDataKey = 'user_data';

  static Future<void> save(String token) => _storage.write(key: _key, value: token);
  static Future<String?> read() => _storage.read(key: _key);
  static Future<void> clear() => _storage.delete(key: _key);

  /// Vérifie si un token JWT est expiré localement (sans appel API)
  /// Retourne true si le token est valide, false s'il est expiré ou invalide
  static bool isTokenValid(String? token) {
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      // Un JWT a 3 parties séparées par des points : header.payload.signature
      final parts = token.split('.');
      if (parts.length != 3) {
        return false; // Format invalide
      }

      // Décoder le payload (partie 2)
      final payload = parts[1];
      
      // Ajouter le padding si nécessaire (base64url peut ne pas avoir de padding)
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

      // Remplacer les caractères base64url par base64 standard
      normalizedPayload = normalizedPayload.replaceAll('-', '+').replaceAll('_', '/');

      // Décoder base64
      final decodedBytes = base64Decode(normalizedPayload);
      final decodedString = utf8.decode(decodedBytes);
      final payloadMap = jsonDecode(decodedString) as Map<String, dynamic>;

      // Vérifier l'expiration (exp est un timestamp Unix en secondes)
      final exp = payloadMap['exp'] as int?;
      if (exp == null) {
        return false; // Pas de champ exp, considérer comme invalide
      }

      // Comparer avec l'heure actuelle
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000; // Convertir en secondes
      final isValid = exp > now;

      if (!isValid) {
        print('⚠️ Token expiré. Exp: $exp, Now: $now');
      }

      return isValid;
    } catch (e) {
      print('❌ Erreur lors de la vérification du token: $e');
      return false; // En cas d'erreur, considérer comme invalide
    }
  }

  /// Vérifie si le refresh token est expiré localement
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

  // Refresh token
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

  // Session valide
  static const _sessionValidKey = 'session_valid';

  static Future<void> setSessionValid(bool valid) async {
    await _storage.write(key: _sessionValidKey, value: valid.toString());
  }

  static Future<bool> isSessionValid() async {
    final value = await _storage.read(key: _sessionValidKey);
    return value == 'true';
  }

  // Déconnexion complète - supprime TOUS les tokens et données de session
  static Future<void> clearAll() async {
    print('🧹 Suppression complète de tous les tokens et données de session...');
    
    // Supprimer le token principal
    await clear();
    print('  ✅ Token principal supprimé');
    
    // Supprimer les rôles
    await clearRoles();
    print('  ✅ Rôles supprimés');
    
    // Supprimer les données utilisateur
    await clearUserData();
    print('  ✅ Données utilisateur supprimées');
    
    // Supprimer le refresh token
    await clearRefreshToken();
    print('  ✅ Refresh token supprimé');
    
    // Supprimer complètement la clé de session (pas juste la mettre à false)
    await _storage.delete(key: _sessionValidKey);
    print('  ✅ Session supprimée');
    
    print('✅ Tous les tokens et données de session ont été supprimés');
  }
}