import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'token_storage.dart';
import 'bottom_nav.dart';
import 'services/sync_service.dart';
import 'services/connectivity_service.dart';
import 'services/offline_auth.dart';
import 'services/local_database.dart';
import 'models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConnectivityService.initialize();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JWT Auth',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashPage(),
        '/register': (_) => const RegisterPage(),
        '/login': (_) => const LoginPage(),
        '/main': (_) => const MainPage(),
        '/debug': (_) => const DebugPage(),
      },
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
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

  Future<bool> _validateToken(String token) async {
    try {
      final response = await ApiClient.getUser(token: token);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.apps, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'Angers Mobile App',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text('Vérification de la session...'),
          ],
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}
class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final surnameCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();
  bool loading = false;
  String? error;
  bool isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    ConnectivityService.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _setupConnectivityListener() {
    ConnectivityService.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged(bool online) {
    if (mounted) {
      setState(() {
        isOnline = online;
      });
      
      // Afficher un message de changement de connectivité
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                online ? Icons.wifi : Icons.wifi_off,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(online ? 'Connexion rétablie' : 'Mode hors ligne'),
            ],
          ),
          backgroundColor: online ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _checkConnectivity() async {
    final online = await ConnectivityService.checkConnectivity();
    setState(() {
      isOnline = online;
    });
  }

  Future<void> _submit() async {
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inscription impossible en mode hors ligne'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (!_form.currentState!.validate()) return;
    
    setState(() { loading = true; error = null; });
    
    try {
      // Tester d'abord la connexion à l'API
      print('🔍 Test de connexion à l\'API...');
      final canConnect = await ApiClient.testConnection();
      if (!canConnect) {
        setState(() { 
          loading = false; 
          error = 'Impossible de se connecter à l\'API.\n\n'
                  'Vérifiez que:\n'
                  '• L\'API est démarrée (npm start dans le dossier API)\n'
                  '• L\'URL est correcte dans api_client.dart\n'
                  '• Vous êtes sur le même réseau Wi-Fi\n'
                  '• Le firewall n\'bloque pas le port 8080\n\n'
                  'URL actuelle: ${ApiClient.apiBaseUrl}';
        });
        return;
      }
      
      print('✅ Connexion à l\'API réussie, tentative d\'inscription...');
      final http.Response resp = await ApiClient.signup(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
        name: nameCtrl.text.trim(),
        surname: surnameCtrl.text.trim(),
      );
      
      setState(() { loading = false; });
      
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inscription réussie, connectez-vous.')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        final errorBody = resp.body;
        setState(() { 
          error = 'Erreur ${resp.statusCode}: ${errorBody.isNotEmpty ? errorBody : 'Erreur inconnue'}';
        });
      }
    } on TimeoutException catch (e) {
      setState(() { 
        loading = false; 
        error = 'Timeout: Impossible de se connecter à l\'API.\n\n'
                'Le serveur n\'a pas répondu dans les délais.\n\n'
                'Vérifiez que:\n'
                '• L\'API est démarrée: cd API && npm start\n'
                '• L\'API écoute sur le port 8080\n'
                '• L\'URL est correcte: ${ApiClient.apiBaseUrl}\n'
                '• Votre appareil peut accéder à cette adresse\n\n'
                'Si vous utilisez un émulateur, essayez: http://10.0.2.2:8080';
      });
      print('❌ Timeout lors de l\'inscription: $e');
    } catch (e) {
      setState(() { 
        loading = false; 
        error = 'Erreur d\'inscription: $e\n\n'
                'URL utilisée: ${ApiClient.apiBaseUrl}\n\n'
                'Assurez-vous que l\'API est démarrée.';
      });
      print('❌ Erreur d\'inscription: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        actions: [
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            color: isOnline ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: ListView(
            children: [
              // Indicateur de mode
              Card(
                color: isOnline ? Colors.green.shade50 : Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        isOnline ? Icons.wifi : Icons.wifi_off,
                        color: isOnline ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOnline ? 'Mode en ligne' : 'Mode hors ligne',
                        style: TextStyle(
                          color: isOnline ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Message pour mode offline
              if (!isOnline)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.block, color: Colors.red),
                            const SizedBox(width: 8),
                            const Text(
                              'Inscription désactivée',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'L\'inscription n\'est pas disponible en mode hors ligne. Veuillez vous connecter à internet pour créer un compte.',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Prénom',
                  suffixIcon: !isOnline ? const Icon(Icons.block, color: Colors.red) : null,
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                enabled: isOnline,
              ),
              TextFormField(
                controller: surnameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nom',
                  suffixIcon: !isOnline ? const Icon(Icons.block, color: Colors.red) : null,
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                enabled: isOnline,
              ),
              TextFormField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Email',
                  suffixIcon: !isOnline ? const Icon(Icons.block, color: Colors.red) : null,
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                keyboardType: TextInputType.emailAddress,
                enabled: isOnline,
              ),
              TextFormField(
                controller: passCtrl,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: !isOnline ? const Icon(Icons.block, color: Colors.red) : null,
                ),
                validator: (v) => (v == null || v.length < 6) ? 'Min 6 chars' : null,
                obscureText: true,
                enabled: isOnline,
              ),
              TextFormField(
                controller: confirmPassCtrl,
                decoration: InputDecoration(
                  labelText: 'Confirmer Password',
                  suffixIcon: !isOnline ? const Icon(Icons.block, color: Colors.red) : null,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requis';
                  if (v != passCtrl.text) return 'Les mots de passe ne correspondent pas';
                  return null;
                },
                obscureText: true,
                enabled: isOnline,
              ),
              const SizedBox(height: 12),
              if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: (loading || !isOnline) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: !isOnline ? Colors.grey : null,
                ),
                child: loading 
                    ? const CircularProgressIndicator() 
                    : !isOnline 
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.block, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Inscription désactivée'),
                            ],
                          )
                        : const Text('Register'),
              ),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Déjà un compte ? Login'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  String? error;
  bool isOnline = true;
  UserModel? lastUser;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadLastUser();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    ConnectivityService.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _setupConnectivityListener() {
    ConnectivityService.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged(bool online) {
    if (mounted) {
      setState(() {
        isOnline = online;
      });
      
      // Afficher un message de changement de connectivité
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                online ? Icons.wifi : Icons.wifi_off,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(online ? 'Connexion rétablie' : 'Mode hors ligne'),
            ],
          ),
          backgroundColor: online ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _checkConnectivity() async {
    final online = await ConnectivityService.checkConnectivity();
    setState(() {
      isOnline = online;
    });
  }

  Future<void> _loadLastUser() async {
    try {
      // Vérifier d'abord si la session est valide
      final sessionValid = await TokenStorage.isSessionValid();
      if (!sessionValid) {
        print('❌ Session non valide, pas de dernier utilisateur');
        return;
      }
      
      final user = await OfflineAuth.getLastConnectedUser();
      setState(() {
        lastUser = user;
        if (user != null) {
          emailCtrl.text = user.email;
          print('✅ Dernier utilisateur chargé: ${user.email}');
        }
      });
    } catch (e) {
      print('Erreur chargement dernier utilisateur: $e');
    }
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() { loading = true; error = null; });
    
    if (isOnline) {
      await _loginOnline();
    } else {
      await _loginOffline();
    }
  }

  Future<void> _loginOnline() async {
    try {
      // Tester d'abord la connexion à l'API
      print('🔍 Test de connexion à l\'API...');
      final canConnect = await ApiClient.testConnection();
      if (!canConnect) {
        setState(() { 
          loading = false; 
          error = 'Impossible de se connecter à l\'API.\n\n'
                  'Vérifiez que:\n'
                  '• L\'API est démarrée (npm start dans le dossier API)\n'
                  '• L\'URL est correcte dans api_client.dart\n'
                  '• Vous êtes sur le même réseau Wi-Fi\n'
                  '• Le firewall n\'bloque pas le port 8080\n\n'
                  'URL actuelle: ${ApiClient.apiBaseUrl}';
        });
        return;
      }
      
      print('✅ Connexion à l\'API réussie, tentative de login...');
      final resp = await ApiClient.signin(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
      );
      setState(() { loading = false; });
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final token = data['accessToken'] as String?;
        if (token == null) { setState(() => error = 'Token manquant'); return; }
        await TokenStorage.save(token);
        
        // Sauvegarder le refresh token
        final refreshToken = data['refreshToken'] as String?;
        if (refreshToken != null) {
          await TokenStorage.saveRefreshToken(refreshToken);
        }
        
        final roles = (data['roles'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList();
        await TokenStorage.saveRoles(roles);
        
        // Stocker les données utilisateur
        final email = data['email'] ?? emailCtrl.text.trim();
        await TokenStorage.saveUserData({
          'name': data['name'] ?? email.split('@')[0],
          'surname': data['surname'] ?? '',
          'role': data['role'] ?? 'user',
          'email': email,
        });
        
        // Marquer la session comme valide
        await TokenStorage.setSessionValid(true);
        
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        final errorBody = resp.body;
        setState(() { 
          error = 'Erreur ${resp.statusCode}: ${errorBody.isNotEmpty ? errorBody : 'Erreur inconnue'}';
        });
      }
    } on TimeoutException catch (e) {
      setState(() { 
        loading = false; 
        error = 'Timeout: Impossible de se connecter à l\'API.\n\n'
                'Le serveur n\'a pas répondu dans les délais.\n\n'
                'Vérifiez que:\n'
                '• L\'API est démarrée: cd API && npm start\n'
                '• L\'API écoute sur le port 8080\n'
                '• L\'URL est correcte: ${ApiClient.apiBaseUrl}\n'
                '• Votre appareil peut accéder à cette adresse\n\n'
                'Si vous utilisez un émulateur, essayez: http://10.0.2.2:8080';
      });
      print('❌ Timeout lors de la connexion: $e');
    } catch (e) {
      setState(() { 
        loading = false; 
        error = 'Erreur de connexion: $e\n\n'
                'URL utilisée: ${ApiClient.apiBaseUrl}\n\n'
                'Assurez-vous que l\'API est démarrée.';
      });
      print('❌ Erreur de connexion: $e');
    }
  }

  Future<void> _loginOffline() async {
    try {
      print('🔍 Tentative de connexion offline...');
      print('📧 Email: ${emailCtrl.text.trim()}');
      
      // En mode offline, on n'a pas besoin du mot de passe
      // On vérifie seulement si l'utilisateur était connecté précédemment
      final user = await OfflineAuth.authenticateOffline(
        emailCtrl.text.trim(),
        '', // Pas de mot de passe nécessaire en mode offline
      );
      
      setState(() { loading = false; });
      
      if (user != null) {
        print('✅ Authentification offline réussie pour: ${user.email}');
        // Simuler la connexion offline
        await OfflineAuth.simulateOfflineLogin(user);
        
        // Marquer la session comme valide
        await TokenStorage.setSessionValid(true);
        
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/main');
    } else {
        print('❌ Échec de l\'authentification offline');
        setState(() { 
          error = 'Utilisateur non trouvé en mode offline. Seul le dernier utilisateur connecté peut se connecter hors ligne.';
        });
      }
    } catch (e) {
      print('❌ Erreur lors de la connexion offline: $e');
      setState(() { 
        loading = false; 
        error = 'Erreur de connexion offline: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        actions: [
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            color: isOnline ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: ListView(
            children: [
              // Indicateur de mode
              Card(
                color: isOnline ? Colors.green.shade50 : Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        isOnline ? Icons.wifi : Icons.wifi_off,
                        color: isOnline ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOnline ? 'Mode en ligne' : 'Mode hors ligne',
                        style: TextStyle(
                          color: isOnline ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Message pour mode offline
              if (!isOnline)
                Card(
                  color: lastUser != null ? Colors.blue.shade50 : Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              lastUser != null ? 'Mode hors ligne activé' : 'Mode hors ligne - Session expirée',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: lastUser != null ? Colors.blue.shade700 : Colors.red.shade700,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () async {
                                final online = await ConnectivityService.checkConnectivity();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Test: ${online ? "En ligne" : "Hors ligne"}'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              tooltip: 'Tester la connectivité',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (lastUser != null) ...[
                          Text('Seul ${lastUser!.email} peut se connecter hors ligne.'),
                          const SizedBox(height: 4),
                          const Text(
                            'En mode offline, le mot de passe n\'est pas vérifié pour des raisons de sécurité.',
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ] else ...[
                          const Text(
                            'Vous avez été déconnecté. En mode offline, vous ne pouvez plus vous reconnecter ni créer de compte.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Connectez-vous au réseau pour vous reconnecter.',
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                keyboardType: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: passCtrl,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: isOnline ? 'Mot de passe requis' : 'Pas nécessaire en mode offline',
                ),
                validator: isOnline ? (v) => (v == null || v.isEmpty) ? 'Requis' : null : null,
                obscureText: true,
                enabled: isOnline, // Désactiver en mode offline
              ),
              const SizedBox(height: 12),
              if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: (loading || (!isOnline && lastUser == null)) ? null : _login,
                child: loading ? const CircularProgressIndicator() : const Text('Login'),
              ),
              TextButton(
                onPressed: (!isOnline && lastUser == null) ? null : () => Navigator.pushReplacementNamed(context, '/register'),
                child: Text(
                  (!isOnline && lastUser == null) 
                    ? "Inscription impossible en mode offline" 
                    : "Pas de compte ? Register"
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  String userRole = 'Chargement...';
  String userName = '';
  bool loading = true;
  bool isOnline = true;
  List<UserModel> users = [];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    ConnectivityService.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _setupConnectivityListener() {
    ConnectivityService.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged(bool online) {
    if (mounted) {
      setState(() {
        isOnline = online;
      });
      
      if (online) {
        _syncData();
        // Afficher un message de reconnexion
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Connexion rétablie - Synchronisation...'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // Afficher un message de déconnexion
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Mode hors ligne - Données locales'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
      ),
    );
  }
}
  }

  Future<void> _loadUserInfo() async {
    try {
    final token = await TokenStorage.read();
      if (token == null || !TokenStorage.isTokenValid(token)) {
        setState(() {
          userRole = 'Non connecté';
          loading = false;
        });
        // Si le token est expiré, nettoyer
        if (token != null && !TokenStorage.isTokenValid(token)) {
          await TokenStorage.clearAll();
        }
        return;
      }

      // Récupérer les données depuis le cache local ou l'API
      final currentUser = await SyncService.getCurrentUser();
      if (currentUser != null) {
        setState(() {
          userRole = currentUser.role;
          userName = '${currentUser.name} ${currentUser.surname}'.trim();
          loading = false;
        });
      } else {
        // Fallback vers le stockage sécurisé
        final storedUserData = await TokenStorage.readUserData();
        if (storedUserData != null) {
          setState(() {
            userRole = storedUserData['role'] ?? 'user';
            userName = '${storedUserData['name'] ?? ''} ${storedUserData['surname'] ?? ''}'.trim();
            loading = false;
          });
        } else {
          setState(() {
            userRole = 'Données non disponibles';
            userName = 'Utilisateur';
            loading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        userRole = 'Erreur: $e';
        loading = false;
      });
    }
  }

  Future<void> _syncData() async {
    try {
      await SyncService.syncUsersFromApi();
      await _loadUsers();
    } catch (e) {
      print('Erreur de synchronisation: $e');
    }
  }

  Future<void> _loadUsers() async {
    try {
      final usersList = await SyncService.getUsers();
      setState(() {
        users = usersList;
      });
    } catch (e) {
      print('Erreur de chargement des utilisateurs: $e');
    }
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _logout() async {
    // Si on est en mode offline, afficher un popup d'avertissement
    if (!isOnline) {
      final shouldLogout = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('Attention !'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vous êtes actuellement hors ligne.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Si vous vous déconnectez maintenant, vous ne pourrez plus :',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Vous reconnecter en mode offline'),
                Text('• Créer un nouveau compte'),
                SizedBox(height: 8),
                Text(
                  'Vous devrez attendre d\'être reconnecté au réseau pour pouvoir vous reconnecter.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                SizedBox(height: 8),
                Text(
                  'Êtes-vous sûr de vouloir continuer ?',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Déconnexion'),
              ),
            ],
          );
        },
      );

      // Si l'utilisateur annule, ne pas déconnecter
      if (shouldLogout != true) {
        return;
      }
    }

    try {
      // Vider complètement le stockage sécurisé
      await TokenStorage.clearAll();
      
      // Vider le cache local
      await LocalDatabase.clearAllUsers();
      
      // Afficher un message selon le mode
      if (!isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Déconnexion effectuée. En mode offline, vous ne pourrez plus vous reconnecter ni créer de compte.'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Déconnexion effectuée avec succès.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Widget _buildContent() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return _buildUsersContent();
      case 2:
        return _buildAdminContent();
      case 3:
        return _buildOrganisationContent();
      case 4:
        return _buildProfileContent();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.home, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text('Page d\'Accueil', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (loading)
            const CircularProgressIndicator()
          else ...[
            Text('Bonjour $userName', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Votre rôle: $userRole', style: const TextStyle(fontSize: 16, color: Colors.blue)),
          ],
        ],
      ),
    );
  }

  Widget _buildUsersContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              const Text('Utilisateurs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Icon(
                    isOnline ? Icons.wifi : Icons.wifi_off,
                    color: isOnline ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                  Text(isOnline ? 'En ligne' : 'Hors ligne', 
                    style: TextStyle(color: isOnline ? Colors.green : Colors.red)),
                ],
                ),
              ],
            ),
          const SizedBox(height: 16),
            Expanded(
            child: users.isEmpty
                ? const Center(child: Text('Aucun utilisateur'))
                : ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                      final user = users[index];
                      return Card(
                        child: ListTile(
                          title: Text('${user.name} ${user.surname}'),
                          subtitle: Text('${user.email} - ${user.role}'),
                          trailing: user.lastSync != null
                              ? Text('Sync: ${user.lastSync!.hour}:${user.lastSync!.minute.toString().padLeft(2, '0')}')
                              : const Text('Non sync'),
                        ),
                  );
                },
              ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.admin_panel_settings, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text('Page Administration', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Text('Gestion des utilisateurs et rôles', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildOrganisationContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business, size: 64, color: Colors.orange),
          SizedBox(height: 16),
          Text('Page Organisation', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Text('Gestion des organisations', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person, size: 64, color: Colors.purple),
          const SizedBox(height: 16),
          const Text('Profil Utilisateur', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (loading)
            const CircularProgressIndicator()
          else ...[
            Text('Nom: $userName', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Rôle: $userRole', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: !isOnline ? Colors.orange : null,
                foregroundColor: !isOnline ? Colors.white : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isOnline) ...[
                    const Icon(Icons.warning, size: 16),
                    const SizedBox(width: 4),
                  ],
                  const Text('Se déconnecter'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        actions: [
          // Indicateur de connectivité
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            color: isOnline ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          // Bouton debug
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/debug'),
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug - Base de données',
          ),
          if (_currentIndex == 4) // Seulement sur la page profil
            IconButton(
              onPressed: _logout,
              icon: Icon(
                Icons.logout,
                color: !isOnline ? Colors.orange : null,
              ),
              tooltip: !isOnline ? 'Déconnexion (Attention: mode offline)' : 'Se déconnecter',
            ),
        ],
      ),
      body: _buildContent(),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Accueil';
      case 1:
        return 'Utilisateurs';
      case 2:
        return 'Administration';
      case 3:
        return 'Organisation';
      case 4:
        return 'Profil';
      default:
        return 'App';
    }
  }
}

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});
  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  bool isOnline = true;
  List<UserModel> users = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _setupConnectivityListener();
    // Délai pour s'assurer que la connectivité est bien détectée
    Future.delayed(const Duration(milliseconds: 100), () {
      _loadData();
    });
  }

  @override
  void dispose() {
    ConnectivityService.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _setupConnectivityListener() {
    ConnectivityService.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged(bool online) {
    if (mounted) {
      setState(() {
        isOnline = online;
      });
      _loadData(); // Recharger les données quand la connectivité change
    }
  }

  Future<void> _checkConnectivity() async {
    final online = await ConnectivityService.checkConnectivity();
    setState(() {
      isOnline = online;
    });
  }

  Future<void> _loadData() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      // Vérifier d'abord la connectivité actuelle
      final currentOnline = await ConnectivityService.checkConnectivity();
      
      if (currentOnline) {
        // Mode online - récupérer depuis l'API
        await _loadFromAPI();
      } else {
        // Mode offline - récupérer depuis le cache local
        await _loadFromLocal();
      }
        } catch (e) {
      setState(() {
        error = 'Erreur: $e';
        loading = false;
      });
    }
  }

  Future<void> _loadFromAPI() async {
    try {
      // En mode debug, on peut afficher tous les utilisateurs de l'API
      final response = await ApiClient.getAllUsersPublic();
      if (response.statusCode == 200) {
        final List<dynamic> usersData = jsonDecode(response.body);
        setState(() {
          users = usersData.map((data) => UserModel.fromApi(data as Map<String, dynamic>)).toList();
          loading = false;
        });
        print('${users.length} utilisateur(s) chargé(s) depuis l\'API');
      } else {
        // En cas d'erreur API, essayer le cache local
        print('Erreur API, basculement vers le cache local');
        await _loadFromLocal();
      }
    } catch (e) {
      // En cas d'erreur de connexion, essayer le cache local
      print('Erreur de connexion API, basculement vers le cache local: $e');
      await _loadFromLocal();
    }
  }

  Future<void> _loadFromLocal() async {
    try {
      final localUsers = await LocalDatabase.getAllUsers();
      setState(() {
        users = localUsers;
        loading = false;
        // Pas d'erreur même si pas de données locales
        error = null;
      });
      
      if (localUsers.isEmpty) {
        print('Aucune donnée dans le cache local');
      } else {
        print('${localUsers.length} utilisateur(s) trouvé(s) dans le cache local (utilisateur connecté uniquement)');
      }
    } catch (e) {
      setState(() {
        error = 'Erreur base locale: $e';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug - Base de Données'),
        actions: [
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            color: isOnline ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
          children: [
          // Indicateur de mode
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: isOnline ? Colors.green.shade50 : Colors.orange.shade50,
            child: Row(
              children: [
                Icon(
                  isOnline ? Icons.wifi : Icons.wifi_off,
                  color: isOnline ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  isOnline ? 'Mode en ligne - Données API' : 'Mode hors ligne - Utilisateur connecté uniquement',
                  style: TextStyle(
                    color: isOnline ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${users.length} utilisateur(s)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          // Message de sécurité en mode offline
          if (!isOnline)
            Container(
              width: double.infinity,
        padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mode sécurisé : Seul l\'utilisateur connecté est affiché',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Contenu principal
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              'Erreur',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadData,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : users.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('Aucune donnée trouvée'),
                              ],
                            ),
                          )
                        : ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                              final user = users[index];
                              return Card(
                                margin: const EdgeInsets.all(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                                      // En-tête utilisateur
            Row(
              children: [
                                          CircleAvatar(
                                            child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${user.name} ${user.surname}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Text(
                                                  user.email,
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                ),
              ],
            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: user.role == 'admin' 
                                                  ? Colors.red.shade100 
                                                  : user.role == 'organisation'
                                                      ? Colors.blue.shade100
                                                      : Colors.green.shade100,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              user.role.toUpperCase(),
                                              style: TextStyle(
                                                color: user.role == 'admin' 
                                                    ? Colors.red.shade800 
                                                    : user.role == 'organisation'
                                                        ? Colors.blue.shade800
                                                        : Colors.green.shade800,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 12),
                                      
                                      // Détails complets
                                      _buildDetailRow('ID Utilisateur', user.userId.toString()),
                                      _buildDetailRow('Email', user.email),
                                      _buildDetailRow('Nom', user.name),
                                      _buildDetailRow('Prénom', user.surname),
                                      _buildDetailRow('Rôle', user.role),
                                      _buildDetailRow('Créé le', _formatDate(user.createdAt)),
                                      _buildDetailRow('Modifié le', _formatDate(user.updatedAt)),
                                      if (user.lastSync != null)
                                        _buildDetailRow('Dernière sync', _formatDate(user.lastSync!)),
                                      
            const SizedBox(height: 8),
                                      
                                      // Indicateur de source
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isOnline ? Colors.blue.shade50 : Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isOnline ? Icons.cloud : Icons.storage,
                                              size: 16,
                                              color: isOnline ? Colors.blue : Colors.orange,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isOnline ? 'Source: API' : 'Source: Local',
                                              style: TextStyle(
                                                color: isOnline ? Colors.blue : Colors.orange,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                  );
                },
              ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}