import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static bool _isOnline = true;
  static final List<Function(bool)> _listeners = [];

  // État de la connectivité
  static bool get isOnline => _isOnline;

  // Ajouter un listener pour les changements de connectivité
  static void addListener(Function(bool) listener) {
    _listeners.add(listener);
  }

  // Supprimer un listener
  static void removeListener(Function(bool) listener) {
    _listeners.remove(listener);
  }

  // Notifier tous les listeners
  static void _notifyListeners(bool isOnline) {
    for (var listener in _listeners) {
      listener(isOnline);
    }
  }

  // Initialiser le service de connectivité
  static Future<void> initialize() async {
    // Vérifier l'état initial
    final result = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(result);
    _notifyListeners(_isOnline);

    // Écouter les changements de connectivité
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = _hasConnection(result);
      
      // Toujours notifier, même si l'état n'a pas changé
      _notifyListeners(_isOnline);
      
      print('Connectivité changée: ${wasOnline} -> ${_isOnline}');
    });
  }

  // Vérifier si il y a une connexion
  static bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => 
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet
    );
  }

  // Vérifier manuellement la connectivité
  static Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(result);
    return _isOnline;
  }

  // Arrêter le service
  static void dispose() {
    _subscription?.cancel();
    _listeners.clear();
  }
}
