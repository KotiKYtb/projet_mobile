import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'events_content.dart';
import '../utils/app_colors.dart';
import '../api_client.dart';
import '../services/map_service.dart';
import '../services/sync_service.dart';
import '../services/local_database.dart';
import '../services/connectivity_service.dart';
import '../models/user_model.dart';
import '../token_storage.dart';
import '../widgets/home_widget_service.dart';

/// Widget qui affiche une image depuis une URL réseau ou une data URL (base64)
class FlexibleImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;

  const FlexibleImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.loadingBuilder,
  });

  bool get isDataUrl => imageUrl.startsWith('data:image');

  Uint8List? _decodeBase64() {
    if (!isDataUrl) return null;
    try {
      // Format: data:image/jpeg;base64,<base64_string>
      final base64String = imageUrl.split(',')[1];
      return base64Decode(base64String);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isDataUrl) {
      final bytes = _decodeBase64();
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: errorBuilder,
        );
      } else {
        // Si le décodage échoue, afficher l'erreur
        if (errorBuilder != null) {
          return errorBuilder!(context, Exception('Invalid base64 image'), null);
        }
        return Container(
          color: Colors.grey[300],
          child: const Center(child: Icon(Icons.error)),
        );
      }
    } else {
      return Image.network(
        imageUrl,
        fit: fit,
        errorBuilder: errorBuilder,
        loadingBuilder: loadingBuilder,
      );
    }
  }
}

class EventDetailsScreen extends StatefulWidget {
  final EventItem event;

