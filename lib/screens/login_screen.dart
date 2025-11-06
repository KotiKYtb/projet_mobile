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
      // Pas de notification pour les changements de connectivité
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
      backgroundColor: AppColors.getPrimaryBackground(context),
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
                
                // Champ Email avec style du template
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryButton.withOpacity(0.15),
                        blurRadius: 8,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                    style: TextStyle(color: AppColors.getTextPrimary(context)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.getMenuBackground(context),
                      hintText: 'Entrez votre email',
                      hintStyle: TextStyle(color: AppColors.getTextDisabled(context)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(
                          color: AppColors.primaryButton.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(
                          color: AppColors.primaryButton.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(
                          color: AppColors.primaryButton.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Champ Password avec style du template
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryButton.withOpacity(0.15),
                        blurRadius: 8,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: passCtrl,
                    obscureText: !_isPasswordVisible,
                    enabled: isOnline,
                    validator: isOnline ? (v) => (v == null || v.isEmpty) ? 'Requis' : null : null,
                    style: TextStyle(color: AppColors.getTextPrimary(context)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isOnline ? AppColors.getMenuBackground(context) : AppColors.getMenuBackground(context).withOpacity(0.5),
                      hintText: isOnline ? 'Entrez votre mot de passe' : 'Pas nécessaire en mode hors ligne',
                      hintStyle: TextStyle(color: AppColors.getTextDisabled(context)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(
                          color: AppColors.primaryButton.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(
                          color: AppColors.primaryButton.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(
                          color: AppColors.primaryButton.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    suffixIcon: isOnline
                        ? IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: AppColors.getTextDisabled(context),
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
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: (loading || (!isOnline && lastUser == null))
                          ? AppColors.getMenuBackground(context)
                          : AppColors.primaryButton,
                      boxShadow: (loading || (!isOnline && lastUser == null))
                          ? []
                          : [
                              BoxShadow(
                                color: AppColors.primaryButton.withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 0,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: AppColors.secondaryText.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 0,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: !loading
                        ? Text(
                            'Se connecter',
                            style: TextStyle(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : CircularProgressIndicator(
                            color: AppColors.getTextPrimary(context),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Lien vers l'inscription (juste sous les inputs)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Vous n\'avez pas de compte ?',
                        style: TextStyle(color: AppColors.getTextDisabled(context)),
                      ),
                    ),
                    GestureDetector(
                      onTap: (!isOnline && lastUser == null)
                          ? null
                          : () => Navigator.pushReplacementNamed(context, '/register'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          ' S\'inscrire',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: (!isOnline && lastUser == null)
                                ? AppColors.getIconDisabled(context)
                                : AppColors.primaryButton,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                Flexible(
                  flex: 2,
                  child: Container(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

