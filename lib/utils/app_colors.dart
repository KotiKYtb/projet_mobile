import 'package:flutter/material.dart';

/// Palette de couleurs de l'application avec support dark/light mode
class AppColors {
  // Couleurs dark mode (existantes)
  static const Color darkPrimaryBackground = Color(0xFF252d3c);
  static const Color darkMenuBackground = Color(0xFF2e3749);
  static const Color darkCardBackground = Color(0xFF2e3749);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextDisabled = Colors.white60;

  // Couleurs light mode (nouvelles)
  static const Color lightPrimaryBackground = Color(0xFFF5F7FA);
  static const Color lightMenuBackground = Color(0xFFFFFFFF);
  static const Color lightCardBackground = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextDisabled = Color(0xFF6B7280);

  // Couleurs communes (n'changent pas entre dark/light)
  static const Color primaryButton = Color(0xFF39aeea);
  static const Color primaryText = Color(0xFF39aeea);
  static const Color secondaryBackground = Color(0xFF3f8deb);
  static const Color secondaryText = Color(0xFF3f8deb);
  static const Color textSecondary = Color(0xFF3f8deb);
  static const Color iconPrimary = Color(0xFF39aeea);
  static const Color iconSecondary = Color(0xFF3f8deb);

  // Méthodes pour obtenir les couleurs selon le thème
  static Color getPrimaryBackground(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkPrimaryBackground : lightPrimaryBackground;
  }

  static Color getMenuBackground(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkMenuBackground : lightMenuBackground;
  }

  static Color getCardBackground(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkCardBackground : lightCardBackground;
  }

  static Color getTextPrimary(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;
  }

  static Color getTextDisabled(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkTextDisabled : lightTextDisabled;
  }

  static Color getIconDisabled(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkTextDisabled : lightTextDisabled;
  }

  // Propriétés pour compatibilité avec l'ancien code (deprecated - utilisez les méthodes get)
  @Deprecated('Utilisez getPrimaryBackground(context)')
  static Color get primaryBackground => darkPrimaryBackground;

  @Deprecated('Utilisez getMenuBackground(context)')
  static Color get menuBackground => darkMenuBackground;

  @Deprecated('Utilisez getCardBackground(context)')
  static Color get cardBackground => darkCardBackground;

  @Deprecated('Utilisez getTextPrimary(context)')
  static Color get textPrimary => darkTextPrimary;

  @Deprecated('Utilisez getTextDisabled(context)')
  static Color get textDisabled => darkTextDisabled;

  @Deprecated('Utilisez getIconDisabled(context)')
  static Color get iconDisabled => darkTextDisabled;
}
