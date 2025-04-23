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
import 'features/marketplace/marketplace_screen.dart';
import 'marketplace_screen.dart' show MarketplaceScreen;

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _image;
  final picker = ImagePicker();
  bool _isLoading = false;
  String? _classificationResult;
  String? _confidence;
  String? _explanation;
  String? _disposalInstructions;
  List<Map<String, dynamic>> _history = [];
  final String _geminiApiKey = 'AIzaSyAf6iaA9g0R0bbqju_UPVA90vw1G4Uld3w';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .collection('classifications')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      setState(() {
        _history = snapshot.docs.map((doc) => doc.data()).toList();
      });
    } catch (e) {
      print('Error loading history: $e');
    }
  }

  Future<void> _getImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _classificationResult = null;
        _confidence = null;
        _explanation = null;
        _disposalInstructions = null;
      });
    }
  }

  Future<Map<String, dynamic>> _callGeminiAPI(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      const prompt = """
      Analyze this waste item image and provide a JSON response with these fields:
      - is_compostable: boolean (true if compostable, false otherwise)
      - confidence: string (High/Medium/Low)
      - category: string (Compostable/Recyclable/Landfill/Hazardous)
      - explanation: string (detailed technical reasoning)
      - disposal: string (specific disposal instructions)
      - misconceptions: string (common mistakes about this item)

      Guidelines:
      - Compostable only for: food waste, yard trimmings, uncoated paper, natural fibers
      - Not Compostable for: plastics, metals, glass, animal products, oily items
      - Be extremely strict about compostability
      - Provide clear disposal instructions

      Return ONLY the JSON object, nothing else.
      """;

      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro-vision:generateContent?key=$_geminiApiKey');

      final headers = {'Content-Type': 'application/json'};

      final body = {
        "contents": [
          {
            "parts": [
              {"text": prompt},
              {
                "inlineData": {
                  "mimeType": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.1,
          "topP": 0.7,
          "topK": 20,
          "maxOutputTokens": 1000
        }
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final text = responseData['candidates'][0]['content']['parts'][0]['text'];

        // Try to parse the response as JSON
        try {
          final jsonResponse = jsonDecode(text);
          return jsonResponse;
        } catch (e) {
          // If parsing as JSON fails, fall back to text parsing
          return _parsePlainTextResponse(text);
        }
      } else {
        throw Exception('API request failed with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to call Gemini API: $e');
    }
  }

  Map<String, dynamic> _parsePlainTextResponse(String text) {
    // Default values
    final result = {
      'is_compostable': false,
      'confidence': 'Medium',
      'category': 'Landfill',
      'explanation': 'No explanation provided',
      'disposal': 'Dispose properly',
      'misconceptions': 'None noted'
    };

    // Try to extract information from the text response
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmedLine = line.trim().toLowerCase();

      if (trimmedLine.contains('compostable')) {
        result['is_compostable'] = trimmedLine.contains('yes') ||
            trimmedLine.contains('true') ||
            (trimmedLine.contains('compostable') && !trimmedLine.contains('not'));
      }

      if (trimmedLine.contains('confidence:')) {
        if (trimmedLine.contains('high')) {
          result['confidence'] = 'High';
        } else if (trimmedLine.contains('medium')) {
          result['confidence'] = 'Medium';
        } else if (trimmedLine.contains('low')) {
          result['confidence'] = 'Low';
        }
      }

      if (trimmedLine.contains('category:')) {
        if (trimmedLine.contains('compostable')) {
          result['category'] = 'Compostable';
        } else if (trimmedLine.contains('recyclable')) {
          result['category'] = 'Recyclable';
        } else if (trimmedLine.contains('hazardous')) {
          result['category'] = 'Hazardous';
        } else {
          result['category'] = 'Landfill';
        }
      }

      if (trimmedLine.contains('explanation:')) {
        result['explanation'] = line.substring(line.indexOf(':') + 1).trim();
      }

      if (trimmedLine.contains('disposal:')) {
        result['disposal'] = line.substring(line.indexOf(':') + 1).trim();
      }
    }

    return result;
  }

  Future<void> _classifyImage() async {
    if (_image == null) return;

    setState(() => _isLoading = true);

    try {
      // Upload image to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_images/${widget.user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(_image!);
      final imageUrl = await storageRef.getDownloadURL();

      // Call Gemini API
      final result = await _callGeminiAPI(_image!);
      print('API Response: $result'); // Debug print

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .collection('classifications')
          .add({
        'imageUrl': imageUrl,
        'is_compostable': result['is_compostable'] ?? false,
        'category': result['category'] ?? 'Landfill',
        'confidence': result['confidence'] ?? 'Medium',
        'explanation': result['explanation'] ?? 'No explanation provided',
        'instructions': result['disposal'] ?? 'Dispose properly',
        'misconceptions': result['misconceptions'] ?? 'None noted',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update UI
      setState(() {
        _classificationResult = (result['is_compostable'] ?? false) ? 'COMPOSTABLE' : 'NOT COMPOSTABLE';
        _confidence = result['confidence'] ?? 'Medium';
        _explanation = result['explanation'] ?? 'No explanation provided';
        _disposalInstructions = result['disposal'] ?? 'Dispose properly';
        _isLoading = false;
      });

      // Reload history
      _loadHistory();
    } catch (e) {
      print('Error: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Classification failed: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Color _getResultColor() {
    return _classificationResult == 'COMPOSTABLE' ? Colors.green : Colors.red;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EcoSort AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<AuthService>(context, listen: false).signOut();
            },
          ),
        ],
      ),
      body: _selectedIndex == 0 ? _buildClassificationContent() : const MarketplaceScreen(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Classify',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Marketplace',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildClassificationContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Upload clear photo of waste item:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                onPressed: () => _getImage(ImageSource.camera),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                onPressed: () => _getImage(ImageSource.gallery),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_image != null) ...[
            Container(
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.file(_image!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _classifyImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                'ANALYZE WASTE',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          if (_classificationResult != null) ...[
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getResultColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: _getResultColor().withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _classificationResult == 'COMPOSTABLE'
                            ? Icons.eco
                            : Icons.warning,
                        color: _getResultColor(),
                        size: 30,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _classificationResult!,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _getResultColor(),
                        ),
                      ),
                    ],
                  ),
                  if (_confidence != null) ...[
                    const SizedBox(height: 15),
                    Text(
                      'Confidence: $_confidence',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (_explanation != null) ...[
                    const SizedBox(height: 15),
                    const Text(
                      'Analysis:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _explanation!,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                  if (_disposalInstructions != null) ...[
                    const SizedBox(height: 15),
                    const Text(
                      'Disposal Instructions:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _disposalInstructions!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 30),
            const Text(
              'RECENT SCANS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            ..._history.map((item) {
              final isCompostable = item['is_compostable'] == true;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item['imageUrl'] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item['imageUrl'],
                            width: double.infinity,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            isCompostable ? Icons.eco : Icons.warning,
                            color: isCompostable ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isCompostable ? 'Compostable' : 'Not Compostable',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isCompostable ? Colors.green : Colors.red,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            item['confidence'] ?? 'Medium',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (item['explanation'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          item['explanation'],
                          style: const TextStyle(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (item['instructions'] != null) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Instructions:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          item['instructions'],
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
}