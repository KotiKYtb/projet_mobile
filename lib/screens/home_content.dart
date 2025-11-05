import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class HomeContent extends StatefulWidget {
  final String userName;
  final String userRole;
  final bool loading;

  const HomeContent({
    super.key,
    required this.userName,
    required this.userRole,
    required this.loading,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  // Position initiale sur Angers
  static const double _centerLat = 47.4784;
  static const double _centerLng = -0.5632;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.getPrimaryBackground(context),
      child: Column(
        children: [
          const SizedBox(height: 48),
          // Carte (1/3 supérieur de l'écran)
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.33,
            child: Card(
              margin: const EdgeInsets.all(16),
              color: AppColors.getCardBackground(context),
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: AppColors.primaryButton.withOpacity(0.2),
                  width: 1,
                ),
              ),
              shadowColor: AppColors.primaryButton.withOpacity(0.3),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.getMenuBackground(context),
                      AppColors.getPrimaryBackground(context),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryButton.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: AppColors.secondaryText.withOpacity(0.15),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map,
                        size: 60,
                        color: AppColors.primaryButton,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Angers',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_centerLat.toStringAsFixed(4)}°N, ${_centerLng.toStringAsFixed(4)}°W',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Prochain événement
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryButton.withOpacity(0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryButton.withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: AppColors.secondaryText.withOpacity(0.15),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prochain événement',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryButton,
                  ),
                ),
                const SizedBox(height: 8),
                // TODO: Remplacer par les vraies données de l'événement
                Text(
                  'Festival des Arts',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                Text(
                  '15 Novembre 2025 - Place du Ralliement',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Liste des favoris
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vos favoris',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryButton,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: 10, // TODO: Remplacer par le nombre réel de favoris
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.getCardBackground(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Événement ${index + 1}', // TODO: Remplacer par le vrai titre
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.getTextPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Date et lieu de l\'événement', // TODO: Remplacer par les vraies données
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

