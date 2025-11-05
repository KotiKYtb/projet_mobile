import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // ============================================================================
  // CONFIGURATION DE L'URL DE L'API
  // ============================================================================
  // IMPORTANT: Modifiez cette URL selon votre environnement :
  //
  // 1. Pour un ÉMULATEUR Android : utilisez 'http://10.0.2.2:8080'
  // 2. Pour un APPAREIL PHYSIQUE Android/iPhone : utilisez l'IP locale de votre PC
  //    - Exemple: 'http://192.168.1.113:8080'
  //    - Pour trouver votre IP : 
  //      Windows: ipconfig dans CMD
  //      Mac/Linux: ifconfig dans Terminal
  // 3. Assurez-vous que l'API est démarrée et accessible depuis votre PC
  // ============================================================================
  
  // Pour émulateur Android :
  // static const String baseUrl = 'http://10.0.2.2:8080';
  
  // Pour appareil physique (remplacez par votre IP locale) :
  // Essayez d'abord avec l'IP de votre réseau Wi-Fi (pas le hotspot):
  static const String baseUrl = 'http://172.16.80.137:8080';
  
  // Getter pour accéder à baseUrl depuis l'extérieur
  static String get apiBaseUrl => baseUrl;
  
  // Timeout pour les requêtes HTTP (en secondes)
  static const Duration timeout = Duration(seconds: 10);
  
  // Méthode helper pour tester la connexion à l'API
  static Future<bool> testConnection() async {
    try {
      print('🔍 Test de connexion à: $baseUrl');
      final response = await http
          .get(Uri.parse('$baseUrl/'))
          .timeout(timeout);
      
      print('✅ Réponse reçue: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('✅ Connexion réussie!');
        return true;
      } else {
        print('⚠️ Réponse inattendue: ${response.statusCode}');
        return false;
      }
    } on TimeoutException catch (e) {
      print('❌ TIMEOUT: Impossible de se connecter à $baseUrl');
      print('💡 Causes possibles:');
      print('   1. L\'API n\'est pas démarrée ou n\'écoute pas sur le port 8080');
      print('   2. L\'IP est incorrecte (actuellement: $baseUrl)');
      print('   3. Vous utilisez un ÉMULATEUR -> Essayez http://10.0.2.2:8080');
      print('   4. Le FIREWALL Windows bloque la connexion');
      print('   5. Le PC et le téléphone ne sont pas sur le même réseau');
      print('');
      print('📝 Solutions:');
      print('   • Testez dans le navigateur de votre TÉLÉPHONE: $baseUrl');
      print('   • Si ça fonctionne dans le navigateur, le problème vient de l\'app');
      print('   • Si ça ne fonctionne pas, vérifiez l\'IP et le firewall');
      return false;
    } catch (e) {
      print('❌ Erreur de connexion à l\'API: $e');
      print('💡 Vérifiez que:');
      print('   1. L\'API est démarrée sur le port 8080');
      print('   2. L\'URL est correcte dans api_client.dart');
      print('   3. Vous êtes sur le même réseau Wi-Fi (appareil physique)');
      print('   4. Le firewall ne bloque pas la connexion');
      print('   URL testée: $baseUrl');
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
}