import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final backgroundColor = isSelected
        ? (isDark ? AppTheme.pureWhite : AppTheme.pitchBlack)
        : (isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg);

    final textColor = isSelected
        ? (isDark ? AppTheme.pitchBlack : AppTheme.pureWhite)
        : (isDark ? AppTheme.pureWhite : AppTheme.pitchBlack);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppTheme.pureWhite : AppTheme.pitchBlack)
                : (isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
