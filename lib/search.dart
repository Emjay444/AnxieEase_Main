import 'dart:async';
import 'dart:math' as math;
import 'dart:math' show min;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'utils/logger.dart';

// Add travel mode enum near the top of the file
enum TravelMode { driving, walking, bicycling, transit }

/// A short-lived cache entry for a clinic search at a given location bucket.
class _CachedClinicSearch {
  _CachedClinicSearch(this.places, this.fetchedAt);
  final List<Map<String, dynamic>> places;
  final DateTime fetchedAt;
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  SearchScreenState createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  final dio = Dio();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final BitmapDescriptor _mentalHealthMarkerIcon =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
  final BitmapDescriptor _selectedMarkerIcon =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

  // Store nearby places data for the list view
  List<Map<String, dynamic>> _nearbyPlaces = [];

  Position? _currentPosition;
  bool _isLoading = true;
  bool _mapCreated = false;
  final bool _showMap = true; // Default to showing the map
  bool _mapError = false;
  bool _hasLocationPermission = false;
  Map<String, dynamic>? _selectedPlace;
  String _errorMessage = '';
  String? _lastPlacesApiError;
  TravelMode _selectedTravelMode = TravelMode.driving;
  // Tracks whether the in-app permission rationale dialog has already been
  // shown this screen session, so retries don't show it again.
  bool _rationaleShown = false;

  // Animation controller for camera movements
  AnimationController? _animationController;

  // Store route details for display
  String? _routeDistance;
  String? _routeDuration;
  bool _isNavigating = false;

  // Location tracking for navigation
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isLocationTracking = false;

  // Voice guidance
  FlutterTts flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _voiceGuidanceEnabled = true; // Default to enabled

  // UI state
  bool _isBottomCardCollapsed = false; // Track if bottom card is collapsed

  // Places/Directions REST calls go through our own Cloud Functions proxy
  // instead of calling Google Maps directly with an embedded key. The key
  // lives server-side only (functions/.env -> MAPS_SERVER_KEY), so it can't
  // be lifted out of the APK and abused against our billing account.
  static const String _proxyBaseUrl =
      'https://us-central1-anxieease-sensors.cloudfunctions.net';

  // Cache of recent search results keyed by a rounded lat/lng "bucket" so
  // reopening this screen near the same spot doesn't re-spend API quota.
  static final Map<String, _CachedClinicSearch> _searchCache = {};
  static const Duration _cacheTtl = Duration(minutes: 15);

  // Control for the draggable bottom sheet
  final DraggableScrollableController _dragController =
      DraggableScrollableController();
  // Add a new controller for the clinic list draggable sheet
  final DraggableScrollableController _clinicListController =
      DraggableScrollableController();

  // Navigation state
  List<dynamic> _navigationSteps = [];
  int _currentStepIndex = 0;

  @override
  void initState() {
    super.initState();
    Logger.info('SearchScreen initialized');
    // Setup animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    // Initialize text-to-speech
    _initTts();
    // Test internet connectivity
    testInternet();
    // Simply use default markers with different hues
    _getCurrentLocation();
  }

  // Initialize text-to-speech engine
  Future<void> _initTts() async {
    try {
      await flutterTts.setLanguage("en-US");
      await flutterTts
          .setSpeechRate(0.5); // Slower rate for better understanding
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);

      // Set audio quality parameters
      await flutterTts.setSpeechRate(0.5); // Repeat for emphasis

      // Try to set a voice similar to Google Maps
      try {
        final voices = await flutterTts.getVoices;
        if (voices != null) {
          // Look for a voice that sounds like Google Maps
          final voiceList = voices as List;

          // First try to find a Google voice
          var googleVoice = voiceList.firstWhere(
            (voice) =>
                (voice['name'] as String).toLowerCase().contains('google'),
            orElse: () => null,
          );

          // If no Google voice, try to find a US English voice
          googleVoice ??= voiceList.firstWhere(
            (voice) =>
                (voice['name'] as String).toLowerCase().contains('en-us'),
            orElse: () => null,
          );

          // If we found a suitable voice, use it
          if (googleVoice != null) {
            await flutterTts
                .setVoice({"name": googleVoice['name'], "locale": "en-US"});
            Logger.info('Set voice to: ${googleVoice['name']}');
          }
        }
      } catch (e) {
        Logger.error('Error setting voice', e);
        // Continue with default voice if there's an error
      }

      // Set completion handler
      flutterTts.setCompletionHandler(() {
        setState(() {
          _isSpeaking = false;
        });
      });

      // Set error handler
      flutterTts.setErrorHandler((msg) {
        Logger.error('TTS error: $msg');
        setState(() {
          _isSpeaking = false;
        });
      });

      Logger.info('TTS initialized successfully');
    } catch (e) {
      Logger.error('Error initializing TTS', e);
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _stopLocationTracking(); // Stop location tracking when disposing
    _stopSpeaking(); // Stop any ongoing speech
    flutterTts.stop();
    dio.close();
    _dragController.dispose();
    _clinicListController.dispose();
    super.dispose();
  }

