import 'package:flutter/material.dart';
import 'package:nobe/product_grid.dart';
import 'package:provider/provider.dart';

import 'compost_search_delegate.dart';
import 'filter_bar.dart';
import 'marketplace_provider.dart';
import 'upload_product_screen.dart';

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MarketplaceProvider(),
      child: const MarketplaceView(),
    );
  }
}

class MarketplaceView extends StatelessWidget {
  const MarketplaceView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MarketplaceProvider>(context);

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
              delegate: CompostSearchDelegate(provider.compostProducts),
            ),
            tooltip: 'Search products',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadProducts(), // Changed to public method
        child: Column(
          children: [
            const FilterBar(),
            Expanded(
              child: Consumer<MarketplaceProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
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
                            onPressed: () => provider.loadProducts(), // Changed to public method
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

  void _navigateToUploadScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: Provider.of<MarketplaceProvider>(context, listen: false),
          child: const UploadProductScreen(),
        ),
        fullscreenDialog: true,
      ),
    ).then((_) {
      // Refresh products after returning from upload screen
      Provider.of<MarketplaceProvider>(context, listen: false).loadProducts(); // Changed to public method
    });
  }
}