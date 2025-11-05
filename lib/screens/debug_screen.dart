import 'dart:convert';
import 'package:flutter/material.dart';
import '../api_client.dart';
import '../services/connectivity_service.dart';
import '../services/local_database.dart';
import '../models/user_model.dart';

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
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade400,
        elevation: 0,
        title: const Text(
          'Debug - Base de Données',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isOnline ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOnline ? Colors.green.shade300 : Colors.orange.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOnline ? Icons.wifi : Icons.wifi_off,
                  color: isOnline ? Colors.green.shade700 : Colors.orange.shade700,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? 'En ligne' : 'Hors ligne',
                  style: TextStyle(
                    color: isOnline ? Colors.green.shade700 : Colors.orange.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            color: Colors.black87,
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
            decoration: BoxDecoration(
              color: isOnline ? Colors.green.shade50 : Colors.orange.shade50,
              border: Border(
                bottom: BorderSide(
                  color: isOnline ? Colors.green.shade200 : Colors.orange.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isOnline ? Icons.wifi : Icons.wifi_off,
                  color: isOnline ? Colors.green.shade700 : Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOnline ? 'Mode en ligne - Données API' : 'Mode hors ligne - Utilisateur connecté uniquement',
                    style: TextStyle(
                      color: isOnline ? Colors.green.shade700 : Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOnline ? Colors.green.shade300 : Colors.orange.shade300,
                    ),
                  ),
                  child: Text(
                    '${users.length} utilisateur(s)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOnline ? Colors.green.shade700 : Colors.orange.shade700,
                      fontSize: 12,
                    ),
                  ),
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
                border: Border.all(color: Colors.blue.shade200, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.blue.shade700, size: 20),
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
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color.fromARGB(255, 130, 110, 100),
                      ),
                    ),
                  )
                : error != null
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          margin: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(5, 5),
                              ),
                              BoxShadow(
                                color: Colors.white.withOpacity(0.8),
                                blurRadius: 10,
                                offset: const Offset(-5, -5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error, size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              const Text(
                                'Erreur',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Text(
                                  error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              InkWell(
                                onTap: _loadData,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: const ShapeDecoration(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(4)),
                                    ),
                                    color: Color.fromARGB(255, 130, 110, 100),
                                  ),
                                  child: const Text(
                                    'Réessayer',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : users.isEmpty
                        ? Center(
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              margin: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(5, 5),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.8),
                                    blurRadius: 10,
                                    offset: const Offset(-5, -5),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inbox, size: 64, color: Colors.grey.shade600),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Aucune donnée trouvée',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(5, 5),
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.8),
                                      blurRadius: 10,
                                      offset: const Offset(-5, -5),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // En-tête utilisateur
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: const Color.fromARGB(255, 130, 110, 100),
                                            child: Text(
                                              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
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
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  user.email,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 16),
                                      Container(
                                        height: 1,
                                        color: Colors.grey.shade300,
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
                                      
                                      const SizedBox(height: 12),
                                      
                                      // Indicateur de source
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isOnline ? Colors.blue.shade50 : Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isOnline ? Colors.blue.shade200 : Colors.orange.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isOnline ? Icons.cloud : Icons.storage,
                                              size: 16,
                                              color: isOnline ? Colors.blue.shade700 : Colors.orange.shade700,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isOnline ? 'Source: API' : 'Source: Local',
                                              style: TextStyle(
                                                color: isOnline ? Colors.blue.shade700 : Colors.orange.shade700,
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
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

