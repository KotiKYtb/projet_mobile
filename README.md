# projet_mobile

This project is a Flutter mobile app with a Node.js REST API (Express + Sequelize) and a SQLite database server-side, plus planned local `sqflite` cache for offline-first behavior.

## Backend (API)
- Express server in `API/`
- Auth (JWT), users/roles, events endpoints
- Sequelize with SQLite (`API/data.sqlite`) in dev

## Mobile (Flutter)
- Flutter app in root `lib/`
- Android/iOS/macOS/Linux/Windows targets present

## Getting Started
- Install Flutter and Node.js
- API: `cd API && npm install && npm start`
- App: `flutter run`


## A Ajouter
- le fichier easteregg_sceen.dart
```dart
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class EasterEggScreen extends StatefulWidget {
  const EasterEggScreen({super.key});

  @override
  State<EasterEggScreen> createState() => _EasterEggScreenState();
}

class _EasterEggScreenState extends State<EasterEggScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late AnimationController _colorController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    // Animation de rotation
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    // Animation de scale (pulsation)
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    // Animation de couleur
    _colorController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: AppColors.primaryButton,
      end: AppColors.secondaryBackground,
    ).animate(
      CurvedAnimation(parent: _colorController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getPrimaryBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getPrimaryBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '🎉 Easter Egg 🎉',
          style: TextStyle(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône animée
              AnimatedBuilder(
                animation: Listenable.merge([
                  _rotationAnimation,
                  _scaleAnimation,
                  _colorAnimation,
                ]),
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _colorAnimation.value ?? AppColors.primaryButton,
                              _colorAnimation.value?.withOpacity(0.3) ??
                                  AppColors.primaryButton.withOpacity(0.3),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_colorAnimation.value ??
                                      AppColors.primaryButton)
                                  .withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.celebration,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 48),
              // Titre
              Text(
                'Félicitations ! 🎊',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Message
              Text(
                'Vous avez découvert l\'easter egg !',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.getTextDisabled(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Vous êtes un utilisateur curieux et persévérant ! 👏',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.getTextDisabled(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              // Emojis animés
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _buildAnimatedEmoji('🎉', 0),
                  _buildAnimatedEmoji('🎊', 0.2),
                  _buildAnimatedEmoji('🎈', 0.4),
                  _buildAnimatedEmoji('🎁', 0.6),
                  _buildAnimatedEmoji('⭐', 0.8),
                ],
              ),
              const SizedBox(height: 48),
              // Message secret
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.getCardBackground(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryButton.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryButton.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: AppColors.primaryButton,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Message Secret',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Merci d\'avoir exploré l\'application !\n'
                      'Vous faites partie des rares utilisateurs\n'
                      'qui ont trouvé cette page cachée.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextDisabled(context),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedEmoji(String emoji, double delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: (1000 + delay * 1000).round()),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 40),
          ),
        );
      },
    );
  }
}
```
- remplacer le fichier profile_content.dart par
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import '../utils/app_colors.dart';
import '../services/theme_service.dart';
import '../api_client.dart';
import '../token_storage.dart';
import 'easter_egg_screen.dart';

class ProfileSection {
  final String title;
  final IconData icon;
  final List<Widget> content;
  bool isExpanded;

  ProfileSection({
    required this.title,
    required this.icon,
    required this.content,
    this.isExpanded = false,
  });
}

class ProfileContent extends StatefulWidget {
  final String userName;
  final String userRole;
  final bool loading;
  final bool isOnline;
  final VoidCallback onLogout;

  const ProfileContent({
    super.key,
    required this.userName,
    required this.userRole,
    required this.loading,
    required this.isOnline,
    required this.onLogout,
  });

  @override
  State<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  List<ProfileSection>? _sections;
  
  // Compteur invisible pour l'easter egg
  int _easterEggClickCount = 0;
  Timer? _easterEggResetTimer;

