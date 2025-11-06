import 'package:flutter/material.dart';
import 'events_content.dart';
import '../utils/app_colors.dart';

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

  // TODO: Replace with actual coordinates from the event
  static const double _defaultLat = 47.4739884;
  static const double _defaultLng = -0.5515588;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Initialiser l'opacité au démarrage
    _appBarOpacity = 0.0;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
                  ],
                  const SizedBox(height: 24),

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
                          // Map placeholder
                          Container(
                            width: double.infinity,
                            height: double.infinity,
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
                                  Icon(
                                    Icons.map,
                                    size: _isMapExpanded ? 60 : 50,
                                    color: AppColors.primaryButton,
                                  ),
                                  SizedBox(height: _isMapExpanded ? 12 : 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Text(
                                      widget.event.place,
                                      style: TextStyle(
                                        fontSize: _isMapExpanded ? 18 : 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.getTextPrimary(context),
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_isMapExpanded) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_defaultLat.toStringAsFixed(4)}°N, ${_defaultLng.toStringAsFixed(4)}°W',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.secondaryText,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryButton.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryButton.withOpacity(0.3),
                                            blurRadius: 8,
                                            spreadRadius: 0,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.location_on,
                                        color: AppColors.primaryButton,
                                        size: 28,
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_defaultLat.toStringAsFixed(4)}°N, ${_defaultLng.toStringAsFixed(4)}°W',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.secondaryText,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
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