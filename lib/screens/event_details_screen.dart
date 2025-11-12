import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'events_content.dart';
import '../utils/app_colors.dart';
import '../api_client.dart';
import '../token_storage.dart';

class EventDetailsScreen extends StatefulWidget {
  final EventItem event;

  const EventDetailsScreen({
    super.key,
    required this.event,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  bool _isMapExpanded = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _mapKey = GlobalKey();
  double _appBarOpacity = 0.0;
  bool _notificationsEnabled = false;
  bool _isFavorite = false;
  late MapController _mapController;
  bool _isMapReady = false;

  // TODO: Replace with actual coordinates from the event
  static const double _defaultLat = 47.4739884;
  static const double _defaultLng = -0.5515588;

  @override
  void initState() {
    super.initState();
    _mapController = MapController(
      initPosition: GeoPoint(latitude: _defaultLat, longitude: _defaultLng),
    );
    _scrollController.addListener(_onScroll);
    // Initialiser l'opacité au démarrage
    _appBarOpacity = 0.0;
    _loadNotificationPreference();
    _loadFavoritePreference();
  }

  Future<void> _loadNotificationPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'event_notification_${widget.event.eventId}';
      setState(() {
        _notificationsEnabled = prefs.getBool(key) ?? false;
      });
    } catch (e) {
      print('Erreur lors du chargement de la préférence de notification: $e');
    }
  }

