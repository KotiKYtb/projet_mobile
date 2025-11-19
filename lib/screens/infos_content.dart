import 'package:flutter/material.dart';
import '../token_storage.dart';
import '../utils/app_colors.dart';
import '../api_client.dart';
import '../services/connectivity_service.dart';
import '../services/local_database.dart';
import '../services/sync_service.dart';
import 'dart:convert';

class NotificationItem {
	final int userNotificationId;
	final String title;
	final String body;
	bool read;
	final int? eventId;
	final String? eventTitle;
	final String? eventLocation;
	final DateTime createdAt;

	NotificationItem({
		required this.userNotificationId,
		required this.title,
		required this.body,
		this.read = false,
		this.eventId,
		this.eventTitle,
		this.eventLocation,
		required this.createdAt,
	});

	factory NotificationItem.fromJson(Map<String, dynamic> json) {
		return NotificationItem(
			userNotificationId: json['user_notification_id'] as int,
			title: json['title'] as String? ?? 'Notification',
			body: json['body'] as String? ?? '',
			read: json['read'] as bool? ?? false,
			eventId: json['event_id'] as int?,
			eventTitle: json['event_title'] as String?,
			eventLocation: json['event_location'] as String?,
			createdAt: DateTime.parse(json['created_at'] as String),
		);
	}
}

class InfosContent extends StatefulWidget {
	const InfosContent({super.key});

	@override
	State<InfosContent> createState() => _InfosContentState();
}