  // Start real-time location tracking for navigation
  void _startLocationTracking() {
    if (_isLocationTracking) return; // Already tracking

    try {
      Logger.info('Starting location tracking for navigation');

      // Set up location tracking with high accuracy
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      );

      // Listen to position updates
      _positionStreamSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen((Position position) {
        Logger.debug('Position update: $position');

        // Update current position
        setState(() {
          _currentPosition = position;
        });

        // Update the current location marker
        _updateCurrentLocationMarker();

        // If navigating, update the camera to follow the user
        if (_isNavigating && _mapCreated) {
          _followUserLocation();
        }
      });

      _isLocationTracking = true;
    } catch (e) {
      Logger.error('Error starting location tracking', e);
    }
  }

  // Stop location tracking
  void _stopLocationTracking() {
    if (_positionStreamSubscription != null) {
      Logger.info('Stopping location tracking');
      _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
      _isLocationTracking = false;
    }
  }

  // Update just the current location marker without clearing other markers
  void _updateCurrentLocationMarker() {
    if (_currentPosition == null) return;

    setState(() {
      // Remove the old current location marker
      _markers.removeWhere(
          (marker) => marker.markerId == const MarkerId('current_location'));

      // Add the new current location marker
      _markers.add(Marker(
        markerId: const MarkerId('current_location'),
        position:
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        zIndex: 2, // Make sure it's on top of other markers
      ));
    });
  }

  // Follow user's location during navigation
  Future<void> _followUserLocation() async {
    if (!_controller.isCompleted || _currentPosition == null) return;

    try {
      final GoogleMapController controller = await _controller.future;

      // Get the next point in the route to calculate bearing
      final points = _polylines.first.points;
      if (points.isEmpty) return;

      // Find the closest point on the route to the current position
      final currentLatLng =
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      final closestPointIndex = _findClosestPointIndex(currentLatLng, points);

      // If we have a next point, use it for bearing
      double bearing = 0;
      if (closestPointIndex < points.length - 1) {
        bearing = _getBearing(currentLatLng, points[closestPointIndex + 1]);
      }

      // Animate camera to follow user with the correct bearing in 2D
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentLatLng,
            zoom: 17.0,
            tilt: 0.0, // No tilt for 2D view
            bearing: bearing,
          ),
        ),
      );

      // Check if we need to announce the next navigation step
      _checkAndAnnounceNavigationStep(currentLatLng);

      // Check if user has reached the destination
      _checkDestinationReached(currentLatLng);
    } catch (e) {
      Logger.error('Error following user location', e);
    }
  }

  // Check if we need to announce the next navigation step based on user's position
  void _checkAndAnnounceNavigationStep(LatLng currentPosition) {
    if (!_isNavigating || _navigationSteps.isEmpty) return;

    try {
      // Find the closest step to the current position
      int closestStepIndex = _findClosestStepIndex(currentPosition);

      // If the closest step is different from the current step, announce it
      if (closestStepIndex != _currentStepIndex && closestStepIndex >= 0) {
        setState(() {
          _currentStepIndex = closestStepIndex;
        });

        // Announce the new step
        _announceNextStep(closestStepIndex);
      }
    } catch (e) {
      Logger.error('Error checking navigation step', e);
    }
  }

  // Find the closest navigation step to the current position
  int _findClosestStepIndex(LatLng currentPosition) {
    if (_navigationSteps.isEmpty) return -1;

    double minDistance = double.infinity;
    int closestIndex = -1;

    for (int i = 0; i < _navigationSteps.length; i++) {
      final step = _navigationSteps[i];

      // Get the start location of the step
      final startLat = step['start_location']?['lat'];
      final startLng = step['start_location']?['lng'];

      if (startLat == null || startLng == null) continue;

      // Calculate distance to the step's start location
      final distance = _calculateDistance(currentPosition.latitude,
          currentPosition.longitude, startLat, startLng);

      // If this step is closer than the previous closest, update
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    // Only consider it the closest if we're within 50 meters
    return (minDistance <= 50) ? closestIndex : -1;
  }

  // Find the index of the closest point on the route to the current position
  int _findClosestPointIndex(LatLng currentPosition, List<LatLng> routePoints) {
    if (routePoints.isEmpty) return 0;

    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < routePoints.length; i++) {
      final distance = _calculateDistance(
          currentPosition.latitude,
          currentPosition.longitude,
          routePoints[i].latitude,
          routePoints[i].longitude);

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // in meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  // Convert degrees to radians
  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  // Safely extracts lat/lng from a Google Places `geometry.location` object.
  // Returns null if geometry is missing or the coordinates are non-numeric
  // or out of valid range, so callers can skip the place instead of
  // crashing on a malformed Places API result.
  LatLng? _extractPlaceLatLng(Map<String, dynamic> place) {
    final geometry = place['geometry'];
    if (geometry is! Map) return null;
    final location = geometry['location'];
    if (location is! Map) return null;
    final lat = location['lat'];
    final lng = location['lng'];
    if (lat is! num || lng is! num) return null;
    final latD = lat.toDouble();
    final lngD = lng.toDouble();
    if (latD.isNaN || lngD.isNaN) return null;
    if (latD < -90 || latD > 90 || lngD < -180 || lngD > 180) return null;
    return LatLng(latD, lngD);
  }

  Future<void> _getCurrentLocation() async {
    try {
      Logger.info('Getting current location...');

      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage =
              'Location services are disabled. Please enable location in your device settings.';
          _isLoading = false;
        });
        Logger.warning('Location services are disabled');

        // Show a dialog to guide the user
        _showLocationServicesDialog();
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      Logger.info('Initial permission status: $permission');

      if (permission == LocationPermission.denied) {
        // Explain why we need location before the OS prompt fires, but only
        // the first time per screen session - not on every retry.
        if (!_rationaleShown) {
          _rationaleShown = true;
          final proceed = await _showLocationRationaleDialog();
          if (!proceed) {
            setState(() {
              _errorMessage =
                  'Location permission is needed to find nearby clinics.';
              _isLoading = false;
            });
            return;
          }
        }

        permission = await Geolocator.requestPermission();
        Logger.info('After request permission status: $permission');

        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage =
                'Location permissions are denied. Please grant location permission for this app.';
            _isLoading = false;
          });
          Logger.warning('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage =
              'Location permissions are permanently denied. Please enable them in app settings.';
          _isLoading = false;
        });
        Logger.warning('Location permissions are permanently denied');
        return;
      }

      // If we reach here, we have permission
      Logger.info('Getting position with extended timeout...');

      try {
        // Try with higher accuracy and longer timeout
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15), // Extended timeout
        );

        Logger.info('Position obtained: $position');
        setState(() {
          _currentPosition = position;
          _isLoading = false;
          _errorMessage = ''; // Clear any error messages
          _hasLocationPermission = true; // Set permission flag
        });

        // Add a marker for the current position
        _addCurrentLocationMarker();

        // Start a timer to check if the map has been created
        _startMapCreationTimer();

        _searchClinicsWhenMapIsReady();
      } catch (e) {
        Logger.error(
            'Error getting high accuracy position, trying with lower accuracy',
            e);

        try {
          // Try again with lower accuracy as fallback
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );

          Logger.info('Position obtained with lower accuracy: $position');
          setState(() {
            _currentPosition = position;
            _isLoading = false;
            _errorMessage = 'Using approximate location (low accuracy).';
          });

          // Add a marker for the current position
          _addCurrentLocationMarker();

          // Start a timer to check if the map has been created
          _startMapCreationTimer();

          _searchClinicsWhenMapIsReady();
        } catch (e2) {
          Logger.error(
              'Error getting position with any accuracy, using default', e2);

          // Only use default position as a last resort
          _useDefaultPosition(
              'Could not determine your location. Using a default location instead. Please check your device location settings.');
        }
      }
    } catch (e) {
      Logger.error('Error in _getCurrentLocation', e);
      _useDefaultPosition('Error accessing location services: ${e.toString()}');
    }
  }

  // Helper method to use default position when location cannot be determined
  void _useDefaultPosition(String errorMessage) {
    if (!mounted) return;

    // Default position in Manila or your preferred default location
    Position defaultPosition = Position(
      latitude: 14.5995,
      longitude: 120.9842,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

    setState(() {
      _currentPosition = defaultPosition;
      _isLoading = false;
      _errorMessage = errorMessage;
    });

    // Add a marker for the default position
    _addCurrentLocationMarker();

    // Start a timer to check if the map has been created
    _startMapCreationTimer();

    _searchClinicsWhenMapIsReady();

    // Show a dialog to inform the user about using default location
    _showDefaultLocationDialog();
  }

  void _searchClinicsWhenMapIsReady() {
    if (_currentPosition == null) return;

    if (_mapCreated) {
      _searchNearbyHospitals();
      return;
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _mapCreated && _nearbyPlaces.isEmpty) {
        _searchNearbyHospitals();
      }
    });
  }

  // Dialog to show when using default location
  void _showDefaultLocationDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Using Default Location'),
          content: const Text('We could not access your current location.\n\n'
              'The app is currently showing a default location in Manila, Philippines. '
              'The clinics shown on the map are not near your actual location.\n\n'
              'Please check your device location settings and permissions to see clinics near you.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _getCurrentLocation();
              },
              child: const Text('Try Again'),
            ),
          ],
        );
      },
    );
  }

  // Explains why we need location before the OS permission prompt fires.
  // Returns true if the user wants to proceed to the OS prompt, false if
  // they declined (handled the same as a denial, no crash either way).
  Future<bool> _showLocationRationaleDialog() async {
    if (!mounted) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Access'),
          content: const Text(
              'AnxieEase needs your location to find nearby clinics and '
              'support locations. Your location is only used on this '
              'screen and is not saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Now'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // Dialog to guide users to enable location services
  void _showLocationServicesDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text(
              'Please enable location services on your device to find clinics near you.\n\n'
              'Go to Settings > Privacy > Location Services.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openLocationSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _startMapCreationTimer() {
    // Set a timer to check if the map was created within a reasonable time
    Future.delayed(const Duration(seconds: 5), () {
      if (!_mapCreated && mounted) {
        Logger.warning(
            'Map creation timeout - map not created within 5 seconds');
        setState(() {
          _mapError = true;
          _errorMessage = 'Map failed to load. This could be due to:\n'
              '1. Invalid Google Maps API key\n'
              '2. Missing Google Play Services\n'
              '3. Insufficient permissions\n'
              'Try using the placeholder view instead.';
        });
      }
    });
  }

  void _addCurrentLocationMarker() {
    if (_currentPosition != null) {
      setState(() {
        _markers.clear();
        _markers.add(Marker(
          markerId: const MarkerId('current_location'),
          position:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ));

      });
    }
  }

  // Rounds a lat/lng to ~100m precision so nearby repeat searches can reuse
  // the cache instead of re-spending Google Places quota.
  String _cacheKeyFor(Position position) {
    final lat = (position.latitude * 1000).round() / 1000;
    final lng = (position.longitude * 1000).round() / 1000;
    return '$lat,$lng';
  }

  Future<void> _searchNearbyHospitals() async {
    if (_currentPosition == null) {
      Logger.error('Cannot search: current position is null');
      return;
    }

    final cacheKey = _cacheKeyFor(_currentPosition!);
    final cached = _searchCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      Logger.info('Using cached clinic results for $cacheKey');
      _applyClinicResults(cached.places, fromCache: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      Logger.info(
          'Searching for nearby hospitals at ${_currentPosition!.latitude},${_currentPosition!.longitude}');

      final baseUrl = '$_proxyBaseUrl/placesNearbySearch';

      Response? response;
      bool apiSuccess = false;
      String? lastApiError;

      // Mental-health-specific facilities are tried first since this is an
      // anxiety-support app; general hospitals/clinics are the fallback.
      final searchConfigs = [
        {
          'keyword': 'mental health clinic psychiatrist psychologist',
          'radius': '5000',
        },
        {
          'type': 'hospital',
          'keyword': 'hospital clinic medical center healthcare',
          'radius': '5000',
        },
        {
          'type': 'health',
          'keyword': 'hospital clinic medical center healthcare',
          'radius': '5000',
        },
        {
          'type': 'doctor',
          'keyword': 'hospital clinic medical center healthcare',
          'radius': '5000',
        },
        {
          'keyword': 'hospital clinic medical center healthcare',
          'radius': '5000',
        },
      ];

      List<Map<String, dynamic>> results = [];

      for (final config in searchConfigs) {
        Logger.info('Trying search with config: $config');

        try {
          final queryParams = {
            'location':
                '${_currentPosition!.latitude},${_currentPosition!.longitude}',
            'rankby': 'prominence',
            ...config,
          };

          response = await dio.get(baseUrl, queryParameters: queryParams);

          if (response.statusCode == 200) {
            final data = response.data;
            if (data['status'] == 'OK' &&
                (data['results'] as List).isNotEmpty) {
              Logger.info(
                  'Found ${(data['results'] as List).length} results with config: $config');
              results = List<Map<String, dynamic>>.from(data['results']);
              results = await _fetchAdditionalPages(baseUrl, data, results);
              apiSuccess = true;
              break;
            } else if (data['status'] == 'ZERO_RESULTS') {
              lastApiError = 'No nearby results for config: $config';
              Logger.warning(
                  'No results found with this config, trying next config');
              continue;
            } else {
              lastApiError =
                  'Google Places ${data['status']}: ${data['error_message'] ?? 'No details'}';
              Logger.warning(lastApiError);
              continue;
            }
          }
        } catch (e) {
          lastApiError = e.toString();
          Logger.error('Error querying clinic search proxy', e);
          continue;
        }
      }

      if (!apiSuccess) {
        _lastPlacesApiError = lastApiError;

        final textSearchSucceeded = await _searchWithTextSearch(
          showErrorOnFailure: false,
        );
        if (textSearchSucceeded) return;

        _showSearchFailedState(
          lastApiError ??
              'Google Places did not return clinic results for this area.',
        );
        return;
      }

      _searchCache[cacheKey] = _CachedClinicSearch(results, DateTime.now());
      _applyClinicResults(results);
    } catch (e) {
      Logger.error('Error searching for nearby hospitals', e);
      _showSearchFailedState(_lastPlacesApiError ?? e.toString());
    }
  }

  // Follows Google's next_page_token to pull a second page of results when
  // available (Places API requires a short delay before a fresh token is
  // valid, so we only fetch one extra page rather than looping indefinitely).
  Future<List<Map<String, dynamic>>> _fetchAdditionalPages(
    String baseUrl,
    Map<String, dynamic> firstPageData,
    List<Map<String, dynamic>> results,
  ) async {
    final nextPageToken = firstPageData['next_page_token'] as String?;
    if (nextPageToken == null || nextPageToken.isEmpty) return results;

    try {
      await Future.delayed(const Duration(seconds: 2));
      final response = await dio.get(
        baseUrl,
        queryParameters: {'pagetoken': nextPageToken},
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'OK') {
          results.addAll(List<Map<String, dynamic>>.from(data['results']));
        }
      }
    } catch (e) {
      Logger.error('Error fetching additional clinic results page', e);
    }
    return results;
  }

  // Applies a successful (or cached) clinic search result to map state.
  void _applyClinicResults(
    List<Map<String, dynamic>> results, {
    bool fromCache = false,
  }) {
    if (!mounted || _currentPosition == null) return;

    // Drop any result with missing/invalid geometry up front - every other
    // place in this file (sorting, distance display, marker tap, directions)
    // reads from _nearbyPlaces/_markers, so filtering once here means none
    // of those call sites can ever see a malformed place.
    final validResults = results.where((place) {
      final latLng = _extractPlaceLatLng(place);
      if (latLng == null) {
        Logger.warning(
            'Skipping clinic result with missing/invalid geometry: ${place['name']}');
        return false;
      }
      return true;
    }).toList();

    setState(() {
      _markers.clear();
      _nearbyPlaces = validResults;
      _lastPlacesApiError = null;

      _markers.add(Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        zIndex: 2,
      ));

      for (var place in validResults) {
        final latLng = _extractPlaceLatLng(place)!;
        final name = place['name'] ?? 'Unknown Facility';
        final vicinity = place['vicinity'] ?? 'Address unavailable';

        Logger.debug('Adding marker for: $name at ${latLng.latitude},${latLng.longitude}');

        _markers.add(Marker(
          markerId: MarkerId(place['place_id']),
          position: latLng,
          infoWindow: InfoWindow(title: name, snippet: vicinity),
          icon: _mentalHealthMarkerIcon,
          onTap: () {
            Logger.debug('Marker tapped: $name');
            _onMarkerTapped(place['place_id']);
          },
        ));
      }

      _isLoading = false;
      _errorMessage = fromCache ? '' : '';
    });
  }

  // Honest failure state: no more inventing fake clinics. Shows a clear
  // error with a retry action instead of misleading users in a mental
  // health crisis with non-existent "clinics" at made-up coordinates.
  void _showSearchFailedState(String reason) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _nearbyPlaces = [];
      _errorMessage = 'Could not load nearby clinics right now. $reason';
    });

    _showErrorDialog(
      'Search Error',
      'Failed to search live clinic data.\n\n$reason\n\n'
          'Please check your internet connection and try again.',
    );
  }

  // Show error dialog. Normal users only ever see "OK"/"Retry" - raw API
  // error text and the "Debug Info" escape hatch are developer tools and
  // must not surface to anxious end users in a release build.
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _searchNearbyHospitals();
              },
              child: const Text('Retry'),
            ),
            if (kDebugMode)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showDebugInfo();
                },
                child: const Text('Debug Info'),
              ),
          ],
        );
      },
    );
  }

  // Show debug information dialog
  void _showDebugInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Debug Information'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Current Position:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_currentPosition != null
                    ? 'Lat: ${_currentPosition!.latitude}, Lng: ${_currentPosition!.longitude}'
                    : 'No position available'),
                const SizedBox(height: 16),
                const Text('Markers:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Total markers: ${_markers.length}'),
                const SizedBox(height: 16),
                const Text('Nearby Places:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Total places: ${_nearbyPlaces.length}'),
                if (_lastPlacesApiError != null) ...[
                  const SizedBox(height: 16),
                  const Text('Last Google Places Error:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SelectableText(
                    _lastPlacesApiError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
                if (_nearbyPlaces.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('First place:',
                      style: TextStyle(fontStyle: FontStyle.italic)),
                  Text('Name: ${_nearbyPlaces.first['name'] ?? 'Unknown'}'),
                  Text(
                      'Place ID: ${_nearbyPlaces.first['place_id'] ?? 'Unknown'}'),
                  Text('Types: ${_nearbyPlaces.first['types'] ?? 'Unknown'}'),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Try a different search approach
                    _searchWithTextSearch();
                  },
                  child: const Text('Try Text Search API Instead'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Try using the Text Search API instead of Nearby Search
  Future<bool> _searchWithTextSearch({bool showErrorOnFailure = true}) async {
    if (_currentPosition == null) return false;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final baseUrl = '$_proxyBaseUrl/placesTextSearch';
      bool apiSuccess = false;

      try {
        final response = await dio.get(
          baseUrl,
          queryParameters: {
            'query': 'mental health clinic hospital near me',
            'location':
                '${_currentPosition!.latitude},${_currentPosition!.longitude}',
            'radius': '5000',
          },
        );

        if (response.statusCode == 200) {
          final data = response.data;
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            apiSuccess = true;
            _lastPlacesApiError = null;

            final results = List<Map<String, dynamic>>.from(data['results']);
            Logger.info(
                'Found ${results.length} facilities with Text Search API');

            final cacheKey = _cacheKeyFor(_currentPosition!);
            _searchCache[cacheKey] =
                _CachedClinicSearch(results, DateTime.now());
            _applyClinicResults(results);

            // Close the debug dialog only for manual debug-dialog retries.
            if (mounted && showErrorOnFailure) {
              Navigator.of(context).pop();
            }
          } else {
            _lastPlacesApiError =
                'Google Text Search ${data['status']}: ${data['error_message'] ?? 'No details'}';
            Logger.warning(_lastPlacesApiError!);
          }
        }
      } catch (e) {
        _lastPlacesApiError = e.toString();
        Logger.error('Error with Text Search API', e);
      }

      if (!apiSuccess) {
        throw Exception('Text Search API failed');
      }

      return true;
    } catch (e) {
      Logger.error('Error with Text Search API', e);
      if (showErrorOnFailure && mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Error searching with Text Search API: ${e.toString()}';
        });
      }
      return false;
    }
  }

  // Get travel mode string for API
  String _getTravelModeString() {
    switch (_selectedTravelMode) {
      case TravelMode.walking:
        return 'walking';
      case TravelMode.bicycling:
        return 'bicycling';
      case TravelMode.transit:
        return 'transit';
      case TravelMode.driving:
        return 'driving';
    }
  }

  // Switches travel mode and re-fetches directions for the selected clinic.
  void _setTravelMode(TravelMode mode) {
    if (_selectedTravelMode == mode) return;
    setState(() {
      _selectedTravelMode = mode;
    });
    if (_selectedPlace != null) {
      _getDirections();
    }
  }

  // Calculate bearing between two points
  double _getBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * (math.pi / 180);
    double lng1 = start.longitude * (math.pi / 180);
    double lat2 = end.latitude * (math.pi / 180);
    double lng2 = end.longitude * (math.pi / 180);

    double dLon = lng2 - lng1;

    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    double bearing = math.atan2(y, x);

    bearing = (bearing * 180 / math.pi + 360) % 360;

    return bearing;
  }

  // Method to handle marker tap
  void _onMarkerTapped(String placeId) {
    // Find the place in the markers
    for (final marker in _markers) {
      if (marker.markerId.value == placeId) {
        // Find the place data for this marker
        final place = _nearbyPlaces.firstWhere(
          (place) => place['place_id'] == placeId,
          orElse: () => <String, dynamic>{},
        );

        final placeLatLng = _extractPlaceLatLng(place);
        if (place.isNotEmpty && placeLatLng != null) {
          setState(() {
            _selectedPlace = place;
          });

          // Move camera to the selected place
          _moveCamera(placeLatLng, 15.0);

          // Get directions automatically
          _getDirections(place);
          return;
        }
      }
    }

    // If we get here, we didn't find the place in _nearbyPlaces
    // Try to find it in the markers directly
    for (final marker in _markers) {
      if (marker.markerId.value == placeId) {
        final selectedPlace = {
          'name': marker.infoWindow.title ?? 'Selected Clinic',
          'vicinity': marker.infoWindow.snippet ?? 'Address unavailable',
          'geometry': {
            'location': {
              'lat': marker.position.latitude,
              'lng': marker.position.longitude,
            }
          },
          'place_id': placeId,
        };

        setState(() {
          _selectedPlace = selectedPlace;
        });

        // Move camera to the selected place
        _moveCamera(marker.position, 15.0);

        // Get directions automatically
        _getDirections(selectedPlace);
        return;
      }
    }
  }

  // Method to get directions with improved UI and different travel modes
  Future<void> _getDirections([Map<String, dynamic>? place]) async {
    // If a place is provided, set it as the selected place
    if (place != null) {
      setState(() {
        _selectedPlace = place;
      });
    }

    Logger.info(
        'Getting directions for selected place: ${_selectedPlace?.toString() ?? 'null'}');

    if (_currentPosition == null) {
      Logger.warning('Cannot get directions: position is null');
      if (mounted) {
        _showApiResponseDialog({'error': 'Current position is null'});
      }
      return;
    }

    if (_selectedPlace == null) {
      Logger.warning('Cannot get directions: selected place is null');
      if (mounted) {
        _showApiResponseDialog({'error': 'Selected place is null'});
      }
      return;
    }

    final destinationLatLng = _extractPlaceLatLng(_selectedPlace!);
    if (destinationLatLng == null) {
      Logger.warning('Cannot get directions: invalid destination coordinates');
      if (mounted) {
        _showApiResponseDialog(
            {'error': 'This clinic has invalid location data'});
      }
      return;
    }

    // Show loading state
    setState(() {
      _isLoading = true;
      // Reset route information
      _routeDuration = null;
      _routeDistance = null;
      _navigationSteps = [];
      _isNavigating = false;
      _currentStepIndex = 0;
    });

    try {
      Logger.info(
          'Getting directions to ${_selectedPlace!['name']} by ${_getTravelModeString()}');

      // Get directions via our Cloud Functions proxy (keeps the Maps key
      // server-side instead of embedded in the app).
      final baseUrl = '$_proxyBaseUrl/mapsDirections';

      Response? response;
      bool apiSuccess = false;
      dynamic lastError;
      StackTrace? lastStack;

      try {
        response = await dio.get(
          baseUrl,
          queryParameters: {
            'origin':
                '${_currentPosition!.latitude},${_currentPosition!.longitude}',
            'destination':
                '${destinationLatLng.latitude},${destinationLatLng.longitude}',
            'mode': _getTravelModeString(),
          },
          options: Options(
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

        if (response.statusCode == 200) {
          final data = response.data;
          if (data['status'] == 'OK') {
            apiSuccess = true;
          } else {
            Logger.warning('API returned non-OK status: ${data['status']}');
            lastError =
                'API status: ${data['status']} - ${data['error_message'] ?? 'No error message'}';
          }
        } else {
          Logger.warning('API returned status code: ${response.statusCode}');
          lastError = 'HTTP status: ${response.statusCode}';
        }
      } catch (e, stack) {
        Logger.error('Error requesting directions', e);
        lastError = e;
        lastStack = stack;
      }

      if (!apiSuccess) {
        Logger.error('Directions request failed', lastError);

        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          // Show a more user-friendly error dialog
          _showApiResponseDialog({
            'error': 'Failed to get directions',
            'details': lastError.toString(),
            'stack': lastStack?.toString() ?? 'No stack trace available',
            'message':
                'Please check your Google Maps API configuration and internet connection.'
          });
        }
        return;
      }

      final data = response!.data;
      // Log the API response for debugging
      Logger.info('Directions API response received');
      Logger.debug('Response status: ${data['status']}');

      if (data['status'] != 'OK') {
        Logger.error('Directions API returned non-OK status',
            'Status: ${data['status']}, Error: ${data['error_message'] ?? 'No error message'}');

        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          // Show a more user-friendly error dialog
          _showApiResponseDialog({
            'error': 'Google Maps API Error',
            'details':
                'Status: ${data['status']}, ${data['error_message'] ?? 'No error message'}',
            'message':
                'The Directions API could not calculate a route. This may be due to API restrictions or an invalid route.'
          });
        }
        return;
      }

      if (data['routes'] == null ||
          data['routes'].isEmpty ||
          data['routes'][0]['legs'] == null ||
          data['routes'][0]['legs'].isEmpty) {
        Logger.error('No routes or legs found in API response', data);

        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          _showApiResponseDialog({
            'error': 'No Route Available',
            'details': 'The API response did not contain any valid routes',
            'message':
                'Google Maps could not find a route to this location. Please try a different clinic or travel mode.'
          });
        }
        return;
      }

      final leg = data['routes'][0]['legs'][0];
      final steps = leg['steps'] ?? [];
      if (steps.isEmpty) {
        Logger.error('No navigation steps found in API response', data);

        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          _showApiResponseDialog({
            'error': 'No Navigation Steps',
            'details': 'The API response did not contain any navigation steps',
            'message':
                'Google Maps found a route but no navigation steps. This is unusual and may indicate an API issue.'
          });
        }
        return;
      }

      try {
        // Decode polyline points
        final points =
            _decodePolyline(data['routes'][0]['overview_polyline']['points']);

        // Get route color based on travel mode
        Color routeColor;
        switch (_selectedTravelMode) {
          case TravelMode.walking:
            routeColor = Colors.green;
            break;
          case TravelMode.bicycling:
            routeColor = Colors.orange;
            break;
          case TravelMode.transit:
            routeColor = Colors.purple;
            break;
          case TravelMode.driving:
            routeColor = Colors.blue;
        }

        setState(() {
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points:
                  points.map((point) => LatLng(point[0], point[1])).toList(),
              color: routeColor,
              width: 6,
              patterns: _selectedTravelMode == TravelMode.driving
                  ? []
                  : [PatternItem.dash(15), PatternItem.gap(10)],
              endCap: Cap.roundCap,
              startCap: Cap.roundCap,
            ),
          );

          // Store route information
          _routeDistance = leg['distance']['text'];
          _routeDuration = leg['duration']['text'];
          // Parse navigation steps
          _navigationSteps = steps;
          _currentStepIndex = 0;
          _isLoading = false;
        });

        // Log navigation steps
        Logger.debug(
            'Navigation steps set with length: ${_navigationSteps.length}');
        for (var step in _navigationSteps) {
          Logger.debug('Step instruction: ${step['html_instructions']}');
        }

        // Try to move camera to show the route, with delay and validation
        if (_mapCreated) {
          await Future.delayed(
              const Duration(milliseconds: 500)); // Wait for map to be ready
          bool cameraMoved = false;
          int retryCount = 0;
          const maxRetries = 3;
          bool boundsValid = false;

          // Validate bounds
          final boundsData = data['routes'][0]['bounds'];
          final southwest = boundsData['southwest'];
          final northeast = boundsData['northeast'];
          if (southwest['lat'] != northeast['lat'] ||
              southwest['lng'] != northeast['lng']) {
            boundsValid = true;
          }

          while (!cameraMoved && retryCount < maxRetries && boundsValid) {
            try {
              final GoogleMapController controller = await _controller.future;
              final bounds = LatLngBounds(
                southwest: LatLng(southwest['lat'], southwest['lng']),
                northeast: LatLng(northeast['lat'], northeast['lng']),
              );
              await controller.moveCamera(
                CameraUpdate.newLatLngBounds(bounds, 100),
              );
              cameraMoved = true;
            } catch (e, stack) {
              Logger.error(
                  'Error moving camera (attempt ${retryCount + 1})', e);
              Logger.debug('Error details: $e\nStack trace: $stack');
              retryCount++;
              if (retryCount < maxRetries) {
                await Future.delayed(const Duration(milliseconds: 500));
              }
            }
          }

          if (!cameraMoved) {
            // Fallback: move to user's current location
            try {
              final GoogleMapController controller = await _controller.future;
              await controller.moveCamera(
                CameraUpdate.newLatLng(
                  LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude),
                ),
              );
              cameraMoved = true;
            } catch (e, stack) {
              Logger.error(
                  'Error in fallback camera movement to user location', e);
              Logger.debug('Error details: $e\nStack trace: $stack');
            }
          }

          // We no longer show camera movement error snackbars

          // We no longer show a snackbar with route details
          // The information is already displayed in the bottom card
        }
      } catch (e, stack) {
        Logger.error('Error processing polyline data', e);
        Logger.debug('Error details: $e\nStack trace: $stack');
        _showApiResponseDialog({
          'error': 'Route Processing Error',
          'details': e.toString(),
          'message':
              'There was an error processing the route data. Please try again.'
        });
        // We no longer show error snackbars
        // Errors are handled through dialogs instead
        _showRouteError();
      }
    } catch (e, stack) {
      setState(() {
        _isLoading = false;
      });
      Logger.error('Error getting directions', e);
      Logger.debug('Error details: $e\nStack trace: $stack');
      _showApiResponseDialog({
        'error': 'Directions Error',
        'details': e.toString(),
        'message':
            'There was an error getting directions. Please check your internet connection and try again.'
      });
      // We no longer show error snackbars
      // Errors are handled through dialogs instead
      _showRouteError();
    }
    // Always show error dialog if navigation steps are empty after call
    if (_navigationSteps.isEmpty && mounted) {
      Logger.warning('_getDirections completed but no navigation steps found');
      _showApiResponseDialog({
        'error': 'No Navigation Steps',
        'details': 'No navigation steps found after directions call',
        'message':
            'The directions API did not return any navigation steps. Please try a different clinic or travel mode.'
      });
      _showRouteError();
    }
  }

  // Helper method to decode polyline
  List<List<double>> _decodePolyline(String encoded) {
    if (encoded.isEmpty) {
      Logger.warning('Empty polyline string received');
      return [];
    }

    List<List<double>> poly = [];
    try {
      int index = 0, len = encoded.length;
      int lat = 0, lng = 0;

      while (index < len) {
        int b, shift = 0, result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        shift = 0;
        result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        poly.add([lat / 1E5, lng / 1E5]);
      }
    } catch (e) {
      Logger.error('Error decoding polyline', e);
    }

    return poly;
  }

  // This method has been replaced by _getDirections() which handles directions internally

  void _checkGoogleApiKey() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Google Maps API Configuration'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Configuration Status:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _errorMessage.isEmpty
                      ? 'Maps are working correctly'
                      : 'Maps configuration error detected',
                  style: TextStyle(
                    color: _errorMessage.isEmpty ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Places/Directions requests go through our server-side '
                  'proxy, so no API key is stored in the app.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Troubleshooting Steps:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  '1. Make sure your API key is enabled for:\n'
                  '   - Maps SDK for Android\n'
                  '   - Places API\n'
                  '   - Directions API\n\n'
                  '2. Check API key restrictions:\n'
                  '   - Maps SDK can use Android app restrictions\n'
                  '   - Places/Directions REST calls need a key that is allowed for web-service API calls\n'
                  '   - Check if API key has billing enabled\n'
                  '   - Verify the key is not disabled or expired\n\n'
                  '3. Verify internet connectivity\n\n'
                  '4. For testing, try using a key with no restrictions\n\n'
                  '5. Check Google Cloud Console for any error messages or quotas exceeded',
                ),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Current Error:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  SelectableText(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _errorMessage = '';
                });
                Navigator.of(context).pop();
                // Retry loading maps after clearing error
                _searchNearbyHospitals();
              },
              child: const Text('Clear Error & Retry'),
            ),
          ],
        );
      },
    );
  }

  // This method has been replaced by inline marker creation in _searchNearbyHospitals

  // This method has been replaced by direct marker updates in the marker onTap callback

  // Get custom map style for better UI
  String getCustomMapStyle() {
    return '''
    [
      {
        "featureType": "poi",
        "elementType": "labels.icon",
        "stylers": [
          {
            "visibility": "on"
          }
        ]
      },
      {
        "featureType": "poi.medical",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#f5e1e1"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#ffffff"
          }
        ]
      },
      {
        "featureType": "transit.station",
        "elementType": "labels.icon",
        "stylers": [
          {
            "visibility": "on"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#c9eaf2"
          }
        ]
      }
    ]
    ''';
  }

  // Simplified camera movement method
  Future<void> _moveCamera(LatLng target, double zoom) async {
    if (!_controller.isCompleted) return;

    try {
      final GoogleMapController controller = await _controller.future;
      await controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: zoom,
          ),
        ),
      );
    } catch (e) {
      Logger.error('Error moving camera', e);
      // Don't show error to user, just log it
    }
  }

  // Build a modern top card
  Widget _buildTopCard() {
    // Don't show during navigation
    if (_isNavigating) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.only(top: 40, bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Back button
              Material(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () {
                    // Navigate back to home page
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.grey.shade700,
                      size: 20,
                    ),
                  ),
                ),
              ),
              // Center the title
              Expanded(
                child: Center(
                  child: Text(
                    'AnxieEase',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                    ),
                  ),
                ),
              ),
              // Spacer to balance the back button
              const SizedBox(width: 36),
            ],
          ),
        ),
      ),
    );
  }

  // Build the clinic list view
  Widget _buildClinicListView() {
    // Don't show during navigation or when a clinic is selected
    if (_isNavigating || _selectedPlace != null) return const SizedBox.shrink();

    // Don't show if map is not created yet or is still loading
    if (!_mapCreated || _isLoading) return const SizedBox.shrink();

    // Don't show if we don't have any markers (except user location)
    if (_markers.length <= 1) return const SizedBox.shrink();

    // Get all places from markers
    List<Map<String, dynamic>> places = [];
    for (final marker in _markers) {
      if (marker.markerId.value != 'current_location') {
        // Find the place data for this marker
        final place = _nearbyPlaces.firstWhere(
          (place) => place['place_id'] == marker.markerId.value,
          orElse: () => <String, dynamic>{},
        );

        if (place.isNotEmpty) {
          places.add(place);
        }
      }
    }

    // Defensive: ignore any place whose geometry can't be parsed, even
    // though _applyClinicResults already filters these out at the source.
    places = places.where((p) => _extractPlaceLatLng(p) != null).toList();

    // Sort places by distance if available
    if (_currentPosition != null) {
      places.sort((a, b) {
        final aLatLng = _extractPlaceLatLng(a)!;
        final bLatLng = _extractPlaceLatLng(b)!;

        final distA = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          aLatLng.latitude,
          aLatLng.longitude,
        );

        final distB = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          bLatLng.latitude,
          bLatLng.longitude,
        );

        return distA.compareTo(distB);
      });
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.3, // Initial height (30% of screen)
      minChildSize: 0.1, // Minimum height (10% of screen)
      maxChildSize: 0.85, // Maximum height (85% of screen)
      snap: true, // Snap to specific sizes
      snapSizes: const [0.3, 0.6, 0.85], // Snap to these specific sizes
      controller: _clinicListController, // Use the controller
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.teal.shade50],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 15,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced handle and title - now clickable to expand
              GestureDetector(
                onTap: () {
                  // Toggle between initial and expanded sizes
                  if (_clinicListController.size <= 0.3) {
                    _clinicListController.animateTo(
                      0.6,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  } else {
                    _clinicListController.animateTo(
                      0.3,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle indicator
                      Container(
                        width: 50,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Header with icon and count
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.local_hospital,
                                color: Colors.teal[700],
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Nearby Clinics',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal[700],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.teal[50],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${places.length} found',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.teal[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Divider
              Divider(color: Colors.grey[200], height: 1),

              // List of clinics - now using the scrollController
              Expanded(
                child: places.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.search_off,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No clinics or hospitals found nearby',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your location or search radius',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _searchNearbyHospitals,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller:
                            scrollController, // Use the provided controller
                        padding: const EdgeInsets.only(
                            top: 8, left: 16, right: 16, bottom: 80),
                        itemCount: places.length,
                        itemBuilder: (context, index) {
                          final place = places[index];
                          final name = place['name'] ?? 'Unknown Clinic';
                          final vicinity =
                              place['vicinity'] ?? 'Address unavailable';
                          final rating = place['rating'] ?? 0.0;
                          final types = place['types'] as List? ?? [];
                          final isHospital = types.contains('hospital') ||
                              name.toLowerCase().contains('hospital');
                          final typeColor =
                              isHospital ? Colors.red : Colors.teal;
                          final typeIcon = isHospital
                              ? Icons.local_hospital
                              : Icons.psychology;
                          final typeLabel = isHospital ? 'Hospital' : 'Clinic';

                          // Real open/closed status from Places API, when
                          // Google provides it. Null means "unknown" - we no
                          // longer fabricate a fake status from the clock.
                          final bool? isOpen =
                              place['opening_hours']?['open_now'] as bool?;

                          // Calculate distance
                          String distance = '';
                          final placeLatLng = _extractPlaceLatLng(place);
                          if (_currentPosition != null && placeLatLng != null) {
                            final distanceInMeters = Geolocator.distanceBetween(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                              placeLatLng.latitude,
                              placeLatLng.longitude,
                            );
                            if (distanceInMeters < 1000) {
                              distance =
                                  '${distanceInMeters.toStringAsFixed(0)} m';
                            } else {
                              distance =
                                  '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
                            }
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shadowColor: Colors.black26,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            child: InkWell(
                              onTap: () =>
                                  _onMarkerTapped(place['place_id'] as String),
                              borderRadius: BorderRadius.circular(16),
                              splashColor: typeColor.withOpacity(0.1),
                              highlightColor: typeColor.withOpacity(0.05),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Icon/avatar with indicator
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor:
                                              typeColor.withOpacity(0.12),
                                          radius: 28,
                                          child: Icon(typeIcon,
                                              color: typeColor, size: 28),
                                        ),
                                        // Only show the status dot when
                                        // Google actually reports open/closed
                                        // for this place - no fabricated guess.
                                        if (isOpen != null)
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: isOpen
                                                    ? Colors.green
                                                    : Colors.orange,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: Colors.white,
                                                    width: 2),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),

                                    // Clinic info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: typeColor
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  typeLabel,
                                                  style: TextStyle(
                                                    color: typeColor,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            vicinity,
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              // Rating
                                              const Icon(Icons.star,
                                                  color: Colors.amber,
                                                  size: 16),
                                              Text(rating.toString(),
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13)),
                                              const SizedBox(width: 12),

                                              // Distance with icon
                                              const Icon(Icons.location_on,
                                                  color: Colors.blue, size: 16),
                                              Text(distance,
                                                  style: const TextStyle(
                                                      fontSize: 13)),

                                              // Open/closed status - only
                                              // shown when Google reports it
                                              if (isOpen != null) ...[
                                                const SizedBox(width: 12),
                                                Text(
                                                  isOpen ? 'Open' : 'Closed',
                                                  style: TextStyle(
                                                    color: isOpen
                                                        ? Colors.green
                                                        : Colors.orange,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Directions button
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      child: ElevatedButton.icon(
                                        onPressed: () => _onMarkerTapped(
                                            place['place_id'] as String),
                                        icon: const Icon(Icons.directions,
                                            size: 16),
                                        label: const Text('Go'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal[600],
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Bottom buttons - now inside the draggable sheet
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withOpacity(0.8), Colors.white],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          if (_currentPosition != null) {
                            _moveCamera(
                              LatLng(_currentPosition!.latitude,
                                  _currentPosition!.longitude),
                              15.0,
                            );
                          }
                        },
                        icon: const Icon(Icons.my_location, size: 16),
                        label: const Text('Your Location'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                          side: BorderSide(color: Colors.blue[700]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _searchNearbyHospitals,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // A single selectable travel-mode chip (Drive/Walk/Transit/Bike).
  Widget _buildTravelModeChip(TravelMode mode, IconData icon, String label) {
    final bool isSelected = _selectedTravelMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setTravelMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomCard() {
    // Only show the card if a clinic has been selected
    if (_selectedPlace == null) {
      return const SizedBox
          .shrink(); // Return empty widget if no clinic selected
    }

    // Get the clinic name
    final clinicName = _selectedPlace!['name'] ?? 'Selected Clinic';
    // Determine if it's a clinic or hospital based on types or name
    final types = _selectedPlace!['types'] as List? ?? [];
    final name = _selectedPlace!['name'] as String? ?? '';
    final clinicType =
        types.contains('hospital') || name.toLowerCase().contains('hospital')
            ? 'Hospital'
            : 'Clinic';
    final rating = _selectedPlace!['rating'] ?? 4.5;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: Container(
        padding: _isNavigating && _isBottomCardCollapsed
            ? const EdgeInsets.symmetric(vertical: 8, horizontal: 16)
            : const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Collapsible handle for navigation mode
            if (_isNavigating)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isBottomCardCollapsed = !_isBottomCardCollapsed;
                  });
                },
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isBottomCardCollapsed
                            ? 'Show details'
                            : 'Hide details',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // If collapsed during navigation, only show minimal info
            if (_isNavigating && _isBottomCardCollapsed)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      clinicName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _routeDistance ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

            // Only show the rest of the content if not collapsed
            if (!_isNavigating || !_isBottomCardCollapsed) ...[
              // Back button row - only show when not navigating
              if (!_isNavigating)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    Material(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedPlace = null;
                            _polylines.clear(); // Clear the route polylines
                            _navigationSteps.clear();
                            _routeDuration = null;
                            _routeDistance = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.arrow_back,
                                color: Colors.grey.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Back',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Current location button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (_currentPosition != null) {
                            _moveCamera(
                              LatLng(_currentPosition!.latitude,
                                  _currentPosition!.longitude),
                              15.0,
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.my_location,
                            color: Colors.blue[700],
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              // Current location button only (when navigating)
              if (_isNavigating)
                Align(
                  alignment: Alignment.centerRight,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (_currentPosition != null) {
                          _moveCamera(
                            LatLng(_currentPosition!.latitude,
                                _currentPosition!.longitude),
                            15.0,
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.my_location,
                          color: Colors.blue[700],
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Clinic header with icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.psychology,
                      color: Colors.teal.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Clinic name
                        Text(
                          clinicName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Clinic type
                        Text(
                          clinicType,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.teal.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Rating stars
                        Row(
                          children: [
                            ...List.generate(5, (index) {
                              return Icon(
                                index < rating.floor()
                                    ? Icons.star
                                    : (index < rating)
                                        ? Icons.star_half
                                        : Icons.star_border,
                                color: Colors.amber,
                                size: 16,
                              );
                            }),
                            const SizedBox(width: 4),
                            Text(
                              rating.toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Clinic address
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 18, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedPlace!['vicinity'] ?? 'Address not available',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Travel mode selector - lets the user actually pick a mode
              // instead of always silently using driving directions.
              if (!_isNavigating)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      _buildTravelModeChip(
                          TravelMode.driving, Icons.directions_car, 'Drive'),
                      const SizedBox(width: 8),
                      _buildTravelModeChip(
                          TravelMode.walking, Icons.directions_walk, 'Walk'),
                      const SizedBox(width: 8),
                      _buildTravelModeChip(
                          TravelMode.transit, Icons.directions_bus, 'Transit'),
                      const SizedBox(width: 8),
                      _buildTravelModeChip(TravelMode.bicycling,
                          Icons.directions_bike, 'Bike'),
                    ],
                  ),
                ),

              // Travel info row
              Row(
                children: [
                  // Time container
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 20, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Duration',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              Text(
                                _routeDuration != null ? _routeDuration! : '--',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Distance container
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.route,
                              size: 20, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Distance',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              Text(
                                _routeDistance != null ? _routeDistance! : '--',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Voice guidance toggle (only shown during navigation)
              if (_isNavigating)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        _voiceGuidanceEnabled
                            ? Icons.volume_up
                            : Icons.volume_off,
                        size: 20,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Voice Guidance',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _voiceGuidanceEnabled,
                        onChanged: (value) {
                          _toggleVoiceGuidance();
                        },
                        activeColor: Colors.blue.shade700,
                      ),
                    ],
                  ),
                ),

              // Navigation button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: _isNavigating
                    ? ElevatedButton(
                        onPressed: _showEndNavigationConfirmationDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'End Navigation',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _navigationSteps.isNotEmpty
                            ? _startNavigation
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.navigation, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Start Navigation',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_navigationSteps.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildFABs() {
    // We're no longer using a floating action button for location
    // The location button is now integrated into the cards
    return const SizedBox.shrink();
  }

  Widget _buildLoadingOverlay() {
    return _isLoading
        ? Container(
            color: Colors.black.withAlpha(51),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          )
        : const SizedBox.shrink();
  }

  // Build a welcome card to show when no clinic is selected or map is loading
  Widget _buildWelcomeCard() {
    // Don't show if a clinic is selected
    if (_selectedPlace != null) {
      return const SizedBox.shrink();
    }

    // Don't show if we have location permission errors
    if (_errorMessage.contains('Location permissions are denied') ||
        _errorMessage.contains('Location permissions are permanently denied')) {
      return const SizedBox.shrink();
    }

    // Don't show if map is loaded and we have markers (show list instead)
    if (_mapCreated && !_isLoading && _markers.length > 1) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Empty container instead of row with icons and buttons
            // Only show loading indicator
            _isLoading || !_mapCreated
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.teal.shade700),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Finding clinics near you...',
                            style: TextStyle(
                              color: Colors.teal.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(),
          ],
        ),
      ),
    );
  }

  // Build location permission error screen
  Widget _buildLocationPermissionErrorScreen() {
    final bool isPermanentlyDenied =
        _errorMessage.contains('permanently denied');

    return Container(
      color: Colors.grey.shade50,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_off,
                  size: 60,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Location Permission Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                isPermanentlyDenied
                    ? 'Location permissions are permanently denied. To find nearby clinics, please enable location permissions in your device settings.'
                    : 'AnxieEase needs location access to find nearby mental health clinics and provide you with directions.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Action buttons
              Column(
                children: [
                  if (!isPermanentlyDenied) ...[
                    // Retry button for regular denial
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _errorMessage = '';
                            _isLoading = true;
                          });
                          _getCurrentLocation();
                        },
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text(
                          'Grant Location Permission',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    // Open settings button for permanent denial
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Geolocator.openAppSettings();
                        },
                        icon: const Icon(Icons.settings, color: Colors.white),
                        label: const Text(
                          'Open App Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Go back button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: Icon(Icons.arrow_back, color: Colors.grey.shade700),
                      label: Text(
                        'Go Back',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Logger.debug(
        'Building SearchScreen, isLoading: $_isLoading, hasPosition: ${_currentPosition != null}, mapCreated: $_mapCreated, mapError: $_mapError');

    // Fallback: show full-screen error if no navigation steps and not loading
    if (!_isLoading && _isNavigating && (_navigationSteps.isEmpty)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Directions Error')),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No navigation steps or Directions API response available.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Text('Possible causes:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                  '- API key is missing or restricted\n- Billing is not enabled on your Google Cloud project\n- No internet connection\n- Directions API is not enabled\n- The selected place is not routable',
                  style: TextStyle(fontSize: 13)),
              SizedBox(height: 16),
              Text(
                  'Please check your API key, billing, and network connection.',
                  style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Google Map as background OR location permission error screen
          if (_currentPosition != null)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                    _currentPosition!.latitude, _currentPosition!.longitude),
                zoom: 14,
              ),
              myLocationEnabled: _hasLocationPermission,
              myLocationButtonEnabled: false,
              markers: _markers,
              polylines: _polylines,
              padding: EdgeInsets.only(
                  bottom: 300, // Increased for clinic list
                  top: _isNavigating
                      ? 100
                      : 120), // Add top padding for the top card
              style: getCustomMapStyle(), // Use style property directly
              onMapCreated: (GoogleMapController controller) {
                if (!_controller.isCompleted) {
                  _controller.complete(controller);
                  setState(() {
                    _mapCreated = true;
                    _mapError = false;
                  });

                  Logger.info('Map created successfully with custom style');

                  if (_currentPosition != null && mounted) {
                    _searchNearbyHospitals();
                  }
                }
              },
              mapToolbarEnabled: false,
              compassEnabled: true,
              zoomControlsEnabled: false,
              trafficEnabled: true,
            )
          else if (_errorMessage.contains('Location permissions are denied') ||
              _errorMessage
                  .contains('Location permissions are permanently denied'))
            // Show location permission error screen
            _buildLocationPermissionErrorScreen()
          else
            // Show loading or default background
            Container(
              color: Colors.grey.shade100,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),

          // Modern top card
          _buildTopCard(),

          // Google Maps style navigation bar (only shown during navigation)
          if (_isNavigating) _buildNavigationTopBar(),

          // Clinic list view (only shown when no clinic is selected)
          _buildClinicListView(),

          // Bottom overlay card (only shown when a clinic is selected)
          _buildBottomCard(),

          // Welcome card (shown when map is loading or when no clinics are found)
          _buildWelcomeCard(),

          // Floating action buttons
          _buildFABs(),

          // Loading overlay
          _buildLoadingOverlay(),
        ],
      ),
    );
  }

  // Build Google Maps style navigation top bar
  Widget _buildNavigationTopBar() {
    // Get the current navigation step if available
    String instruction = '';
    String nextInstruction = '';

    if (_navigationSteps.isNotEmpty &&
        _currentStepIndex < _navigationSteps.length) {
      final step = _navigationSteps[_currentStepIndex];
      instruction = step['html_instructions'] ?? '';
      instruction = instruction
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll('  ', ' ')
          .trim();

      // Get next instruction if available
      if (_currentStepIndex + 1 < _navigationSteps.length) {
        final nextStep = _navigationSteps[_currentStepIndex + 1];
        nextInstruction = nextStep['html_instructions'] ?? '';
        nextInstruction = nextInstruction
            .replaceAll(RegExp(r'<[^>]*>'), ' ')
            .replaceAll('  ', ' ')
            .trim();
      }
    }

    // Get destination name
    final destination = _selectedPlace?['name'] ?? 'Destination';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green.shade800,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main navigation bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Up arrow icon
                    const Icon(
                      Icons.arrow_upward,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    // Destination text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'toward',
                            style: TextStyle(
                              color:
                                  Colors.white.withAlpha(230), // ~90% opacity
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            destination,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Voice assistant button
                    GestureDetector(
                      onTap: _toggleVoiceGuidance,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _voiceGuidanceEnabled ? Icons.mic : Icons.mic_off,
                          color:
                              _voiceGuidanceEnabled ? Colors.blue : Colors.grey,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Next instruction bar (if available)
              if (nextInstruction.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.green.shade900,
                  child: const Row(
                    children: [
                      Text(
                        'Then',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // This method has been replaced by direct marker handling in the UI

  // Create a dedicated error widget for showing route errors
  Widget _buildRouteErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Error displaying route',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Unable to establish connection on channel: "dev.flutter.pigeon.goog"\n'
            'This is likely due to a Google Maps API configuration issue.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Simple retry that bypasses complex animations
                    _simpleMoveToClinic();
                    Navigator.of(context).pop(); // Close dialog
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Refresh location and clinics
                    Navigator.of(context).pop(); // Close dialog
                    _getCurrentLocation();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Refresh Location'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to check if the current location is the default location
  bool _isUsingDefaultLocation() {
    if (_currentPosition == null) return true;

    // Check if position is close to Manila (the default location)
    const defaultLat = 14.5995;
    const defaultLng = 120.9842;
    const margin = 0.001; // Small margin for floating point comparison

    return (_currentPosition!.latitude - defaultLat).abs() < margin &&
        (_currentPosition!.longitude - defaultLng).abs() < margin;
  }

  // Show API configuration error with options to fix
  void _showApiConfigErrorDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Google Maps API Error'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'There was an error with the Google Maps API configuration. This could be due to:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('• Invalid or restricted API key'),
              const Text('• API quota exceeded'),
              const Text('• Required APIs not enabled for your key'),
              const Text('• Internet connection issues'),
              const SizedBox(height: 16),
              if (_isUsingDefaultLocation())
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Note: You are currently viewing a default location, not your actual location.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Dismiss'),
            ),
            if (_isUsingDefaultLocation())
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _getCurrentLocation();
                },
                child: const Text('Refresh Location'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _checkGoogleApiKey();
              },
              child: const Text('Check API Config'),
            ),
          ],
        );
      },
    );
  }

  // Show route error with retry option
  void _showRouteError() {
    if (!mounted) return;

    // Cancel any existing SnackBar first
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // If the error is likely due to API configuration and we're using the default location,
    // show the more comprehensive API error dialog
    if (_errorMessage.contains('API') || _isUsingDefaultLocation()) {
      _showApiConfigErrorDialog();
      return;
    }

    // Otherwise show a dialog with our custom error widget for other kinds of errors
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: _buildRouteErrorWidget(),
          backgroundColor: Colors.transparent,
          elevation: 0,
        );
      },
    );
  }

  // Simplified clinic movement with error handling
  void _simpleMoveToClinic() {
    if (_selectedPlace == null) return;

    try {
      final latLng = _extractPlaceLatLng(_selectedPlace!);
      if (latLng == null) return;
      // Skip complex animation and just move the camera directly
      _moveCamera(latLng, 15.0);
    } catch (e) {
      Logger.error('Error in simplified clinic movement', e);
    }
  }

  void _startNavigation() {
    if (_navigationSteps.isEmpty) return;

    setState(() {
      _isNavigating = true;
      _currentStepIndex = 0;
      _isLoading = false;
    });

    // Start location tracking to update user's position in real-time
    _startLocationTracking();

    // Announce the start of navigation with voice guidance
    _announceNavigationStart();

    // Start Google Maps-like animation along the route
    _animateAlongRoute();
  }

  // Animate camera along the polyline route with Google Maps-like animation
  Future<void> _animateAlongRoute() async {
    if (!_mapCreated || _polylines.isEmpty) return;

    try {
      final GoogleMapController controller = await _controller.future;

      // Get all points from the polyline
      final points = _polylines.first.points;
      if (points.isEmpty) return;

      // First, zoom out to show the entire route
      final LatLngBounds bounds = _getBounds(points);
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
            bounds, 100.0), // More padding for better view
      );

      // Wait for the animation to complete
      await Future.delayed(const Duration(milliseconds: 1200));

      if (!_isNavigating) return; // Stop if navigation is cancelled

      // Then zoom in to the start of the route with tilt
      final startPoint = points.first;
      final secondPoint = points.length > 1 ? points[1] : points.first;
      final initialBearing = _getBearing(startPoint, secondPoint);

      // Single transition - zoom in with 2D view (no tilt)
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: startPoint,
            zoom: 17.0,
            tilt: 0.0, // No tilt for 2D view
            bearing: initialBearing,
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 600));
      if (!_isNavigating) return;

      // Now animate along the route with smooth transitions
      // Use more points for a smoother animation
      final animationPoints = _getAnimationPoints(points);

      for (int i = 0; i < min(animationPoints.length - 1, 5); i++) {
        if (!_isNavigating) break; // Stop if navigation is cancelled

        final currentPoint = animationPoints[i];
        final nextPoint = animationPoints[i + 1];
        final pointBearing = _getBearing(currentPoint, nextPoint);

        // Smooth camera movement with 2D view
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: currentPoint,
              zoom: 17.0,
              tilt: 0.0, // No tilt for 2D view
              bearing: pointBearing,
            ),
          ),
        );

        // Longer delay for more visible animation
        await Future.delayed(const Duration(milliseconds: 800));
      }

      // After animation completes, start following the user's current location
      if (_isNavigating) {
        await Future.delayed(const Duration(milliseconds: 500));
        _followUserLocation();
      }
    } catch (e) {
      Logger.error('Error animating along route', e);

      // Even if animation fails, try to follow user location
      if (_isNavigating && _currentPosition != null) {
        _followUserLocation();
      }
    }
  }

  // Helper method to get bounds for the entire route
  LatLngBounds _getBounds(List<LatLng> points) {
    double minLat = 90.0;
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // Helper method to get a subset of points for animation
  List<LatLng> _getAnimationPoints(List<LatLng> allPoints) {
    // If we have few points, use them all
    if (allPoints.length <= 10) return allPoints;

    // Otherwise, sample points for a smooth animation
    // Take first point, last point, and some points in between
    final result = <LatLng>[];
    result.add(allPoints.first);

    // Add some points from the beginning of the route
    final step = allPoints.length ~/ 8;
    for (int i = 1; i < min(allPoints.length - 1, 8); i++) {
      result.add(allPoints[i * step]);
    }

    result.add(allPoints.last);
    return result;
  }

  // Voice guidance methods

  // Speak a message using TTS
  Future<void> _speak(String message) async {
    if (!_voiceGuidanceEnabled) return;

    try {
      if (_isSpeaking) {
        await _stopSpeaking();
      }

      Logger.info('Speaking: $message');
      setState(() {
        _isSpeaking = true;
      });

      await flutterTts.speak(message);
    } catch (e) {
      Logger.error('Error speaking message', e);
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  // Stop any ongoing speech
  Future<void> _stopSpeaking() async {
    try {
      if (_isSpeaking) {
        await flutterTts.stop();
        setState(() {
          _isSpeaking = false;
        });
      }
    } catch (e) {
      Logger.error('Error stopping speech', e);
    }
  }

  // Announce the start of navigation
  void _announceNavigationStart() {
    if (!_voiceGuidanceEnabled) return;

    final destination = _selectedPlace?['name'] ?? 'your destination';
    final distance = _routeDistance ?? 'unknown distance';
    final duration = _routeDuration ?? 'unknown time';

    final message = 'Starting navigation to $destination. '
        'The distance is $distance and it will take approximately $duration.';

    _speak(message);
  }

  // Announce the next navigation step
  void _announceNextStep(int stepIndex) {
    if (!_voiceGuidanceEnabled || _navigationSteps.isEmpty) return;

    if (stepIndex < 0 || stepIndex >= _navigationSteps.length) {
      return;
    }

    final step = _navigationSteps[stepIndex];
    String instruction = step['html_instructions'] ?? '';

    // Clean up HTML tags from the instruction
    instruction = instruction.replaceAll(RegExp(r'<[^>]*>'), ' ');
    instruction = instruction.replaceAll('  ', ' ').trim();

    final distance = step['distance']?['text'] ?? '';

    // Format the instruction to sound more natural like Google Maps
    String message;

    // Check if this is the last step (destination)
    if (stepIndex == _navigationSteps.length - 1) {
      final destination = _selectedPlace?['name'] ?? 'your destination';
      message = 'You have arrived at $destination';
    }
    // Check if this is a turn instruction
    else if (instruction.toLowerCase().contains('turn')) {
      // For turns, announce the distance first
      message = 'In $distance, $instruction';
    }
    // For continue straight instructions
    else if (instruction.toLowerCase().contains('continue') ||
        instruction.toLowerCase().contains('straight')) {
      message = 'Continue straight for $distance';
    }
    // For merge or exit instructions
    else if (instruction.toLowerCase().contains('merge') ||
        instruction.toLowerCase().contains('exit')) {
      message = 'In $distance, $instruction';
    }
    // Default format
    else {
      message = instruction;
      if (distance.isNotEmpty) {
        message += ' for $distance';
      }
    }

    _speak(message);
  }

  // Toggle voice guidance on/off
  void _toggleVoiceGuidance() {
    setState(() {
      _voiceGuidanceEnabled = !_voiceGuidanceEnabled;
    });

    if (_voiceGuidanceEnabled) {
      _speak('Voice guidance turned on');

      // If we're currently navigating, announce the current step
      if (_isNavigating &&
          _navigationSteps.isNotEmpty &&
          _currentStepIndex < _navigationSteps.length) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          _announceNextStep(_currentStepIndex);
        });
      }
    } else {
      _stopSpeaking();
      _speak('Voice guidance turned off');
    }
  }

  // Step navigation methods removed

  void _showApiResponseDialog(dynamic data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Directions API Response'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show error details
                  if (data is Map && data.containsKey('error')) ...[
                    const Text('Error:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(data['error']?.toString() ?? 'Unknown error',
                        style:
                            const TextStyle(color: Colors.red, fontSize: 14)),
                    const SizedBox(height: 12),
                  ],

                  // Show troubleshooting information
                  const Text('Troubleshooting:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text(
                    '1. Check your Google Maps API key configuration\n'
                    '2. Ensure the Directions API is enabled in Google Cloud Console\n'
                    '3. Verify your API key has billing enabled\n'
                    '4. Check your internet connection\n'
                    '5. Make sure your API key has the correct restrictions',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),

                  // Show raw response data
                  const Text('Raw Response:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(data.toString(), style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _checkGoogleApiKey(); // Show API key configuration dialog
                },
                child: const Text('Check API Config'),
              ),
            ],
          ),
        );
      } else {
        // Fallback: show a full-screen error page
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Directions API Error')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'No Directions API response received or an error occurred.',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // Show error details if available
                    if (data is Map && data.containsKey('error')) ...[
                      const Text('Error:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(data['error']?.toString() ?? 'Unknown error',
                          style:
                              const TextStyle(color: Colors.red, fontSize: 14)),
                      const SizedBox(height: 16),
                    ],

                    const Text('Possible causes:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text(
                      '• API key is missing or restricted\n'
                      '• Billing is not enabled on your Google Cloud project\n'
                      '• No internet connection\n'
                      '• Directions API is not enabled\n'
                      '• The selected place is not routable\n\n'
                      'Please check your API key, billing, and network connection.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    // Show raw response data
                    const Text('Raw Response:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      data == null || data.toString().isEmpty
                          ? 'No response data available'
                          : data.toString(),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(Icons.arrow_back),
              ),
            ),
          ),
        );
      }
    });
  }

  void testInternet() async {
    try {
      final response =
          await dio.get('https://jsonplaceholder.typicode.com/todos/1');
      Logger.info('Internet test response: ${response.data}');
    } catch (e) {
      Logger.error('Internet test failed', e);
    }
  }

  // Check if the user has reached their destination
  void _checkDestinationReached(LatLng currentPosition) {
    if (!_isNavigating || _selectedPlace == null) return;

    try {
      // Get destination coordinates
      final destLatLng = _extractPlaceLatLng(_selectedPlace!);
      if (destLatLng == null) return;

      // Calculate distance to destination
      final distance = _calculateDistance(currentPosition.latitude,
          currentPosition.longitude, destLatLng.latitude, destLatLng.longitude);

      // If within 30 meters of destination, consider it reached
      if (distance <= 30) {
        // Only show the notification once
        if (_isNavigating) {
          _showDestinationReachedDialog();
        }
      }
    } catch (e) {
      Logger.error('Error checking if destination reached', e);
    }
  }

  // Show a dialog when the user reaches their destination
  void _showDestinationReachedDialog() {
    // Announce arrival with voice guidance
    final destination = _selectedPlace?['name'] ?? 'your destination';
    _speak('You have arrived at $destination');

    // Show dialog
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap a button to dismiss
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600),
              const SizedBox(width: 10),
              const Text('Destination Reached'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have arrived at ${_selectedPlace?['name'] ?? 'your destination'}.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                'Total distance: ${_routeDistance ?? "N/A"}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              Text(
                'Total time: ${_routeDuration ?? "N/A"}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // End navigation
                setState(() {
                  _isNavigating = false;
                });
                _stopLocationTracking();
                _stopSpeaking();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('End Navigation'),
            ),
          ],
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
      },
    );

    // Set navigation to false to prevent multiple dialogs
    setState(() {
      _isNavigating = false;
    });
  }

  // Show confirmation dialog when user tries to end navigation
  void _showEndNavigationConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber),
              SizedBox(width: 10),
              Text('End Navigation'),
            ],
          ),
          content: const Text(
            'Are you sure you want to end navigation? You will return to the map with nearby clinics.',
            style: TextStyle(fontSize: 16),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // User clicked "No" - stay in navigation mode
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
              child: const Text('No, Continue Navigation'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // User clicked "Yes" - end navigation
                setState(() {
                  _isNavigating = false;
                });
                _stopLocationTracking();
                _stopSpeaking();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Yes, End Navigation'),
            ),
          ],
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
      },
    );
  }
}
