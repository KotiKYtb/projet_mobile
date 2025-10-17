import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _key = 'token';
  static const _rolesKey = 'roles';

  static Future<void> save(String token) => _storage.write(key: _key, value: token);
  static Future<String?> read() => _storage.read(key: _key);
  static Future<void> clear() => _storage.delete(key: _key);

  static Future<void> saveRoles(List<String> roles) =>
      _storage.write(key: _rolesKey, value: roles.join(','));
  static Future<List<String>> readRoles() async {
    final v = await _storage.read(key: _rolesKey);
    if (v == null || v.isEmpty) return <String>[];
    return v.split(',');
  }
  static Future<void> clearRoles() => _storage.delete(key: _rolesKey);
}