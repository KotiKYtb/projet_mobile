import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class MapService {
  static final MapService _instance = MapService._internal();
  factory MapService() => _instance;
  MapService._internal();

  MapController? _controller;
  bool _isInitialized = false;
  bool _isReady = false;

  // Position par défaut (Angers)
  static const double defaultLat = 47.4784;
  static const double defaultLng = -0.5632;

  // Initialiser le service de carte
  Future<void> initialize() async {
    if (_isInitialized) return;

    _controller = MapController(
      initPosition: GeoPoint(latitude: defaultLat, longitude: defaultLng),
    );

    _isInitialized = true;
    print('🗺️ MapService initialisé');
  }

  // Obtenir le contrôleur de carte
  MapController? getController() {
    return _controller;
  }

  // Vérifier si la carte est prête
  bool get isReady => _isReady;

  // Marquer la carte comme prête
  void setReady(bool ready) {
    _isReady = ready;
  }

  // Créer un nouveau contrôleur pour une position spécifique
  MapController createControllerForLocation({
    required double latitude,
    required double longitude,
  }) {
    return MapController(
      initPosition: GeoPoint(latitude: latitude, longitude: longitude),
    );
  }

  // Nettoyer les ressources
  void dispose() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _isReady = false;
  }
}

