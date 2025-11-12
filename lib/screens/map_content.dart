import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class MapContent extends StatefulWidget {
  const MapContent({super.key});

  @override
  State<MapContent> createState() => _MapContentState();
}

class _MapContentState extends State<MapContent> with AutomaticKeepAliveClientMixin {
  late MapController controller;
  bool _isMapReady = false;

  @override
  bool get wantKeepAlive => true; // ✅ Garde la carte en mémoire

  @override
  void initState() {
    super.initState();
    
    controller = MapController(
      initPosition: GeoPoint(latitude: 47.4784, longitude: -0.5632),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Important pour AutomaticKeepAliveClientMixin
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte d\'Angers'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          OSMFlutter(
            controller: controller,
            onMapIsReady: (isReady) {
              setState(() {
                _isMapReady = true;
              });
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
                      color: Colors.blue,
                      size: 48,
                    ),
                  ),
                  [GeoPoint(latitude: 47.4784, longitude: -0.5632)],
                ),
              ],
              userLocationMarker: UserLocationMaker(
                personMarker: const MarkerIcon(
                  icon: Icon(
                    Icons.location_history_rounded,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                directionArrowMarker: const MarkerIcon(
                  icon: Icon(
                    Icons.double_arrow,
                    size: 48,
                  ),
                ),
              ),
              roadConfiguration: const RoadOption(
                roadColor: Colors.blueAccent,
              ),
            ),
          ),
          // ✅ Overlay de chargement qui disparaît quand la carte est prête
          if (!_isMapReady)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Chargement de la carte...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
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
