import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import '../utils/app_colors.dart';
import '../api_client.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../services/map_service.dart';
import '../services/local_database.dart';
import '../token_storage.dart';
import '../models/user_model.dart';
import '../widgets/shared_map_widget.dart';
import 'events_content.dart';
import 'event_details_screen.dart';

class HomeContent extends StatefulWidget {
  final String userName;
  final String userRole;
  final bool loading;
  final bool isActive;

  const HomeContent({
    super.key,
    required this.userName,
    required this.userRole,
    required this.loading,
    this.isActive = true,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> with AutomaticKeepAliveClientMixin {
  EventItem? _nextEvent;
  bool _isLoadingEvent = true;
  String? _errorEvent;
  List<EventItem> _favoriteEvents = [];
  bool _isLoadingFavorites = true;
  bool _hasLoadedFavorites = false;
  bool _wasActive = false;
  List<EventItem> _events = []; // Événements avec coordonnées GPS pour la carte
  bool _isLoadingEvents = false;
  MapController? _mapController;
  Map<String, EventItem> _eventMap = {}; // Pour retrouver l'événement par son ID de pin
  bool _listenerSetup = false; // Pour éviter d'ajouter le listener plusieurs fois
  bool _isBottomSheetOpen = false; // Pour éviter d'ouvrir plusieurs fois la bottom sheet
  Map<int, String?> _organizerProfilePictures = {}; // Cache des images de profil des organisateurs
  Map<int, Uint8List?> _organizerProfilePicturesBytes = {}; // Cache des bytes des images de profil
  List<StaticPositionGeoPoint> _pins = [
    // Pin "Angers" par défaut
    StaticPositionGeoPoint(
      "angers",
      const MarkerIcon(
        icon: Icon(
          Icons.location_city,
          color: Colors.red,
          size: 48,
        ),
      ),
      [GeoPoint(latitude: 47.4784, longitude: -0.5632)],
    ),
  ]; // Pins avec images de profil

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _wasActive = widget.isActive;
    _mapController = MapService().getController();
    _loadNextEvent();
    _loadFavorites();
    _hasLoadedFavorites = true;
    _loadEvents(); // Charger les événements pour la carte
    _setupMapListener(); // Configurer le listener pour les clics sur les pins
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_hasLoadedFavorites) {
      _loadFavorites();
    }
  }

  @override
  void didUpdateWidget(HomeContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si le widget devient inactif, retirer le listener
    if (!widget.isActive && oldWidget.isActive && _listenerSetup && _mapController != null) {
      _mapController!.listenerMapSingleTapping.removeListener(_onMapTapHandler);
      _listenerSetup = false;
      print(' Listener retiré (Home, widget devenu inactif)');
    }
    
    // Si le widget redevient actif, réajouter le listener
    if (widget.isActive && !_wasActive) {
      _loadFavorites();
      _loadNextEvent(); // Recharger le prochain événement quand la page redevient active
      _loadEvents(); // Recharger les événements pour la carte
      _setupMapListener(); // Réajouter le listener
    }
    _wasActive = widget.isActive;
  }

  @override
  void dispose() {
    if (_mapController != null && _listenerSetup) {
      _mapController!.listenerMapSingleTapping.removeListener(_onMapTapHandler);
      _listenerSetup = false;
    }
    super.dispose();
  }

  void _setupMapListener() {
    if (_mapController == null) return;
    
    // TOUJOURS retirer le listener d'abord pour éviter les doublons
    // Retirer même si _listenerSetup est false, au cas où il serait attaché ailleurs
    try {
      _mapController!.listenerMapSingleTapping.removeListener(_onMapTapHandler);
    } catch (e) {
      // Ignorer si le listener n'était pas attaché
    }
    _listenerSetup = false;
    
    // N'ajouter le listener que si le widget est actif
    if (widget.isActive) {
      // S'assurer qu'on n'ajoute pas le listener plusieurs fois
      try {
        _mapController!.listenerMapSingleTapping.removeListener(_onMapTapHandler);
      } catch (e) {
        // Ignorer
      }
      _mapController!.listenerMapSingleTapping.addListener(_onMapTapHandler);
      _listenerSetup = true;
      print(' Listener ajouté (HomeContent, actif)');
    } else {
      print(' Listener non ajouté (HomeContent, inactif)');
    }
  }

  void _onMapTapHandler() async {
    // Ne traiter que si ce widget est actif
    if (!widget.isActive || !mounted) {
      return;
    }
    
    print(' _onMapTapHandler() appelé (Home)');
    
    if (_mapController == null || !mounted) {
      print(' Controller null ou widget non monté (Home)');
      return;
    }
    
    final tappedPoint = _mapController!.listenerMapSingleTapping.value;
    print(' tappedPoint (Home): $tappedPoint');
    
    if (tappedPoint != null && mounted) {
      print(' Clic détecté sur la carte Home: (${tappedPoint.latitude}, ${tappedPoint.longitude})');
      
      // Obtenir le niveau de zoom actuel pour calculer la taille du pin en pixels
      double? currentZoom;
      try {
        currentZoom = await _mapController!.getZoom();
      } catch (e) {
        print(' Impossible d\'obtenir le zoom (Home), utilisation du zoom par défaut: $e');
        currentZoom = 13.0; // Zoom par défaut
      }
      
      // Taille du pin en pixels (72 pixels)
      const double pinSizePixels = 72.0;
      // Convertir la taille en pixels en distance en mètres selon le zoom
      // Formule : mètres par pixel = (156543.03392 * cos(latitude)) / (2^zoom)
      final double metersPerPixel = (156543.03392 * math.cos(tappedPoint.latitude * math.pi / 180)) / math.pow(2, currentZoom);
      // Zone de clic = taille exacte du pin (rayon = demi-taille du pin)
      // On utilise la taille exacte du pin pour détecter les clics directement dessus
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

          // Utiliser la zone de clic = taille exacte du pin
          // Si le clic est dans la zone du pin, on le détecte
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
      }
    }
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
      print(' Bottom sheet déjà ouverte (Home), ignore le clic');
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

  Future<void> _loadNextEvent() async {
    if (!mounted) return;
    setState(() {
      _isLoadingEvent = true;
      _errorEvent = null;
    });

    try {
      // Récupérer l'userId
      final userId = await SyncService.getCurrentUserId();
      if (userId == null) {
        setState(() {
          _nextEvent = null;
          _isLoadingEvent = false;
        });
        return;
      }

      // Vérifier la connectivité réseau
      final isOnline = await ConnectivityService.checkConnectivity();
      List<EventItem> events = [];

      if (isOnline) {
        // En ligne -> charger depuis l'API
        try {
          final response = await ApiClient.getEvents(page: 1, pageSize: 200);
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final eventsData = data['data'] as List<dynamic>;
            
            // Sauvegarder dans le cache
            try {
              final eventsList = eventsData
                  .map((e) => e is Map<String, dynamic> ? e : e as Map<String, dynamic>)
                  .toList();
              await LocalDatabase.saveEvents(eventsList);
            } catch (e) {
              print(' Erreur lors de la sauvegarde dans le cache: $e');
            }
            
            events = eventsData
                .map((json) => EventItem.fromJson(json as Map<String, dynamic>))
                .toList();
          }
        } catch (e) {
          print(' Erreur API, chargement depuis le cache: $e');
          // En cas d'erreur API, charger depuis le cache
          final eventsJson = await LocalDatabase.getAllEvents();
          events = eventsJson
              .map((json) => EventItem.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      } else {
        // Hors ligne -> charger depuis le cache local
        final eventsJson = await LocalDatabase.getAllEvents();
        events = eventsJson
            .map((json) => EventItem.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      // Traiter et afficher le prochain événement
      await _processNextEvent(events, userId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorEvent = 'Erreur lors du chargement: $e';
        _isLoadingEvent = false;
      });
    }
  }

  Future<void> _processNextEvent(List<EventItem> events, int userId) async {
    try {
      List<EventItem> filteredEvents = [];
      
      // Si organisateur : utiliser tous ses événements
      if (widget.userRole.toLowerCase() == 'organizer' || widget.userRole.toLowerCase() == 'organisateur') {
        filteredEvents = events
            .where((event) {
              final eventCreatedBy = event.createdBy;
              if (eventCreatedBy == null || eventCreatedBy.isEmpty) return false;
              final createdById = int.tryParse(eventCreatedBy.toString());
              return createdById != null && createdById == userId;
            })
            .toList();
      } else {
        // Si utilisateur normal : utiliser uniquement les favoris
        final favoriteEventIds = await SyncService.getFavoriteEventIds(userId);
        
        // Si aucun favori, pas de prochain événement
        if (favoriteEventIds.isEmpty) {
          if (mounted) {
            setState(() {
              _nextEvent = null;
              _isLoadingEvent = false;
            });
          }
          return;
        }
        
        filteredEvents = events
            .where((event) => favoriteEventIds.contains(event.eventId))
            .toList();
      }

      // Filtrer uniquement les événements futurs (après maintenant)
      // Normaliser en UTC pour une comparaison fiable
      final now = DateTime.now().toUtc();
      final futureEvents = filteredEvents.where((event) {
        final eventStart = event.startAt.toUtc();
        return eventStart.isAfter(now);
      }).toList();
      
      // Trier par date de début (du plus proche au plus lointain)
      futureEvents.sort((a, b) => a.startAt.compareTo(b.startAt));
      
      if (!mounted) return;
      if (futureEvents.isNotEmpty) {
        // Prendre le premier événement futur (le plus proche)
        setState(() {
          _nextEvent = futureEvents.first;
          _isLoadingEvent = false;
        });
      } else {
        // Aucun événement futur trouvé
        setState(() {
          _nextEvent = null;
          _isLoadingEvent = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorEvent = 'Erreur lors du chargement: $e';
        _isLoadingEvent = false;
      });
    }
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoadingFavorites = true;
    });

    try {
      final userId = await SyncService.getCurrentUserId();
      if (userId == null) {
        setState(() {
          _favoriteEvents = [];
          _isLoadingFavorites = false;
        });
        return;
      }

      // Vérifier la connectivité réseau
      final isOnline = await ConnectivityService.checkConnectivity();
      List<EventItem> allEvents = [];

      if (isOnline) {
        // En ligne -> charger depuis l'API
        try {
          final eventsResponse = await ApiClient.getEvents(page: 1, pageSize: 200);
          if (eventsResponse.statusCode == 200) {
            final eventsData = jsonDecode(eventsResponse.body) as Map<String, dynamic>;
            final allEventsData = eventsData['data'] as List<dynamic>;
            
            // Sauvegarder dans le cache
            try {
              final eventsList = allEventsData
                  .map((e) => e is Map<String, dynamic> ? e : e as Map<String, dynamic>)
                  .toList();
              await LocalDatabase.saveEvents(eventsList);
            } catch (e) {
              print(' Erreur lors de la sauvegarde dans le cache: $e');
            }
            
            allEvents = allEventsData
                .map((json) => EventItem.fromJson(json as Map<String, dynamic>))
                .toList();
          }
        } catch (e) {
          print(' Erreur API, chargement depuis le cache: $e');
          // En cas d'erreur API, charger depuis le cache
          final eventsJson = await LocalDatabase.getAllEvents();
          allEvents = eventsJson
              .map((json) => EventItem.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      } else {
        // Hors ligne -> charger depuis le cache local
        final eventsJson = await LocalDatabase.getAllEvents();
        allEvents = eventsJson
            .map((json) => EventItem.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      // Filtrer selon le rôle
      List<EventItem> favoriteEvents = [];
      
      if (widget.userRole.toLowerCase() == 'organizer' || widget.userRole.toLowerCase() == 'organisateur') {
        // Si organisateur : charger tous ses événements
        favoriteEvents = allEvents
            .where((event) {
              final eventCreatedBy = event.createdBy;
              if (eventCreatedBy == null || eventCreatedBy.isEmpty) return false;
              final createdById = int.tryParse(eventCreatedBy.toString());
              return createdById != null && createdById == userId;
            })
            .toList();
      } else {
        // Si utilisateur normal : charger uniquement les favoris
        final favoriteEventIds = await SyncService.getFavoriteEventIds(userId);
        favoriteEvents = allEvents
            .where((e) => favoriteEventIds.contains(e.eventId))
            .toList();
      }

      favoriteEvents.sort((a, b) => a.startAt.compareTo(b.startAt));

      setState(() {
        _favoriteEvents = favoriteEvents;
        _isLoadingFavorites = false;
      });
      
      // Mettre à jour le prochain événement et les événements pour la carte
      _loadNextEvent();
      _loadEvents();
    } catch (e) {
      print('Erreur lors du chargement des favoris: $e');
      setState(() {
        _favoriteEvents = [];
        _isLoadingFavorites = false;
      });
    }
  }

  Future<void> _loadEvents() async {
    if (_isLoadingEvents) return; // Éviter les chargements multiples
    
    setState(() {
      _isLoadingEvents = true;
    });

    try {
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
          // En cas d'erreur API, charger depuis le cache
          final eventsJson = await LocalDatabase.getAllEvents();
          allEvents = eventsJson
              .map((json) => EventItem.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      } else {
        // Hors ligne -> charger depuis le cache local
        print(' Hors ligne, chargement depuis le cache local');
        final eventsJson = await LocalDatabase.getAllEvents();
        allEvents = eventsJson
            .map((json) => EventItem.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      // Filtrer et afficher les événements
      await _processAndDisplayEvents(allEvents);
    } catch (e) {
      print(' Erreur chargement événements pour la carte Home: $e');
      setState(() {
        _events = [];
        _isLoadingEvents = false;
      });
    }
  }

  Future<void> _processAndDisplayEvents(List<EventItem> allEvents) async {
    // Filtrer les événements selon le rôle de l'utilisateur
    List<EventItem> filteredEvents = [];
    
    // Si organisateur : afficher tous ses événements
    if (widget.userRole.toLowerCase() == 'organizer' || widget.userRole.toLowerCase() == 'organisateur') {
      final userId = await SyncService.getCurrentUserId();
      if (userId != null) {
        filteredEvents = allEvents
            .where((event) {
              final eventCreatedBy = event.createdBy;
              if (eventCreatedBy == null || eventCreatedBy.isEmpty) return false;
              final createdById = int.tryParse(eventCreatedBy.toString());
              return createdById != null && createdById == userId;
            })
            .toList();
      }
    } else {
      // Si utilisateur normal : afficher uniquement les favoris
      final userId = await SyncService.getCurrentUserId();
      if (userId != null) {
        final favoriteEventIds = await SyncService.getFavoriteEventIds(userId);
        filteredEvents = allEvents
            .where((event) => favoriteEventIds.contains(event.eventId))
            .toList();
      }
    }
    
    // Filtrer uniquement les événements avec coordonnées GPS
    final events = filteredEvents
        .where((event) => event.latitude != null && event.longitude != null)
        .toList();

    // Créer un map pour retrouver rapidement les événements par leur ID de pin
    _eventMap.clear();
    for (var event in events) {
      _eventMap['event_${event.eventId}'] = event;
    }

    if (mounted) {
      setState(() {
        _events = events;
        _isLoadingEvents = false;
      });
      
      // Charger les images de profil des organisateurs
      await _loadOrganizerProfilePictures();
      
      // Construire les pins avec les images de profil
      _pins = await _buildEventPins();
      
      // Mettre à jour l'état pour reconstruire les pins avec les images
      if (mounted) {
        setState(() {});
      }
    }
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
      
      // Récupérer les images de profil depuis la base de données locale ou l'API
      for (var organizerId in organizerIds) {
        if (!_organizerProfilePictures.containsKey(organizerId)) {
          try {
            // Essayer d'abord depuis le cache local
            var user = await LocalDatabase.getUserById(organizerId);
            
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
                      if (userId == organizerId) {
                        final userFromApi = UserModel.fromApi(userMap);
                        await LocalDatabase.insertOrUpdateUser(userFromApi);
                        user = userFromApi;
                        break;
                      }
                    }
                    // Si toujours pas trouvé, réessayer depuis le cache
                    if (user == null) {
                      user = await LocalDatabase.getUserById(organizerId);
                    }
                  }
                } catch (e) {
                  print('Erreur lors de la récupération depuis l\'API pour l\'organisateur $organizerId: $e');
                }
              }
            }
            
            if (user != null && user.profilePicture != null && user.profilePicture!.isNotEmpty) {
              _organizerProfilePictures[organizerId] = user.profilePicture;
              
              // Charger l'image et la convertir en bytes
              try {
                final imageUrl = user.profilePicture!;
                final cleanImageUrl = ApiClient.cleanUrl(imageUrl);
                final response = await http.get(Uri.parse(cleanImageUrl));
                if (response.statusCode == 200) {
                  _organizerProfilePicturesBytes[organizerId] = response.bodyBytes;
                }
              } catch (e) {
                print('Erreur lors du chargement de l\'image pour l\'organisateur $organizerId: $e');
              }
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

  Future<List<StaticPositionGeoPoint>> _buildEventPins() async {
    final pins = <StaticPositionGeoPoint>[];
    
    // Ajouter le pin "Angers" par défaut
    pins.add(
      StaticPositionGeoPoint(
        "angers",
        const MarkerIcon(
          icon: Icon(
            Icons.location_city,
            color: Colors.red,
            size: 48,
          ),
        ),
        [GeoPoint(latitude: 47.4784, longitude: -0.5632)],
      ),
    );
    
    // Ajouter les pins des événements
    for (var event in _events) {
      if (event.latitude == null || event.longitude == null) {
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
        }
      }
      
      // Créer l'icône du pin : utiliser l'image de profil si disponible
      Widget? pinIconWidget;
      Icon? pinIcon;
      
      if (profilePictureBytes != null && profilePictureBytes.isNotEmpty) {
        // Utiliser l'image de profil de l'organisateur avec Image.memory
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
                return Icon(
                  Icons.event,
                  color: AppColors.primaryButton,
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
      final MarkerIcon markerIcon = pinIconWidget != null
          ? MarkerIcon(
              iconWidget: pinIconWidget,
            )
          : MarkerIcon(
              icon: pinIcon ?? Icon(
                Icons.event,
                color: AppColors.primaryButton,
                size: 72,
              ),
            );
      
      pins.add(
        StaticPositionGeoPoint(
          'event_${event.eventId}',
          markerIcon,
          [GeoPoint(
            latitude: event.latitude!,
            longitude: event.longitude!,
          )],
        ),
      );
    }
    
    return pins;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Container(
      color: AppColors.getPrimaryBackground(context),
      child: Column(
        children: [
          const SizedBox(height: 48),

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
              child: Stack(
                children: [

                  SharedMapWidget(
                    visible: widget.isActive,
                    customOption: OSMOption(
                      zoomOption: const ZoomOption(
                        initZoom: 13,
                        minZoomLevel: 3,
                        maxZoomLevel: 19,
                        stepZoom: 1.0,
                      ),
                      staticPoints: _pins,
                      roadConfiguration: const RoadOption(
                        roadColor: Colors.blueAccent,
                      ),
                    ),
                    onMapReady: (isReady) {
                      print(' onMapReady appelé (Home): isReady=$isReady');
                      debugPrint(' onMapReady appelé (Home): isReady=$isReady');
                      if (isReady) {
                        print(' Carte prête, configuration du listener dans onMapReady (Home)...');
                        debugPrint(' Carte prête, configuration du listener dans onMapReady (Home)...');
                        // Attendre un peu pour que la carte soit complètement initialisée
                        Future.delayed(const Duration(milliseconds: 1000), () {
                          if (mounted) {
                            // _setupMapListener() retire déjà l'ancien listener si nécessaire
                            _setupMapListener();
                          }
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

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
            child: _isLoadingEvent
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _errorEvent != null
                    ? Column(
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
                          Text(
                            _errorEvent!,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      )
                    : _nextEvent == null
                        ? Column(
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
                              Text(
                                'Aucun événement à venir',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          )
                        : InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EventDetailsScreen(
                                    event: _nextEvent!,
                                  ),
                                ),
                              );

                              if (mounted) {
                                _loadFavorites();
                                _loadNextEvent(); // Mettre à jour le prochain événement après retour
                              }
                            },
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
                                Text(
                                  _nextEvent!.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.getTextPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: AppColors.secondaryText,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_formatDate(_nextEvent!.startAt.toLocal())} à ${_formatTime(_nextEvent!.startAt.toLocal())}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_nextEvent!.location != null && _nextEvent!.location!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: AppColors.secondaryText,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _nextEvent!.location!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.secondaryText,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userRole.toLowerCase() == 'organizer' || widget.userRole.toLowerCase() == 'organisateur'
                        ? 'Vos événements'
                        : 'Vos favoris',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryButton,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _isLoadingFavorites
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _favoriteEvents.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    widget.userRole.toLowerCase() == 'organizer' || widget.userRole.toLowerCase() == 'organisateur'
                                        ? 'Aucun événement créé'
                                        : 'Aucun événement en favoris',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 100),
                                itemCount: _favoriteEvents.length,
                                itemBuilder: (context, index) {
                                  final event = _favoriteEvents[index];
                                  return InkWell(
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EventDetailsScreen(
                                            event: event,
                                          ),
                                        ),
                                      );

                                      if (mounted) {
                                        _loadFavorites();
                                        _loadNextEvent(); // Mettre à jour le prochain événement après retour
                                      }
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.getCardBackground(context),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.primaryButton.withOpacity(0.2),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryButton.withOpacity(0.1),
                                            blurRadius: 4,
                                            spreadRadius: 0,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  event.title,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.getTextPrimary(context),
                                                  ),
                                                ),
                                              ),
                                              Icon(
                                                Icons.star,
                                                size: 16,
                                                color: AppColors.primaryButton,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 14,
                                                color: AppColors.secondaryText,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${_formatDate(event.startAt.toLocal())} à ${_formatTime(event.startAt.toLocal())}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: AppColors.secondaryText,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (event.location != null && event.location!.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.location_on,
                                                  size: 14,
                                                  color: AppColors.secondaryText,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    event.location!,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: AppColors.secondaryText,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
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

