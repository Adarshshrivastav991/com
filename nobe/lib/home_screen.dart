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
  String? _explanation; // Added for explanation
  List<Map<String, dynamic>> _history = [];
  final String _geminiApiKey = 'YOUR_GEMINI_API_KEY'; // Replace with your actual API key

  // ... (keep all your existing methods until _callGeminiAPI)

  Future<Map<String, dynamic>> _callGeminiAPI(File imageFile) async {
    try {
      // Read image bytes and convert to base64
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Prepare the API request
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro-vision:generateContent?key=$_geminiApiKey');

      final headers = {
        'Content-Type': 'application/json',
      };

      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text": """
                Analyze this waste item image and determine if it's compostable or not. 
                Consider:
                - Organic materials (food scraps, yard waste) are compostable
                - Plastics, metals, glass are not compostable
                - Contaminated items are not compostable
                
                Return response in JSON format:
                {
                  "label": "Compostable" or "Not Compostable",
                  "confidence": "High", "Medium", or "Low",
                  "explanation": "Brief explanation"
                }
                """
              },
              {
                "inlineData": {
                  "mimeType": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ]
      });

      // Make the HTTP request
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final text = responseData['candidates'][0]['content']['parts'][0]['text'];

        try {
          // Parse the JSON response from Gemini
          final jsonResponse = jsonDecode(text);
          return {
            'label': jsonResponse['label'] ?? 'Unknown',
            'confidence': jsonResponse['confidence'] ?? 'Medium',
            'explanation': jsonResponse['explanation'] ?? 'No explanation',
          };
        } catch (e) {
          // Fallback if JSON parsing fails
          return {
            'label': text.contains('Compostable') ? 'Compostable' : 'Not Compostable',
            'confidence': 'Medium',
            'explanation': 'Gemini response: $text',
          };
        }
      } else {
        throw Exception('API request failed with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to call Gemini API: $e');
    }
  }

  // Update the _classifyImage method to include explanation
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

      final result = await _callGeminiAPI(_image!);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('classifications')
          .add({
        'imageUrl': imageUrl,
        'result': result['label'],
        'confidence': result['confidence'],
        'explanation': result['explanation'],
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _classificationResult = result['label'];
        _confidence = result['confidence'];
        _explanation = result['explanation'];
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

  // Update the build method to show explanation
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
            // ... (keep all your existing UI code until the result display)

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
                              'Confidence: ${_confidence}',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        if (_explanation != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _explanation!,
                              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

            // ... (keep the rest of your existing UI code)
          ],
        ),
      ),
    );
  }
}