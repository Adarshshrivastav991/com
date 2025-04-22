import 'package:cloud_firestore/cloud_firestore.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

Future<void> addCompostProduct() async {
  try {
    await _firestore.collection('compost_products').add({
      'name': "Premium Vermicompost",
      'type': "Vermicompost",
      'description': "High quality worm compost...",
      'pricePerKg': 1.50,
      'sellerId': "user123",
      'sellerName': "Green Farms",
      'imageUrl': "https://...",
      'availableQuantity': 200,
      'isAvailable': true,
      'createdAt': Timestamp.now(),
    });
    print('Product added successfully');
  } catch (e) {
    print('Error adding product: $e');
  }
}