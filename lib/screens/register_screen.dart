import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api_client.dart';
import '../services/connectivity_service.dart';

const webScreenSize = 600;

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
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    ConnectivityService.removeListener(_onConnectivityChanged);
    emailCtrl.dispose();
    nameCtrl.dispose();
    surnameCtrl.dispose();
    passCtrl.dispose();
    confirmPassCtrl.dispose();
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
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey.shade300,
      body: SafeArea(
        child: SingleChildScrollView(
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
                  const SizedBox(height: 32),
                  // Logo ou branding
                  SizedBox(
                    height: 100,
                    child: Icon(
                      Icons.person_add_outlined,
                      size: 70,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
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
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.block, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Inscription désactivée',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'L\'inscription n\'est pas disponible en mode hors ligne. Veuillez vous connecter à internet pour créer un compte.',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Champ Prénom avec style du template
                  TextFormField(
                    controller: nameCtrl,
                    enabled: isOnline,
                    validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isOnline ? Colors.black : Colors.grey.shade800,
                      hintText: 'Enter your first name',
                      hintStyle: const TextStyle(color: Colors.white60),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Champ Nom avec style du template
                  TextFormField(
                    controller: surnameCtrl,
                    enabled: isOnline,
                    validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isOnline ? Colors.black : Colors.grey.shade800,
                      hintText: 'Enter your last name',
                      hintStyle: const TextStyle(color: Colors.white60),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Champ Email avec style du template
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    enabled: isOnline,
                    validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isOnline ? Colors.black : Colors.grey.shade800,
                      hintText: 'Enter your email',
                      hintStyle: const TextStyle(color: Colors.white60),
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
                    validator: (v) => (v == null || v.length < 6) ? 'Min 6 chars' : null,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isOnline ? Colors.black : Colors.grey.shade800,
                      hintText: 'Enter your password',
                      hintStyle: const TextStyle(color: Colors.white60),
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
                                color: Colors.white60,
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
                  
                  // Champ Confirmer Password avec style du template
                  TextFormField(
                    controller: confirmPassCtrl,
                    obscureText: !_isConfirmPasswordVisible,
                    enabled: isOnline,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requis';
                      if (v != passCtrl.text) return 'Les mots de passe ne correspondent pas';
                      return null;
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isOnline ? Colors.black : Colors.grey.shade800,
                      hintText: 'Confirm your password',
                      hintStyle: const TextStyle(color: Colors.white60),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      suffixIcon: isOnline
                          ? IconButton(
                              icon: Icon(
                                _isConfirmPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white60,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
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
                  
                  // Bouton d'inscription avec style du template
                  InkWell(
                    onTap: (loading || !isOnline) ? null : _submit,
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: ShapeDecoration(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                        color: (loading || !isOnline)
                            ? Colors.grey
                            : Colors.brown,
                      ),
                      child: !loading
                          ? !isOnline
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.block, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Inscription désactivée',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Sign up',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                          : const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Lien vers le login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: const Text(
                          'Already have an account?',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: const Text(
                            ' Login.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

