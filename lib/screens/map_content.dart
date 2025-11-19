import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../services/map_service.dart';
import '../widgets/shared_map_widget.dart';
import '../api_client.dart';
import '../services/connectivity_service.dart';
import '../services/local_database.dart';
import '../services/sync_service.dart';
import '../token_storage.dart';
import '../models/user_model.dart';
import '../utils/app_colors.dart';
import 'events_content.dart';
import 'event_details_screen.dart';

// Log global pour vérifier que le fichier est bien chargé
void _logMapContentLoaded() {
  print(' ========================================');
  print(' FICHIER map_content.dart CHARGÉ');
  print(' ========================================');
  debugPrint(' FICHIER map_content.dart CHARGÉ');
}

// Appeler la fonction au chargement du fichier
final _ = _logMapContentLoaded();

/// Painter personnalisé pour afficher l'image de profil
class _ProfilePicturePainter extends CustomPainter {
  final ui.Image image;
  
  _ProfilePicturePainter(this.image);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      paint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MapContent extends StatefulWidget {
  final bool isActive;
  
  const MapContent({super.key, this.isActive = true});

  @override
  State<MapContent> createState() {
    print(' ========================================');
    print(' MapContent.createState() appelé - WIDGET CRÉÉ');
    print(' ========================================');
    debugPrint(' MapContent.createState() appelé');
    return _MapContentState();
  }
}

class _MapContentState extends State<MapContent> with AutomaticKeepAliveClientMixin {
  MapController? controller;
  bool _isMapReady = false;
  List<EventItem> _events = [];
  bool _isLoadingEvents = true;
  Map<String, EventItem> _eventMap = {}; // Pour retrouver l'événement par son ID de pin
  bool _listenerSetup = false; // Pour éviter d'ajouter le listener plusieurs fois
  bool _isBottomSheetOpen = false; // Pour éviter d'ouvrir plusieurs fois la bottom sheet
  Map<int, String?> _organizerProfilePictures = {}; // Cache des images de profil des organisateurs
  Map<int, Uint8List?> _organizerProfilePicturesBytes = {}; // Cache des bytes des images de profil
  List<StaticPositionGeoPoint> _pins = []; // Pins avec images de profil

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    print(' ========== INIT MAP CONTENT ==========');
    debugPrint(' ========== INIT MAP CONTENT ==========');
    print(' Initialisation de MapContent');
    debugPrint(' Initialisation de MapContent');

    controller = MapService().getController();
    print(' Controller obtenu: ${controller != null ? "OK" : "NULL"}');
    debugPrint(' Controller obtenu: ${controller != null ? "OK" : "NULL"}');

    if (MapService().isReady) {
      _isMapReady = true;
      print(' Carte déjà prête');
      debugPrint(' Carte déjà prête');
    } else {
      print(' Carte pas encore prête');
      debugPrint(' Carte pas encore prête');
    }
    
    print(' Démarrage du chargement des événements...');
    debugPrint(' Démarrage du chargement des événements...');
    _loadEvents();
    _setupMapListener();
    print(' ========== FIN INIT ==========');
    debugPrint(' ========== FIN INIT ==========');
  }

  void _setupMapListener() {
    if (controller == null) return;
    
    // TOUJOURS retirer le listener d'abord pour éviter les doublons
    // Retirer même si _listenerSetup est false, au cas où il serait attaché ailleurs
    try {
      controller!.listenerMapSingleTapping.removeListener(_onMapTapHandler);
    } catch (e) {
      // Ignorer si le listener n'était pas attaché
    }
    _listenerSetup = false;
    
    // N'ajouter le listener que si le widget est actif
    if (widget.isActive) {
      // S'assurer qu'on n'ajoute pas le listener plusieurs fois
      try {
        controller!.listenerMapSingleTapping.removeListener(_onMapTapHandler);
      } catch (e) {
        // Ignorer
      }
      controller!.listenerMapSingleTapping.addListener(_onMapTapHandler);
      _listenerSetup = true;
      print(' Listener ajouté (MapContent, actif)');
    } else {
      print(' Listener non ajouté (MapContent, inactif)');
    }
  }

