import 'package:flutter/material.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  static IconData iconFor(String category) {
    switch (category) {
      case 'Historical':
        return Icons.account_balance_rounded;
      case 'Nature':
        return Icons.park_rounded;
      case 'Religious':
        return Icons.temple_hindu_rounded;
      case 'Adventure':
        return Icons.hiking_rounded;
      case 'Food':
        return Icons.restaurant_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FilterChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? colorScheme.onPrimary : colorScheme.primary,
      ),
      label: Text(label),
      onSelected: (_) => onTap?.call(),
      selectedColor: colorScheme.primary,
      labelStyle: TextStyle(
        color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: colorScheme.surface,
      side: BorderSide(
        color: selected ? colorScheme.primary : const Color(0xFFE4EBEE),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }
}
