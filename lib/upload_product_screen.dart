import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'marketplace_provider.dart';

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
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _imageFile = image;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('compost_images/${DateTime.now().millisecondsSinceEpoch}');
      await storageRef.putFile(File(_imageFile!.path));
      return await storageRef.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    final provider = Provider.of<MarketplaceProvider>(context, listen: false);

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Upload image if selected
      if (_imageFile != null) {
        _imageUrl = await _uploadImage();
      }

      // Create product data
      final productData = {
        'name': _name,
        'type': _type,
        'description': _description,
        'pricePerKg': _pricePerKg,
        'sellerId': 'currentUserId', // Replace with actual user ID
        'sellerName': 'Current User', // Replace with actual user name
        'imageUrl': _imageUrl,
        'availableQuantity': _availableQuantity,
        'isAvailable': _isAvailable,
        'createdAt': Timestamp.now(),
      };

      // Add product through provider
      await provider.addProduct(productData);

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product uploaded successfully!')),
      );

      // Navigate back to marketplace
      Navigator.of(context).pop();
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload product: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
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
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
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