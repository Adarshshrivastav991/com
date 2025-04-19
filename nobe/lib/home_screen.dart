import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'auth_service.dart';
import 'location_service.dart';
import 'pickup_scheduler.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _image;
  final picker = ImagePicker();
  bool _isLoading = false;
  String? _classificationResult;
  String? _confidence;
  List<Map<String, dynamic>> _history = [];
  LatLng? _currentLocation;
  String? _currentAddress;
  bool _isInPickupZone = false;
  bool _isLocationLoading = false;
  bool _isPickupScheduled = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _getUserLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      _currentLocation = await LocationService.getCurrentLatLng();
      _currentAddress = await LocationService.getAddressFromLatLng(_currentLocation!);
      _isInPickupZone = await LocationService.isInPickupZone(_currentLocation!);

      setState(() {
        _isLocationLoading = false;
      });
    } catch (e) {
      setState(() => _isLocationLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: ${e.toString()}')),
      );
    }
  }

  Future<void> _loadHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('classifications')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    setState(() {
      _history = snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> _getImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _classificationResult = null;
        _isPickupScheduled = false;
      });
    }
  }

  Future<void> _classifyImage() async {
    if (_image == null) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_images/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(_image!);
      final imageUrl = await storageRef.getDownloadURL();

      final result = await _callVisionAPI(imageUrl);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('classifications')
          .add({
        'imageUrl': imageUrl,
        'result': result['label'],
        'confidence': result['confidence'],
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _classificationResult = result['label'];
        _confidence = result['confidence'];
        _isLoading = false;
      });

      _loadHistory();
    } catch (e) {
      print('Error: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Classification failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _schedulePickup() async {
    if (_classificationResult == null || _currentLocation == null) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await PickupScheduler.requestPickup(
        userId: user.uid,
        address: _currentAddress ?? 'Unknown address',
        location: _currentLocation!,
        wasteType: _classificationResult!,
      );

      final pickupTime = DateTime.now().add(Duration(days: 1)).copyWith(
        hour: 10,
        minute: 0,
        second: 0,
        millisecond: 0,
      );

      await PickupScheduler.scheduleNotification(
        userId: user.uid,
        pickupTime: pickupTime,
        address: _currentAddress ?? 'Unknown address',
      );

      setState(() {
        _isPickupScheduled = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pickup scheduled successfully!')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to schedule pickup: ${e.toString()}')),
      );
    }
  }

  Future<Map<String, dynamic>> _callVisionAPI(String imageUrl) async {
    await Future.delayed(Duration(seconds: 2));
    final random = DateTime.now().millisecond % 2;
    return {
      'label': random == 0 ? 'Compostable' : 'Not Compostable',
      'confidence': (70 + DateTime.now().millisecond % 30).toString(),
    };
  }

  Widget _buildLocationInfo() {
    if (_isLocationLoading) {
      return CircularProgressIndicator();
    }

    if (_currentLocation == null) {
      return Text(
        'Location not set. Update from menu.',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Location:', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text(_currentAddress ?? 'Unknown address'),
        SizedBox(height: 8),
        Text(
          _isInPickupZone
              ? '✅ You are in our pickup zone'
              : '⚠️ Currently not in pickup zone',
          style: TextStyle(
            color: _isInPickupZone ? Colors.green : Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildPickupButton() {
    if (_classificationResult != 'Compostable') {
      return SizedBox();
    }

    if (_isPickupScheduled) {
      return Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Text(
          '✅ Pickup Scheduled!',
          style: TextStyle(color: Colors.green, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: ElevatedButton(
        onPressed: _isInPickupZone ? _schedulePickup : null,
        child: Text('Schedule Compost Pickup'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: EdgeInsets.symmetric(vertical: 16.0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('EcoSort AI'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildLocationInfo(),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Upload Waste Image',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.camera_alt),
                  label: Text('Camera'),
                  onPressed: () => _getImage(ImageSource.camera),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.photo_library),
                  label: Text('Gallery'),
                  onPressed: () => _getImage(ImageSource.gallery),
                ),
              ],
            ),
            SizedBox(height: 20),
            if (_image != null)
              Column(
                children: [
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Image.file(_image!, fit: BoxFit.cover),
                  ),
                  SizedBox(height: 20),
                  if (!_isLoading)
                    ElevatedButton(
                      onPressed: _classifyImage,
                      child: Text('Classify Waste'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                      ),
                    )
                  else
                    CircularProgressIndicator(),
                ],
              ),
            if (_classificationResult != null)
              Column(
                children: [
                  SizedBox(height: 30),
                  Container(
                    padding: EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: _classificationResult == 'Compostable'
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Classification Result:',
                          style: TextStyle(fontSize: 18),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _classificationResult!,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _classificationResult == 'Compostable'
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        if (_confidence != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Confidence: ${_confidence}%',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        _buildPickupButton(),
                      ],
                    ),
                  ),
                ],
              ),
            SizedBox(height: 30),
            Text(
              'Recent Classifications',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 10),
            if (_history.isEmpty)
              Text('No classification history yet.')
            else
              Column(
                children: _history.map((item) => ListTile(
                  leading: item['imageUrl'] != null
                      ? Image.network(item['imageUrl'], width: 50, height: 50, fit: BoxFit.cover)
                      : Icon(Icons.photo),
                  title: Text(item['result'] ?? 'Unknown'),
                  subtitle: Text('Confidence: ${item['confidence'] ?? 'N/A'}%'),
                  trailing: Text(
                    item['timestamp'] != null
                        ? '${DateTime.now().difference((item['timestamp'] as Timestamp).toDate()).inDays}d ago'
                        : '',
                  ),
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.green,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'EcoSort AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Smart Waste Classification',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('Home'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.location_on),
            title: Text('Update Location'),
            onTap: () {
              Navigator.pop(context);
              _getUserLocation();
            },
          ),
          ListTile(
            leading: Icon(Icons.history),
            title: Text('Classification History'),
            onTap: () {
              Navigator.pop(context);
              // You could add navigation to a dedicated history screen here
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Showing full history')),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.schedule),
            title: Text('Scheduled Pickups'),
            onTap: () {
              Navigator.pop(context);
              // Add navigation to pickup schedule screen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Showing scheduled pickups')),
              );
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              // Add navigation to settings screen
            },
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Logout'),
            onTap: () async {
              Navigator.pop(context);
              await Provider.of<AuthService>(context, listen: false).signOut();
            },
          ),
        ],
      ),
    );
  }
}