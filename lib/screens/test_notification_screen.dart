import 'package:flutter/material.dart';
import '../not_service.dart';

class TestNotificationScreen extends StatelessWidget {
  const TestNotificationScreen({super.key});

  Future<void> _sendTestNotification() async {
    await NotService.showNotification(
      1, // ID unique pour la notif
      'Voiture mal garée',
      'AB-123-CD est garée en double file.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test des notifications')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.notifications_active),
          label: const Text('Envoyer une notification'),
          onPressed: _sendTestNotification,
        ),
      ),
    );
  }
}

