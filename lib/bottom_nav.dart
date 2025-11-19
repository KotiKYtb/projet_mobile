import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final String userRole; // "user", "orga", "admin"

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    // === Définition des icônes selon le rôle ===
    final List<IconData> icons = _getIconsForRole(userRole);

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        height: 80,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
          CustomPaint(
            size: Size(size.width, 80),
            painter: BNBCustomPainter(
              menuBackgroundColor: AppColors.getMenuBackground(context),
            ),
          ),

          Center(
            heightFactor: 0.6,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: currentIndex == 2
                    ? [
                        BoxShadow(
                          color: AppColors.primaryButton.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 3,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: AppColors.secondaryText.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: AppColors.getMenuBackground(context).withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 0,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: FloatingActionButton(
                onPressed: () => onTap(2),
                backgroundColor: currentIndex == 2
                    ? AppColors.primaryButton
                    : AppColors.getMenuBackground(context),
                shape: const CircleBorder(),
                child: Icon(
                  icons[2],
                  color: AppColors.getTextPrimary(context),
                ),
                elevation: 0,
              ),
            ),
          ),

          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () => onTap(0),
                  icon: Icon(
                    icons[0],
                    color: currentIndex == 0
                        ? AppColors.primaryButton
                        : AppColors.getIconDisabled(context),
                  ),
                ),
                IconButton(
                  onPressed: () => onTap(1),
                  icon: Icon(
                    icons[1],
                    color: currentIndex == 1
                        ? AppColors.primaryButton
                        : AppColors.getIconDisabled(context),
                  ),
                ),
                SizedBox(width: size.width * 0.20),
                IconButton(
                  onPressed: () => onTap(3),
                  icon: Icon(
                    icons[3],
                    color: currentIndex == 3
                        ? AppColors.primaryButton
                        : AppColors.getIconDisabled(context),
                  ),
                ),
                IconButton(
                  onPressed: () => onTap(4),
                  icon: Icon(
                    icons[4],
                    color: currentIndex == 4
                        ? AppColors.primaryButton
                        : AppColors.getIconDisabled(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  // Récupère les icônes selon le rôle
  List<IconData> _getIconsForRole(String role) {
    switch (role.toLowerCase()) {
      case "organisation":
        return [
          Icons.event_available, 
          Icons.notifications,   
          Icons.home,            
          Icons.analytics_outlined,
          Icons.settings,         
        ];
      case "admin":
        return [
          Icons.dashboard,       
          Icons.people,          
          Icons.home,            
          Icons.security,        
          Icons.settings_applications, 
        ];
      case "user":
      default:
        return [
          Icons.event,          
          Icons.map,             
          Icons.home,            
          Icons.info_outline,        
          Icons.person,          
        ];
    }
  }
}

class BNBCustomPainter extends CustomPainter {
  final Color menuBackgroundColor;

  BNBCustomPainter({required this.menuBackgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = menuBackgroundColor
      ..style = PaintingStyle.fill;

    final Path background = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final double leftStart = size.width * 0.35;
    final double leftControlX = size.width * 0.40;
    final double rightControlX = size.width * 0.60;
    final double rightEnd = size.width * 0.65;
    const double depth = 22.0;

    final Path hole = Path()
      ..moveTo(leftStart, 0)
      ..quadraticBezierTo(leftControlX, 0, leftControlX, depth)
      ..arcToPoint(
        Offset(rightControlX, depth),
        radius: const Radius.circular(12.0),
        clockwise: false,
      )
      ..quadraticBezierTo(rightControlX, 0, rightEnd, 0)
      ..lineTo(leftStart, 0)
      ..close();

    final Path finalPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(background, Offset.zero)
      ..addPath(hole, Offset.zero);

    canvas.drawPath(finalPath, paint);

    final Rect shadowRect = Rect.fromLTWH(
      size.width * 0.40,
      0,
      size.width * 0.20,
      depth + 8,
    );

    final Paint softShadow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withOpacity(0.25),
          Colors.transparent,
        ],
        radius: 1.0,
        center: Alignment.bottomCenter,
      ).createShader(shadowRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width / 2, depth - 5), radius: 22),
      0,
      3.14,
      false,
      softShadow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
