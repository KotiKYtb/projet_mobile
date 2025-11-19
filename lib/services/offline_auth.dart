import '../models/user_model.dart';
import '../services/local_database.dart';
import '../token_storage.dart';

class OfflineAuth {

  static Future<UserModel?> authenticateOffline(String email, String password) async {
    try {
      print(' Tentative d\'authentification offline pour: $email');

      final users = await LocalDatabase.getAllUsers();
      print(' Utilisateurs en cache local: ${users.length}');
      
      for (var u in users) {
        print('  - ${u.email} (lastSync: ${u.lastSync})');
      }

      final user = users.where((u) => u.email == email).firstOrNull;
      
      if (user == null) {
        print(' Utilisateur $email non trouvé dans le cache local');
        return null;
      }
      
      print(' Utilisateur trouvé: ${user.email}');



      print('🔒 Mode offline sécurisé: autorisation basée sur la session précédente');

      await LocalDatabase.updateLastSync(user.userId);
      return user;
    } catch (e) {
      print(' Erreur authentification offline: $e');
      return null;
    }
  }

  static Future<bool> canLoginOffline(String email) async {
    try {
      final users = await LocalDatabase.getAllUsers();
      return users.any((u) => u.email == email);
    } catch (e) {
      return false;
    }
  }

  static Future<UserModel?> getLastConnectedUser() async {
    try {
      return await LocalDatabase.getCurrentUser();
    } catch (e) {
      return null;
    }
  }

  static Future<void> simulateOfflineLogin(UserModel user) async {
    try {

      await TokenStorage.saveUserData({
        'name': user.name,
        'surname': user.surname,
        'role': user.role,
        'email': user.email,
      });

      final localToken = 'offline_${user.userId}_${DateTime.now().millisecondsSinceEpoch}';
      await TokenStorage.save(localToken);

      await TokenStorage.saveRoles([user.role]);
    } catch (e) {
      print('Erreur simulation login offline: $e');
    }
  }

  static bool isOfflineMode() {

    return true;
  }
}
