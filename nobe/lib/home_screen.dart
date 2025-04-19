// home_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:provider/provider.dart';

import 'auth_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadHistory();
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
      });
    }
  }

  Future<void> _classifyImage() async {
    if (_image == null) return;

    setState(() => _isLoading = true);

    try {
      // Upload image to Firebase Storage
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_images/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(_image!);
      final imageUrl = await storageRef.getDownloadURL();

      // Call Cloud Vision API (or your custom ML model)
      final result = await _callVisionAPI(imageUrl);

      // Save to Firestore
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

      // Update UI
      setState(() {
        _classificationResult = result['label'];
        _confidence = result['confidence'];
        _isLoading = false;
      });

      // Refresh history
      _loadHistory();
    } catch (e) {
      print('Error: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Classification failed: ${e.toString()}')),
      );
    }
  }

  Future<Map<String, dynamic>> _callVisionAPI(String imageUrl) async {
    // This is a placeholder for your actual API call
    // For Google Cloud Vision, you would need to set up the API properly

    // Simulate API call with a mock response
    await Future.delayed(Duration(seconds: 2));

    // Mock response - replace with actual API call
    final random = DateTime.now().millisecond % 2;
    return {
      'label': random == 0 ? 'Compostable' : 'Not Compostable',
      'confidence': (70 + DateTime.now().millisecond % 30).toString(),
    };

    // Actual implementation would look something like this:
    /*
    final apiKey = 'YOUR_GOOGLE_CLOUD_API_KEY';
    final url = 'https://vision.googleapis.com/v1/images:annotate?key=$apiKey';

    final response = await http.post(
      Uri.parse(url),
      body: jsonEncode({
        'requests': [
          {
            'image': {'source': {'imageUri': imageUrl}},
            'features': [
              {'type': 'LABEL_DETECTION', 'maxResults': 5}
            ]
          }
        ]
      }),
    );

    final data = jsonDecode(response.body);
    // Process the response to determine if the waste is compostable
    */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('EcoSort AI'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<AuthService>(context, listen: false).signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
}