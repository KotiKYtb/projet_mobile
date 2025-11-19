import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'event_details_screen.dart';
import '../utils/app_colors.dart';
import '../api_client.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../services/local_database.dart';
import '../token_storage.dart';
import '../widgets/home_widget_service.dart';

class EventItem {
	final int eventId;
	final String title;
	final String? description;
	final String? location;
	final double? latitude;
	final double? longitude;
	final DateTime startAt;
	final DateTime? endAt;
	final String? category;
	final String? imageUrl;
	final String? createdBy;

	EventItem({
		required this.eventId,
		required this.title,
		this.description,
		this.location,
		this.latitude,
		this.longitude,
		required this.startAt,
		this.endAt,
		this.category,
		this.imageUrl,
		this.createdBy,
	});

	/// Crée un EventItem à partir des données JSON de l'API
	/// Gère la conversion des types pour latitude/longitude qui peuvent être num ou String
	factory EventItem.fromJson(Map<String, dynamic> json) {
		return EventItem(
			eventId: json['event_id'] as int,
			title: json['title'] as String,
			description: json['description'] as String?,
			location: json['location'] as String?,
			/// Conversion flexible: accepte num (int/double) ou String pour les coordonnées
			latitude: json['latitude'] != null ? (json['latitude'] is num ? json['latitude'].toDouble() : double.tryParse(json['latitude'].toString())) : null,
			longitude: json['longitude'] != null ? (json['longitude'] is num ? json['longitude'].toDouble() : double.tryParse(json['longitude'].toString())) : null,
			startAt: DateTime.parse(json['startAt'] as String),
			endAt: json['endAt'] != null ? DateTime.parse(json['endAt'] as String) : null,
			category: json['category'] as String?,
			imageUrl: json['image_url'] as String?,
			createdBy: json['created_by']?.toString(),
		);
	}

	String get id => eventId.toString();
	String get place => location ?? 'Lieu non spécifié';
	DateTime get date => startAt;
}

class EventsContent extends StatefulWidget {
	const EventsContent({super.key});

	@override
	State<EventsContent> createState() => _EventsContentState();
}

class _EventsContentState extends State<EventsContent> {
	final TextEditingController _searchController = TextEditingController();
	List<EventItem> _allEvents = [];
	List<EventItem> _filteredEvents = [];
	bool _isLoading = true;
	String? _error;
	Set<int> _favoriteEventIds = {};

	@override
	void initState() {
		super.initState();
		_loadEvents();
		_loadFavorites();
		_searchController.addListener(_onSearchChanged);
	}

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();

