import 'package:flutter/material.dart';
import '../token_storage.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';
import '../api_client.dart';
import 'dart:convert';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(seconds: 2)); // Splash screen
    
    try {
      // Vérifier la connectivité
      final isOnline = await ConnectivityService.checkConnectivity();
      
      if (isOnline) {
        // Mode online - vérifier la session normale
        await _checkOnlineSession();
      } else {
        // Mode offline - vérifier le cache local
        await _checkOfflineSession();
      }
    } catch (e) {
      // Erreur, essayer le mode offline
      await _checkOfflineSession();
    }
  }

  Future<void> _checkOnlineSession() async {
    final token = await TokenStorage.read();
    final refreshToken = await TokenStorage.readRefreshToken();
    
    if (token != null && refreshToken != null) {
      // Vérifier d'abord localement si le token est valide (sans appel API)
      final isTokenValidLocally = TokenStorage.isTokenValid(token);
      
      if (isTokenValidLocally) {
        // Token valide localement, continuer la session
        print('✅ Token valide localement, connexion automatique');
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/main');
        return;
      } else {
        // Token expiré localement, vérifier si le refresh token est encore valide
        final isRefreshTokenValid = TokenStorage.isRefreshTokenValid(refreshToken);
        
        if (isRefreshTokenValid) {
          // Refresh token valide, essayer de rafraîchir le token
          print('🔄 Token expiré mais refresh token valide, tentative de rafraîchissement...');
          final newToken = await _refreshToken(refreshToken);
          if (newToken != null) {
            await TokenStorage.save(newToken);
            print('✅ Token rafraîchi avec succès');
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/main');
            return;
          } else {
            print('❌ Échec du rafraîchissement du token');
          }
        } else {
          print('❌ Token et refresh token expirés, connexion requise');
        }
      }
    }
    
    // Pas de session valide, aller au login
    // Nettoyer les tokens expirés
    if (token != null && !TokenStorage.isTokenValid(token)) {
      print('🧹 Nettoyage des tokens expirés');
      await TokenStorage.clearAll();
    }
    
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _checkOfflineSession() async {
    // Vérifier s'il y a un utilisateur en cache local
    final currentUser = await SyncService.getCurrentUser();
    if (currentUser != null) {
      // Utilisateur trouvé en cache, aller à la page principale
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/main');
      return;
    }
    
    // Pas d'utilisateur en cache, aller au login
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<String?> _refreshToken(String refreshToken) async {
    try {
      final response = await ApiClient.refreshToken(refreshToken: refreshToken);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['accessToken'] as String?;
      }
    } catch (e) {
      print('Erreur refresh token: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade300,
              Colors.grey.shade400,
              Colors.grey.shade500,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo animé avec effet de pulsation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeInOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                            offset: const Offset(5, 5),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.8),
                            blurRadius: 20,
                            spreadRadius: 5,
                            offset: const Offset(-5, -5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.location_city,
                          size: 70,
                          color: const Color.fromARGB(255, 130, 110, 100),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              
              // Nom de l'application avec animation fade-in
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeIn,
                builder: (context, opacity, child) {
                  return Opacity(
                    opacity: opacity,
                    child: const Text(
                      'Angers',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 2,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeIn,
                builder: (context, opacity, child) {
                  return Opacity(
                    opacity: opacity,
                    child: Text(
                      'Mobile App',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                        color: Colors.grey.shade700,
                        letterSpacing: 3,
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 60),
              
              // Indicateur de chargement avec animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeIn,
                builder: (context, opacity, child) {
                  return Opacity(
                    opacity: opacity,
                    child: Column(
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color.fromARGB(255, 130, 110, 100),
                          ),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Vérification de la session...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

