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

