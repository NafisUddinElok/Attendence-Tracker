import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geofence Attendance',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AttendanceScreen(),
    );
  }
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = false;
  
  // Replace with your local machine's IP if testing on a physical device,
  // or your production server URL.
  final String backendUrl = 'http://192.168.1.100:3000/mark-attendance';
  final String studentId = 'STU_001'; // In production, get this from login

  Future<void> _markAttendance() async {
    setState(() => _isLoading = true);

    try {
      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showDialog('Error', 'Please enable location services on your phone.');
        return;
      }

      // 2. Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showDialog('Error', 'Location permissions are denied.');
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showDialog('Error', 'Permissions are permanently denied. Please enable them in settings.');
        return;
      }

      // 3. Get High-Accuracy Position
      // This is where the magic happens. We request high accuracy to ensure
      // the geofence math is as exact as possible.
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // 4. Send to Backend
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'studentId': studentId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'isMocked': position.isMocked, // Detects GPS spoofing apps!
        }),
      );

      // 5. Handle Server Response
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success']) {
        _showDialog('Success', data['message']);
      } else {
        _showDialog('Failed', data['message'] ?? 'An error occurred.');
      }

    } catch (e) {
      _showDialog('Error', 'Could not connect to the server: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Department Attendance')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                onPressed: _markAttendance,
                child: const Text('Mark Attendance'),
              ),
      ),
    );
  }
}