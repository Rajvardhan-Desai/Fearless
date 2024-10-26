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

// Riverpod state management classes
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

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  SearchPageState createState() => SearchPageState();
}

class SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  Completer<GoogleMapController> _mapController = Completer();
  static const LatLng _initialPosition = LatLng(18.516726, 73.856255);
  Marker? _sourceMarker;
  Marker? _destinationMarker;
  Map<PolylineId, Polyline> _polylines = {};
  final Map<String, LatLng> _geocodeCache = {};
  late GooglePlace _googlePlace;
  Position? _currentPosition;
  final String _googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY']!;

  @override
  void initState() {
    super.initState();
    _googlePlace = GooglePlace(_googleApiKey);
    _requestLocationPermission();
    _startLocationUpdates(); // Start listening for location updates
  }

  @override
  void dispose() {
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
    Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)).listen((Position position) {
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
    });
  }

  Future<BitmapDescriptor> _createCustomMarker(String assetPath) async {
    final ImageConfiguration configuration = ImageConfiguration();
    return await BitmapDescriptor.fromAssetImage(configuration, assetPath);
  }

  void _setMarkers(LatLng sourceLatLng, LatLng destinationLatLng) async {
    BitmapDescriptor sourceIcon = await _createCustomMarker('assets/source_marker.png');
    BitmapDescriptor destinationIcon = await _createCustomMarker('assets/destination_marker.png');

    setState(() {
      _sourceMarker = Marker(
        markerId: const MarkerId('source'),
        position: sourceLatLng,
        icon: sourceIcon,
        infoWindow: const InfoWindow(title: 'Source'),
      );
      _destinationMarker = Marker(
        markerId: const MarkerId('destination'),
        position: destinationLatLng,
        icon: destinationIcon,
        infoWindow: const InfoWindow(title: 'Destination'),
      );
    });
    ref.read(navigationStateProvider.notifier).setRouteActive(true);
  }

  Future<void> _searchRoute() async {
    String source = _sourceController.text.trim();
    String destination = _destinationController.text.trim();

    if (source.isEmpty || destination.isEmpty) {
      _showErrorDialog('Please enter both source and destination.');
      return;
    }

    ref.read(navigationStateProvider.notifier).setLoading(true);

    try {
      LatLng sourceLatLng = source == 'Current Location' && _currentPosition != null
          ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
          : await _geocodeAddress(source);
      LatLng destinationLatLng = await _geocodeAddress(destination);

      _setMarkers(sourceLatLng, destinationLatLng);
      _fitMapToBounds(sourceLatLng, destinationLatLng);
      await _getDirections(sourceLatLng, destinationLatLng);
    } catch (e) {
      _showErrorDialog('Error occurred: $e');
    } finally {
      ref.read(navigationStateProvider.notifier).setLoading(false);
    }
  }

  Future<LatLng> _geocodeAddress(String address) async {
    if (_geocodeCache.containsKey(address)) {
      return _geocodeCache[address]!;
    }

    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_googleApiKey';

    final response = await http.get(Uri.parse(url));
    final json = jsonDecode(response.body);

    if (response.statusCode != 200 || json['status'] != 'OK' || json['results'].isEmpty) {
      _showErrorDialog('Failed to geocode address. Please try again.');
      throw Exception('Failed to geocode address: ${json['status']}');
    }

    final location = json['results'][0]['geometry']['location'];
    final latLng = LatLng(location['lat'], location['lng']);
    _geocodeCache[address] = latLng; // Cache the result
    return latLng;
  }

  Future<void> _getDirections(LatLng source, LatLng destination) async {
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${source.latitude},${source.longitude}&destination=${destination.latitude},${destination.longitude}&key=$_googleApiKey';

    final response = await http.get(Uri.parse(url));
    final json = jsonDecode(response.body);

    if (response.statusCode != 200 || json['status'] != 'OK') {
      _showErrorDialog('Failed to get directions. Please try again later.');
      throw Exception('Failed to get directions: ${json['status']}');
    }

    final route = json['routes'][0];
    final overviewPolyline = route['overview_polyline']['points'];
    final legs = route['legs'][0];
    ref.read(navigationStateProvider.notifier).setTravelInfo(
        '${legs['distance']['text']} - ${legs['duration']['text']}');

    _addPolyline(overviewPolyline);
  }

  void _addPolyline(String encodedPolyline) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> points = polylinePoints.decodePolyline(encodedPolyline);

    List<LatLng> coordinates =
    points.map((point) => LatLng(point.latitude, point.longitude)).toList();

    final PolylineId polylineId = const PolylineId('route');
    final Polyline polyline = Polyline(
      polylineId: polylineId,
      color: Colors.blue,
      width: 5,
      points: coordinates,
    );

    setState(() {
      _polylines[polylineId] = polyline;
    });
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

  Future<void> _fitMapToBounds(LatLng source, LatLng destination) async {
    final GoogleMapController controller = await _mapController.future;
    LatLngBounds bounds;

    if (source.latitude > destination.latitude && source.longitude > destination.longitude) {
      bounds = LatLngBounds(southwest: destination, northeast: source);
    } else if (source.longitude > destination.longitude) {
      bounds = LatLngBounds(
        southwest: LatLng(source.latitude, destination.longitude),
        northeast: LatLng(destination.latitude, source.longitude),
      );
    } else if (source.latitude > destination.latitude) {
      bounds = LatLngBounds(
        southwest: LatLng(destination.latitude, source.longitude),
        northeast: LatLng(source.latitude, destination.longitude),
      );
    } else {
      bounds = LatLngBounds(southwest: source, northeast: destination);
    }

    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
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
                  onPressed: navigationState.isNavigating ? _endNavigation : _startNavigation,
                  child: Icon(navigationState.isNavigating ? Icons.stop : Icons.navigation),
                ),
                const SizedBox(height: 10),
                navigationState.isRouteActive
                    ? FloatingActionButton(
                  onPressed: _clearRoute,
                  child: const Icon(Icons.clear),
                )
                    : FloatingActionButton(
                  onPressed: _searchRoute,
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          if (navigationState.isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (navigationState.travelInfo != null)
            Positioned(
              bottom: 100,
              left: 15,
              right: 15,
              child: Card(
                color: Colors.white,
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    navigationState.travelInfo!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAutocomplete(
      String label, TextEditingController controller, bool isSource) {
    return Column(
      children: [
        if (isSource)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _setSourceToCurrentLocation,
              child: const Text('Use Current Location'),
            ),
          ),
        Autocomplete<AutocompletePrediction>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<AutocompletePrediction>.empty();
            }
            final predictions = await _googlePlace.autocomplete.get(
              textEditingValue.text,
              language: "en",
            );
            return predictions?.predictions ?? const Iterable<AutocompletePrediction>.empty();
          },
          displayStringForOption: (AutocompletePrediction option) =>
          option.description ?? '',
          onSelected: (AutocompletePrediction selection) {
            controller.text = selection.description ?? '';
          },
          fieldViewBuilder: (BuildContext context, TextEditingController fieldController,
              FocusNode focusNode, VoidCallback onFieldSubmitted) {
            controller.addListener(() {
              fieldController.text = controller.text;
            });
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
                prefixIcon: isSource ? Icon(Icons.location_on) : Icon(Icons.flag),
              ),
            );
          },
        ),
      ],
    );
  }

  void _setSourceToCurrentLocation() {
    if (_currentPosition != null) {
      LatLng currentLatLng =
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      setState(() {
        _sourceMarker = Marker(
          markerId: const MarkerId('source'),
          position: currentLatLng,
          infoWindow: const InfoWindow(title: 'Current Location'),
        );
        _sourceController.text = 'Current Location';
      });
      _fitMapToBounds(currentLatLng, currentLatLng);
    } else {
      _showErrorDialog('Current location is not available.');
    }
  }

  void _clearRoute() {
    _sourceController.clear();
    _destinationController.clear();
    _sourceMarker = null;
    _destinationMarker = null;
    _polylines.clear();
    ref.read(navigationStateProvider.notifier).clear();
  }

  void _startNavigation() {
    if (_sourceMarker == null || _destinationMarker == null) {
      _showErrorDialog('Please search for a route first.');
      return;
    }
    ref.read(navigationStateProvider.notifier).setNavigating(true);
  }

  void _endNavigation() {
    ref.read(navigationStateProvider.notifier).setNavigating(false);
  }
}
