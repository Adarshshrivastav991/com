import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nobe/product_grid.dart';
import 'compost_search_delegate.dart';
import 'filter_bar.dart';
import 'marketplace_provider.dart';
import 'upload_product_screen.dart';

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MarketplaceProvider()..loadProducts(),
      child: const MarketplaceView(),
    );
  }
}

class MarketplaceView extends StatefulWidget {
  const MarketplaceView({Key? key}) : super(key: key);

  @override
  State<MarketplaceView> createState() => _MarketplaceViewState();
}

class _MarketplaceViewState extends State<MarketplaceView> {
  late MarketplaceProvider _provider;
  late StreamSubscription<QuerySnapshot>? _productsSubscription;

  @override
  void initState() {
    super.initState();
    _provider = Provider.of<MarketplaceProvider>(context, listen: false);
    _setupProductsStream();
  }

  void _setupProductsStream() {
    _productsSubscription = FirebaseFirestore.instance
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _provider.updateProductsFromSnapshot(snapshot);
    }, onError: (error) {
      _provider.errorMessage = 'Failed to load products: $error';
      _provider.isLoading = false;
      _provider.notifyListeners();
    });
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compost Marketplace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToUploadScreen(context),
            tooltip: 'Add new product',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: CompostSearchDelegate(_provider.compostProducts),
            ),
            tooltip: 'Search products',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _provider.loadProducts(),
        child: Column(
          children: [
            const FilterBar(),
            Expanded(
              child: Consumer<MarketplaceProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading && provider.compostProducts.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (provider.errorMessage != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(provider.errorMessage!),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => provider.loadProducts(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (provider.filteredProducts.isEmpty) {
                    return const Center(
                      child: Text('No products available'),
                    );
                  }
                  return ProductGrid(products: provider.filteredProducts);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToUploadScreen(context),
        child: const Icon(Icons.add),
        tooltip: 'Add new product',
      ),
    );
  }

  Future<void> _navigateToUploadScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: _provider,
          child: const UploadProductScreen(),
        ),
        fullscreenDialog: true,
      ),
    );

    // The stream will automatically update the products
    // No need for manual refresh
  }
}