  const EventDetailsScreen({
    super.key,
    required this.event,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  bool _isMapExpanded = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _mapKey = GlobalKey();
  double _appBarOpacity = 0.0;
  bool _notificationsEnabled = false;
  bool _isFavorite = false;
  MapController? _mapController;
  bool _isMapReady = false;
  bool _isInteractingWithMap = false; // Pour suivre si on interagit avec la carte
  String? _organizerProfilePictureUrl; // URL de l'image de profil de l'organisateur
  Uint8List? _organizerProfilePictureBytes; // Bytes de l'image de profil
  List<StaticPositionGeoPoint> _pins = []; // Pins avec image de profil

  static const double _defaultLat = 47.4739884;
  static const double _defaultLng = -0.5515588;

  /// Récupère l'image de profil de l'organisateur de l'événement
  Future<void> _loadOrganizerProfilePicture() async {
    try {
      if (widget.event.createdBy == null || widget.event.createdBy!.isEmpty) {
        // Pas d'organisateur, utiliser l'icône par défaut
        _pins = await _buildEventPin();
        if (mounted) setState(() {});
        return;
      }
      
      final createdById = int.tryParse(widget.event.createdBy!.trim());
      if (createdById == null) {
        // ID invalide, utiliser l'icône par défaut
        _pins = await _buildEventPin();
        if (mounted) setState(() {});
        return;
      }
      
      // Essayer d'abord depuis le cache local
      var user = await LocalDatabase.getUserById(createdById);
      
      // Si pas dans le cache OU si l'utilisateur n'a pas d'image de profil, récupérer depuis l'API
      final needsUpdate = user == null || user.profilePicture == null || user.profilePicture!.isEmpty;
      if (needsUpdate) {
        final isOnline = await ConnectivityService.checkConnectivity();
        if (isOnline) {
          try {
            // Récupérer tous les utilisateurs depuis l'API publique pour avoir les organisateurs
            final response = await ApiClient.getAllUsersPublic();
            if (response.statusCode == 200) {
              final usersData = jsonDecode(response.body) as List<dynamic>;
              for (var userData in usersData) {
                final userMap = userData as Map<String, dynamic>;
                final userId = userMap['user_id'] as int? ?? userMap['id'] as int?;
                if (userId == createdById) {
                  final userFromApi = UserModel.fromApi(userMap);
                  await LocalDatabase.insertOrUpdateUser(userFromApi);
                  user = userFromApi;
                  break;
                }
              }
              // Si toujours pas trouvé, réessayer depuis le cache
              if (user == null) {
                user = await LocalDatabase.getUserById(createdById);
              }
            }
          } catch (e) {
            print('Erreur lors de la récupération depuis l\'API pour l\'organisateur $createdById: $e');
          }
        }
      }
      
      if (user != null && user.profilePicture != null && user.profilePicture!.isNotEmpty) {
        _organizerProfilePictureUrl = user.profilePicture;
        
        // Charger l'image et la convertir en bytes
        try {
          final imageUrl = user.profilePicture!;
          final cleanImageUrl = ApiClient.cleanUrl(imageUrl);
          final response = await http.get(Uri.parse(cleanImageUrl));
          if (response.statusCode == 200) {
            _organizerProfilePictureBytes = response.bodyBytes;
          }
        } catch (e) {
          print('Erreur lors du chargement de l\'image pour l\'organisateur $createdById: $e');
        }
      }
      
      // Construire les pins avec l'image de profil
      _pins = await _buildEventPin();
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Erreur lors du chargement de l\'image de profil: $e');
      // En cas d'erreur, utiliser l'icône par défaut
      _pins = await _buildEventPin();
      if (mounted) setState(() {});
    }
  }

  Future<List<StaticPositionGeoPoint>> _buildEventPin() async {
    final pins = <StaticPositionGeoPoint>[];
    
    // Utiliser les coordonnées GPS de l'événement si disponibles
    if (widget.event.latitude == null || widget.event.longitude == null) {
      return pins;
    }
    
    // Créer l'icône du pin : utiliser l'image de profil si disponible
    Widget? pinIconWidget;
    Icon? pinIcon;
    
    if (_organizerProfilePictureBytes != null && _organizerProfilePictureBytes!.isNotEmpty) {
      // Utiliser l'image de profil de l'organisateur avec Image.memory
      pinIconWidget = Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.red,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.memory(
            _organizerProfilePictureBytes!,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.location_on,
                color: Colors.red,
                size: 72,
              );
            },
          ),
        ),
      );
    } else if (_organizerProfilePictureUrl != null && _organizerProfilePictureUrl!.isNotEmpty) {
      // Si on a l'URL mais pas les bytes, utiliser Image.network
      pinIconWidget = Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.red,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            _organizerProfilePictureUrl!,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.location_on,
                color: Colors.red,
                size: 72,
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              );
            },
          ),
        ),
      );
    } else {
      // Icône par défaut si pas d'image de profil
      pinIcon = Icon(
        Icons.location_on,
        color: Colors.red,
        size: 72,
      );
    }
    
    // Créer le MarkerIcon avec iconWidget si disponible, sinon utiliser icon
    final MarkerIcon markerIcon = pinIconWidget != null
        ? MarkerIcon(
            iconWidget: pinIconWidget,
          )
        : MarkerIcon(
            icon: pinIcon ?? Icon(
              Icons.location_on,
              color: Colors.red,
              size: 72,
            ),
          );
    
    pins.add(
      StaticPositionGeoPoint(
        "event_location",
        markerIcon,
        [GeoPoint(
          latitude: widget.event.latitude!,
          longitude: widget.event.longitude!,
        )],
      ),
    );
    
    return pins;
  }

  @override
  void initState() {
    super.initState();

    _mapController = MapService().getController();

    if (MapService().isReady) {
      _isMapReady = true;
    }
    
    _scrollController.addListener(_onScroll);

    _appBarOpacity = 0.0;
    _loadNotificationPreference();
    _loadFavoritePreference();
    _loadOrganizerProfilePicture();
  }

  Future<void> _loadNotificationPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'event_notification_${widget.event.eventId}';
      setState(() {
        _notificationsEnabled = prefs.getBool(key) ?? false;
      });
    } catch (e) {
      print('Erreur lors du chargement de la préférence de notification: $e');
    }
  }

  Future<void> _loadFavoritePreference() async {
    try {
      // Utiliser SyncService qui gère automatiquement le cache offline
      final userId = await SyncService.getCurrentUserId();
      if (userId != null) {
        final isFavorite = await SyncService.isFavorite(
          userId: userId,
          eventId: widget.event.eventId,
        );
        setState(() {
          _isFavorite = isFavorite;
        });
        
        // Garder aussi SharedPreferences pour compatibilité
        final prefs = await SharedPreferences.getInstance();
        final key = 'event_favorite_${widget.event.eventId}';
        await prefs.setBool(key, isFavorite);
        return;
      }

      // Fallback sur SharedPreferences si pas d'userId
      final prefs = await SharedPreferences.getInstance();
      final key = 'event_favorite_${widget.event.eventId}';
      setState(() {
        _isFavorite = prefs.getBool(key) ?? false;
      });
    } catch (e) {
      print('Erreur lors du chargement de la préférence de favori: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = 'event_favorite_${widget.event.eventId}';
        setState(() {
          _isFavorite = prefs.getBool(key) ?? false;
        });
      } catch (e2) {
        print('Erreur lors du chargement du cache local: $e2');
      }
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final token = await TokenStorage.read();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vous devez être connecté pour ajouter aux favoris'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final newValue = !_isFavorite;
      http.Response response;

      if (newValue) {

        response = await ApiClient.addFavorite(
          token: token,
          eventId: widget.event.eventId,
        );
      } else {

        response = await ApiClient.removeFavorite(
          token: token,
          eventId: widget.event.eventId,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Mettre à jour le cache local
        final userId = await SyncService.getCurrentUserId();
        if (userId != null) {
          if (newValue) {
            await LocalDatabase.insertOrUpdateFavorite(userId: userId, eventId: widget.event.eventId);
          } else {
            await LocalDatabase.deleteFavorite(userId: userId, eventId: widget.event.eventId);
          }
        }

        setState(() {
          _isFavorite = newValue;
        });

        final prefs = await SharedPreferences.getInstance();
        final key = 'event_favorite_${widget.event.eventId}';
        await prefs.setBool(key, newValue);

        HomeWidgetService.updateWidgetWithFavoriteEvents();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.transparent,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
              ),
              elevation: 0,
              padding: EdgeInsets.zero,
              content: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryButton.withOpacity(0.9),
                      AppColors.secondaryBackground.withOpacity(0.8),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primaryButton.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryButton.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                  Icon(
                    newValue ? Icons.star : Icons.star_border,
                    color: Colors.white,
                    size: 24,
                  ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        newValue 
                          ? 'Événement ajouté aux favoris'
                          : 'Événement retiré des favoris',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Erreur lors de la sauvegarde du favori: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _openNavigationApp() async {
    if (widget.event.latitude == null || widget.event.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordonnées GPS non disponibles')),
      );
      return;
    }

    final double lat = widget.event.latitude!;
    final double lng = widget.event.longitude!;

    // Utiliser le schéma geo: qui ouvrira le choix Android pour sélectionner l'application GPS
    final geoUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    
    try {
      await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir l\'application de navigation')),
        );
      }
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'event_notification_${widget.event.eventId}';
      await prefs.setBool(key, enabled);
      setState(() {
        _notificationsEnabled = enabled;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.transparent,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
            ),
            elevation: 0,
            padding: EdgeInsets.zero,
            content: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryButton.withOpacity(0.9),
                    AppColors.secondaryBackground.withOpacity(0.8),
                  ],
                ),
                border: Border.all(
                  color: AppColors.primaryButton.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryButton.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    enabled ? Icons.notifications_active : Icons.notifications_off,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      enabled 
                        ? 'Notifications activées pour cet événement'
                        : 'Notifications désactivées pour cet événement',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      print('Erreur lors de la sauvegarde de la préférence de notification: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();


    
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;


    final expandedHeight = 200.0;
    final currentScroll = _scrollController.offset;
    final opacity = (currentScroll / expandedHeight).clamp(0.0, 1.0);
    
    setState(() {
      _appBarOpacity = opacity;
    });
  }

  void _scrollToMap() {
    final context = _mapKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getPrimaryBackground(context),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Bloquer le scroll si on interagit avec la carte
          if (_isInteractingWithMap && notification is ScrollUpdateNotification) {
            return true; // Consommer la notification pour empêcher le scroll
          }
          return false;
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: _isInteractingWithMap 
              ? const NeverScrollableScrollPhysics() 
              : const AlwaysScrollableScrollPhysics(),
        slivers: [

          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.getMenuBackground(context),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryButton,
                        AppColors.secondaryBackground,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryButton.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            titleSpacing: 0,
            actions: [

              Padding(
                padding: const EdgeInsets.all(8.0),
                child: InkWell(
                  onTap: _toggleFavorite,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isFavorite 
                        ? AppColors.primaryButton.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isFavorite 
                          ? AppColors.primaryButton
                          : Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _isFavorite 
                        ? Icons.star 
                        : Icons.star_border,
                      color: _isFavorite 
                        ? AppColors.primaryButton 
                        : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(8.0),
                child: InkWell(
                  onTap: () => _toggleNotifications(!_notificationsEnabled),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _notificationsEnabled 
                        ? AppColors.primaryButton.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _notificationsEnabled 
                          ? AppColors.primaryButton
                          : Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _notificationsEnabled 
                        ? Icons.notifications_active 
                        : Icons.notifications_off,
                      color: _notificationsEnabled 
                        ? AppColors.primaryButton 
                        : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(8.0),
                child: InkWell(
                  onTap: _openNavigationApp,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.gps_fixed,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.zero,
              centerTitle: false,
              title: Padding(
                padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    widget.event.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.center,
                    softWrap: true,
                  ),
                ),
              ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [

                        widget.event.imageUrl != null && widget.event.imageUrl!.isNotEmpty
                            ? FlexibleImage(
                                imageUrl: widget.event.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          AppColors.getMenuBackground(context),
                                          AppColors.getCardBackground(context),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.event,
                                        size: 80,
                                        color: AppColors.primaryButton,
                                      ),
                                    ),
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          AppColors.getMenuBackground(context),
                                          AppColors.getCardBackground(context),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.primaryButton,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppColors.getMenuBackground(context),
                                      AppColors.getCardBackground(context),
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.event,
                                    size: 80,
                                    color: AppColors.primaryButton,
                                  ),
                                ),
                              ),

                        AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          color: Colors.black.withOpacity(0.4 + (_appBarOpacity * 0.4)),


                        ),
                      ],
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Card(
                    color: AppColors.getCardBackground(context),
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
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryButton.withOpacity(0.15),
                            blurRadius: 10,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.calendar_today,
                          color: AppColors.primaryButton,
                        ),
                        title: Text(
                          _formatDate(widget.event.startAt.toLocal()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        subtitle: Text(
                          _formatTime(widget.event.startAt.toLocal()),
                          style: TextStyle(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    color: AppColors.getCardBackground(context),
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
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryButton.withOpacity(0.15),
                            blurRadius: 10,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.location_on,
                          color: AppColors.primaryButton,
                        ),
                        title: Text(
                          widget.event.place,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        subtitle: Text(
                          'Tap pour voir sur la carte',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _isMapExpanded = !_isMapExpanded;
                          });

                          if (_isMapReady && _mapController != null) {
                            _mapController!.setZoom(zoomLevel: _isMapExpanded ? 15.0 : 13.0);
                          }

                          Future.delayed(const Duration(milliseconds: 350), () {
                            _scrollToMap();
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (widget.event.description != null && widget.event.description!.isNotEmpty) ...[
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryButton,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.event.description!,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  AnimatedContainer(
                    key: _mapKey,
                    duration: const Duration(milliseconds: 300),
                    height: _isMapExpanded ? 400 : 200,
                    child: Card(
                      color: AppColors.getCardBackground(context),
                      clipBehavior: Clip.antiAlias,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: AppColors.primaryButton.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      shadowColor: AppColors.primaryButton.withOpacity(0.3),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
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
                        child: Stack(
                        children: [

                          _mapController != null
                              ? Listener(
                                  // Détecter les gestes de pan (horizontaux et verticaux) pour désactiver le scroll
                                  onPointerDown: (event) {
                                    setState(() {
                                      _isInteractingWithMap = true;
                                    });
                                  },
                                  onPointerMove: (event) {
                                    // Si mouvement détecté, garder l'interaction active et bloquer le scroll
                                    if (event.delta.dx.abs() > 2 || event.delta.dy.abs() > 2) {
                                      _scrollController.jumpTo(_scrollController.offset);
                                    }
                                  },
                                  onPointerUp: (event) {
                                    // Délai pour permettre les gestes de zoom
                                    Future.delayed(const Duration(milliseconds: 150), () {
                                      if (mounted) {
                                        setState(() {
                                          _isInteractingWithMap = false;
                                        });
                                      }
                                    });
                                  },
                                  onPointerCancel: (event) {
                                    setState(() {
                                      _isInteractingWithMap = false;
                                    });
                                  },
                                  // Ne pas bloquer les gestes, juste les détecter
                                  behavior: HitTestBehavior.translucent,
                                  child: OSMFlutter(
                                    controller: _mapController!,
                                    onMapIsReady: (isReady) {
                                      if (mounted) {
                                        MapService().setReady(true);
                                        setState(() {
                                          _isMapReady = true;
                                        });
                                        
                                        // Centrer la carte sur l'événement si coordonnées disponibles
                                        if (isReady && widget.event.latitude != null && widget.event.longitude != null) {
                                          Future.delayed(const Duration(milliseconds: 500), () {
                                            if (mounted && _mapController != null) {
                                              _mapController!.goToLocation(
                                                GeoPoint(
                                                  latitude: widget.event.latitude!,
                                                  longitude: widget.event.longitude!,
                                                ),
                                              );
                                            }
                                          });
                                        }
                                      }
                                    },
                                    osmOption: OSMOption(
                                      zoomOption: ZoomOption(
                                        initZoom: _isMapExpanded ? 15 : 13,
                                        minZoomLevel: 3,
                                        maxZoomLevel: 19,
                                        stepZoom: 1.0,
                                      ),
                                      staticPoints: _pins,
                                      roadConfiguration: const RoadOption(
                                        roadColor: Colors.blueAccent,
                                      ),
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ),

                          if (!_isMapReady)
                            IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.getMenuBackground(context),
                                      AppColors.getPrimaryBackground(context),
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(
                                        color: AppColors.primaryButton,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Chargement de la carte...',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.getTextPrimary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryButton.withOpacity(0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: FloatingActionButton.small(
                                backgroundColor: AppColors.primaryButton,
                                onPressed: () {
                                  setState(() {
                                    _isMapExpanded = !_isMapExpanded;
                                  });

                                  if (_isMapReady && _mapController != null) {
                                    _mapController!.setZoom(zoomLevel: _isMapExpanded ? 15.0 : 13.0);
                                  }

                                  Future.delayed(const Duration(milliseconds: 350), () {
                                    _scrollToMap();
                                  });
                                },
                                child: Icon(
                                  _isMapExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
                                  color: AppColors.getTextPrimary(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const List<String> days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    const List<String> months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 
                                'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    
    final weekday = days[date.weekday - 1];
    final month = months[date.month - 1];
    
    return '$weekday ${date.day} $month ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}