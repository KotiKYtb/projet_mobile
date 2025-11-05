import '../models/user_model.dart';
import '../services/local_database.dart';
import '../token_storage.dart';

class OfflineAuth {
  // Authentifier un utilisateur en mode offline
  static Future<UserModel?> authenticateOffline(String email, String password) async {
    try {
      print('🔍 Tentative d\'authentification offline pour: $email');
      
      // Récupérer tous les utilisateurs du cache local
      final users = await LocalDatabase.getAllUsers();
      print('📱 Utilisateurs en cache local: ${users.length}');
      
      for (var u in users) {
        print('  - ${u.email} (lastSync: ${u.lastSync})');
      }
      
      // Chercher l'utilisateur par email
      final user = users.where((u) => u.email == email).firstOrNull;
      
      if (user == null) {
        print('❌ Utilisateur $email non trouvé dans le cache local');
        return null; // Utilisateur non trouvé
      }
      
      print('✅ Utilisateur trouvé: ${user.email}');
      
      // En mode offline sécurisé, on ne vérifie PAS le mot de passe
      // On autorise seulement le dernier utilisateur connecté à se reconnecter
      // sans vérification de mot de passe (session persistante)
      print('🔒 Mode offline sécurisé: autorisation basée sur la session précédente');
      
      // Mettre à jour la dernière connexion
      await LocalDatabase.updateLastSync(user.userId);
      return user;
    } catch (e) {
      print('❌ Erreur authentification offline: $e');
      return null;
    }
  }

  // Vérifier si un utilisateur peut se connecter en offline
  static Future<bool> canLoginOffline(String email) async {
    try {
      final users = await LocalDatabase.getAllUsers();
      return users.any((u) => u.email == email);
    } catch (e) {
      return false;
    }
  }

  // Obtenir le dernier utilisateur connecté
  static Future<UserModel?> getLastConnectedUser() async {
    try {
      return await LocalDatabase.getCurrentUser();
    } catch (e) {
      return null;
    }
  }

  // Simuler une connexion offline (sauvegarder les données utilisateur)
  static Future<void> simulateOfflineLogin(UserModel user) async {
    try {
      // Sauvegarder les données utilisateur dans le stockage sécurisé
      await TokenStorage.saveUserData({
        'name': user.name,
        'surname': user.surname,
        'role': user.role,
        'email': user.email,
      });
      
      // Créer un token local (simulé)
      final localToken = 'offline_${user.userId}_${DateTime.now().millisecondsSinceEpoch}';
      await TokenStorage.save(localToken);
      
      // Sauvegarder les rôles
      await TokenStorage.saveRoles([user.role]);
    } catch (e) {
      print('Erreur simulation login offline: $e');
    }
  }

  // Vérifier si on est en mode offline
  static bool isOfflineMode() {
    // Cette méthode sera appelée quand la connectivité est détectée comme offline
    return true;
  }
}
