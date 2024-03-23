import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wildlifeconnect/pages/Auth/secure_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TestMapPage extends StatefulWidget {
  const TestMapPage({Key? key, String? location, String? imageUrl}) : super(key: key);

  @override
  _TestMapPageState createState() => _TestMapPageState();
}

class _TestMapPageState extends State<TestMapPage> {
  late Future<List<dynamic>> posts;
  late Timer _timer;
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  final Set<Marker> _markers = {};

  static const CameraPosition middleofSl = CameraPosition(
    target: LatLng(7.812227821350098, 80.740390625),
    zoom: 7.5,
  );

  @override
  void initState() {
    super.initState();
    posts = fetchPosts();
    _startPolling();
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer to prevent memory leaks
    super.dispose();
  }

  void _startPolling() {
    const Duration pollInterval = Duration(seconds: 30);

    _timer = Timer.periodic(pollInterval, (timer) {
      // Fetch posts periodically
      setState(() {
        posts = fetchPosts();
      });
    });
  }

  Future<List<dynamic>> fetchPosts() async {
    String? token = await SecureStorage.getToken();

    final response = await http.get(
      Uri.parse('https://10.0.2.2/api/posts/get'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load posts');
    }
  }

  Future<void> _loadMarkerData() async {
    List<dynamic> postData = await posts;

    for (var post in postData) {
      final String? location = post['location'];
      final String? imageUrl = post['imageUrl'];

      if (location != null && imageUrl != null) {
        try {
          final List<String> locationSplit = location.split(',');
          final double latitude = double.tryParse(locationSplit[0]) ?? 0.0;
          final double longitude = double.tryParse(locationSplit[1]) ?? 0.0;

          final Uint8List markerIcon = await _getMarkerIcon(imageUrl);

          final Marker marker = Marker(
            markerId: MarkerId(location),
            position: LatLng(latitude, longitude),
            infoWindow: const InfoWindow(
              title: 'Recent Sighting',
            ),
            icon: BitmapDescriptor.fromBytes(markerIcon),
          );

          _markers.add(marker);

        } catch (e) {
          print('Error loading data: $e');
        }
      }
    }

    setState(() {});
  }

  Future<Uint8List> _getMarkerIcon(String imageUrl) async {
    try {
      final http.Response response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to load image data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching image data: $e');
      // Throw the error to be handled by the caller
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Sightings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: posts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            _loadMarkerData();
            return GoogleMap(
        mapType: MapType.normal,
        markers: _markers,
        initialCameraPosition: middleofSl,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
              },
            );
          }
        },
      ),
    );
  }
}