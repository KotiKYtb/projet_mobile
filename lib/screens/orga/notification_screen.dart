import 'package:flutter/material.dart';
import 'dart:convert';
import '../../api_client.dart';
import '../../token_storage.dart';
import '../../utils/app_colors.dart';
import '../../services/sync_service.dart';
import '../../services/local_database.dart';
import '../../services/connectivity_service.dart';
import '../events_content.dart';

class NotificationItem {
  final int notificationId;
  final String title;
  final String body;
  final List<int> eventIds;
  final int sentCount;
  final int failedCount;
  final DateTime createdAt;
  final int? createdBy;

  NotificationItem({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.eventIds,
    required this.sentCount,
    required this.failedCount,
    required this.createdAt,
    this.createdBy,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      notificationId: json['notification_id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      eventIds: (json['event_ids'] as List<dynamic>).map((e) => e as int).toList(),
      sentCount: json['sent_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as int?,
    );
  }
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _isLoading = false;
  List<NotificationItem> _notifications = [];
  List<EventItem> _allEvents = [];
  bool _isLoadingEvents = false;
  bool _isSendingNotification = false; // Protection contre les doubles clics

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await TokenStorage.read();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Non authentifié')),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Vérifier la connectivité réseau
      final isOnline = await ConnectivityService.checkConnectivity();
      
      if (isOnline) {
        // En ligne -> charger depuis l'API
        try {
          final response = await ApiClient.getNotifications(token: token);
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final notificationsData = data['notifications'] as List<dynamic>;
            
            // Sauvegarder dans le cache local
            try {
              final notificationsList = notificationsData
                  .map((n) => n as Map<String, dynamic>)
                  .toList();
              await LocalDatabase.saveNotifications(notificationsList);
            } catch (e) {
              print(' Erreur lors de la sauvegarde dans le cache: $e');
            }
            
            final notifications = notificationsData
                .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
                .toList();

            setState(() {
              _notifications = notifications;
              _isLoading = false;
            });
            return;
          } else {
            throw Exception('Erreur ${response.statusCode}: ${response.body}');
          }
        } catch (e) {
          print(' Erreur API, chargement depuis le cache: $e');
          // En cas d'erreur API, charger depuis le cache
          final notificationsJson = await LocalDatabase.getAllNotifications();
          final notifications = notificationsJson
              .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
              .toList();

          setState(() {
            _notifications = notifications;
            _isLoading = false;
          });
          return;
        }
      } else {
        // Hors ligne -> charger depuis le cache local
        final notificationsJson = await LocalDatabase.getAllNotifications();
        final notifications = notificationsJson
            .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
            .toList();

        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur chargement notifications: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoadingEvents = true;
    });

