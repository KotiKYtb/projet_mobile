import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import '../services/map_service.dart';

final _sharedMapKey = GlobalKey();

class _MapInstanceManager {
  static _MapInstanceManager? _instance;
  static _MapInstanceManager get instance => _instance ??= _MapInstanceManager._();
  _MapInstanceManager._();

  bool _hasActiveInstance = false;
  GlobalKey? _activeKey;

  bool canCreateInstance(GlobalKey key, {bool force = false}) {
    print(' MapInstanceManager.canCreateInstance: force=$force, hasActive=$_hasActiveInstance');
    debugPrint(' MapInstanceManager.canCreateInstance: force=$force, hasActive=$_hasActiveInstance');

    if (!_hasActiveInstance) {
      _hasActiveInstance = true;
      _activeKey = key;
      print(' MapInstanceManager: Première instance créée');
      debugPrint(' MapInstanceManager: Première instance créée');
      return true;
    }

    if (_activeKey == key) {
      print(' MapInstanceManager: Même instance, autorisée');
      debugPrint(' MapInstanceManager: Même instance, autorisée');
      return true;
    }

    if (force) {
      print(' MapInstanceManager: Force=true, remplacement de l\'instance active');
      debugPrint(' MapInstanceManager: Force=true, remplacement de l\'instance active');
      _activeKey = key;
      return true;
    }

    print(' MapInstanceManager: Instance bloquée (déjà une instance active)');
    debugPrint(' MapInstanceManager: Instance bloquée (déjà une instance active)');
    return false;
  }

  void releaseInstance(GlobalKey key) {
    print(' MapInstanceManager.releaseInstance appelé');
    debugPrint(' MapInstanceManager.releaseInstance appelé');
    if (_activeKey == key) {
      _hasActiveInstance = false;
      _activeKey = null;
      print(' MapInstanceManager: Instance libérée');
      debugPrint(' MapInstanceManager: Instance libérée');
    }
  }
  
  void forceRelease() {
    _hasActiveInstance = false;
    _activeKey = null;
  }
}


class SharedMapWidget extends StatefulWidget {
  final bool visible;
  final OSMOption? customOption;
  final Function(bool)? onMapReady;

  const SharedMapWidget({
    super.key,
    this.visible = true,
    this.customOption,
    this.onMapReady,
  });

  @override
  State<SharedMapWidget> createState() => _SharedMapWidgetState();
}

class _SharedMapWidgetState extends State<SharedMapWidget> with AutomaticKeepAliveClientMixin {
  MapController? _controller;
  bool _isMapReady = false;
  late final GlobalKey _instanceKey;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Créer une clé unique basée sur la clé du widget parent pour permettre plusieurs instances
    _instanceKey = GlobalKey();
    _controller = MapService().getController();
    if (MapService().isReady) {
      _isMapReady = true;
    }
    print(' SharedMapWidget.initState() - InstanceKey créé');
    debugPrint(' SharedMapWidget.initState() - InstanceKey créé');
  }

  @override
  void dispose() {
    _MapInstanceManager.instance.releaseInstance(_instanceKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_controller == null) {
      return const SizedBox.shrink();
    }

    final defaultOption = OSMOption(
      zoomOption: const ZoomOption(
        initZoom: 13,
        minZoomLevel: 3,
        maxZoomLevel: 19,
        stepZoom: 1.0,
      ),
      roadConfiguration: const RoadOption(
        roadColor: Colors.blueAccent,
      ),
    );

    final finalOption = widget.customOption ?? defaultOption;
    final staticPointsCount = finalOption.staticPoints?.length ?? 0;
    
    print(' SharedMapWidget.build() - staticPoints: $staticPointsCount');
    debugPrint(' SharedMapWidget.build() - staticPoints: $staticPointsCount');
    if (staticPointsCount > 0) {
      print('   IDs: ${finalOption.staticPoints!.map((p) => p.id).join(", ")}');
      debugPrint('   IDs: ${finalOption.staticPoints!.map((p) => p.id).join(", ")}');
    }

    if (!widget.visible) {
      print(' SharedMapWidget: visible=false, masquage du widget');
      debugPrint(' SharedMapWidget: visible=false, masquage du widget');
      return const SizedBox.shrink();
    }

    final canCreate = _MapInstanceManager.instance.canCreateInstance(_instanceKey, force: widget.visible);
    print(' SharedMapWidget: canCreateInstance=$canCreate (visible=${widget.visible})');
    debugPrint(' SharedMapWidget: canCreateInstance=$canCreate (visible=${widget.visible})');
    
    if (!canCreate) {
      print(' SharedMapWidget: Instance bloquée par MapInstanceManager');
      debugPrint(' SharedMapWidget: Instance bloquée par MapInstanceManager');
      return const SizedBox.shrink();
    }

    // Créer une clé unique basée sur les staticPoints pour forcer la reconstruction
    final pinsKey = staticPointsCount > 0 
        ? 'osm_${staticPointsCount}_${finalOption.staticPoints!.map((p) => p.id).join('_')}'
        : 'osm_empty';
    
    print(' SharedMapWidget: Clé OSMFlutter: $pinsKey');
    debugPrint(' SharedMapWidget: Clé OSMFlutter: $pinsKey');

    return OSMFlutter(
      key: ValueKey(pinsKey), // Utiliser ValueKey au lieu de GlobalKey pour forcer la reconstruction
      controller: _controller!,
      onMapIsReady: (isReady) {
        if (mounted) {
          MapService().setReady(true);
          setState(() {
            _isMapReady = true;
          });
          widget.onMapReady?.call(isReady);
        }
      },
      osmOption: finalOption,
    );
  }
}