		_loadFavorites();
	}

	@override
	void dispose() {
		_searchController.removeListener(_onSearchChanged);
		_searchController.dispose();
		super.dispose();
	}

	void _onSearchChanged() {
		final q = _searchController.text.trim().toLowerCase();
		setState(() {
			if (q.isEmpty) {
				_filteredEvents = List.from(_allEvents);
			} else {
				_filteredEvents = _allEvents.where((e) {
					return e.title.toLowerCase().contains(q) || 
						(e.location?.toLowerCase().contains(q) ?? false);
				}).toList();
			}
		});
	}

	Future<void> _loadEvents() async {
		setState(() {
			_isLoading = true;
			_error = null;
		});

		try {
			// Vérifier la connectivité réseau
			final isOnline = await ConnectivityService.checkConnectivity();
			print(' État de connectivité: ${isOnline ? "EN LIGNE" : "HORS LIGNE"}');
			
			if (isOnline) {
				// En ligne -> essayer de charger depuis l'API
				print(' Tentative de chargement depuis l\'API...');
				try {
					await _loadEventsFromAPI();
				} catch (e) {
					// Si l'API échoue, charger depuis le cache
					print(' Erreur API détectée: $e');
					print(' Basculement vers le cache local...');
					await _loadEventsFromCache();
				}
			} else {
				// Hors ligne -> charger depuis le cache local
				print(' Hors ligne détecté, chargement depuis le cache local');
				await _loadEventsFromCache();
			}
		} catch (e) {
			print(' Erreur lors du chargement des événements: $e');
			print(' Stack trace: ${StackTrace.current}');
			// En cas d'erreur, essayer de charger depuis le cache
			await _loadEventsFromCache();
		}
	}

	Future<void> _loadEventsFromAPI() async {
		print(' Chargement des événements depuis l\'API...');
		final response = await ApiClient.getEvents(page: 1, pageSize: 100);
		
		if (response.statusCode == 200) {
			final data = jsonDecode(response.body) as Map<String, dynamic>;
			final eventsData = data['data'] as List<dynamic>;
			
			// Sauvegarder dans le cache local avant de convertir en EventItem
			await _saveEventsToCache(eventsData);

			final events = eventsData
				.map((json) => EventItem.fromJson(json as Map<String, dynamic>))
				.toList();

			events.sort((a, b) => a.startAt.compareTo(b.startAt));

			setState(() {
				_allEvents = events;
				_filteredEvents = List.from(_allEvents);
				_isLoading = false;
				_error = null;
			});

			print(' ${events.length} événements chargés depuis l\'API');
		} else {
			throw Exception('Erreur ${response.statusCode}: ${response.body}');
		}
	}

	Future<void> _loadEventsFromCache() async {
		try {
			print(' Chargement des événements depuis le cache local...');
			final eventsJson = await LocalDatabase.getAllEvents();
			
			if (eventsJson.isNotEmpty) {
				final events = eventsJson
					.map((json) => EventItem.fromJson(json as Map<String, dynamic>))
					.toList();

				events.sort((a, b) => a.startAt.compareTo(b.startAt));

				setState(() {
					_allEvents = events;
					_filteredEvents = List.from(_allEvents);
					_isLoading = false;
					_error = null;
				});

				print(' ${events.length} événements chargés depuis le cache local');
			} else {
				setState(() {
					_allEvents = [];
					_filteredEvents = [];
					_isLoading = false;
					_error = 'Mode hors ligne - Aucun événement en cache';
				});
				print(' Aucun événement trouvé dans le cache local');
			}
		} catch (e) {
			print(' Erreur lors du chargement depuis le cache: $e');
			setState(() {
				_allEvents = [];
				_filteredEvents = [];
				_isLoading = false;
				_error = 'Erreur lors du chargement du cache local';
			});
		}
	}

	Future<void> _saveEventsToCache(List<dynamic> eventsJson) async {
		try {
			// Convertir en List<Map<String, dynamic>> si nécessaire
			final eventsList = eventsJson
				.map((e) => e is Map<String, dynamic> ? e : e as Map<String, dynamic>)
				.toList();
			
			await LocalDatabase.saveEvents(eventsList);
			print(' Événements sauvegardés dans le cache local');
		} catch (e) {
			print(' Erreur lors de la sauvegarde dans le cache: $e');
			// Ne pas bloquer si la sauvegarde échoue
		}
	}

	Future<void> _loadFavorites() async {
		try {
			// Utiliser SyncService qui gère automatiquement le cache offline
			final userId = await SyncService.getCurrentUserId();
			if (userId == null) {
				setState(() {
					_favoriteEventIds = {};
				});
				return;
			}

			final favoriteIds = await SyncService.getFavoriteEventIds(userId);
			setState(() {
				_favoriteEventIds = favoriteIds.toSet();
			});
		} catch (e) {
			print('Erreur lors du chargement des favoris: $e');
			setState(() {
				_favoriteEventIds = {};
			});
		}
	}

	Future<void> _toggleFavorite(EventItem event) async {
		try {
			final token = await TokenStorage.read();
			if (token == null) {
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(
						const SnackBar(
							content: Text('Vous devez être connecté pour ajouter aux favoris'),
							duration: Duration(seconds: 2),
						),
					);
				}
				return;
			}

			final isFavorite = _favoriteEventIds.contains(event.eventId);
			http.Response response;

			if (isFavorite) {

				response = await ApiClient.removeFavorite(
					token: token,
					eventId: event.eventId,
				);
			} else {

				response = await ApiClient.addFavorite(
					token: token,
					eventId: event.eventId,
				);
			}

		if (response.statusCode == 200 || response.statusCode == 201) {
			// Mettre à jour le cache local
			final userId = await SyncService.getCurrentUserId();
			if (userId != null) {
				if (isFavorite) {
					await LocalDatabase.deleteFavorite(userId: userId, eventId: event.eventId);
				} else {
					await LocalDatabase.insertOrUpdateFavorite(userId: userId, eventId: event.eventId);
				}
			}

			await _loadFavorites();

			HomeWidgetService.updateWidgetWithFavoriteEvents();
		} else {
			throw Exception('Erreur ${response.statusCode}: ${response.body}');
		}
		} catch (e) {
			print('Erreur lors de la sauvegarde du favori: $e');
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: Text('Erreur: ${e.toString()}'),
						duration: const Duration(seconds: 2),
					),
				);
			}
		}
	}

	Future<void> _refresh() async {
		await _loadEvents();
		await _loadFavorites();
	}

	String _formatDate(DateTime d) {
		final local = d.toLocal();

		final two = (int n) => n.toString().padLeft(2, '0');
		return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppColors.getPrimaryBackground(context),
			body: Padding(
				padding: const EdgeInsets.all(12.0),
				child: Column(
					children: [
						const SizedBox(height: 48),

						Container(
							decoration: BoxDecoration(
								borderRadius: BorderRadius.circular(12),
								boxShadow: [
									BoxShadow(
										color: AppColors.primaryButton.withOpacity(0.2),
										blurRadius: 12,
										spreadRadius: 0,
										offset: const Offset(0, 2),
									),
									BoxShadow(
										color: AppColors.secondaryText.withOpacity(0.15),
										blurRadius: 8,
										spreadRadius: 0,
										offset: const Offset(0, 1),
									),
								],
							),
							child: TextField(
								controller: _searchController,
								style: TextStyle(color: AppColors.getTextPrimary(context)),
								decoration: InputDecoration(
									hintText: 'Rechercher un événement ou un lieu',
									hintStyle: TextStyle(color: AppColors.getTextDisabled(context)),
									prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
									filled: true,
									fillColor: AppColors.getCardBackground(context),
									border: OutlineInputBorder(
										borderRadius: BorderRadius.circular(12),
										borderSide: BorderSide(
											color: AppColors.primaryButton.withOpacity(0.3),
											width: 1,
										),
									),
									enabledBorder: OutlineInputBorder(
										borderRadius: BorderRadius.circular(12),
										borderSide: BorderSide(
											color: AppColors.primaryButton.withOpacity(0.2),
											width: 1,
										),
									),
									focusedBorder: OutlineInputBorder(
										borderRadius: BorderRadius.circular(12),
										borderSide: BorderSide(
											color: AppColors.primaryButton.withOpacity(0.5),
											width: 1.5,
										),
									),
								),
							),
						),
						const SizedBox(height: 24),

						Row(
							mainAxisAlignment: MainAxisAlignment.spaceBetween,
							children: [
								const Text(
									'Prochains événements',
									style: TextStyle(
										fontSize: 16,
										fontWeight: FontWeight.bold,
										color: AppColors.primaryButton,
									),
								),
								Text(
									'${_filteredEvents.length} trouvés',
									style: const TextStyle(
										color: AppColors.secondaryText,
									),
								),
							],
						),
						const SizedBox(height: 8),

						Expanded(
							child: RefreshIndicator(
								onRefresh: _refresh,
								color: AppColors.primaryButton,
								child: _isLoading
									? ListView(
										physics: const AlwaysScrollableScrollPhysics(),
										padding: const EdgeInsets.only(bottom: 100),
										children: [
											SizedBox(
												height: MediaQuery.of(context).size.height * 0.5,
												child: Center(
													child: Column(
														mainAxisAlignment: MainAxisAlignment.center,
														children: [
															CircularProgressIndicator(
																valueColor: AlwaysStoppedAnimation<Color>(
																	AppColors.primaryButton,
																),
															),
															const SizedBox(height: 16),
															Text(
																'Chargement des événements...',
																style: TextStyle(
																	color: AppColors.getTextPrimary(context),
																),
															),
														],
													),
												),
											),
										],
									)
									: _error != null && _filteredEvents.isEmpty
									? ListView(
										physics: const AlwaysScrollableScrollPhysics(),
										padding: const EdgeInsets.only(bottom: 100),
										children: [
											SizedBox(
												height: MediaQuery.of(context).size.height * 0.5,
												child: Center(
													child: Column(
														mainAxisAlignment: MainAxisAlignment.center,
														children: [
															Icon(
																Icons.error_outline,
																size: 48,
																color: AppColors.getTextDisabled(context),
															),
															const SizedBox(height: 16),
															Padding(
																padding: const EdgeInsets.symmetric(horizontal: 32),
																child: Text(
																	_error!,
																	style: TextStyle(
																		color: AppColors.getTextPrimary(context),
																	),
																	textAlign: TextAlign.center,
																),
															),
														],
													),
												),
											),
										],
									)
									: _filteredEvents.isEmpty
										? ListView(
												physics: const AlwaysScrollableScrollPhysics(),
												padding: const EdgeInsets.only(bottom: 100),
												children: [
													SizedBox(
														height: MediaQuery.of(context).size.height * 0.5,
														child: Center(
															child: Text(
																_searchController.text.isEmpty
																		? 'Aucun événement à venir.'
																		: 'Aucun résultat pour "${_searchController.text}"',
																style: TextStyle(
																	color: AppColors.getTextPrimary(context),
																),
															),
														),
													),
												],
											)
										: ListView.separated(
												padding: const EdgeInsets.only(bottom: 100),
												itemCount: _filteredEvents.length,
												separatorBuilder: (_, __) => const SizedBox(height: 8),
												itemBuilder: (context, index) {
													final ev = _filteredEvents[index];
													return InkWell(
														onTap: () async {
															await Navigator.push(
																context,
																MaterialPageRoute(
																	builder: (context) => EventDetailsScreen(event: ev),
																),
															);

															_loadFavorites();
														},
														child: Container(
															padding: const EdgeInsets.all(12),
															decoration: BoxDecoration(
																color: AppColors.getCardBackground(context),
																borderRadius: BorderRadius.circular(10),
															),
															child: Row(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [

																Container(
																	padding: const EdgeInsets.all(8),
																	decoration: BoxDecoration(
																		color: AppColors.primaryButton.withOpacity(0.2),
																		borderRadius: BorderRadius.circular(8),
																	),
																	child: Column(
																		mainAxisSize: MainAxisSize.min,
																		children: [
																			Text(
																				'${ev.date.day}',
																				style: const TextStyle(
																					fontSize: 18,
																					fontWeight: FontWeight.bold,
																					color: AppColors.primaryButton,
																				),
																			),
																			Text(
																				'${ev.date.month}',
																				style: const TextStyle(
																					color: AppColors.secondaryText,
																				),
																			),
																		],
																	),
																),
																const SizedBox(width: 12),

																Expanded(
																	child: Column(
																		crossAxisAlignment: CrossAxisAlignment.start,
																		children: [
																			Text(
																				ev.title,
																				style: TextStyle(
																					fontSize: 16,
																					fontWeight: FontWeight.w600,
																					color: AppColors.getTextPrimary(context),
																				),
																			),
																			const SizedBox(height: 6),
																			Text(
																				ev.place,
																				style: const TextStyle(
																					color: AppColors.secondaryText,
																				),
																			),
																		],
																	),
																),

																Column(
																	crossAxisAlignment: CrossAxisAlignment.end,
																	children: [
																		Text(
																			_formatDate(ev.date),
																			style: TextStyle(
																				color: AppColors.getTextPrimary(context),
																			),
																		),
																		const SizedBox(height: 8),
																		IconButton(
																			onPressed: () {
																				_toggleFavorite(ev);
																			},
																			icon: Icon(
																				_favoriteEventIds.contains(ev.eventId)
																					? Icons.star
																					: Icons.star_border,
																				color: AppColors.primaryButton,
																			),
																		),
																	],
																),
															],
														),
													),
													);
												},
											),
							),
						),
					],
				),
			),
		);
	}
}
