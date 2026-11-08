import 'package:flutter/material.dart';

/// Display info for one category: name, icon and chart color.
class CategoryInfo {
  final String name;
  final IconData icon;
  final Color color;

  const CategoryInfo({
    required this.name,
    required this.icon,
    required this.color,
  });
}

const List<CategoryInfo> expenseCategories = <CategoryInfo>[
  CategoryInfo(
    name: 'Food',
    icon: Icons.restaurant,
    color: Color(0xFFFFB74D),
  ),
  CategoryInfo(
    name: 'Transport',
    icon: Icons.directions_bus,
    color: Color(0xFF64B5F6),
  ),
  CategoryInfo(
    name: 'Bills',
    icon: Icons.receipt_long,
    color: Color(0xFFBA68C8),
  ),
  CategoryInfo(
    name: 'Shopping',
    icon: Icons.shopping_bag,
    color: Color(0xFFF06292),
  ),
  CategoryInfo(
    name: 'Health',
    icon: Icons.health_and_safety,
    color: Color(0xFF4DB6AC),
  ),
  CategoryInfo(
    name: 'Education',
    icon: Icons.school,
    color: Color(0xFFAED581),
  ),
  CategoryInfo(
    name: 'Entertainment',
    icon: Icons.movie,
    color: Color(0xFFFFD54F),
  ),
  CategoryInfo(
    name: 'Other',
    icon: Icons.more_horiz,
    color: Color(0xFF90A4AE),
  ),
];

const List<CategoryInfo> incomeCategories = <CategoryInfo>[
  CategoryInfo(
    name: 'Salary',
    icon: Icons.payments,
    color: Color(0xFF39FF88),
  ),
  CategoryInfo(
    name: 'Freelance',
    icon: Icons.laptop_mac,
    color: Color(0xFF40C4FF),
  ),
  CategoryInfo(
    name: 'Business',
    icon: Icons.storefront,
    color: Color(0xFFFFCC80),
  ),
  CategoryInfo(
    name: 'Other Income',
    icon: Icons.add_card,
    color: Color(0xFFB39DDB),
  ),
];

/// Finds a category by name in the right list, falling back to the
/// last entry (Other / Other Income) so old saved data never crashes.
CategoryInfo categoryByName(String name, {required bool isIncome}) {
  final List<CategoryInfo> list =
      isIncome ? incomeCategories : expenseCategories;
  for (final CategoryInfo info in list) {
    if (info.name == name) {
      return info;
    }
  }
  return list.last;
}
