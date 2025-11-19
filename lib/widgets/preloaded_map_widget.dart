import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import '../services/map_service.dart';


class PreloadedMapWidget extends StatefulWidget {
  const PreloadedMapWidget({super.key});

  @override
  State<PreloadedMapWidget> createState() => _PreloadedMapWidgetState();
}

class _PreloadedMapWidgetState extends State<PreloadedMapWidget> with AutomaticKeepAliveClientMixin {
  MapController? _controller;
  bool _isReady = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = MapService().getController();
    _isReady = MapService().isReady;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_controller == null) {
      return const SizedBox.shrink();
    }

    return Opacity(
      opacity: 0,
      child: IgnorePointer(
        ignoring: true,
        child: SizedBox(
          width: 1,
          height: 1,
          child: OSMFlutter(
            controller: _controller!,
            onMapIsReady: (isReady) {
              if (mounted) {
                MapService().setReady(true);
                setState(() {
                  _isReady = true;
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
              roadConfiguration: const RoadOption(
                roadColor: Colors.blueAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

