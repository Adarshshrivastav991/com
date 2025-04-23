import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadProductScreen extends StatefulWidget {
  const UploadProductScreen({Key? key}) : super(key: key);

  @override
  State<UploadProductScreen> createState() => _UploadProductScreenState();
}

class _UploadProductScreenState extends State<UploadProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  String? _imageUrl;
  String? _imagePath;

  // Form fields
  String _name = '';
  String _type = 'Vermicompost';
  String _description = '';
  double _pricePerKg = 0.0;
  int _availableQuantity = 0;
  bool _isAvailable = true;

  final List<String> _compostTypes = [
    'Vermicompost',
    'Organic Compost',
    'Manure',
    'Leaf Compost',
    'Bokashi',
    'Other'
  ];

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _imageFile = image;
        });
      }
    } catch (e) {
      _showError('Failed to pick image: ${e.toString()}');
    }
  }

  Future<String?> _uploadImage(String productId) async {
    if (_imageFile == null) return null;

    try {
      // Create reference with product ID
      _imagePath = 'compost_images/$productId.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(_imagePath!);

      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
          'timestamp': DateTime.now().toString(),
        },
      );

      await storageRef.putFile(
        File(_imageFile!.path),
        metadata,
      );

      // Get download URL
      return await storageRef.getDownloadURL();
    } catch (e) {
      _showError('Failed to upload image: ${e.toString()}');
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('You must be logged in to upload products');
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Create product document reference first
      final productRef = FirebaseFirestore.instance.collection('products').doc();

      // Upload image if selected
      if (_imageFile != null) {
        _imageUrl = await _uploadImage(productRef.id);
      }

      // Prepare product data
      final productData = {
        'name': _name,
        'type': _type,
        'description': _description,
        'pricePerKg': _pricePerKg,
        'sellerId': user.uid,
        'sellerName': user.displayName ?? 'Anonymous Seller',
        'sellerEmail': user.email,
        'imageUrl': _imageUrl,
        'imagePath': _imagePath, // Store the storage path for deletion later
        'availableQuantity': _availableQuantity,
        'isAvailable': _isAvailable,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Validate data matches security rules
      if (_pricePerKg <= 0 || _availableQuantity <= 0) {
        throw Exception('Price and quantity must be positive numbers');
      }

      // Save to Firestore
      await productRef.set(productData);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success and reset form
      _showSuccess('Product uploaded successfully!');
      _resetForm();
    } catch (e) {
      // Clean up failed upload
      if (_imagePath != null) {
        await FirebaseStorage.instance.ref().child(_imagePath!).delete().catchError((e) {});
      }

      if (mounted) Navigator.of(context).pop();
      _showError('Failed to upload product: ${e.toString()}');
    }
  }

  void _resetForm() {
    setState(() {
      _formKey.currentState?.reset();
      _imageFile = null;
      _imageUrl = null;
      _imagePath = null;
      _name = '';
      _type = 'Vermicompost';
      _description = '';
      _pricePerKg = 0.0;
      _availableQuantity = 0;
      _isAvailable = true;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Upload Product')),
        body: const Center(
          child: Text('Please sign in to upload products'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Compost Product'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _submitForm,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Upload Section
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: _imageFile != null
                      ? Image.file(
                    File(_imageFile!.path),
                    fit: BoxFit.cover,
                  )
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_a_photo, size: 50),
                      SizedBox(height: 8),
                      Text('Add Product Image'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Product Name
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a product name';
                  }
                  return null;
                },
                onSaved: (value) => _name = value!,
              ),
              const SizedBox(height: 16),

              // Compost Type Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Compost Type',
                  border: OutlineInputBorder(),
                ),
                value: _type,
                items: _compostTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _type = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a compost type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  if (value.length < 10) {
                    return 'Description should be at least 10 characters';
                  }
                  return null;
                },
                onSaved: (value) => _description = value!,
              ),
              const SizedBox(height: 16),

              // Price per kg
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Price per kg (\$)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price';
                  }
                  final price = double.tryParse(value);
                  if (price == null) {
                    return 'Please enter a valid number';
                  }
                  if (price <= 0) {
                    return 'Price must be greater than 0';
                  }
                  return null;
                },
                onSaved: (value) => _pricePerKg = double.parse(value!),
              ),
              const SizedBox(height: 16),

              // Available Quantity
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Available Quantity (kg)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter available quantity';
                  }
                  final quantity = int.tryParse(value);
                  if (quantity == null) {
                    return 'Please enter a valid number';
                  }
                  if (quantity <= 0) {
                    return 'Quantity must be greater than 0';
                  }
                  return null;
                },
                onSaved: (value) => _availableQuantity = int.parse(value!),
              ),
              const SizedBox(height: 16),

              // Availability Switch
              Row(
                children: [
                  const Text('Available for Sale:'),
                  const SizedBox(width: 8),
                  Switch(
                    value: _isAvailable,
                    onChanged: (value) {
                      setState(() {
                        _isAvailable = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Upload Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}