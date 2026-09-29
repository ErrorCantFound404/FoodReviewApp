import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final bool isInteractive;
  final ValueChanged<double>? onRatingChanged;

  const StarRating({
    super.key,
    required this.rating,
    this.size = 18,
    this.isInteractive = false,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        IconData iconData;
        Color iconColor;

        if (rating >= starValue) {
          iconData = Icons.star_rounded;
          iconColor = AppTheme.fireCoral;
        } else if (rating >= starValue - 0.5) {
          iconData = Icons.star_half_rounded;
          iconColor = AppTheme.fireCoral;
        } else {
          iconData = Icons.star_outline_rounded;
          iconColor = Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkGrayBorder
              : AppTheme.grayBorder;
        }

        Widget starWidget = Icon(iconData, size: size, color: iconColor);

        if (isInteractive) {
          return InkWell(
            onTap: () {
              if (onRatingChanged != null) {
                onRatingChanged!(starValue.toDouble());
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: starWidget,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(right: 2.0),
          child: starWidget,
        );
      }),
    );
  }
}
