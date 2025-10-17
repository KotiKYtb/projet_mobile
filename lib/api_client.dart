import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // Emulateur Android: 10.0.2.2
  static const String baseUrl = 'http://172.16.80.125:8080';

  static Future<http.Response> signup({
    required String username,
    required String email,
    required String password,
    List<String>? roles,
  }) {
    return http.post(
      Uri.parse('$baseUrl/api/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        if (roles != null) 'roles': roles,
      }),
    );
  }

  static Future<http.Response> signin({
    required String username,
    required String password,
  }) {
    return http.post(
      Uri.parse('$baseUrl/api/auth/signin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
  }

  static Future<http.Response> getUser({required String token}) {
    return http.get(
      Uri.parse('$baseUrl/api/test/user'),
      headers: {'x-access-token': token},
    );
  }

  static Future<http.Response> getModerator({required String token}) {
    return http.get(
      Uri.parse('$baseUrl/api/test/mod'),
      headers: {'x-access-token': token},
    );
  }

  static Future<http.Response> getAdmin({required String token}) {
    return http.get(
      Uri.parse('$baseUrl/api/test/admin'),
      headers: {'x-access-token': token},
    );
  }

  static Future<http.Response> getDebugUsers() {
    return http.get(Uri.parse('$baseUrl/api/debug/users'));
  }
}