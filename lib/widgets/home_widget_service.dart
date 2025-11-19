import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import '../api_client.dart';
import '../token_storage.dart';

class HomeWidgetService {
  static const String _widgetName = 'AngersWidget';
  static const String _androidName = 'AngersWidgetProvider';

  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId('group.angers_mobile_app');
      print(' HomeWidget initialisé avec succès');
    } catch (e) {
      print(' Erreur lors de l\'initialisation du HomeWidget: $e');
    }
  }

  static Future<void> updateWidgetWithFavoriteEvents() async { 
    try {
      print(' Début de la mise à jour du widget...');
      final token = await TokenStorage.read();
      if (token == null) {
        print(' Pas de token, widget vide');
        await _updateWidgetWithEmptyState();
        return;
      }

      print('📡 Récupération des favoris...');
      final favoritesResponse = await ApiClient.getFavorites(token: token)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        print(' Timeout lors de la récupération des favoris');
        throw TimeoutException('Timeout lors de la récupération des favoris');
      });
      
      if (favoritesResponse.statusCode != 200) {
        print(' Erreur API favoris: ${favoritesResponse.statusCode}');
        await _updateWidgetWithEmptyState();
        return;
      }

      final favoritesData = jsonDecode(favoritesResponse.body) as Map<String, dynamic>;
      final favoritesList = favoritesData['favorites'] as List<dynamic>? ?? [];
      
      if (favoritesList.isEmpty) {
        await _updateWidgetWithEmptyState();
        return;
      }

      final favoriteEventIds = favoritesList
          .map((f) => (f as Map<String, dynamic>)['event_id'] as int)
          .toList();

      print('📡 Récupération des événements...');
      final eventsResponse = await ApiClient.getEvents(page: 1, pageSize: 100)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        print(' Timeout lors de la récupération des événements');
        throw TimeoutException('Timeout lors de la récupération des événements');
      });
      
      if (eventsResponse.statusCode != 200) {
        print(' Erreur API événements: ${eventsResponse.statusCode}');
        await _updateWidgetWithEmptyState();
        return;
      }

      final eventsData = jsonDecode(eventsResponse.body) as Map<String, dynamic>;
      final allEventsData = eventsData['data'] as List<dynamic>;

      final now = DateTime.now();
      final upcomingFavoriteEvents = <Map<String, dynamic>>[];
      
      print(' Filtrage des événements favoris...');
      print('   Nombre d\'événements favoris (IDs): ${favoriteEventIds.length}');
      print('   IDs favoris: $favoriteEventIds');
      print('   Nombre total d\'événements: ${allEventsData.length}');
      
      for (final eventJson in allEventsData) {
        final event = eventJson as Map<String, dynamic>;
        final eventId = event['event_id'] as int;
        
        if (favoriteEventIds.contains(eventId)) {
          final startAtStr = event['startAt'] as String;
          final startAt = DateTime.parse(startAtStr);
          
          print('   📅 Événement $eventId: ${event['title']} - ${startAtStr}');
          print('      Maintenant: $now');
          print('      Est à venir: ${startAt.isAfter(now)}');

          if (startAt.isAfter(now)) {
            upcomingFavoriteEvents.add({
              'id': eventId,
              'title': event['title'] as String? ?? 'Sans titre',
              'startAt': startAtStr,
              'location': event['location'] as String? ?? '',
            });
            print('       Ajouté à la liste');
          } else {
            print('       Ignoré (déjà passé)');
          }
        }
      }

      upcomingFavoriteEvents.sort((a, b) {
        final dateA = DateTime.parse(a['startAt'] as String);
        final dateB = DateTime.parse(b['startAt'] as String);
        return dateA.compareTo(dateB);
      });

      final eventsToShow = upcomingFavoriteEvents.take(5).toList();

      print(' ${eventsToShow.length} événements favoris à venir trouvés');
      for (int i = 0; i < eventsToShow.length; i++) {
        final event = eventsToShow[i];
        print('  - Événement $i: ${event['title']} (${event['startAt']})');
      }

      print('═══════════════════════════════════════');
      print(' MISE À JOUR DU WIDGET');
      print('═══════════════════════════════════════');
      print(' ${eventsToShow.length} événements à sauvegarder');
      
      try {

        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('events_count', eventsToShow.length.toString());
        print(' events_count sauvegardé dans SharedPreferences: ${eventsToShow.length}');
        
        for (int i = 0; i < eventsToShow.length; i++) {
          final event = eventsToShow[i];
          final title = event['title'] as String;
          final date = _formatDate(event['startAt'] as String);
          final location = event['location'] as String;
          
          print(' Événement $i:');
          print('   Titre: $title');
          print('   Date: $date');
          print('   Lieu: $location');

          await prefs.setString('event_${i}_title', title);
          await prefs.setString('event_${i}_date', date);
          await prefs.setString('event_${i}_location', location);
          await prefs.setString('event_${i}_id', event['id'].toString());
        }

        final savedCount = prefs.getString('events_count');
        print(' Vérification: events_count lu = $savedCount');

        await HomeWidget.updateWidget(
          name: _widgetName,
          androidName: _androidName,
        );

        print(' Widget notifié avec ${eventsToShow.length} événements favoris');
      } catch (e, stackTrace) {
        print(' ERREUR lors de la sauvegarde: $e');
        print('Stack trace: $stackTrace');
        await _updateWidgetWithEmptyState();
      }
      print('═══════════════════════════════════════');
    } on TimeoutException catch (e) {
      print(' Timeout lors de la mise à jour du widget: $e');
      print(' Le widget sera mis à jour lors de la prochaine tentative');

    } catch (e, stackTrace) {
      print(' Erreur lors de la mise à jour du widget: $e');
      print('Stack trace: $stackTrace');
      await _updateWidgetWithEmptyState();
    }
  }

  static Future<void> _updateWidgetWithEmptyState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('events_count', '0');
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _androidName,
      );
    } catch (e) {
      print(' Erreur lors de la mise à jour du widget vide: $e');
    }
  }

  static String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final eventDate = DateTime(date.year, date.month, date.day);

      if (eventDate == today) {
        return 'Aujourd\'hui ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (eventDate == today.add(const Duration(days: 1))) {
        return 'Demain ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else {
        final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
        return '${days[date.weekday - 1]} ${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return dateStr;
    }
  }

  static Future<void> updateWidget({
    String? title,
    String? message,
    String? date,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('title', title ?? 'Angers Mobile');
      await HomeWidget.saveWidgetData<String>('message', message ?? 'Bienvenue');
      await HomeWidget.saveWidgetData<String>('date', date ?? '');
      
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _androidName,
      );
      
      print(' Widget mis à jour avec succès');
    } catch (e) {
      print(' Erreur lors de la mise à jour du widget: $e');
    }
  }
}

