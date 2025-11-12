import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import '../utils/app_colors.dart';
import '../api_client.dart';
import '../services/connectivity_service.dart';
import '../token_storage.dart';
import 'events_content.dart';
import 'event_details_screen.dart';

class HomeContent extends StatefulWidget {
  final String userName;
  final String userRole;
  final bool loading;

  const HomeContent({
    super.key,
    required this.userName,
    required this.userRole,
    required this.loading,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> with AutomaticKeepAliveClientMixin {
  late MapController controller;
  bool _isMapReady = false;

  // Position initiale sur Angers
  static const double _centerLat = 47.4784;
  static const double _centerLng = -0.5632;
  
  EventItem? _nextEvent;
  bool _isLoadingEvent = true;
  String? _errorEvent;
  List<EventItem> _favoriteEvents = [];
  bool _isLoadingFavorites = true;
  bool _hasLoadedFavorites = false;

  @override
  bool get wantKeepAlive => true; // ✅ Garde la carte en mémoire

  @override
  void initState() {
    super.initState();
    
    controller = MapController(
      initPosition: GeoPoint(latitude: _centerLat, longitude: _centerLng),
    );
    
    _loadNextEvent();
    _loadFavorites();
    _hasLoadedFavorites = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recharger les favoris quand on revient sur la page
    if (_hasLoadedFavorites) {
      _loadFavorites();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _loadNextEvent() async {
    if (!mounted) return;
    setState(() {
      _isLoadingEvent = true;
      _errorEvent = null;
    });

    try {
      final isOnline = await ConnectivityService.checkConnectivity();
      List<EventItem> events = [];

      if (isOnline) {
        // Charger depuis l'API
        final response = await ApiClient.getEvents(page: 1, pageSize: 100);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final eventsData = data['data'] as List<dynamic>;
          events = eventsData
              .map((json) => EventItem.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }

      // Trier par date de début (le plus proche en premier)
      events.sort((a, b) => a.startAt.compareTo(b.startAt));
      
      if (!mounted) return;
      if (events.isNotEmpty) {
        setState(() {
          _nextEvent = events.first;
          _isLoadingEvent = false;
        });
      } else {
        setState(() {
          _nextEvent = null;
          _isLoadingEvent = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorEvent = 'Erreur lors du chargement: $e';
        _isLoadingEvent = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoadingFavorites = true;
    });

    try {
      final token = await TokenStorage.read();
      if (token == null) {
        setState(() {
          _favoriteEvents = [];
          _isLoadingFavorites = false;
        });
        return;
      }

      final response = await ApiClient.getFavorites(token: token);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final favoritesData = data['favorites'] as List<dynamic>? ?? [];
        
        // Récupérer les IDs des événements favoris
        final favoriteEventIds = favoritesData
            .map((f) => (f as Map<String, dynamic>)['event_id'] as int)
            .toList();

        if (favoriteEventIds.isNotEmpty) {
          // Charger tous les événements pour obtenir les détails
          final eventsResponse = await ApiClient.getEvents(page: 1, pageSize: 100);
          if (eventsResponse.statusCode == 200) {
            final eventsData = jsonDecode(eventsResponse.body) as Map<String, dynamic>;
            final allEventsData = eventsData['data'] as List<dynamic>;
            final allEvents = allEventsData
                .map((json) => EventItem.fromJson(json as Map<String, dynamic>))
                .toList();

            // Filtrer pour ne garder que les favoris
            final favoriteEvents = allEvents
                .where((e) => favoriteEventIds.contains(e.eventId))
                .toList();

            // Trier par date de début (le plus proche en premier)
            favoriteEvents.sort((a, b) => a.startAt.compareTo(b.startAt));

            setState(() {
              _favoriteEvents = favoriteEvents;
              _isLoadingFavorites = false;
            });
          } else {
            setState(() {
              _favoriteEvents = [];
              _isLoadingFavorites = false;
            });
          }
        } else {
          setState(() {
            _favoriteEvents = [];
            _isLoadingFavorites = false;
          });
        }
      } else {
        setState(() {
          _favoriteEvents = [];
          _isLoadingFavorites = false;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des favoris: $e');
      setState(() {
        _favoriteEvents = [];
        _isLoadingFavorites = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Important pour AutomaticKeepAliveClientMixin
    
    return Container(
      color: AppColors.getPrimaryBackground(context),
      child: Column(
        children: [
          const SizedBox(height: 48),
          // Carte (1/3 supérieur de l'écran)
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.33,
            child: Card(
              margin: const EdgeInsets.all(16),
              color: AppColors.getCardBackground(context),
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: AppColors.primaryButton.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // ✅ Carte OSM
                  OSMFlutter(
                    controller: controller,
                    onMapIsReady: (isReady) {
                      if (mounted) {
                        setState(() {
                          _isMapReady = true;
                        });
                      }
                    },
                    osmOption: OSMOption(
                      zoomOption: const ZoomOption(
                        initZoom: 13,
                        minZoomLevel: 3,
                        maxZoomLevel: 19,
                        stepZoom: 1.0,
                      ),
                      staticPoints: [
                        StaticPositionGeoPoint(
                          "angers",
                          const MarkerIcon(
                            icon: Icon(
                              Icons.location_city,
                              color: Colors.red,
                              size: 48,
                            ),
                          ),
                          [GeoPoint(latitude: _centerLat, longitude: _centerLng)],
                        ),
                      ],
                      roadConfiguration: const RoadOption(
                        roadColor: Colors.blueAccent,
                      ),
                    ),
                  ),
                  // ✅ Overlay de chargement
                  if (!_isMapReady)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.getMenuBackground(context),
                            AppColors.getPrimaryBackground(context),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: AppColors.primaryButton,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chargement de la carte...',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.getTextPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Prochain événement
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryButton.withOpacity(0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryButton.withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: AppColors.secondaryText.withOpacity(0.15),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: _isLoadingEvent
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _errorEvent != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prochain événement',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryButton,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorEvent!,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      )
                    : _nextEvent == null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Prochain événement',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryButton,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Aucun événement à venir',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          )
                        : InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EventDetailsScreen(
                                    event: _nextEvent!,
                                  ),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Prochain événement',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryButton,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _nextEvent!.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.getTextPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: AppColors.secondaryText,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_formatDate(_nextEvent!.startAt.toLocal())} à ${_formatTime(_nextEvent!.startAt.toLocal())}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_nextEvent!.location != null && _nextEvent!.location!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: AppColors.secondaryText,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _nextEvent!.location!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.secondaryText,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
          ),
          const SizedBox(height: 24),
          
          // Liste des favoris
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vos favoris',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryButton,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _isLoadingFavorites
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _favoriteEvents.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'Aucun événement en favoris',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 100),
                                itemCount: _favoriteEvents.length,
                                itemBuilder: (context, index) {
                                  final event = _favoriteEvents[index];
                                  return InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EventDetailsScreen(
                                            event: event,
                                          ),
                                        ),
                                      ).then((_) {
                                        // Recharger les favoris après retour
                                        _loadFavorites();
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.getCardBackground(context),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.primaryButton.withOpacity(0.2),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryButton.withOpacity(0.1),
                                            blurRadius: 4,
                                            spreadRadius: 0,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  event.title,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.getTextPrimary(context),
                                                  ),
                                                ),
                                              ),
                                              Icon(
                                                Icons.star,
                                                size: 16,
                                                color: AppColors.primaryButton,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 14,
                                                color: AppColors.secondaryText,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${_formatDate(event.startAt.toLocal())} à ${_formatTime(event.startAt.toLocal())}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: AppColors.secondaryText,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (event.location != null && event.location!.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.location_on,
                                                  size: 14,
                                                  color: AppColors.secondaryText,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    event.location!,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: AppColors.secondaryText,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

