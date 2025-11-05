import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../api_client.dart';
import '../token_storage.dart';
import '../services/connectivity_service.dart';
import '../services/offline_auth.dart';
import '../models/user_model.dart';
import '../utils/app_colors.dart';

const webScreenSize = 600;

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
  bool _isPasswordVisible = false;

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
    emailCtrl.dispose();
    passCtrl.dispose();
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
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Container(
          // Adjusts padding based on screen size.
          padding: MediaQuery.of(context).size.width > webScreenSize
              ? EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width / 3)
              : const EdgeInsets.symmetric(horizontal: 32),
          width: double.infinity,
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  flex: 1,
                  child: Container(),
                ),
                // Logo ou branding (vous pouvez ajouter votre logo ici)
                SizedBox(
                  height: 120,
                  child: const Icon(
                    Icons.lock_outline,
                    size: 80,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Indicateur de mode connectivité
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isOnline ? Colors.green.shade200 : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOnline ? Icons.wifi : Icons.wifi_off,
                        color: isOnline ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOnline ? 'Mode en ligne' : 'Mode hors ligne',
                        style: TextStyle(
                          color: isOnline ? Colors.green.shade700 : Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Message pour mode offline
                if (!isOnline)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: lastUser != null ? Colors.blue.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: lastUser != null ? Colors.blue.shade200 : Colors.red.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lastUser != null ? 'Mode hors ligne activé' : 'Mode hors ligne - Session expirée',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: lastUser != null ? Colors.blue.shade700 : Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (lastUser != null) ...[
                          Text(
                            'Seul ${lastUser!.email} peut se connecter hors ligne.',
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                          ),
                        ] else ...[
                          Text(
                            'Vous avez été déconnecté. Connectez-vous au réseau pour vous reconnecter.',
                            style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                          ),
                        ],
                      ],
                    ),
                  ),
                
                // Champ Email avec style du template
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.menuBackground,
                    hintText: 'Enter your email',
                    hintStyle: const TextStyle(color: AppColors.textDisabled),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Champ Password avec style du template
                TextFormField(
                  controller: passCtrl,
                  obscureText: !_isPasswordVisible,
                  enabled: isOnline,
                  validator: isOnline ? (v) => (v == null || v.isEmpty) ? 'Requis' : null : null,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isOnline ? AppColors.menuBackground : AppColors.menuBackground.withOpacity(0.5),
                    hintText: isOnline ? 'Enter your password' : 'Pas nécessaire en mode offline',
                    hintStyle: const TextStyle(color: AppColors.textDisabled),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                    suffixIcon: isOnline
                        ? IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: AppColors.textDisabled,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Message d'erreur
                if (error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                
                // Bouton de connexion avec style du template
                InkWell(
                  onTap: (loading || (!isOnline && lastUser == null)) ? null : _login,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: ShapeDecoration(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      color: (loading || (!isOnline && lastUser == null))
                          ? AppColors.menuBackground
                          : AppColors.primaryButton,
                    ),
                    child: !loading
                        ? const Text(
                            'Log in',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : const CircularProgressIndicator(
                            color: AppColors.textPrimary,
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                
                Flexible(
                  flex: 2,
                  child: Container(),
                ),
                
                // Lien vers l'inscription
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: const Text(
                        'Don\'t have an account?',
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                    ),
                    GestureDetector(
                      onTap: (!isOnline && lastUser == null)
                          ? null
                          : () => Navigator.pushReplacementNamed(context, '/register'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          ' Signup.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: (!isOnline && lastUser == null)
                                ? AppColors.iconDisabled
                                : AppColors.primaryButton,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

