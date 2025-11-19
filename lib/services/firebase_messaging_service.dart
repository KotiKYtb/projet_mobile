import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import '../api_client.dart';
import '../token_storage.dart';

/// Service pour gérer Firebase Cloud Messaging
/// Gère la réception des notifications push, les tokens FCM, et l'intégration avec les notifications locales
class FirebaseMessagingService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  static final Set<String> _processedMessageIds = <String>{}; // Pour éviter les doublons

  /// Initialise Firebase Messaging
  /// Configure les handlers pour les notifications en foreground et background
  static Future<void> initialize() async {
    // Initialiser les notifications locales pour afficher les notifications en foreground
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Gérer le clic sur une notification locale si nécessaire
        print(' Notification locale cliquée: ${response.payload}');
      },
    );

    // Créer le canal de notification Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'nocta_channel',
      'Nocta Notifications',
      description: 'Notifications de Nocta',
      importance: Importance.high,
      playSound: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Demander la permission pour les notifications (Android 13+)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print(' Permission de notification: ${settings.authorizationStatus}');

    // Obtenir le token FCM
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      print(' Token FCM: $token');
      // TODO: Envoyer le token à votre serveur backend
      await _sendTokenToServer(token);
    }

    // Écouter les changements de token
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      print(' Nouveau token FCM: $newToken');
      _sendTokenToServer(newToken);
    });

    // Configurer les handlers pour les notifications
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageOpened);

    // Vérifier si l'app a été ouverte depuis une notification
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessageOpened(initialMessage);
    }
  }

  /// Gère les notifications reçues lorsque l'app est en foreground
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Vérifier si cette notification a déjà été traitée (éviter les doublons)
    final messageId = message.messageId ?? message.data.toString();
    if (_processedMessageIds.contains(messageId)) {
      print(' Notification déjà traitée, ignorée (messageId: $messageId)');
      return;
    }
    _processedMessageIds.add(messageId);
    
    // Nettoyer les anciens messageIds (garder seulement les 100 derniers)
    if (_processedMessageIds.length > 100) {
      final idsToRemove = _processedMessageIds.take(_processedMessageIds.length - 100).toList();
      _processedMessageIds.removeAll(idsToRemove);
    }
    
    print(' Notification reçue en foreground: ${message.messageId}');
    print('   Titre: ${message.notification?.title}');
    print('   Corps: ${message.notification?.body}');
    print('   Données: ${message.data}');

    // Afficher une notification locale quand l'app est en foreground
    if (message.notification != null) {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'nocta_channel',
        'Nocta Notifications',
        channelDescription: 'Notifications de Nocta',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      // Utiliser un ID unique basé sur le messageId pour éviter les doublons
      final notificationId = message.messageId?.hashCode ?? message.hashCode;
      
      await _localNotifications.show(
        notificationId,
        message.notification!.title ?? 'Nocta',
        message.notification!.body ?? '',
        notificationDetails,
        payload: message.data.toString(),
      );
    }
  }

  /// Gère l'ouverture de l'app depuis une notification en background
  static void _handleBackgroundMessageOpened(RemoteMessage message) {
    print(' App ouverte depuis une notification: ${message.messageId}');
    print('   Données: ${message.data}');

    // Extraire event_id si présent et naviguer vers les détails
    final eventId = message.data['event_id'];
    if (eventId != null) {
      // TODO: Naviguer vers EventDetailsScreen avec l'event_id
      print(' Navigation vers l\'événement: $eventId');
    }
  }

  /// Envoie le token FCM au serveur backend
  /// Peut être appelée publiquement pour forcer l'enregistrement après connexion
  static Future<void> _sendTokenToServer(String token) async {
    try {
      // Récupérer le token d'authentification
      final authToken = await TokenStorage.read();
      if (authToken == null) {
        print(' Pas de token d\'authentification, le token FCM sera enregistré après connexion');
        return;
      }

      // Déterminer le type de dispositif
      String deviceType = 'android';
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        deviceType = 'ios';
      } else if (defaultTargetPlatform == TargetPlatform.windows || 
                 defaultTargetPlatform == TargetPlatform.linux || 
                 defaultTargetPlatform == TargetPlatform.macOS) {
        deviceType = 'web';
      }

      // Envoyer le token à l'API
      final response = await ApiClient.registerFCMToken(
        token: authToken,
        fcmToken: token,
        deviceType: deviceType,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print(' Token FCM enregistré avec succès sur le serveur');
      } else {
        print(' Erreur lors de l\'enregistrement du token FCM: ${response.statusCode}');
        print('   Réponse: ${response.body}');
      }
    } catch (e) {
      print(' Erreur lors de l\'envoi du token FCM: $e');
    }
  }

  /// S'abonne à un topic Firebase
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print(' Abonné au topic: $topic');
    } catch (e) {
      print(' Erreur lors de l\'abonnement au topic: $e');
    }
  }

  /// Se désabonne d'un topic Firebase
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print(' Désabonné du topic: $topic');
    } catch (e) {
      print(' Erreur lors du désabonnement du topic: $e');
    }
  }

  /// Obtient le token FCM actuel
  static Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  /// Réenregistre le token FCM au serveur
  /// Utile après une connexion pour s'assurer que le token est bien enregistré
  static Future<void> reRegisterToken() async {
    try {
      final token = await getToken();
      if (token != null) {
        await _sendTokenToServer(token);
      }
    } catch (e) {
      print(' Erreur lors du réenregistrement du token FCM: $e');
    }
  }
}

