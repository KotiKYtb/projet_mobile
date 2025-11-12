import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  /// Initialise les notifications locales
  static Future<void> initNotifications() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);
    _initialized = true;
  }

  /// Détail du style de notification
  static NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'nocta_channel',
        'Nocta Notifications',
        channelDescription: 'Notifications de Nocta',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      ),
    );
  }

  /// Affiche une notification simple
  static Future<void> showNotification(
      int id, String title, String body) async {
    await _notificationsPlugin.show(
      id,
      title,
      body,
      _notificationDetails(),
    );
  }
}

