import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../utils/app_colors.dart';
import '../services/theme_service.dart';
import '../api_client.dart';
import '../token_storage.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../services/local_database.dart';
import '../models/user_model.dart';

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
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isChangingPassword = false;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _profilePictureUrl;
  bool _isUploadingProfilePicture = false;
  bool _isLoadingProfilePicture = false;

  @override
  void initState() {
    super.initState();
    _loadProfilePicture();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfilePicture() async {
    // Éviter les appels multiples simultanés
    if (_isLoadingProfilePicture) {
      return;
    }
    
    _isLoadingProfilePicture = true;
    
    try {
      // Forcer une synchronisation depuis l'API pour récupérer l'image de profil à jour
      print('Chargement de la photo de profil - Synchronisation depuis l\'API...');
      await SyncService.forceSync();
      
      // Récupérer l'utilisateur après synchronisation
      final currentUser = await SyncService.getCurrentUser();
      if (currentUser != null) {
        setState(() {
          _profilePictureUrl = currentUser.profilePicture;
        });
        print('Photo de profil chargée: ${currentUser.profilePicture ?? "NULL"}');
      } else {
        print('Aucun utilisateur trouvé lors du chargement de la photo de profil');
      }
    } catch (e) {
      print('Erreur lors du chargement de la photo de profil: $e');
      // En cas d'erreur, essayer de charger depuis le cache local
      try {
        final currentUser = await SyncService.getCurrentUser();
        if (currentUser != null) {
          setState(() {
            _profilePictureUrl = currentUser.profilePicture;
          });
          print('Photo de profil chargée depuis le cache: ${currentUser.profilePicture ?? "NULL"}');
        }
      } catch (e2) {
        print('Erreur lors du chargement depuis le cache: $e2');
      }
    } finally {
      _isLoadingProfilePicture = false;
    }
  }

  Future<void> _pickAndUploadProfilePicture() async {
    // Vérifier si l'utilisateur est organisateur
    final userRole = widget.userRole.toLowerCase();
    if (userRole != 'organisation' && userRole != 'organizer' && userRole != 'organisateur' && userRole != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seuls les organisateurs peuvent ajouter une photo de profil')),
      );
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isUploadingProfilePicture = true;
      });

      final token = await TokenStorage.read();
      if (token == null) {
        throw Exception('Non authentifié');
      }

      // Upload de l'image
      final uploadResponse = await ApiClient.uploadProfileImage(
        token: token,
        imageFile: File(image.path),
      );

      if (uploadResponse.statusCode == 200) {
        final uploadData = jsonDecode(uploadResponse.body) as Map<String, dynamic>;
        final imageUrl = uploadData['imageUrl'] as String;

        // Mettre à jour le profil avec l'URL de l'image
        final updateResponse = await ApiClient.updateProfile(
          token: token,
          profilePicture: imageUrl,
        );

        if (updateResponse.statusCode == 200) {
          final updateData = jsonDecode(updateResponse.body) as Map<String, dynamic>;
          final updatedUserData = updateData['user'] as Map<String, dynamic>;
          
          // Mettre à jour le cache local
          final updatedUser = UserModel.fromApi(updatedUserData);
          await LocalDatabase.insertOrUpdateUser(updatedUser);

          // Forcer une nouvelle synchronisation pour s'assurer que tout est à jour
          await SyncService.forceSync();

          setState(() {
            _profilePictureUrl = imageUrl;
            _isUploadingProfilePicture = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Photo de profil mise à jour avec succès !')),
            );
          }
        } else {
          throw Exception('Erreur lors de la mise à jour du profil: ${updateResponse.body}');
        }
      } else {
        throw Exception('Erreur lors de l\'upload: ${uploadResponse.body}');
      }
    } catch (e) {
      print('Erreur lors de l\'upload de la photo de profil: $e');
      print('Type d\'erreur: ${e.runtimeType}');
      setState(() {
        _isUploadingProfilePicture = false;
      });
      if (mounted) {
        String errorMessage = 'Erreur lors de l\'upload';
        if (e.toString().contains('Connection reset')) {
          errorMessage = 'La connexion a été interrompue. Veuillez réessayer.';
        } else if (e.toString().contains('Timeout')) {
          errorMessage = 'Le téléchargement a pris trop de temps. Veuillez réessayer avec une image plus petite.';
        } else {
          errorMessage = 'Erreur: ${e.toString()}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {

    _oldPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _obscureOldPassword = true;
    _obscureNewPassword = true;
    _obscureConfirmPassword = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.getCardBackground(context),
          title: Text(
            'Changer le mot de passe',
            style: TextStyle(
              color: AppColors.getTextPrimary(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                TextField(
                  controller: _oldPasswordController,
                  obscureText: _obscureOldPassword,
                  decoration: InputDecoration(
                    labelText: 'Ancien mot de passe',
                    labelStyle: TextStyle(color: AppColors.getTextDisabled(context)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primaryButton.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primaryButton),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureOldPassword ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.getTextDisabled(context),
                      ),
                      onPressed: () {
                        setDialogState(() {
                          _obscureOldPassword = !_obscureOldPassword;
                        });
                      },
                    ),
                  ),
                  style: TextStyle(color: AppColors.getTextPrimary(context)),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    labelStyle: TextStyle(color: AppColors.getTextDisabled(context)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primaryButton.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primaryButton),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.getTextDisabled(context),
                      ),
                      onPressed: () {
                        setDialogState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                  ),
                  style: TextStyle(color: AppColors.getTextPrimary(context)),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirmer le nouveau mot de passe',
                    labelStyle: TextStyle(color: AppColors.getTextDisabled(context)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primaryButton.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primaryButton),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.getTextDisabled(context),
                      ),
                      onPressed: () {
                        setDialogState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  style: TextStyle(color: AppColors.getTextPrimary(context)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isChangingPassword
                  ? null
                  : () {
                      Navigator.of(context).pop();
                    },
              child: Text(
                'Annuler',
                style: TextStyle(color: AppColors.getTextDisabled(context)),
              ),
            ),
            ElevatedButton(
              onPressed: _isChangingPassword
                  ? null
                  : () async {
                      await _handleChangePassword(context, setDialogState);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryButton,
                disabledBackgroundColor: AppColors.primaryButton.withOpacity(0.5),
              ),
              child: _isChangingPassword
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Changer',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleChangePassword(BuildContext context, StateSetter setDialogState) async {
    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (oldPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer votre ancien mot de passe')),
      );
      return;
    }

    if (newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un nouveau mot de passe')),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le mot de passe doit contenir au moins 6 caractères')),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas')),
      );
      return;
    }

    if (oldPassword == newPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nouveau mot de passe doit être différent de l\'ancien')),
      );
      return;
    }

    if (!widget.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de changer le mot de passe en mode hors ligne'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setDialogState(() {
      _isChangingPassword = true;
    });

    try {
      final token = await TokenStorage.read();
      if (token == null) {
        setDialogState(() {
          _isChangingPassword = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expirée. Veuillez vous reconnecter')),
        );
        return;
      }

      final response = await ApiClient.changePassword(
        token: token,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      if (response.statusCode == 200) {
        setDialogState(() {
          _isChangingPassword = false;
        });
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mot de passe modifié avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        setDialogState(() {
          _isChangingPassword = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['message'] ?? 'Erreur lors du changement de mot de passe'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setDialogState(() {
        _isChangingPassword = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
            value: true,
            activeColor: AppColors.primaryButton,
            onChanged: (bool value) {

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
              _showChangePasswordDialog(context);
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
      length: 1,
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
            height: 400,
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

    final sections = _initSections(context);

    return Container(
      color: AppColors.getPrimaryBackground(context),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          const SizedBox(height: 48),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [

                    GestureDetector(
                      onTap: (widget.userRole.toLowerCase() == 'organisation' || widget.userRole.toLowerCase() == 'organizer' || widget.userRole.toLowerCase() == 'organisateur' || widget.userRole.toLowerCase() == 'admin') && !_isUploadingProfilePicture
                          ? _pickAndUploadProfilePicture
                          : null,
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
                              backgroundImage: _profilePictureUrl != null
                                  ? NetworkImage(_profilePictureUrl!)
                                  : null,
                              child: _profilePictureUrl == null
                                  ? Icon(
                                      Icons.person,
                                      size: 50,
                                      color: AppColors.primaryButton,
                                    )
                                  : null,
                            ),
                          ),
                          if ((widget.userRole.toLowerCase() == 'organisation' || widget.userRole.toLowerCase() == 'organizer' || widget.userRole.toLowerCase() == 'organisateur' || widget.userRole.toLowerCase() == 'admin') && !_isUploadingProfilePicture)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryButton,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
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
                          if (_isUploadingProfilePicture)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      widget.userName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),

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
        _loadUsers();
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
                                            onPressed: null,
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
