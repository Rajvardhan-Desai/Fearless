import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

import 'package:google_maps_webservice/places.dart' as gmw;

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  SearchPageState createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> {
  CameraPosition _initialLocation = const CameraPosition(
    target: LatLng(18.516726, 73.856255),
    zoom: 12.0,
  ); // Example: San Francisco
  late GoogleMapController mapController;
  bool _isTrafficEnabled = true;

  late gmw.GoogleMapsPlaces places;

  Future<List<gmw.Prediction>> _fetchPlaceSuggestions(String input) async {
    if (input.isEmpty) return [];
    try {
      final response = await places.autocomplete(input);
      if (response.isOkay) {
        return response.predictions;
      } else {
        print("Error fetching place suggestions: ${response.errorMessage}");
        _showSnackBar('Error fetching suggestions: ${response.errorMessage}');
        return [];
      }
    } catch (e) {
      print("Exception fetching suggestions: $e");
      _showSnackBar('Exception: $e');
      return [];
    }
  }

  Position? _currentPosition;
  String _currentAddress = '';

  final startAddressController = TextEditingController();
  final destinationAddressController = TextEditingController();

  final startAddressFocusNode = FocusNode();
  final destinationAddressFocusNode = FocusNode();

  String _startAddress = '';
  String _destinationAddress = '';
  String? _placeDistance;

  Set<Marker> markers = {};

  late PolylinePoints polylinePoints;
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final String googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY']!;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    polylinePoints = PolylinePoints();
    places = gmw.GoogleMapsPlaces(apiKey: dotenv.env['GOOGLE_MAPS_API_KEY']!);
  }

  Future<void> _checkPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Check for permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permissions are denied');
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permissions are permanently denied.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Permissions are granted, proceed
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Try last known location first
      Position? lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null && mounted) {
        setState(() {
          _currentPosition = lastKnownPosition;
          _initialLocation = CameraPosition(
            target:
                LatLng(lastKnownPosition.latitude, lastKnownPosition.longitude),
            zoom: 18.0,
          );
        });
        mapController
            .animateCamera(CameraUpdate.newCameraPosition(_initialLocation));
      }

      // Fetch updated location in background
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _initialLocation = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 18.0,
          );
        });
        mapController
            .animateCamera(CameraUpdate.newCameraPosition(_initialLocation));
        await _getAddress();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error getting location: $e');
      }
    }
  }

  Future<void> _getAddress() async {
    if (_currentPosition == null) return;
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      Placemark place = placemarks[0];
      if (mounted) {
        setState(() {
          _currentAddress =
              "${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}";
          startAddressController.text = _currentAddress;
          _startAddress = _currentAddress;
        });
      }
    } catch (e) {
      _showSnackBar('Error getting address: $e');
    }
  }

  Future<bool> _calculateDistance() async {
    try {
      if (_startAddress.isEmpty ||
          _destinationAddress.isEmpty ||
          _currentPosition == null) {
        _showSnackBar('Invalid addresses or location');
        return false;
      }

      List<Location> startPlacemark = await locationFromAddress(_startAddress);
      List<Location> destinationPlacemark =
          await locationFromAddress(_destinationAddress);

      double startLatitude = _startAddress == _currentAddress
          ? _currentPosition!.latitude
          : startPlacemark[0].latitude;

      double startLongitude = _startAddress == _currentAddress
          ? _currentPosition!.longitude
          : startPlacemark[0].longitude;

      double destinationLatitude = destinationPlacemark[0].latitude;
      double destinationLongitude = destinationPlacemark[0].longitude;

      String startCoordinatesString = '($startLatitude, $startLongitude)';
      String destinationCoordinatesString =
          '($destinationLatitude, $destinationLongitude)';

      Marker startMarker = Marker(
        markerId: MarkerId(startCoordinatesString),
        position: LatLng(startLatitude, startLongitude),
        infoWindow: InfoWindow(title: 'Start', snippet: _startAddress),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );

      Marker destinationMarker = Marker(
        markerId: MarkerId(destinationCoordinatesString),
        position: LatLng(destinationLatitude, destinationLongitude),
        infoWindow:
            InfoWindow(title: 'Destination', snippet: _destinationAddress),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );

      setState(() {
        markers.add(startMarker);
        markers.add(destinationMarker);
      });

      LatLngBounds bounds;
      if (startLatitude > destinationLatitude &&
          startLongitude > destinationLongitude) {
        bounds = LatLngBounds(
          southwest: LatLng(destinationLatitude, destinationLongitude),
          northeast: LatLng(startLatitude, startLongitude),
        );
      } else if (startLongitude > destinationLongitude) {
        bounds = LatLngBounds(
          southwest: LatLng(startLatitude, destinationLongitude),
          northeast: LatLng(destinationLatitude, startLongitude),
        );
      } else if (startLatitude > destinationLatitude) {
        bounds = LatLngBounds(
          southwest: LatLng(destinationLatitude, startLongitude),
          northeast: LatLng(startLatitude, destinationLongitude),
        );
      } else {
        bounds = LatLngBounds(
          southwest: LatLng(startLatitude, startLongitude),
          northeast: LatLng(destinationLatitude, destinationLongitude),
        );
      }

      mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));

      await _createPolylines(
        startLatitude,
        startLongitude,
        destinationLatitude,
        destinationLongitude,
      );

      double totalDistance = 0.0;
      for (int i = 0; i < polylineCoordinates.length - 1; i++) {
        totalDistance += Geolocator.distanceBetween(
          polylineCoordinates[i].latitude,
          polylineCoordinates[i].longitude,
          polylineCoordinates[i + 1].latitude,
          polylineCoordinates[i + 1].longitude,
        );
      }

      setState(() {
        _placeDistance =
            (totalDistance / 1000).toStringAsFixed(2); // Convert to km
      });

      return true;
    } catch (e) {
      _showSnackBar('Error calculating distance: $e');
      return false;
    }
  }

  Future<void> _createPolylines(
      double startLatitude,
      double startLongitude,
      double destinationLatitude,
      double destinationLongitude,
      ) async {
    final String baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
    final String origin = '$startLatitude,$startLongitude';
    final String destination = '$destinationLatitude,$destinationLongitude';

    final Uri uri = Uri.parse(
      '$baseUrl?origin=$origin&destination=$destination&alternatives=true&key=$googleMapsApiKey',
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          setState(() {
            polylineCoordinates.clear();
            polylines.clear();

            int routeIndex = 0;

            for (var route in data['routes']) {
              String encodedPolyline = route['overview_polyline']['points'];
              List<LatLng> polylineCoords = _decodePolyline(encodedPolyline);

              if (routeIndex == 0) {
                polylineCoordinates = polylineCoords; // Set default route coordinates
              }

              PolylineId polylineId = PolylineId('route_$routeIndex');
              polylines[polylineId] = Polyline(
                polylineId: polylineId,
                color: routeIndex == 0 ? Colors.blue : Colors.grey,
                points: polylineCoords,
                width: 5,
                onTap: () => _onRouteTapped(routeIndex, polylineCoords),
              );

              routeIndex++;
            }
          });
        } else {
          _showSnackBar('Error: ${data['error_message']}');
        }
      } else {
        _showSnackBar('Error fetching routes: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Error creating polylines: $e');
    }
  }

  void _onRouteTapped(int routeIndex, List<LatLng> selectedRoute) {
    setState(() {
      polylines.forEach((id, polyline) {
        polylines[id] = polyline.copyWith(
          colorParam: id.value == 'route_$routeIndex' ? Colors.blue : Colors.grey,
          widthParam: id.value == 'route_$routeIndex' ? 6 : 4,
        );
      });

      // Calculate and display the distance for the selected route
      double totalDistance = _calculateRouteDistance(selectedRoute);
      _placeDistance = totalDistance.toStringAsFixed(2); // Update distance
    });

    // Fit the camera to the selected route
    LatLngBounds bounds = _getLatLngBounds(selectedRoute);
    mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));

    _showSnackBar('Selected Route: $_placeDistance km');
  }


  LatLngBounds _getLatLngBounds(List<LatLng> points) {
    double south = points.map((e) => e.latitude).reduce(min);
    double west = points.map((e) => e.longitude).reduce(min);
    double north = points.map((e) => e.latitude).reduce(max);
    double east = points.map((e) => e.longitude).reduce(max);

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }


  double _calculateRouteDistance(List<LatLng> route) {
    double totalDistance = 0.0;
    for (int i = 0; i < route.length - 1; i++) {
      totalDistance += Geolocator.distanceBetween(
        route[i].latitude,
        route[i].longitude,
        route[i + 1].latitude,
        route[i + 1].longitude,
      );
    }
    return totalDistance / 1000; // Return distance in kilometers
  }




  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polyline;
  }





  Widget _textField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required double width,
    required Icon prefixIcon,
    Widget? suffixIcon,
    required Function(String) locationCallback,
  }) {
    return Container(
      width: width * 0.8,
      child: GestureDetector(
        onTap: () async {
          // Trigger Autocomplete
          showModalBottomSheet(
            context: context,
            builder: (BuildContext context) {
              return _buildPlaceAutocomplete(controller, locationCallback);
            },
          );
        },
        child: AbsorbPointer(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              labelText: label,
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10.0)),
                borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10.0)),
                borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
              ),
              contentPadding: EdgeInsets.all(15),
              hintText: hint,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceAutocomplete(
    TextEditingController controller,
    Function(String) locationCallback,
  ) {
    // Move suggestions outside to maintain state
    List<gmw.Prediction> suggestions = [];
    Timer? _debounce;
    bool _isLoadingSuggestions = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: TextField(
                autofocus: true,
                onChanged: (value) async {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce =
                      Timer(const Duration(milliseconds: 500), () async {
                    if (value.isNotEmpty) {
                      setState(() {
                        _isLoadingSuggestions = true;
                      });
                      var fetchedSuggestions =
                          await _fetchPlaceSuggestions(value);
                      setState(() {
                        suggestions = fetchedSuggestions;
                        _isLoadingSuggestions = false;
                      });
                    } else {
                      setState(() {
                        suggestions = [];
                        _isLoadingSuggestions = false;
                      });
                    }
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Search for a place',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: _isLoadingSuggestions
                  ? Center(child: CircularProgressIndicator())
                  : suggestions.isEmpty
                      ? Center(child: Text('No suggestions found'))
                      : ListView.builder(
                          itemCount: suggestions.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(
                                  suggestions[index].description ?? 'Unknown'),
                              onTap: () {
                                controller.text =
                                    suggestions[index].description ?? '';
                                locationCallback(controller.text);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel(); // Dispose debounce
    startAddressController.dispose();
    destinationAddressController.dispose();
    startAddressFocusNode.dispose();
    destinationAddressFocusNode.dispose();
    mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;

    return Scaffold(
      key: _scaffoldKey,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: <Widget>[
                // Map View
                GoogleMap(
                  markers: markers,
                  initialCameraPosition: _initialLocation,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  mapType: MapType.normal,
                  trafficEnabled:
                      _isTrafficEnabled, // Add this line for traffic overlay
                  zoomGesturesEnabled: true,
                  zoomControlsEnabled: false,
                  polylines: Set<Polyline>.of(polylines.values),
                  onMapCreated: (GoogleMapController controller) {
                    print("Map created successfully");
                    mapController = controller;
                    _getCurrentLocation();
                  },
                ),

                // Zoom Buttons
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10.0, bottom: 10.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        _trafficButton(Icons.traffic_outlined, () {
                          setState(() {
                            _isTrafficEnabled = !_isTrafficEnabled;
                          });
                        }),
                        const SizedBox(height: 20),
                        _zoomButton(Icons.add, () {
                          mapController.animateCamera(CameraUpdate.zoomIn());
                        }),
                        const SizedBox(height: 20),
                        _zoomButton(Icons.remove, () {
                          mapController.animateCamera(CameraUpdate.zoomOut());
                        }),
                      ],
                    ),
                  ),
                ),
                // Input Fields & Show Route Button
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: _inputFields(width),
                    ),
                  ),
                ),
                // Current Location Button
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10.0, bottom: 10.0),
                      child: _currentLocationButton(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onPressed) {
    return ClipOval(
      child: Material(
        color: Colors.blue.shade100,
        child: InkWell(
          splashColor: Colors.blue,
          onTap: onPressed,
          child: SizedBox(
            width: 50,
            height: 50,
            child: Icon(icon),
          ),
        ),
      ),
    );
  }

  Widget _trafficButton(IconData icon, VoidCallback onPressed) {
    return ClipOval(
      child: Material(
        color: Colors.blue.shade100,
        child: InkWell(
          splashColor: Colors.blue,
          onTap: onPressed,
          child: SizedBox(
            width: 50,
            height: 50,
            child: Icon(icon),
          ),
        ),
      ),
    );
  }

  Widget _inputFields(double width) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white70,
        borderRadius: BorderRadius.all(Radius.circular(20.0)),
      ),
      width: width * 0.9,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 5.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Places',
              style: TextStyle(fontSize: 20.0),
            ),
            SizedBox(height: 10),
            _textField(
              label: 'Start',
              hint: 'Choose starting point',
              prefixIcon: Icon(Icons.looks_one),
              suffixIcon: IconButton(
                icon: Icon(Icons.my_location),
                onPressed: () {
                  if (_currentAddress.isNotEmpty) {
                    setState(() {
                      startAddressController.text = _currentAddress;
                      _startAddress = _currentAddress;
                    });
                  } else {
                    _showSnackBar('Current location not available');
                  }
                },
              ),
              controller: startAddressController,
              focusNode: startAddressFocusNode,
              width: width,
              locationCallback: (String value) {
                setState(() {
                  _startAddress = value;
                });
              },
            ),
            SizedBox(height: 10),
            _textField(
              label: 'Destination',
              hint: 'Choose destination',
              prefixIcon: Icon(Icons.looks_two),
              controller: destinationAddressController,
              focusNode: destinationAddressFocusNode,
              width: width,
              locationCallback: (String value) {
                setState(() {
                  _destinationAddress = value;
                });
              },
            ),
            SizedBox(height: 10),
            Visibility(
              visible: _placeDistance != null,
              child: Text(
                'DISTANCE: $_placeDistance km',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 5),
            ElevatedButton(
              onPressed: (_startAddress.isNotEmpty && _destinationAddress.isNotEmpty)
                  ? () async {
                startAddressFocusNode.unfocus();
                destinationAddressFocusNode.unfocus();
                setState(() {
                  markers.clear();
                  polylines.clear();
                  polylineCoordinates.clear();
                  _placeDistance = null;
                });

                bool isCalculated = await _calculateDistance();
                if (isCalculated) {
                  _showSnackBar('Distance Calculated Successfully');
                } else {
                  _showSnackBar('Error Calculating Distance');
                }
              }
                  : null,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                backgroundColor: Color(0xff6c5270),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Show Route'.toUpperCase(),
                  style: TextStyle(color: Colors.white, fontSize: 20.0),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _currentLocationButton() {
    return ClipOval(
      child: Material(
        color: Colors.orange.shade100,
        child: InkWell(
          splashColor: Colors.orange,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.my_location),
          ),
          onTap: () {
            if (_currentPosition != null) {
              mapController.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(_currentPosition!.latitude,
                        _currentPosition!.longitude),
                    zoom: 18.0,
                  ),
                ),
              );
            } else {
              _showSnackBar('Current location not available');
            }
          },
        ),
      ),
    );
  }
}