  Future<void> _loadFavoritePreference() async {
    try {
      final token = await TokenStorage.read();
      if (token != null) {
        // Charger depuis l'API
        final response = await ApiClient.getFavorites(token: token);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final favorites = data['favorites'] as List<dynamic>? ?? [];
          final isFavorite = favorites.any((f) => 
            (f as Map<String, dynamic>)['event_id'] == widget.event.eventId
          );
          setState(() {
            _isFavorite = isFavorite;
          });
          
          // Sauvegarder aussi localement pour le cache
          final prefs = await SharedPreferences.getInstance();
          final key = 'event_favorite_${widget.event.eventId}';
          await prefs.setBool(key, isFavorite);
          return;
        }
      }
      
      // Fallback: charger depuis le cache local
      final prefs = await SharedPreferences.getInstance();
      final key = 'event_favorite_${widget.event.eventId}';
      setState(() {
        _isFavorite = prefs.getBool(key) ?? false;
      });
    } catch (e) {
      print('Erreur lors du chargement de la préférence de favori: $e');
      // Fallback: charger depuis le cache local
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = 'event_favorite_${widget.event.eventId}';
        setState(() {
          _isFavorite = prefs.getBool(key) ?? false;
        });
      } catch (e2) {
        print('Erreur lors du chargement du cache local: $e2');
      }
    }
  }

  Future<void> _toggleFavorite() async {
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

      final newValue = !_isFavorite;
      http.Response response;

      if (newValue) {
        // Ajouter aux favoris
        response = await ApiClient.addFavorite(
          token: token,
          eventId: widget.event.eventId,
        );
      } else {
        // Retirer des favoris
        response = await ApiClient.removeFavorite(
          token: token,
          eventId: widget.event.eventId,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _isFavorite = newValue;
        });
        
        // Sauvegarder aussi localement pour le cache
        final prefs = await SharedPreferences.getInstance();
        final key = 'event_favorite_${widget.event.eventId}';
        await prefs.setBool(key, newValue);
        
        // Afficher un message de confirmation en haut avec le design de l'app
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.transparent,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
              ),
              elevation: 0,
              padding: EdgeInsets.zero,
              content: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryButton.withOpacity(0.9),
                      AppColors.secondaryBackground.withOpacity(0.8),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primaryButton.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryButton.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                  Icon(
                    newValue ? Icons.star : Icons.star_border,
                    color: Colors.white,
                    size: 24,
                  ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        newValue 
                          ? 'Événement ajouté aux favoris'
                          : 'Événement retiré des favoris',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
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

  Future<void> _toggleNotifications(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'event_notification_${widget.event.eventId}';
      await prefs.setBool(key, enabled);
      setState(() {
        _notificationsEnabled = enabled;
      });
      
      // Afficher un message de confirmation en haut avec le design de l'app
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.transparent,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
            ),
            elevation: 0,
            padding: EdgeInsets.zero,
            content: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryButton.withOpacity(0.9),
                    AppColors.secondaryBackground.withOpacity(0.8),
                  ],
                ),
                border: Border.all(
                  color: AppColors.primaryButton.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryButton.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    enabled ? Icons.notifications_active : Icons.notifications_off,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      enabled 
                        ? 'Notifications activées pour cet événement'
                        : 'Notifications désactivées pour cet événement',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      print('Erreur lors de la sauvegarde de la préférence de notification: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    // Calculer l'opacité de l'overlay sombre basé sur la position du scroll
    // Plus on scroll, plus l'image devient sombre
    final expandedHeight = 200.0;
    final currentScroll = _scrollController.offset;
    final opacity = (currentScroll / expandedHeight).clamp(0.0, 1.0);
    
    setState(() {
      _appBarOpacity = opacity;
    });
  }

  void _scrollToMap() {
    final context = _mapKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.1, // Afficher la carte un peu en haut de l'écran
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getPrimaryBackground(context),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // App bar with hero animation
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.getMenuBackground(context),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryButton,
                        AppColors.secondaryBackground,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryButton.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            titleSpacing: 0,
            actions: [
              // Icône favori
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: InkWell(
                  onTap: _toggleFavorite,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isFavorite 
                        ? AppColors.primaryButton.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isFavorite 
                          ? AppColors.primaryButton
                          : Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _isFavorite 
                        ? Icons.star 
                        : Icons.star_border,
                      color: _isFavorite 
                        ? AppColors.primaryButton 
                        : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              // Icône notifications
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: InkWell(
                  onTap: () => _toggleNotifications(!_notificationsEnabled),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _notificationsEnabled 
                        ? AppColors.primaryButton.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _notificationsEnabled 
                          ? AppColors.primaryButton
                          : Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _notificationsEnabled 
                        ? Icons.notifications_active 
                        : Icons.notifications_off,
                      color: _notificationsEnabled 
                        ? AppColors.primaryButton 
                        : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.zero,
              centerTitle: false,
              title: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    widget.event.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 40,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image de fond
                        widget.event.imageUrl != null && widget.event.imageUrl!.isNotEmpty
                            ? Image.network(
                                widget.event.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          AppColors.getMenuBackground(context),
                                          AppColors.getCardBackground(context),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.event,
                                        size: 80,
                                        color: AppColors.primaryButton,
                                      ),
                                    ),
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          AppColors.getMenuBackground(context),
                                          AppColors.getCardBackground(context),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.primaryButton,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppColors.getMenuBackground(context),
                                      AppColors.getCardBackground(context),
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.event,
                                    size: 80,
                                    color: AppColors.primaryButton,
                                  ),
                                ),
                              ),
                        // Overlay sombre par défaut (opacité de base)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          color: Colors.black.withOpacity(0.4 + (_appBarOpacity * 0.4)),
                          // Opacité de base: 0.4 (40% sombre)
                          // Opacité maximale lors du scroll: 0.8 (80% sombre)
                        ),
                      ],
                    ),
            ),
          ),
          // Event details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date and time
                  Card(
                    color: AppColors.getCardBackground(context),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.primaryButton.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    shadowColor: AppColors.primaryButton.withOpacity(0.3),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryButton.withOpacity(0.15),
                            blurRadius: 10,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.calendar_today,
                          color: AppColors.primaryButton,
                        ),
                        title: Text(
                          _formatDate(widget.event.startAt.toLocal()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        subtitle: Text(
                          _formatTime(widget.event.startAt.toLocal()),
                          style: TextStyle(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Location
                  Card(
                    color: AppColors.getCardBackground(context),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.primaryButton.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    shadowColor: AppColors.primaryButton.withOpacity(0.3),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryButton.withOpacity(0.15),
                            blurRadius: 10,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.location_on,
                          color: AppColors.primaryButton,
                        ),
                        title: Text(
                          widget.event.place,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        subtitle: Text(
                          'Tap pour voir sur la carte',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _isMapExpanded = !_isMapExpanded;
                          });
                          // Mettre à jour le zoom de la carte
                          if (_isMapReady && _mapController != null) {
                            _mapController!.setZoom(zoomLevel: _isMapExpanded ? 15.0 : 13.0);
                          }
                          // Attendre un peu pour que l'animation se termine avant de scroller
                          Future.delayed(const Duration(milliseconds: 350), () {
                            _scrollToMap();
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  if (widget.event.description != null && widget.event.description!.isNotEmpty) ...[
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryButton,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.event.description!,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],


                  // Map
                  AnimatedContainer(
                    key: _mapKey,
                    duration: const Duration(milliseconds: 300),
                    height: _isMapExpanded ? 400 : 200,
                    child: Card(
                      color: AppColors.getCardBackground(context),
                      clipBehavior: Clip.antiAlias,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: AppColors.primaryButton.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      shadowColor: AppColors.primaryButton.withOpacity(0.3),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryButton.withOpacity(0.2),
                              blurRadius: 15,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: AppColors.secondaryText.withOpacity(0.15),
                              blurRadius: 10,
                              spreadRadius: 0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                        children: [
                          // Carte OSM
                          OSMFlutter(
                            controller: _mapController,
                            onMapIsReady: (isReady) {
                              if (mounted) {
                                setState(() {
                                  _isMapReady = true;
                                });
                              }
                            },
                            osmOption: OSMOption(
                              zoomOption: ZoomOption(
                                initZoom: _isMapExpanded ? 15 : 13,
                                minZoomLevel: 3,
                                maxZoomLevel: 19,
                                stepZoom: 1.0,
                              ),
                              staticPoints: [
                                StaticPositionGeoPoint(
                                  "event_location",
                                  const MarkerIcon(
                                    icon: Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 48,
                                    ),
                                  ),
                                  [GeoPoint(latitude: _defaultLat, longitude: _defaultLng)],
                                ),
                              ],
                              roadConfiguration: const RoadOption(
                                roadColor: Colors.blueAccent,
                              ),
                            ),
                          ),
                          // Overlay de chargement
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
                                  mainAxisSize: MainAxisSize.min,
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
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryButton.withOpacity(0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: FloatingActionButton.small(
                                backgroundColor: AppColors.primaryButton,
                                onPressed: () {
                                  setState(() {
                                    _isMapExpanded = !_isMapExpanded;
                                  });
                                  // Mettre à jour le zoom de la carte
                                  if (_isMapReady) {
                                    _mapController.setZoom(zoomLevel: _isMapExpanded ? 15.0 : 13.0);
                                  }
                                  // Attendre un peu pour que l'animation se termine avant de scroller
                                  Future.delayed(const Duration(milliseconds: 350), () {
                                    _scrollToMap();
                                  });
                                },
                                child: Icon(
                                  _isMapExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
                                  color: AppColors.getTextPrimary(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                        ),
                      ),
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

  String _formatDate(DateTime date) {
    const List<String> days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    const List<String> months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 
                                'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    
    final weekday = days[date.weekday - 1];
    final month = months[date.month - 1];
    
    return '$weekday ${date.day} $month ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}