  List<ProfileSection> _initSections(BuildContext context) {
    final sections = [
      ProfileSection(
        title: 'Préférences application',
        icon: Icons.settings_outlined,
        content: [
          SwitchListTile(
            title: Text(
              'Notifications push',
              style: TextStyle(color: AppColors.getTextPrimary(context)),
            ),
            subtitle: const Text(
              'Recevoir des alertes push',
              style: TextStyle(color: AppColors.secondaryText),
            ),
            value: true, // TODO: lier à une vraie préférence
            activeColor: AppColors.primaryButton,
            onChanged: (bool value) {
              // TODO: sauvegarder la préférence
            },
          ),
          Consumer<ThemeService>(
            builder: (context, themeService, _) {
              return SwitchListTile(
                title: Text(
                  'Mode sombre',
                  style: TextStyle(color: AppColors.getTextPrimary(context)),
                ),
                subtitle: Text(
                  'Thème sombre de l\'application',
                  style: TextStyle(color: AppColors.secondaryText),
                ),
                value: themeService.isDarkMode,
                activeColor: AppColors.primaryButton,
                onChanged: (bool value) {
                  themeService.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                },
              );
            },
          ),
        ],
      ),
      ProfileSection(
        title: 'Compte',
        icon: Icons.admin_panel_settings_outlined,
        content: [
          ListTile(
            leading: const Icon(
              Icons.security_outlined,
              color: AppColors.primaryButton,
            ),
            title: Text(
              'Changer le mot de passe',
              style: TextStyle(color: AppColors.getTextPrimary(context)),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: AppColors.getIconDisabled(context),
            ),
            onTap: () {
              // TODO: navigation vers changement mdp
            },
          ),
          Divider(
            color: AppColors.getMenuBackground(context),
          ),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: widget.isOnline ? AppColors.primaryButton : Colors.orange,
            ),
            title: Text(
              'Se déconnecter',
              style: TextStyle(
                color: widget.isOnline ? AppColors.primaryButton : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: !widget.isOnline
                ? const Text(
                    'Mode hors ligne - Reconnexion impossible',
                    style: TextStyle(color: Colors.orange),
                  )
                : null,
            onTap: widget.onLogout,
          ),
        ],
      ),
    ];
    
    // Ajouter la section Administrateur uniquement si l'utilisateur est admin
    if (widget.userRole.toLowerCase() == 'admin') {
      sections.add(
        ProfileSection(
          title: 'Administrateur',
          icon: Icons.admin_panel_settings,
          content: [
            _buildAdminTabs(context),
          ],
        ),
      );
    }
    
    return sections;
  }
  
  Widget _buildAdminTabs(BuildContext context) {
    return DefaultTabController(
      length: 1, // Pour l'instant, un seul onglet "Utilisateur"
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            labelColor: AppColors.primaryButton,
            unselectedLabelColor: AppColors.getTextDisabled(context),
            indicatorColor: AppColors.primaryButton,
            tabs: const [
              Tab(
                icon: Icon(Icons.people_outline),
                text: 'Utilisateur',
              ),
            ],
          ),
          SizedBox(
            height: 400, // Hauteur fixe pour le contenu des onglets
            child: TabBarView(
              children: [
                _buildUsersTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUsersTab(BuildContext context) {
    return _UsersListWidget();
  }

  void _handleAvatarClick() {
    // Réinitialiser le timer précédent s'il existe
    _easterEggResetTimer?.cancel();
    
    // Incrémenter le compteur
    setState(() {
      _easterEggClickCount++;
    });
    
    // Si on a atteint 5 clics, ouvrir la page easter egg
    if (_easterEggClickCount >= 5) {
      _easterEggClickCount = 0;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const EasterEggScreen(),
        ),
      );
    } else {
      // Réinitialiser le compteur après 3 secondes si l'utilisateur ne clique pas assez vite
      _easterEggResetTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _easterEggClickCount = 0;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _easterEggResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return Container(
        color: AppColors.getPrimaryBackground(context),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryButton),
          ),
        ),
      );
    }

    // Initialiser les sections dans build() où le contexte est disponible
    final sections = _initSections(context);