class _InfosContentState extends State<InfosContent> {
	final List<NotificationItem> _items = [];
	bool _isLoading = false;

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
					final response = await ApiClient.getReceivedNotifications(token: token);
					if (response.statusCode == 200) {
						final data = jsonDecode(response.body) as Map<String, dynamic>;
						final notificationsData = data['notifications'] as List<dynamic>;
						
						// Sauvegarder dans le cache local
						try {
							final userId = await SyncService.getCurrentUserId();
							if (userId != null) {
								final notificationsList = notificationsData
									.map((n) => n as Map<String, dynamic>)
									.toList();
								await LocalDatabase.saveUserNotifications(
									userId: userId,
									userNotificationsJson: notificationsList,
								);
							}
						} catch (e) {
							print(' Erreur lors de la sauvegarde dans le cache: $e');
						}
						
						final notifications = notificationsData
							.map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
							.toList();

						setState(() {
							_items.clear();
							_items.addAll(notifications);
							_isLoading = false;
						});
						return;
					} else {
						throw Exception('Erreur ${response.statusCode}: ${response.body}');
					}
				} catch (e) {
					print(' Erreur API, chargement depuis le cache: $e');
					// En cas d'erreur API, charger depuis le cache
					await _loadNotificationsFromCache();
					return;
				}
			} else {
				// Hors ligne -> charger depuis le cache local
				print(' Hors ligne, chargement depuis le cache local');
				await _loadNotificationsFromCache();
			}
		} catch (e) {
			print('Erreur chargement notifications: $e');
			// En cas d'erreur, essayer de charger depuis le cache
			await _loadNotificationsFromCache();
		}
	}

	Future<void> _loadNotificationsFromCache() async {
		try {
			final userId = await SyncService.getCurrentUserId();
			if (userId == null) {
				setState(() {
					_items.clear();
					_isLoading = false;
				});
				return;
			}

			final notificationsJson = await LocalDatabase.getUserNotifications(userId);
			final notifications = notificationsJson
				.map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
				.toList();

			setState(() {
				_items.clear();
				_items.addAll(notifications);
				_isLoading = false;
			});
		} catch (e) {
			print(' Erreur lors du chargement depuis le cache: $e');
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

	Future<void> _toggleRead(NotificationItem item) async {
		if (item.read) {
			// Si déjà lue, on ne fait rien (ou on pourrait permettre de la marquer comme non lue)
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

			final response = await ApiClient.markNotificationAsRead(
				token: token,
				userNotificationId: item.userNotificationId,
			);

			if (response.statusCode == 200) {
				setState(() {
					item.read = true;
				});
			} else {
				throw Exception('Erreur ${response.statusCode}: ${response.body}');
			}
		} catch (e) {
			print('Erreur marquage notification: $e');
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Erreur lors du marquage: ${e.toString()}')),
			);
		}
	}

	Future<void> _markAllRead() async {
		try {
			final token = await TokenStorage.read();
			if (token == null) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Non authentifié')),
				);
				return;
			}

			final response = await ApiClient.markAllNotificationsAsRead(token: token);

			if (response.statusCode == 200) {
				setState(() {
					for (final it in _items) {
						it.read = true;
					}
				});
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Toutes les notifications ont été marquées comme lues')),
				);
			} else {
				throw Exception('Erreur ${response.statusCode}: ${response.body}');
			}
		} catch (e) {
			print('Erreur marquage toutes notifications: $e');
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Erreur lors du marquage: ${e.toString()}')),
			);
		}
	}

	Future<void> _hideNotification(NotificationItem item) async {
		try {
			final token = await TokenStorage.read();
			if (token == null) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Non authentifié')),
				);
				return;
			}

			final response = await ApiClient.hideNotification(
				token: token,
				userNotificationId: item.userNotificationId,
			);

			if (response.statusCode == 200) {
				setState(() {
					_items.remove(item);
				});
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Notification masquée')),
				);
			} else {
				throw Exception('Erreur ${response.statusCode}: ${response.body}');
			}
		} catch (e) {
			print('Erreur masquage notification: $e');
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Erreur lors du masquage: ${e.toString()}')),
			);
		}
	}

	int get _unreadCount => _items.where((i) => !i.read).length;

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppColors.getPrimaryBackground(context),
			body: Column(
				children: [
					const SizedBox(height: 48),
					Container(
						width: double.infinity,
						padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
						color: AppColors.getPrimaryBackground(context),
						child: Row(
							mainAxisAlignment: MainAxisAlignment.spaceBetween,
							children: [
								Text(
									'Notifications (${_items.length})',
									style: const TextStyle(
										fontWeight: FontWeight.bold,
										color: AppColors.primaryButton,
									),
								),
								Row(
									children: [
										Text(
											'Non lues: $_unreadCount',
											style: const TextStyle(color: AppColors.secondaryText),
										),
										const SizedBox(width: 16),
										TextButton.icon(
											onPressed: _markAllRead,
											icon: const Icon(Icons.done_all, color: AppColors.primaryButton),
											label: const Text(
												'Tout lire',
												style: TextStyle(color: AppColors.primaryButton),
											),
										),
									],
								),
							],
						),
					),
					Expanded(
						child: _isLoading
							? const Center(child: CircularProgressIndicator())
							: _items.isEmpty
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
												'Aucune notification',
												style: TextStyle(
													fontSize: 16,
													color: AppColors.secondaryText,
												),
											),
										],
									),
								)
								: ListView.separated(
									padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
									itemCount: _items.length,
									separatorBuilder: (_, __) => const SizedBox(height: 8),
									itemBuilder: (context, index) {
										final item = _items[index];
										return Material(
											color: item.read
													? AppColors.getCardBackground(context)
													: AppColors.primaryButton.withOpacity(0.2),
											borderRadius: BorderRadius.circular(10),
											child: Container(
												decoration: BoxDecoration(
													borderRadius: BorderRadius.circular(10),
												),
												child: InkWell(
													borderRadius: BorderRadius.circular(10),
													onTap: () => _toggleRead(item),
													child: Padding(
														padding: const EdgeInsets.all(12),
														child: Row(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																Container(
																	width: 10,
																	height: 10,
																	margin: const EdgeInsets.only(top: 6, right: 12),
																	decoration: BoxDecoration(
																		shape: BoxShape.circle,
																		color: item.read ? Colors.transparent : AppColors.primaryButton,
																		border: Border.all(
																			color: item.read ? AppColors.getIconDisabled(context) : AppColors.primaryButton,
																		),
																	),
																),
																Expanded(
																	child: Column(
																		crossAxisAlignment: CrossAxisAlignment.start,
																		children: [
																			Row(
																				mainAxisAlignment: MainAxisAlignment.spaceBetween,
																				children: [
																					Expanded(
																						child: Text(
																							item.title,
																							style: TextStyle(
																								fontWeight: FontWeight.bold,
																								color: AppColors.getTextPrimary(context),
																							),
																						),
																					),
																					const SizedBox(width: 8),
																					Row(
																						mainAxisSize: MainAxisSize.min,
																						children: [
																							if (!item.read)
																								IconButton(
																									onPressed: () => _toggleRead(item),
																									icon: const Icon(Icons.check, size: 20),
																									color: AppColors.primaryButton,
																									tooltip: 'Marquer lu',
																									padding: EdgeInsets.zero,
																									constraints: const BoxConstraints(),
																								),
																							const SizedBox(width: 4),
																							IconButton(
																								onPressed: () => _hideNotification(item),
																								icon: const Icon(Icons.close, size: 20),
																								color: AppColors.secondaryText,
																								tooltip: 'Masquer',
																								padding: EdgeInsets.zero,
																								constraints: const BoxConstraints(),
																							),
																						],
																					),
																				],
																			),
																			const SizedBox(height: 6),
																			Text(
																				item.body,
																				style: TextStyle(
																					color: AppColors.getTextPrimary(context),
																				),
																			),
																			if (item.eventTitle != null) ...[
																				const SizedBox(height: 6),
																				Text(
																					'📅 ${item.eventTitle}',
																					style: TextStyle(
																						color: AppColors.primaryButton,
																						fontSize: 12,
																						fontWeight: FontWeight.w500,
																					),
																				),
																			],
																		],
																	),
																),
															],
														),
													),
												),
											),
										);
									},
								),
					),
				],
			),
		);
	}
}

