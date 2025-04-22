import 'package:flutter/material.dart';
import 'marketplace_provider.dart';

class CompostSearchDelegate extends SearchDelegate<CompostProduct?> {
  final List<CompostProduct> products;

  CompostSearchDelegate(this.products);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = products.where((product) {
      final nameMatch = product.name.toLowerCase().contains(query.toLowerCase());
      final typeMatch = product.type.toLowerCase().contains(query.toLowerCase());
      return nameMatch || typeMatch;
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final product = results[index];
        return ListTile(
          leading: product.imageUrl.isNotEmpty
              ? Image.network(product.imageUrl, width: 50, height: 50, fit: BoxFit.cover)
              : const Icon(Icons.eco),
          title: Text(product.name),
          subtitle: Text('${product.pricePerKg.toStringAsFixed(2)}/kg'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            close(context, product);
          },
        );
      },
    );
  }
}