    return Container(
      color: AppColors.getPrimaryBackground(context),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          const SizedBox(height: 48),
          // En-tête du profil
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                        // Avatar avec indicateur de statut
                    GestureDetector(
                      onTap: _handleAvatarClick,
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primaryButton,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryButton.withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: AppColors.primaryButton.withOpacity(0.2),
                              child: Icon(
                                Icons.person,
                                size: 50,
                                color: AppColors.primaryButton,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: widget.isOnline ? Colors.green : Colors.orange,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                widget.isOnline ? Icons.wifi : Icons.wifi_off,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Nom d'utilisateur
                    Text(
                      widget.userName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Badge de rôle
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryButton.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryButton.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.userRole,
                        style: const TextStyle(
                          color: AppColors.primaryButton,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Sections expansibles
          ...List.generate(sections.length, (index) {
            final section = sections[index];
            return Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              elevation: 0,
              color: AppColors.getCardBackground(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: AppColors.primaryButton.withOpacity(0.2),
                  width: 1,
                ),
              ),
              shadowColor: AppColors.primaryButton.withOpacity(0.3),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryButton.withOpacity(0.15),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: AppColors.secondaryText.withOpacity(0.1),
                      blurRadius: 6,
                      spreadRadius: 0,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  initiallyExpanded: section.isExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      section.isExpanded = expanded;
                    });
                  },
                  leading: Icon(
                    section.icon,
                    color: AppColors.primaryButton,
                  ),
                  title: Text(
                    section.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  children: [
                    Divider(color: AppColors.getMenuBackground(context)),
                    ...section.content,
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// Modèle pour représenter un utilisateur dans la liste admin
class _UserListItem {
  final int userId;
  final String email;
  final String name;
  final String surname;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;

  _UserListItem({
    required this.userId,
    required this.email,
    required this.name,
    required this.surname,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _UserListItem.fromJson(Map<String, dynamic> json) {
    return _UserListItem(
      userId: json['user_id'] as int,
      email: json['email'] as String,
      name: json['name'] as String,
      surname: json['surname'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

// Widget pour afficher la liste des utilisateurs
class _UsersListWidget extends StatefulWidget {
  @override
  State<_UsersListWidget> createState() => _UsersListWidgetState();
}

class _UsersListWidgetState extends State<_UsersListWidget> {
  List<_UserListItem> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadUsers();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final token = await TokenStorage.read();
      if (token != null) {
        // Décoder le token JWT pour obtenir l'ID de l'utilisateur
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          String normalizedPayload = payload;
          switch (payload.length % 4) {
            case 1:
              normalizedPayload += '===';
              break;
            case 2:
              normalizedPayload += '==';
              break;
            case 3:
              normalizedPayload += '=';
              break;
          }
          normalizedPayload = normalizedPayload.replaceAll('-', '+').replaceAll('_', '/');
          final decodedBytes = base64Decode(normalizedPayload);
          final decodedString = utf8.decode(decodedBytes);
          final payloadMap = jsonDecode(decodedString) as Map<String, dynamic>;
          final userId = payloadMap['id'] as int?;
          setState(() {
            _currentUserId = userId;
          });
        }
      }
    } catch (e) {
      print('Erreur lors de la récupération de l\'ID utilisateur: $e');
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await TokenStorage.read();
      if (token == null) {
        setState(() {
          _errorMessage = 'Token non disponible';
          _isLoading = false;
        });
        return;
      }

      final response = await ApiClient.getAllUsers(token: token);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _users = data.map((json) => _UserListItem.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Erreur lors du chargement: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserRole(int userId, String newRole) async {
    try {
      final token = await TokenStorage.read();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token non disponible')),
        );
        return;
      }

      final response = await ApiClient.updateUserRole(
        token: token,
        userId: userId,
        role: newRole,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rôle mis à jour avec succès')),
        );
        _loadUsers(); // Recharger la liste
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${errorData['message'] ?? 'Erreur inconnue'}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _showRoleDialog(_UserListItem user) {
    final roles = ['user', 'admin', 'organisation'];
    final currentRoleIndex = roles.indexOf(user.role);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Changer le rôle',
          style: TextStyle(color: AppColors.getTextPrimary(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${user.name} ${user.surname}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user.email,
              style: TextStyle(color: AppColors.getTextDisabled(context)),
            ),
            const SizedBox(height: 16),
            Text(
              'Rôle actuel: ${user.role}',
              style: TextStyle(color: AppColors.getTextPrimary(context)),
            ),
            const SizedBox(height: 16),
            ...roles.map((role) => RadioListTile<String>(
              title: Text(
                role,
                style: TextStyle(color: AppColors.getTextPrimary(context)),
              ),
              value: role,
              groupValue: user.role,
              onChanged: (value) {
                if (value != null) {
                  Navigator.pop(context);
                  _updateUserRole(user.userId, value);
                }
              },
              activeColor: AppColors.primaryButton,
            )),
          ],
        ),
        backgroundColor: AppColors.getCardBackground(context),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: AppColors.getTextDisabled(context)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Ajouter 1 heure pour UTC+1
    final dateUTC1 = date.add(const Duration(hours: 1));
    return '${dateUTC1.day}/${dateUTC1.month}/${dateUTC1.year} ${dateUTC1.hour.toString().padLeft(2, '0')}:${dateUTC1.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gestion des utilisateurs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadUsers,
                color: AppColors.primaryButton,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryButton),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _errorMessage!,
                              style: TextStyle(color: AppColors.getTextDisabled(context)),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadUsers,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryButton,
                              ),
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _users.isEmpty
                        ? Center(
                            child: Text(
                              'Aucun utilisateur trouvé',
                              style: TextStyle(color: AppColors.getTextDisabled(context)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                color: AppColors.getCardBackground(context),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: AppColors.primaryButton.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primaryButton.withOpacity(0.2),
                                    child: Icon(
                                      Icons.person,
                                      color: AppColors.primaryButton,
                                    ),
                                  ),
                                  title: Text(
                                    '${user.name} ${user.surname}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.getTextPrimary(context),
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        user.email,
                                        style: TextStyle(
                                          color: AppColors.getTextDisabled(context),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryButton.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              user.role,
                                              style: const TextStyle(
                                                color: AppColors.primaryButton,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Créé le: ${_formatDate(user.createdAt)}',
                                        style: TextStyle(
                                          color: AppColors.getTextDisabled(context),
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'Dernière mise à jour: ${_formatDate(user.updatedAt)}',
                                        style: TextStyle(
                                          color: AppColors.getTextDisabled(context),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: _currentUserId != null && user.userId == _currentUserId
                                      ? Tooltip(
                                          message: 'Vous ne pouvez pas modifier votre propre compte',
                                          child: IconButton(
                                            icon: const Icon(Icons.edit),
                                            color: AppColors.getTextDisabled(context),
                                            onPressed: null, // Désactivé
                                          ),
                                        )
                                      : IconButton(
                                          icon: const Icon(Icons.edit),
                                          color: AppColors.primaryButton,
                                          onPressed: () => _showRoleDialog(user),
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
}
```