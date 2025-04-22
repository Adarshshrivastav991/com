import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../marketplace_provider.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MarketplaceProvider>(context);
    final types = provider.productTypes;

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: types.length,
        itemBuilder: (context, index) {
          final type = types[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: FilterChip(
              label: Text(type),
              selected: provider.selectedFilter == type,
              onSelected: (_) => provider.setFilter(type),
            ),
          );
        },
      ),
    );
  }
}