    try {
      // Récupérer l'ID de l'utilisateur actuel
      final userId = await SyncService.getCurrentUserId();
      if (userId == null) {
        setState(() {
          _isLoadingEvents = false;
        });
        return;
      }

      // Charger tous les événements depuis l'API
      final response = await ApiClient.getEvents(page: 1, pageSize: 200);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final eventsData = data['data'] as List<dynamic>;
        
        final allEvents = eventsData
            .map((json) => EventItem.fromJson(json as Map<String, dynamic>))
            .toList();

        // Filtrer pour ne garder que les événements créés par l'utilisateur
        // createdBy est de type String? dans events_content.dart, on doit convertir en int pour comparer
        final myEvents = allEvents
            .where((event) {
              final eventCreatedBy = event.createdBy;
              if (eventCreatedBy == null || eventCreatedBy.isEmpty) return false;
              // Convertir en int (createdBy est une String dans events_content.dart)
              final createdById = int.tryParse(eventCreatedBy.toString());
              return createdById != null && createdById == userId;
            })
            .toList();

        // Trier par date de début (plus récents en premier)
        myEvents.sort((a, b) => b.startAt.compareTo(a.startAt));

        setState(() {
          _allEvents = myEvents;
          _isLoadingEvents = false;
        });
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Erreur chargement événements: $e');
      setState(() {
        _isLoadingEvents = false;
      });
    }
  }

  void _showCreateNotificationDialog({NotificationItem? notification}) async {
    // Charger les événements avant d'ouvrir le dialog
    if (_allEvents.isEmpty && !_isLoadingEvents) {
      await _loadEvents();
    }

    final titleController = TextEditingController(text: notification?.title ?? '');
    final bodyController = TextEditingController(text: notification?.body ?? '');
    final selectedEventIds = <int>{};
    if (notification != null) {
      selectedEventIds.addAll(notification.eventIds);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return _CreateNotificationDialog(
            notification: notification,
            titleController: titleController,
            bodyController: bodyController,
            allEvents: _allEvents,
            selectedEventIds: selectedEventIds,
            isLoadingEvents: _isLoadingEvents,
            onLoadEvents: () async {
              await _loadEvents();
              setDialogState(() {});
            },
            onSave: () async {
              final title = titleController.text.trim();
              final body = bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le titre et le contenu sont requis')),
      );
      return;
    }

              if (selectedEventIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez sélectionner au moins un événement')),
                );
                return;
              }

              try {
                final token = await TokenStorage.read();
                if (token == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Non authentifié')),
                  );
                  return;
                }

                if (notification != null) {
                  // Mode édition : mettre à jour
                  final response = await ApiClient.updateNotification(
                    token: token,
                    notificationId: notification.notificationId,
                    title: title,
                    body: body,
                    eventIds: selectedEventIds.toList(),
                  );

                  if (response.statusCode == 200) {
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notification mise à jour avec succès !')),
                      );
                      // Forcer une synchronisation immédiate des notifications créées
                      await SyncService.syncCreatedNotificationsFromApi();
                      // Recharger la liste
                      _loadNotifications();
                    }
                  } else {
                    throw Exception('Erreur ${response.statusCode}: ${response.body}');
                  }
                } else {
                  // Mode création : créer sans envoyer
                  final response = await ApiClient.createNotification(
                    token: token,
                    title: title,
                    body: body,
                    eventIds: selectedEventIds.toList(),
                  );

                  if (response.statusCode == 201) {
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notification créée avec succès !')),
                      );
                      // Forcer une synchronisation immédiate des notifications créées
                      await SyncService.syncCreatedNotificationsFromApi();
                      // Recharger la liste
                      _loadNotifications();
                    }
                  } else {
                    throw Exception('Erreur ${response.statusCode}: ${response.body}');
                  }
                }
              } catch (e) {
                print('Erreur sauvegarde notification: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur lors de la sauvegarde: ${e.toString()}')),
                );
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _sendNotification(NotificationItem notification) async {
    // Protection contre les doubles clics
    if (_isSendingNotification) {
      print('Envoi déjà en cours, ignore le double clic');
      return;
    }

    setState(() {
      _isSendingNotification = true;
    });

    try {
      final token = await TokenStorage.read();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Non authentifié')),
        );
        return;
      }

      print('Envoi de la notification ${notification.notificationId}...');
      final response = await ApiClient.sendNotificationById(
        token: token,
        notificationId: notification.notificationId,
      );

      if (response.statusCode == 200) {
        print('Notification envoyée avec succès');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification envoyée avec succès !')),
        );
        // Forcer une synchronisation immédiate des notifications créées
        await SyncService.syncCreatedNotificationsFromApi();
        // Recharger la liste
        _loadNotifications();
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Erreur envoi notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'envoi: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingNotification = false;
        });
      }
    }
  }

  Future<void> _deleteNotification(NotificationItem notification) async {
    // Afficher une boîte de dialogue de confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la notification'),
        content: Text('Êtes-vous sûr de vouloir supprimer la notification "${notification.title}" ?\n\nCette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final token = await TokenStorage.read();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Non authentifié')),
        );
        return;
      }

      final response = await ApiClient.deleteNotification(
        token: token,
        notificationId: notification.notificationId,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification supprimée avec succès !')),
        );
        _loadNotifications();
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Erreur suppression notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getPrimaryBackground(context),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: AppColors.secondaryText,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune notification créée',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 80,
                        left: 16,
                        right: 16,
                        bottom: 16,
                      ),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.getCardBackground(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      notification.title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.getTextPrimary(context),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatDate(notification.createdAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                notification.body,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.getTextPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.event,
                                    size: 16,
                                    color: AppColors.secondaryText,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${notification.eventIds.length} événement(s)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${notification.sentCount} envoyées',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                                  if (notification.failedCount > 0) ...[
                                    const SizedBox(width: 16),
                                    Icon(
                                      Icons.error,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${notification.failedCount} échecs',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    onPressed: () => _showCreateNotificationDialog(notification: notification),
                                    icon: const Icon(Icons.edit, size: 20),
                                    color: AppColors.primaryButton,
                                    tooltip: 'Modifier',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => _deleteNotification(notification),
                                    icon: const Icon(Icons.delete, size: 20),
                                    color: Colors.red,
                                    tooltip: 'Supprimer',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: _isSendingNotification ? null : () => _sendNotification(notification),
                                    icon: const Icon(Icons.send, size: 20),
                                    color: AppColors.primaryButton,
                                    tooltip: 'Envoyer',
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.primaryButton.withOpacity(0.1),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          // Bouton flottant en haut à gauche
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: FloatingActionButton(
              mini: true,
              onPressed: _showCreateNotificationDialog,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'À l\'instant';
        }
        return 'Il y a ${difference.inMinutes} min';
      }
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jours';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _CreateNotificationDialog extends StatefulWidget {
  final NotificationItem? notification;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final List<EventItem> allEvents;
  final Set<int> selectedEventIds;
  final bool isLoadingEvents;
  final VoidCallback onLoadEvents;
  final VoidCallback onSave;

  const _CreateNotificationDialog({
    this.notification,
    required this.titleController,
    required this.bodyController,
    required this.allEvents,
    required this.selectedEventIds,
    required this.isLoadingEvents,
    required this.onLoadEvents,
    required this.onSave,
  });

  bool get isEditMode => notification != null;

  @override
  State<_CreateNotificationDialog> createState() => _CreateNotificationDialogState();
}

class _CreateNotificationDialogState extends State<_CreateNotificationDialog> {
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Ne pas charger automatiquement, les événements sont déjà chargés avant l'ouverture du dialog
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.isEditMode ? 'Modifier la notification' : 'Créer une notification',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            const Text(
              'Titre de la notification',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
                controller: widget.titleController,
              decoration: const InputDecoration(
                hintText: 'Ex : Nouvel événement disponible',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Contenu de la notification',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
                controller: widget.bodyController,
              decoration: const InputDecoration(
                hintText: 'Ex : Un nouvel événement a été ajouté à vos favoris.',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
              const SizedBox(height: 16),
              const Text(
                'Événements associés',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sélectionnez vos événements. La notification sera envoyée à tous les utilisateurs ayant ces événements en favoris.',
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 12),
              if (widget.isLoadingEvents)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (widget.allEvents.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.getCardBackground(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Aucun événement créé. Créez d\'abord un événement.',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                )
              else ...[
                // Liste déroulante pour sélectionner un événement
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Sélectionner un événement',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  value: null,
                  // Afficher uniquement le titre dans le champ sélectionné pour éviter l'overflow
                  selectedItemBuilder: (BuildContext context) {
                    return widget.allEvents.map<Widget>((event) {
                      return Text(
                        event.title,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      );
                    }).toList();
                  },
                  items: widget.allEvents.map((event) {
                    return DropdownMenuItem<int>(
                      value: event.eventId,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              event.title,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            if (event.location != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                event.location!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondaryText,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (int? eventId) {
                    if (eventId != null && !widget.selectedEventIds.contains(eventId)) {
                      setState(() {
                        widget.selectedEventIds.add(eventId);
                      });
                      // Réinitialiser la valeur du dropdown après sélection
                      Future.delayed(Duration.zero, () {
                        if (mounted) {
                          setState(() {});
                        }
                      });
                    }
                  },
                ),
                // Afficher les événements sélectionnés sous forme de chips
                if (widget.selectedEventIds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.selectedEventIds.map((eventId) {
                      final event = widget.allEvents.firstWhere(
                        (e) => e.eventId == eventId,
                        orElse: () => widget.allEvents.first,
                      );
                      return Chip(
                        label: Text(
                          event.title,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onDeleted: () {
                          setState(() {
                            widget.selectedEventIds.remove(eventId);
                          });
                        },
                        deleteIcon: const Icon(Icons.close, size: 18),
                        backgroundColor: AppColors.primaryButton.withOpacity(0.2),
                        labelStyle: const TextStyle(color: AppColors.primaryButton),
                      );
                    }).toList(),
                  ),
                ],
              ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isSending 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.save),
                  label: Text(_isSending ? 'Sauvegarde...' : (widget.isEditMode ? 'Enregistrer les modifications' : 'Créer la notification')),
                  onPressed: _isSending ? null : () {
                    setState(() {
                      _isSending = true;
                    });
                    widget.onSave();
                    Future.delayed(const Duration(seconds: 1), () {
                      if (mounted) {
                        setState(() {
                          _isSending = false;
                        });
                      }
                    });
                  },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primaryButton,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
            ),
        ),
      ),
    );
  }
}
