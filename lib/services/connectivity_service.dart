import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service de gestion de la connectivité réseau
/// Utilise le pattern Observer pour notifier les changements d'état de connexion
/// Permet à l'application de s'adapter automatiquement au mode online/offline
class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static bool _isOnline = true;
  static final List<Function(bool)> _listeners = [];

  static bool get isOnline => _isOnline;

  /// Ajoute un listener qui sera notifié lors des changements de connectivité
  /// Le callback reçoit un booléen indiquant si l'appareil est en ligne
  static void addListener(Function(bool) listener) {
    _listeners.add(listener);
  }

  /// Retire un listener de la liste des observateurs
  static void removeListener(Function(bool) listener) {
    _listeners.remove(listener);
  }

  /// Notifie tous les listeners enregistrés du changement d'état de connexion
  static void _notifyListeners(bool isOnline) {
    for (var listener in _listeners) {
      listener(isOnline);
    }
  }

  /// Initialise le service et démarre l'écoute des changements de connectivité
  /// Vérifie l'état initial et s'abonne aux changements futurs
  static Future<void> initialize() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(result);
    _notifyListeners(_isOnline);

    /// Écoute continue des changements de connectivité
    /// Le stream notifie automatiquement lors de changements (Wi-Fi, mobile, etc.)
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = _hasConnection(result);
      
      _notifyListeners(_isOnline);
      
      print('Connectivité changée: ${wasOnline} -> ${_isOnline}');
    });
  }

  /// Vérifie si au moins un des résultats de connectivité indique une connexion active
  /// Accepte Wi-Fi, mobile (données) et ethernet comme connexions valides
  static bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => 
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet
    );
  }

  static Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(result);
    return _isOnline;
  }

  static void dispose() {
    _subscription?.cancel();
    _listeners.clear();
  }
}
