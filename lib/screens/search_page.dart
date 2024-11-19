import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_place/google_place.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Riverpod state management
final navigationStateProvider = StateNotifierProvider<NavigationStateNotifier, NavigationState>(
      (ref) => NavigationStateNotifier(),
);

class NavigationState {
  final bool isLoading;
  final bool isNavigating;
  final bool isRouteActive;
  final String? travelInfo;

  NavigationState({
    this.isLoading = false,
    this.isNavigating = false,
    this.isRouteActive = false,
    this.travelInfo,
  });

  NavigationState copyWith({
    bool? isLoading,
    bool? isNavigating,
    bool? isRouteActive,
    String? travelInfo,
  }) {
    return NavigationState(
      isLoading: isLoading ?? this.isLoading,
      isNavigating: isNavigating ?? this.isNavigating,
      isRouteActive: isRouteActive ?? this.isRouteActive,
      travelInfo: travelInfo ?? this.travelInfo,
    );
  }
}

class NavigationStateNotifier extends StateNotifier<NavigationState> {
  NavigationStateNotifier() : super(NavigationState());

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setNavigating(bool navigating) {
    state = state.copyWith(isNavigating: navigating);
  }

  void setRouteActive(bool active) {
    state = state.copyWith(isRouteActive: active);
  }

  void setTravelInfo(String? info) {
    state = state.copyWith(travelInfo: info);
  }

  void clear() {
    state = NavigationState();
  }
}

// Debouncer
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  SearchPageState createState() => SearchPageState();
}

class SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  final Debouncer _debouncer = Debouncer(milliseconds: 500);
  Completer<GoogleMapController> _mapController = Completer();
  static const LatLng _initialPosition = LatLng(18.516726, 73.856255);
  Marker? _sourceMarker;
  Marker? _destinationMarker;
  Map<PolylineId, Polyline> _polylines = {};
  final Map<String, LatLng> _geocodeCache = {};
  late GooglePlace _googlePlace;
  Position? _currentPosition;
  final String _googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY']!;
  late StreamSubscription<Position> _positionSubscription;

  @override
  void initState() {
    super.initState();
    _googlePlace = GooglePlace(_googleApiKey);
    _requestLocationPermission();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _positionSubscription.cancel();
    _sourceController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status != PermissionStatus.granted) {
      _showErrorDialog('Location permission is required.');
      return;
    }
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _currentPosition = position;
    } catch (e) {
      _showErrorDialog('Failed to get current location: $e');
    }
  }

  void _startLocationUpdates() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _sourceMarker = Marker(
            markerId: const MarkerId('current_location'),
            position: LatLng(position.latitude, position.longitude),
            infoWindow: const InfoWindow(title: 'Current Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          );
        });

        if (ref.read(navigationStateProvider).isNavigating && _destinationMarker != null) {
          _getDirections(
            LatLng(position.latitude, position.longitude),
            _destinationMarker!.position,
          );
        }
      }
    });
  }

  Future<void> _getDirections(LatLng source, LatLng destination) async {
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${source.latitude},${source.longitude}&destination=${destination.latitude},${destination.longitude}&key=$_googleApiKey';

    final response = await http.get(Uri.parse(url));
    final json = jsonDecode(response.body);

    if (json['status'] == 'OK') {
      final route = json['routes'][0];
      final overviewPolyline = route['overview_polyline']['points'];
      final points = PolylinePoints().decodePolyline(overviewPolyline);

      final coordinates = points.map((point) => LatLng(point.latitude, point.longitude)).toList();
      _addPolyline(coordinates);
    } else {
      throw Exception('Failed to fetch directions');
    }
  }

  void _addPolyline(List<LatLng> coordinates) {
    final polylineId = PolylineId('route');
    final polyline = Polyline(
      polylineId: polylineId,
      points: coordinates,
      width: 5,
      color: Colors.blue,
    );
    setState(() {
      _polylines[polylineId] = polyline;
    });
  }

  Widget _buildAutocomplete(
      String label, TextEditingController controller, bool isSource) {
    return Autocomplete<AutocompletePrediction>(
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<AutocompletePrediction>.empty();
        }

        // Handle predictions with debouncing
        final completer = Completer<Iterable<AutocompletePrediction>>();
        _debouncer.run(() async {
          final predictions = await _googlePlace.autocomplete.get(
            textEditingValue.text,
            language: "en",
          );
          completer.complete(predictions?.predictions ?? const Iterable<AutocompletePrediction>.empty());
        });

        return completer.future;
      },
      displayStringForOption: (AutocompletePrediction option) =>
      option.description ?? '',
      onSelected: (AutocompletePrediction selection) {
        controller.text = selection.description ?? '';
      },
      fieldViewBuilder: (BuildContext context, TextEditingController fieldController,
          FocusNode focusNode, VoidCallback onFieldSubmitted) {
        return TextField(
          controller: fieldController,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey, width: 2.0),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            prefixIcon: isSource ? const Icon(Icons.location_on) : const Icon(Icons.flag),
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigationState = ref.watch(navigationStateProvider);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(target: _initialPosition, zoom: 12),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              markers: {
                if (_sourceMarker != null) _sourceMarker!,
                if (_destinationMarker != null) _destinationMarker!,
              },
              polylines: navigationState.isNavigating ? Set<Polyline>.of(_polylines.values) : {},
              onMapCreated: (GoogleMapController controller) {
                _mapController.complete(controller);
              },
            ),
          ),
          Positioned(
            top: 40,
            left: 15,
            right: 15,
            child: Column(
              children: [
                _buildAutocomplete('Enter Source', _sourceController, true),
                const SizedBox(height: 10),
                _buildAutocomplete('Enter Destination', _destinationController, false),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            right: 15,
            child: Column(
              children: [
                FloatingActionButton(
                  onPressed: navigationState.isNavigating ? null : () => _getDirections(
                    LatLng(18.516726, 73.856255), // Example source
                    LatLng(19.0760, 72.8777), // Example destination
                  ),
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
