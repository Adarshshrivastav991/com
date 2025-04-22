import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MarketplaceProvider with ChangeNotifier {
  List<CompostProduct> _products = [];
  List<CompostProduct> _filteredProducts = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedFilter = 'All';

  List<CompostProduct> get compostProducts => _products;
  List<CompostProduct> get filteredProducts => _filteredProducts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedFilter => _selectedFilter;

  MarketplaceProvider() {
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await FirebaseFirestore.instance
          .collection('compost_products')
          .where('isAvailable', isEqualTo: true)
          .get();

      _products = snapshot.docs.map((doc) => CompostProduct.fromFirestore(doc)).toList();
      _applyFilter();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load products. Please try again.';
      if (kDebugMode) print('Error loading products: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (_selectedFilter == 'All') {
      _filteredProducts = List.from(_products);
    } else {
      _filteredProducts = _products
          .where((product) => product.type == _selectedFilter)
          .toList();
    }
  }

  List<String> get productTypes {
    final types = _products.map((p) => p.type).toSet().toList();
    return ['All', ...types];
  }
}

class CompostProduct {
  final String id;
  final String name;
  final String type;
  final String description;
  final double pricePerKg;
  final String sellerId;
  final String sellerName;
  final String imageUrl;
  final double availableQuantity;

  CompostProduct({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.pricePerKg,
    required this.sellerId,
    required this.sellerName,
    required this.imageUrl,
    required this.availableQuantity,
  });

  factory CompostProduct.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CompostProduct(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Product',
      type: data['type'] ?? 'General',
      description: data['description'] ?? '',
      pricePerKg: (data['pricePerKg'] ?? 0).toDouble(),
      sellerId: data['sellerId'] ?? '',
      sellerName: data['sellerName'] ?? 'Unknown Seller',
      imageUrl: data['imageUrl'] ?? '',
      availableQuantity: (data['availableQuantity'] ?? 0).toDouble(),
    );
  }
}