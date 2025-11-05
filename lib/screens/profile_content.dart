import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

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
  late List<ProfileSection> _sections;

  @override
  void initState() {
    super.initState();
    _initSections();
  }

  void _initSections() {
    _sections = [
      ProfileSection(
        title: 'Préférences application',
        icon: Icons.settings_outlined,
        content: [
          SwitchListTile(
            title: const Text(
              'Notifications push',
              style: TextStyle(color: AppColors.textPrimary),
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
          SwitchListTile(
            title: const Text(
              'Mode sombre',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            subtitle: const Text(
              'Thème sombre de l\'application',
              style: TextStyle(color: AppColors.secondaryText),
            ),
            value: false, // TODO: lier au thème
            activeColor: AppColors.primaryButton,
            onChanged: (bool value) {
              // TODO: changer le thème
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
            title: const Text(
              'Changer le mot de passe',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.iconDisabled,
            ),
            onTap: () {
              // TODO: navigation vers changement mdp
            },
          ),
          Divider(
            color: AppColors.menuBackground,
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
  }


  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return Container(
        color: AppColors.primaryBackground,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryButton),
          ),
        ),
      );
    }

    return Container(
      color: AppColors.primaryBackground,
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
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryButton,
                              width: 3,
                            ),
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
                    const SizedBox(height: 16),
                    // Nom d'utilisateur
                    Text(
                      widget.userName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
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
          ...List.generate(_sections.length, (index) {
            final section = _sections[index];
            return Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              elevation: 0,
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: AppColors.menuBackground,
                ),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  children: [
                    Divider(color: AppColors.menuBackground),
                    ...section.content,
                    const SizedBox(height: 8),
                  ],
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
