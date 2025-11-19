import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

/// Service singleton pour gérer le contrôleur de carte OSM
/// Utilise le pattern Singleton pour garantir une seule instance de MapController
/// Cela permet de partager la même carte entre plusieurs écrans sans la recréer
/// Optimise les performances en évitant de recharger la carte à chaque navigation
class MapService {
  static final MapService _instance = MapService._internal();
  factory MapService() => _instance;
  MapService._internal();

  MapController? _controller;
  bool _isInitialized = false;
  bool _isReady = false;

  /// Coordonnées par défaut: Angers, France
  static const double defaultLat = 47.4784;
  static const double defaultLng = -0.5632;

  /// Initialise le contrôleur de carte une seule fois au démarrage de l'application
  /// Évite la recréation coûteuse du contrôleur à chaque utilisation
  Future<void> initialize() async {
    if (_isInitialized) return;

    _controller = MapController(
      initPosition: GeoPoint(latitude: defaultLat, longitude: defaultLng),
    );

    _isInitialized = true;
    print(' MapService initialisé');
  }

  /// Retourne le contrôleur de carte partagé
  /// Peut retourner null si la carte n'a pas encore été initialisée
  MapController? getController() {
    return _controller;
  }

  /// Indique si la carte est prête à être utilisée
  /// Utilisé pour éviter d'afficher la carte avant qu'elle soit complètement chargée
  bool get isReady => _isReady;

  void setReady(bool ready) {
    _isReady = ready;
  }

  /// Crée un nouveau contrôleur pour une localisation spécifique
  /// Utilisé lorsqu'on a besoin d'un contrôleur indépendant pour une carte dédiée
  MapController createControllerForLocation({
    required double latitude,
    required double longitude,
  }) {
    return MapController(
      initPosition: GeoPoint(latitude: latitude, longitude: longitude),
    );
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _isReady = false;
  }
}