  void _onMapTapHandler() async {
    // Ne traiter que si ce widget est actif
    if (!widget.isActive || !mounted) {
      return;
    }
    
    print(' _onMapTapHandler() appelé (MapContent)');
    
    if (controller == null || !mounted) {
      print(' Controller null ou widget non monté (MapContent)');
      return;
    }
    
    final tappedPoint = controller!.listenerMapSingleTapping.value;
    print(' tappedPoint: $tappedPoint');
    
    if (tappedPoint != null && mounted) {
      print(' Clic détecté sur la carte: (${tappedPoint.latitude}, ${tappedPoint.longitude})');
      
      // Obtenir le niveau de zoom actuel pour calculer la taille du pin en pixels
      double? currentZoom;
      try {
        currentZoom = await controller!.getZoom();
      } catch (e) {
        print(' Impossible d\'obtenir le zoom, utilisation du zoom par défaut: $e');
        currentZoom = 13.0; // Zoom par défaut
      }
      
      // Taille du pin en pixels (72 pixels)
      const double pinSizePixels = 72.0;
      // Convertir la taille en pixels en distance en mètres selon le zoom
      // Formule : mètres par pixel = (156543.03392 * cos(latitude)) / (2^zoom)
      final double metersPerPixel = (156543.03392 * math.cos(tappedPoint.latitude * math.pi / 180)) / math.pow(2, currentZoom);
      // Zone de clic = taille exacte du pin (rayon = demi-taille du pin)
      // Le listener se déclenche même si on clique sur le pin, donc on utilise la taille exacte
      final double clickAreaMeters = (pinSizePixels * metersPerPixel) / 2;
      
      print(' Zoom: $currentZoom, Zone de clic: ${clickAreaMeters.toStringAsFixed(2)}m (taille exacte du pin)');
      
      // Trouver l'événement le plus proche du point cliqué
      EventItem? nearestEvent;
      double minDistance = double.infinity;

      for (var event in _events) {
        if (event.latitude != null && event.longitude != null) {
          final distance = _calculateDistance(
            tappedPoint.latitude,
            tappedPoint.longitude,
            event.latitude!,
            event.longitude!,
          );

          print('    Distance à ${event.title}: ${distance.toStringAsFixed(2)}m');

          // Utiliser la zone de clic calculée dynamiquement
          if (distance < clickAreaMeters && distance < minDistance) {
            minDistance = distance;
            nearestEvent = event;
          }
        }
      }

      if (nearestEvent != null && mounted) {
        print(' Pin cliqué: ${nearestEvent.title} (distance: ${minDistance.toStringAsFixed(2)}m)');
        // Afficher une bottom sheet avec les informations de l'événement
        _showEventInfoBottomSheet(nearestEvent);
      } else {
        print(' Aucun pin détecté à proximité');
      }
    }
  }

  Future<void> _openNavigationApp(EventItem event) async {
    if (event.latitude == null || event.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordonnées GPS non disponibles')),
      );
      return;
    }

    final double lat = event.latitude!;
    final double lng = event.longitude!;

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

