import 'dart:convert';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class RestaurantCard extends StatelessWidget {
  static final LinkedHashMap<String, Uint8List> _memoryImageCache = LinkedHashMap();
  static const int _maxCachedMemoryImages = 40;

  final RestaurantModel restaurant;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmarkToggle;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.isBookmarked,
    required this.onTap,
    required this.onBookmarkToggle,
  });

  /// Giải mã Base64 bất đồng bộ hoặc chạy tính toán tối ưu
  static Uint8List? _getOrDecodeBase64(String dataUrl) {
    if (_memoryImageCache.containsKey(dataUrl)) {
      final cached = _memoryImageCache.remove(dataUrl)!;
      _memoryImageCache[dataUrl] = cached; // LRU touch
      return cached;
    }

    try {
      final base64Str = dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
      final decoded = base64Decode(base64Str);

      if (_memoryImageCache.length >= _maxCachedMemoryImages) {
        _memoryImageCache.remove(_memoryImageCache.keys.first);
      }
      _memoryImageCache[dataUrl] = decoded;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardImageUrl = restaurant.cardImageUrl?.trim() ?? '';
    final imageUrl = cardImageUrl.isNotEmpty
        ? cardImageUrl
        : restaurant.coverImageUrl.trim();
    final isOpen = restaurant.isOpen;
    final cardBg = isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg;
    final border = isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder;
    final muted = isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight;
    final fg = isDark ? AppTheme.pureWhite : AppTheme.pitchBlack;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildImage(imageUrl, isDark),
                ),
                if (!isOpen)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(color: Color(0x4D000000)),
                    ),
                  ),
                // Status tag
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? const Color(0xFF1FA65A)
                          : AppTheme.pitchBlack.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      isOpen ? 'ĐANG MỞ' : 'ĐÃ ĐÓNG',
                      style: const TextStyle(
                        color: AppTheme.pureWhite,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                // Bookmark
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: onBookmarkToggle,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.pureWhite.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000), // 0.15 alpha black
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        isBookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 18,
                        color: isBookmarked
                            ? AppTheme.fireCoral
                            : AppTheme.pitchBlack,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              restaurant.name,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: fg,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              restaurant.cuisine,
                              style: TextStyle(fontSize: 11.5, color: muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: AppTheme.fireCoral),
                          const SizedBox(width: 3),
                          Text(
                            restaurant.rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    restaurant.description,
                    style: TextStyle(fontSize: 12.5, color: muted, height: 1.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 13, color: muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          restaurant.address,
                          style: TextStyle(fontSize: 11.5, color: muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        restaurant.priceRange,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.fireCoral,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String imageUrl, bool isDark) {
    if (imageUrl.trim().isEmpty) {
      return _imageFallback(isDark);
    }

    if (imageUrl.startsWith('data:image/')) {
      final bytes = _getOrDecodeBase64(imageUrl);
      if (bytes == null) return _imageFallback(isDark);

      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true, // Tránh nhấp nháy khi đổi ảnh
        filterQuality: FilterQuality.low,
        errorBuilder: (_, error, stackTrace) => _imageFallback(isDark),
      );
    }

    return Image.network(
      ApiService.resolveImageUrl(imageUrl),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, error, stackTrace) => _imageFallback(isDark),
    );
  }

  Widget _imageFallback(bool isDark) => Container(
    color: isDark ? AppTheme.pitchBlack : AppTheme.lightCardBg,
    child: const Center(
      child: Icon(
        Icons.restaurant_rounded,
        size: 40,
        color: AppTheme.fireCoral,
      ),
    ),
  );
}