  void _showEventInfoBottomSheet(EventItem event) {
    // Éviter d'ouvrir plusieurs fois la bottom sheet
    if (_isBottomSheetOpen) {
      print(' Bottom sheet déjà ouverte, ignore le clic');
      return;
    }
    
    _isBottomSheetOpen = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.getCardBackground(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.secondaryText.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Titre de l'événement
            Text(
              event.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            // Date et heure
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: AppColors.primaryButton,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(event.startAt.toLocal()),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 18,
                  color: AppColors.primaryButton,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(event.startAt.toLocal()),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Bouton Voir les détails
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Fermer la bottom sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailsScreen(event: event),
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline),
                label: const Text('Voir les détails'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryButton,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Bouton GPS
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Fermer la bottom sheet
                  _openNavigationApp(event);
                },
                icon: const Icon(Icons.gps_fixed),
                label: const Text('Itinéraire'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryButton,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: AppColors.primaryButton),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    ).whenComplete(() {
      // Réinitialiser le flag quand la bottom sheet est fermée
      _isBottomSheetOpen = false;
    });
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

  // Calculer la distance entre deux points en mètres (formule de Haversine)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Rayon de la Terre en mètres
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (MapService().isReady && !_isMapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isMapReady = true;
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(MapContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Si le widget devient inactif, retirer le listener
    if (!widget.isActive && oldWidget.isActive && _listenerSetup && controller != null) {
      controller!.listenerMapSingleTapping.removeListener(_onMapTapHandler);
      _listenerSetup = false;
      print(' Listener retiré (widget devenu inactif)');
    }
    
    // Si le widget redevient actif, réajouter le listener
    if (widget.isActive && !oldWidget.isActive) {
      _setupMapListener();
    }
    
    // Si la carte devient active, recharger les événements
    if (widget.isActive && !oldWidget.isActive) {
      print(' Carte devenue active, rechargement des événements...');
      debugPrint(' Carte devenue active, rechargement des événements...');
      _loadEvents();
    }
  }

  Future<void> _loadEvents() async {
    print(' _loadEvents() appelé');
    debugPrint(' _loadEvents() appelé');
    
    setState(() {
      _isLoadingEvents = true;
    });

    try {
      print(' ========== CHARGEMENT DES ÉVÉNEMENTS ==========');
      debugPrint(' ========== CHARGEMENT DES ÉVÉNEMENTS ==========');
      print(' Chargement des événements pour la carte...');
      debugPrint(' Chargement des événements pour la carte...');
      
      // Vérifier la connectivité réseau
      final isOnline = await ConnectivityService.checkConnectivity();
      List<EventItem> allEvents = [];
      
      if (isOnline) {
        // En ligne -> charger depuis l'API
        try {
          final response = await ApiClient.getEvents(page: 1, pageSize: 200);
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final eventsData = data['data'] as List<dynamic>;
            
            debugPrint(' Événements reçus de l\'API: ${eventsData.length}');
            
            // Sauvegarder dans le cache local
            try {
              final eventsList = eventsData
                  .map((e) => e is Map<String, dynamic> ? e : e as Map<String, dynamic>)
                  .toList();
              await LocalDatabase.saveEvents(eventsList);
            } catch (e) {
              print(' Erreur lors de la sauvegarde dans le cache: $e');
            }
            
            allEvents = eventsData
                .map((json) => EventItem.fromJson(json as Map<String, dynamic>))
                .toList();
          }
        } catch (e) {
          print(' Erreur API, chargement depuis le cache: $e');
          debugPrint(' Erreur API, chargement depuis le cache: $e');
          // En cas d'erreur API, charger depuis le cache
          final eventsJson = await LocalDatabase.getAllEvents();
          allEvents = eventsJson
              .map((json) => EventItem.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      } else {
        // Hors ligne -> charger depuis le cache local
        print(' Hors ligne, chargement depuis le cache local');
        debugPrint(' Hors ligne, chargement depuis le cache local');
        final eventsJson = await LocalDatabase.getAllEvents();
        allEvents = eventsJson
            .map((json) => EventItem.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      
      print(' ${allEvents.length} événements chargés');
      debugPrint(' ${allEvents.length} événements chargés');
      
      // Synchroniser les utilisateurs pour avoir les images de profil à jour
      if (isOnline) {
        try {
          await SyncService.syncUsersFromApi();
        } catch (e) {
          print(' Erreur lors de la synchronisation des utilisateurs: $e');
        }
      }
      
      // Afficher les événements
      await _processAndDisplayEvents(allEvents);
    } catch (e) {
      debugPrint(' Erreur chargement événements pour la carte: $e');
      debugPrint(' Stack trace: ${StackTrace.current}');
      setState(() {
        _events = [];
        _isLoadingEvents = false;
      });
    }
  }

  Future<void> _processAndDisplayEvents(List<EventItem> allEvents) async {
      
      // Analyser les événements avant filtrage
      int withCoordinates = 0;
      int withoutCoordinates = 0;
      for (var event in allEvents) {
        if (event.latitude != null && event.longitude != null) {
          withCoordinates++;
          debugPrint('    ${event.title}: lat=${event.latitude}, lng=${event.longitude}');
        } else {
          withoutCoordinates++;
          debugPrint('    ${event.title}: PAS DE COORDONNÉES (location: ${event.location ?? "null"})');
        }
      }
      
      debugPrint(' Résumé: $withCoordinates avec coordonnées, $withoutCoordinates sans coordonnées');
      
      // Filtrer uniquement les événements avec coordonnées GPS
      final events = allEvents
          .where((event) {
            final hasCoords = event.latitude != null && event.longitude != null;
            if (!hasCoords) {
              debugPrint('    Filtré: ${event.title} (pas de coordonnées)');
            }
            return hasCoords;
          })
          .toList();

      print(' Événements avec coordonnées après filtrage: ${events.length}');
      debugPrint(' Événements avec coordonnées après filtrage: ${events.length}');

      // Créer un map pour retrouver rapidement les événements par leur ID de pin
      _eventMap.clear();
      for (var event in events) {
        _eventMap['event_${event.eventId}'] = event;
        debugPrint('    Pin créé pour: ${event.title} (${event.latitude}, ${event.longitude})');
      }

      setState(() {
        _events = events;
        _isLoadingEvents = false;
      });
      
      // Charger les images de profil des organisateurs AVANT de construire les pins
      print(' Chargement des images de profil des organisateurs...');
      debugPrint(' Chargement des images de profil des organisateurs...');
      await _loadOrganizerProfilePictures();
      print(' Images de profil chargées: ${_organizerProfilePictures.length} URLs, ${_organizerProfilePicturesBytes.length} bytes');
      debugPrint(' Images de profil chargées: ${_organizerProfilePictures.length} URLs, ${_organizerProfilePicturesBytes.length} bytes');
      
      // Construire les pins avec les images de profil
      _pins = await _buildEventPins();
      
      // Mettre à jour l'état pour reconstruire les pins avec les images
      if (mounted) {
        setState(() {});
      }
      
      print(' ${events.length} pins prêts à être affichés sur la carte');
      debugPrint(' ${events.length} pins prêts à être affichés sur la carte');
      print(' ========== FIN CHARGEMENT ==========');
      debugPrint(' ========== FIN CHARGEMENT ==========');
      
      // Forcer la reconstruction du widget pour afficher les nouveaux pins
      if (mounted) {
        print(' Forcer setState() pour reconstruire la carte avec ${events.length} événements');
        debugPrint(' Forcer setState() pour reconstruire la carte avec ${events.length} événements');
        setState(() {
          // Le changement d'état forcera la reconstruction avec la nouvelle ValueKey
      });
    }
  }


  void _onMapTap(GeoPoint point) {
    // Gérer le tap sur la carte si nécessaire
  }

  // Méthode non utilisée - conservée pour référence
  void _onPinTap(String pinId) {
    // Ne fait rien - les clics sont gérés par _setupMapListener
  }

  @override
  void dispose() {
    if (controller != null && _listenerSetup) {
      controller!.listenerMapSingleTapping.removeListener(_onMapTapHandler);
      _listenerSetup = false;
    }
    super.dispose();
  }


  /// Récupère les images de profil des organisateurs pour les événements
  Future<void> _loadOrganizerProfilePictures() async {
    try {
      final organizerIds = <int>{};
      
      // Collecter tous les IDs d'organisateurs uniques
      for (var event in _events) {
        if (event.createdBy != null && event.createdBy!.isNotEmpty) {
          final createdById = int.tryParse(event.createdBy!.trim());
          if (createdById != null) {
            organizerIds.add(createdById);
          }
        }
      }
      
      print(' IDs d\'organisateurs à charger: ${organizerIds.toList()}');
      debugPrint(' IDs d\'organisateurs à charger: ${organizerIds.toList()}');
      
      // Récupérer les images de profil depuis la base de données locale ou l'API
      for (var organizerId in organizerIds) {
        if (!_organizerProfilePictures.containsKey(organizerId)) {
          try {
            print('    Recherche de l\'image de profil pour l\'organisateur $organizerId...');
            debugPrint('    Recherche de l\'image de profil pour l\'organisateur $organizerId...');
            
            // Essayer d'abord depuis le cache local
            var user = await LocalDatabase.getUserById(organizerId);
            print('    Utilisateur trouvé dans le cache local: ${user != null ? "OUI" : "NON"}');
            debugPrint('    Utilisateur trouvé dans le cache local: ${user != null ? "OUI" : "NON"}');
            
            // Si pas dans le cache OU si l'utilisateur n'a pas d'image de profil, récupérer depuis l'API
            final needsUpdate = user == null || user.profilePicture == null || user.profilePicture!.isEmpty;
            if (needsUpdate) {
              final isOnline = await ConnectivityService.checkConnectivity();
              print('    En ligne: $isOnline, besoin de mise à jour: $needsUpdate');
              debugPrint('    En ligne: $isOnline, besoin de mise à jour: $needsUpdate');
              if (isOnline) {
                try {
                  // Récupérer tous les utilisateurs depuis l'API publique pour avoir les organisateurs
                  print('    Récupération de tous les utilisateurs depuis l\'API publique...');
                  debugPrint('    Récupération de tous les utilisateurs depuis l\'API publique...');
                  final response = await ApiClient.getAllUsersPublic();
                  if (response.statusCode == 200) {
                    final usersData = jsonDecode(response.body) as List<dynamic>;
                    print('    ${usersData.length} utilisateurs reçus de l\'API publique');
                    debugPrint('    ${usersData.length} utilisateurs reçus de l\'API publique');
                    for (var userData in usersData) {
                      final userMap = userData as Map<String, dynamic>;
                      final userId = userMap['user_id'] as int? ?? userMap['id'] as int?;
                      if (userId == organizerId) {
                        print('    Données brutes de l\'utilisateur $organizerId: ${userMap.keys.toList()}');
                        debugPrint('    Données brutes de l\'utilisateur $organizerId: ${userMap.keys.toList()}');
                        print('    profile_picture dans les données: ${userMap['profile_picture']}');
                        debugPrint('    profile_picture dans les données: ${userMap['profile_picture']}');
                        final userFromApi = UserModel.fromApi(userMap);
                        await LocalDatabase.insertOrUpdateUser(userFromApi);
                        user = userFromApi;
                        print('    Utilisateur $organizerId trouvé et synchronisé depuis l\'API publique');
                        debugPrint('    Utilisateur $organizerId trouvé et synchronisé depuis l\'API publique');
                        print('    profilePicture après fromApi: ${userFromApi.profilePicture}');
                        debugPrint('    profilePicture après fromApi: ${userFromApi.profilePicture}');
                        break;
                      }
                    }
                    // Si toujours pas trouvé, réessayer depuis le cache
                    if (user == null) {
                      user = await LocalDatabase.getUserById(organizerId);
                      print('    Utilisateur trouvé après synchronisation publique: ${user != null ? "OUI" : "NON"}');
                      debugPrint('    Utilisateur trouvé après synchronisation publique: ${user != null ? "OUI" : "NON"}');
                    }
                  } else {
                    print('    Erreur HTTP ${response.statusCode} lors de la récupération des utilisateurs publics');
                    debugPrint('    Erreur HTTP ${response.statusCode} lors de la récupération des utilisateurs publics');
                  }
                } catch (e) {
                  print('Erreur lors de la récupération depuis l\'API pour l\'organisateur $organizerId: $e');
                  debugPrint('Erreur lors de la récupération depuis l\'API pour l\'organisateur $organizerId: $e');
                }
              }
            }
            
            if (user != null) {
              print('    Utilisateur trouvé: ${user.email}, profilePicture: ${user.profilePicture ?? "NULL"}');
              debugPrint('    Utilisateur trouvé: ${user.email}, profilePicture: ${user.profilePicture ?? "NULL"}');
              
              if (user.profilePicture != null && user.profilePicture!.isNotEmpty) {
                _organizerProfilePictures[organizerId] = user.profilePicture;
                print('    Image de profil trouvée pour l\'organisateur $organizerId: ${user.profilePicture}');
                debugPrint('    Image de profil trouvée pour l\'organisateur $organizerId: ${user.profilePicture}');
              
                // Charger l'image et la convertir en bytes
                try {
                  final imageUrl = user.profilePicture!;
                  final cleanImageUrl = ApiClient.cleanUrl(imageUrl);
                  print('    Chargement de l\'image depuis: $cleanImageUrl');
                  debugPrint('    Chargement de l\'image depuis: $cleanImageUrl');
                  final response = await http.get(Uri.parse(cleanImageUrl));
                  if (response.statusCode == 200) {
                    _organizerProfilePicturesBytes[organizerId] = response.bodyBytes;
                    print('    Image chargée avec succès pour l\'organisateur $organizerId (${response.bodyBytes.length} bytes)');
                    debugPrint('    Image chargée avec succès pour l\'organisateur $organizerId (${response.bodyBytes.length} bytes)');
                  } else {
                    print('    Erreur HTTP ${response.statusCode} lors du chargement de l\'image pour l\'organisateur $organizerId');
                    debugPrint('    Erreur HTTP ${response.statusCode} lors du chargement de l\'image pour l\'organisateur $organizerId');
                  }
                } catch (e) {
                  print('    Erreur lors du chargement de l\'image pour l\'organisateur $organizerId: $e');
                  debugPrint('    Erreur lors du chargement de l\'image pour l\'organisateur $organizerId: $e');
                }
              } else {
                print('    Pas d\'image de profil pour l\'organisateur $organizerId');
                debugPrint('    Pas d\'image de profil pour l\'organisateur $organizerId');
              }
            } else {
              print('    Utilisateur non trouvé pour l\'organisateur $organizerId');
              debugPrint('    Utilisateur non trouvé pour l\'organisateur $organizerId');
            }
          } catch (e) {
            print('Erreur lors de la récupération de l\'image de profil pour l\'organisateur $organizerId: $e');
          }
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des images de profil: $e');
    }
  }
  
  /// Convertit une image en bytes en une icône personnalisée
  /// Note: Cette méthode n'est pas utilisée car MarkerIcon n'accepte que des Icon
  /// Mais elle est conservée pour une utilisation future si une alternative est trouvée
  Future<Icon?> _createIconFromImageBytes(Uint8List? imageBytes) async {
    if (imageBytes == null || imageBytes.isEmpty) return null;
    
    try {
      // Charger l'image depuis les bytes
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      // Convertir l'image en bytes PNG
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      
      // Créer une icône personnalisée avec les bytes
      // Note: Cette approche ne fonctionne pas directement avec MarkerIcon
      // Il faudrait utiliser IconData avec un font personnalisé ou une autre approche
      return null;
    } catch (e) {
      print('Erreur lors de la conversion de l\'image en icône: $e');
      return null;
    }
  }

  Future<List<StaticPositionGeoPoint>> _buildEventPins() async {
    // Utiliser print ET debugPrint pour être sûr que les logs apparaissent
    print(' ========== CONSTRUCTION DES PINS ==========');
    debugPrint(' ========== CONSTRUCTION DES PINS ==========');
    print(' Construction de ${_events.length} pins pour la carte...');
    debugPrint(' Construction de ${_events.length} pins pour la carte...');
    
    final pins = <StaticPositionGeoPoint>[];
    
    for (var event in _events) {
      if (event.latitude == null || event.longitude == null) {
        print('    Événement ${event.title} ignoré (coordonnées manquantes)');
        debugPrint('    Événement ${event.title} ignoré (coordonnées manquantes)');
        continue;
      }
      
      // Récupérer l'image de profil de l'organisateur si disponible
      String? profilePictureUrl;
      Uint8List? profilePictureBytes;
      if (event.createdBy != null && event.createdBy!.isNotEmpty) {
        final createdById = int.tryParse(event.createdBy!.trim());
        if (createdById != null) {
          profilePictureUrl = _organizerProfilePictures[createdById];
          profilePictureBytes = _organizerProfilePicturesBytes[createdById];
          print('    Événement ${event.title} - Organisateur: $createdById, URL: ${profilePictureUrl != null ? "OUI" : "NON"}, Bytes: ${profilePictureBytes != null ? "${profilePictureBytes.length} bytes" : "NON"}');
          debugPrint('    Événement ${event.title} - Organisateur: $createdById, URL: ${profilePictureUrl != null ? "OUI" : "NON"}, Bytes: ${profilePictureBytes != null ? "${profilePictureBytes.length} bytes" : "NON"}');
        }
      }
      
      // Créer l'icône du pin : utiliser l'image de profil si disponible
      Widget? pinIconWidget;
      Icon? pinIcon;
      
      if (profilePictureBytes != null && profilePictureBytes.isNotEmpty) {
        // Utiliser l'image de profil de l'organisateur avec Image.memory
        print('    Création du widget avec Image.memory pour ${event.title}');
        debugPrint('    Création du widget avec Image.memory pour ${event.title}');
        pinIconWidget = Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primaryButton,
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
              profilePictureBytes,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // En cas d'erreur, utiliser l'icône par défaut
                return Icon(
            Icons.event,
            color: AppColors.primaryButton,
                  size: 72,
                );
              },
            ),
          ),
        );
      } else if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
        // Si on a l'URL mais pas les bytes, utiliser Image.network
        print('    Création du widget avec Image.network pour ${event.title}');
        debugPrint('    Création du widget avec Image.network pour ${event.title}');
        pinIconWidget = Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primaryButton,
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
              profilePictureUrl,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // En cas d'erreur, utiliser l'icône par défaut
                return Icon(
                  Icons.event,
                  color: AppColors.primaryButton,
                  size: 72,
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                // Afficher un indicateur de chargement pendant le téléchargement
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryButton),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        // Icône par défaut si pas d'image de profil
        pinIcon = Icon(
          Icons.event,
          color: AppColors.primaryButton,
          size: 72,
        );
      }
      
      // Créer le MarkerIcon avec iconWidget si disponible, sinon utiliser icon
      final MarkerIcon markerIcon;
      if (pinIconWidget != null) {
        // Utiliser iconWidget pour afficher l'image de profil
        print('    Création du pin avec iconWidget pour ${event.title}');
        debugPrint('    Création du pin avec iconWidget pour ${event.title}');
        markerIcon = MarkerIcon(
          iconWidget: pinIconWidget,
        );
      } else {
        // Utiliser icon par défaut
        print('    Création du pin avec icon par défaut pour ${event.title}');
        debugPrint('    Création du pin avec icon par défaut pour ${event.title}');
        markerIcon = MarkerIcon(
          icon: pinIcon ?? Icon(
            Icons.event,
            color: AppColors.primaryButton,
            size: 72,
          ),
        );
      }
      
      final pin = StaticPositionGeoPoint(
        'event_${event.eventId}',
        markerIcon,
        [GeoPoint(
          latitude: event.latitude!,
          longitude: event.longitude!,
        )],
      );
      
      pins.add(pin);
      print('    Pin créé: ${event.title} à (${event.latitude}, ${event.longitude})${profilePictureUrl != null ? " avec image de profil" : ""}');
      debugPrint('    Pin créé: ${event.title} à (${event.latitude}, ${event.longitude})${profilePictureUrl != null ? " avec image de profil" : ""}');
    }
    
    print(' ${pins.length} pins construits et prêts à être affichés');
    debugPrint(' ${pins.length} pins construits et prêts à être affichés');
    print(' Pins passés à OSMFlutter: ${pins.map((p) => p.id).join(', ')}');
    debugPrint(' Pins passés à OSMFlutter: ${pins.map((p) => p.id).join(', ')}');
    print(' ========== FIN CONSTRUCTION PINS ==========');
    debugPrint(' ========== FIN CONSTRUCTION PINS ==========');
    return pins;
  }
  

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    print(' ========== BUILD MAP CONTENT ==========');
    debugPrint(' ========== BUILD MAP CONTENT ==========');
    print(' Nombre d\'événements: ${_events.length}');
    debugPrint(' Nombre d\'événements: ${_events.length}');
    print(' Carte prête: $_isMapReady');
    debugPrint(' Carte prête: $_isMapReady');
    print(' Chargement: $_isLoadingEvents');
    debugPrint(' Chargement: $_isLoadingEvents');
    
    // Utiliser les pins stockés dans l'état
    final pins = _pins;
    print(' BUILD: ${pins.length} pins construits dans build()');
    debugPrint(' BUILD: ${pins.length} pins construits dans build()');
    
    return Scaffold(
      body: Stack(
        children: [
          // Utiliser une ValueKey pour forcer la reconstruction quand les événements changent
          // La clé change quand le nombre d'événements ou leurs IDs changent
          KeyedSubtree(
            key: ValueKey('map_${_events.length}_${_events.map((e) => e.eventId).join('_')}'),
            child: SharedMapWidget(
                key: ValueKey('shared_map_${widget.isActive}_${_events.length}'), // Clé unique pour forcer la création
                visible: widget.isActive,
                customOption: OSMOption(
              zoomOption: const ZoomOption(
                initZoom: 13,
                minZoomLevel: 3,
                maxZoomLevel: 19,
                stepZoom: 1.0,
              ),
              staticPoints: pins,
              userLocationMarker: UserLocationMaker(
                personMarker: const MarkerIcon(
                  icon: Icon(
                    Icons.location_history_rounded,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                directionArrowMarker: const MarkerIcon(
                  icon: Icon(
                    Icons.double_arrow,
                    size: 48,
                  ),
                ),
              ),
              roadConfiguration: const RoadOption(
                roadColor: Colors.blueAccent,
              ),
            ),
            onMapReady: (isReady) {
              print(' onMapReady appelé: isReady=$isReady');
              debugPrint(' onMapReady appelé: isReady=$isReady');
              if (isReady) {
                print(' Carte prête, configuration du listener dans onMapReady...');
                debugPrint(' Carte prête, configuration du listener dans onMapReady...');
                // Attendre un peu pour que la carte soit complètement initialisée
                Future.delayed(const Duration(milliseconds: 1000), () {
                  if (mounted) {
                    // _setupMapListener() retire déjà l'ancien listener si nécessaire
                    _setupMapListener();
                  }
                });
              }
              if (isReady && mounted) {
                print(' ========== CARTE PRÊTE ==========');
                debugPrint(' ========== CARTE PRÊTE ==========');
                print(' Carte prête, ${_events.length} événements à afficher');
                debugPrint(' Carte prête, ${_events.length} événements à afficher');
                print(' Nombre de pins dans staticPoints: ${pins.length}');
                debugPrint(' Nombre de pins dans staticPoints: ${pins.length}');
                
                setState(() {
                  _isMapReady = true;
                });
                
                // Attendre un peu pour que la carte soit complètement chargée
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted && controller != null && _events.isNotEmpty) {
                    // Centrer la carte sur les événements si disponibles
                    final firstEvent = _events.first;
                    if (firstEvent.latitude != null && firstEvent.longitude != null) {
                      print(' Centrage de la carte sur: ${firstEvent.title} (${firstEvent.latitude}, ${firstEvent.longitude})');
                      debugPrint(' Centrage de la carte sur: ${firstEvent.title} (${firstEvent.latitude}, ${firstEvent.longitude})');
                      controller!.goToLocation(
                        GeoPoint(
                          latitude: firstEvent.latitude!,
                          longitude: firstEvent.longitude!,
                        ),
                      );
                    }
                  }
                });
              }
            },
            ),
          ),
        ],
      ),
    );
  }
}
