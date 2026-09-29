import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../models/review.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/star_rating.dart';
import 'add_review_dialog.dart';
import 'login_dialog.dart';
import 'business_restaurant_management_screen.dart';
import 'reservation_dialog.dart';
import '../widgets/chat_dock.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final int restaurantId;

  const RestaurantDetailScreen({super.key, required this.restaurantId});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  RestaurantModel? _restaurant;
  bool _isLoading = true;

  Future<void> _copyToClipboard(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.pitchBlack),
    );
  }
  bool _isBookmarked = false;
  int _selectedPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadRestaurantDetail();
  }

  Future<void> _loadRestaurantDetail() async {
    setState(() => _isLoading = true);
    final detail = await ApiService.getRestaurantDetail(widget.restaurantId);
    if (mounted) {
      setState(() {
        _restaurant = detail;
        _selectedPhotoIndex = 0;
        _isBookmarked = ApiService.isBookmarked(widget.restaurantId);
        _isLoading = false;
      });
    }
  }

  void _openAddReviewModal() {
    if (_restaurant == null) return;
    if (_isRestaurantOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chủ quán không thể đánh giá chính quán của mình.'), backgroundColor: AppTheme.fireCoral),
      );
      return;
    }

    final existing = _myReview;
    if (existing != null) {
      _openEditReviewModal(existing);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddReviewDialog(
        restaurantId: _restaurant!.id,
        restaurantName: _restaurant!.name,
        onReviewAdded: _loadRestaurantDetail,
      ),
    );
  }

  void _openReservationDialog() {
    if (_restaurant == null || _isRestaurantOwner) return;
    if (!ApiService.isLoggedIn) {
      showDialog(context: context, builder: (_) => LoginDialog(onLoginSuccess: () {}));
      return;
    }
    showDialog(context: context, builder: (_) => ReservationDialog(restaurant: _restaurant!));
  }

  bool get _isRestaurantOwner {
    final user = ApiService.currentUser;
    return user?.isBusiness == true && _restaurant?.ownerId == user?.id;
  }

  ReviewModel? get _myReview {
    final userId = ApiService.currentUser?.id;
    if (userId == null) return null;
    for (final review in _restaurant?.reviews ?? <ReviewModel>[]) {
      if (review.userId == userId) return review;
    }
    return null;
  }

  // Keeps body content readable & centered on wide/web viewports,
  // consistent with the home screen's _pageWidth wrapper.
  Widget _pageWidth(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1180),
      child: child,
    ),
  );

  Widget _eyebrow(String text, {Color? color}) => Text(
    text.toUpperCase(),
    style: TextStyle(
      color: color ?? AppTheme.fireCoral,
      fontWeight: FontWeight.w800,
      fontSize: 10,
      letterSpacing: 1,
    ),
  );

  Widget _sectionTitle(String eyebrow, String title, bool isDark, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _eyebrow(eyebrow),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.fireCoral),
        ),
      );
    }

    if (_restaurant == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Không tìm thấy thông tin nhà hàng.')),
      );
    }

    final restaurant = _restaurant!;
    final restaurantImages = restaurant.imageUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
    if (restaurantImages.isEmpty) {
      restaurantImages.add(restaurant.coverImageUrl.trim());
    }
    final restLatLng = LatLng(restaurant.latitude, restaurant.longitude);
    const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    final muted = isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight;
    final fg = isDark ? AppTheme.pureWhite : AppTheme.pitchBlack;
    final cardBg = isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg;
    final border = isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
      body: CustomScrollView(
        slivers: [
          // Hero Cover App Bar
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.pitchBlack,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: AppTheme.pureWhite, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                tooltip: 'Chia sẻ thông tin quán',
                onPressed: () => _copyToClipboard(
                  '${restaurant.name}\n${restaurant.address}\nTọa độ: ${restaurant.latitude}, ${restaurant.longitude}',
                  'Đã sao chép thông tin quán.',
                ),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.pureWhite,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.ios_share_rounded, color: AppTheme.pitchBlack, size: 20),
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.pureWhite,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: _isBookmarked ? AppTheme.fireCoral : AppTheme.pitchBlack,
                    size: 20,
                  ),
                ),
                onPressed: () async {
                  if (!ApiService.isLoggedIn) {
                    showDialog<bool>(
                      context: context,
                      builder: (_) => LoginDialog(
                        onLoginSuccess: () async {
                          final newStatus = await ApiService.toggleBookmark(restaurant.id);
                          if (mounted) {
                            setState(() {
                              _isBookmarked = newStatus;
                            });
                          }
                        },
                      ),
                    );
                    return;
                  }
                  final newStatus = await ApiService.toggleBookmark(restaurant.id);
                  if (mounted) {
                    setState(() {
                      _isBookmarked = newStatus;
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(
                    restaurantImages[_selectedPhotoIndex.clamp(0, restaurantImages.length - 1)],
                    fit: BoxFit.cover,
                    errorColor: AppTheme.pitchBlack,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: _pageWidth(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.fireCoral,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  restaurant.cuisine.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.pureWhite,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: restaurant.isOpen
                                      ? const Color(0xFF1FA65A)
                                      : Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  restaurant.isOpen ? 'ĐANG MỞ' : 'ĐÃ ĐÓNG',
                                  style: const TextStyle(
                                    color: AppTheme.pureWhite,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            restaurant.name,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.8,
                              color: AppTheme.pureWhite,
                              shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Details Body
          SliverToBoxAdapter(
            child: _pageWidth(
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating & Price Bar
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppTheme.fireCoral,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 18, color: AppTheme.pureWhite),
                              const SizedBox(width: 4),
                              Text(
                                restaurant.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: AppTheme.pureWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${restaurant.reviewCount} đánh giá',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          restaurant.priceRange,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.fireCoral,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (!_isRestaurantOwner && restaurant.isOpen)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openReservationDialog,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.fireCoral,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.table_restaurant_rounded),
                          label: const Text('Đặt bàn tại quán', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    if (!_isRestaurantOwner && restaurant.isOpen) const SizedBox(height: 24),

                    if (restaurantImages.length > 1) ...[
                      _sectionTitle('Thư viện ảnh', 'Không gian & món ăn', isDark),
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: restaurantImages.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) => GestureDetector(
                            onTap: () => setState(() => _selectedPhotoIndex = index),
                            onDoubleTap: () => _showFullImage(context, restaurantImages[index]),
                            child: Container(
                              width: 112,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _selectedPhotoIndex == index
                                      ? AppTheme.fireCoral
                                      : border,
                                  width: _selectedPhotoIndex == index ? 2 : 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _buildImage(restaurantImages[index], fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                    ],

                    // Description
                    _sectionTitle('Giới thiệu', 'Mô tả nhà hàng', isDark),
                    Text(
                      restaurant.description,
                      style: TextStyle(fontSize: 14, height: 1.6, color: muted),
                    ),
                    const SizedBox(height: 26),

                    if (restaurant.menuItems.isNotEmpty) ...[
                      _sectionTitle('Gọi món', 'Thực đơn', isDark),
                      ...restaurant.menuItems.map((item) => _buildMenuItemCard(item, isDark)),
                      const SizedBox(height: 10),
                    ],

                    // Location Card: address + embedded map
                    _sectionTitle('Vị trí', 'Địa chỉ & bản đồ', isDark),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: AppTheme.fireCoral, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              restaurant.address,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sao chép địa chỉ',
                            onPressed: () => _copyToClipboard(restaurant.address, 'Đã sao chép địa chỉ.'),
                            icon: const Icon(Icons.copy_outlined, size: 19, color: AppTheme.fireCoral),
                          ),
                          IconButton(
                            tooltip: 'Sao chép tọa độ',
                            onPressed: () => _copyToClipboard(
                              '${restaurant.latitude}, ${restaurant.longitude}',
                              'Đã sao chép tọa độ.',
                            ),
                            icon: const Icon(Icons.my_location_rounded, size: 19, color: AppTheme.fireCoral),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: restLatLng,
                          initialZoom: 15.0,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: tileUrl,
                            userAgentPackageName: 'com.example.food_review_app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: restLatLng,
                                width: 110,
                                height: 40,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.fireCoral,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppTheme.pureWhite, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on_rounded, size: 14, color: AppTheme.pureWhite),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          restaurant.name,
                                          style: const TextStyle(
                                            color: AppTheme.pureWhite,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Reviews Header
                    _sectionTitle(
                      'Cộng đồng',
                      'Đánh giá (${restaurant.reviewCount})',
                      isDark,
                      trailing: TextButton.icon(
                        onPressed: _isRestaurantOwner
                            ? () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => BusinessRestaurantManagementScreen(restaurant: restaurant)),
                        ).then((_) => _loadRestaurantDetail())
                            : _openAddReviewModal,
                        icon: Icon(_isRestaurantOwner ? Icons.storefront_rounded : Icons.edit_note_rounded, color: AppTheme.fireCoral, size: 20),
                        label: Text(
                          _isRestaurantOwner ? 'Quản lý quán ăn' : (_myReview != null ? 'Sửa đánh giá' : 'Viết đánh giá'),
                          style: const TextStyle(color: AppTheme.fireCoral, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    // Reviews List
                    if (restaurant.reviews.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Text(
                          'Chưa có đánh giá nào. Hãy là người đầu tiên!',
                          style: TextStyle(color: muted),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: restaurant.reviews.length,
                        itemBuilder: (context, index) {
                          final rev = restaurant.reviews[index];
                          return _buildReviewCard(context, rev, isDark);
                        },
                      ),

                    // Bottom spacing so content clears the floating action buttons.
                    const SizedBox(height: 72),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_restaurant?.ownerId != null && _restaurant?.ownerId != ApiService.currentUser?.id)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton.extended(
                heroTag: 'messageRestaurant',
                onPressed: () => ChatDock.openRestaurant(widget.restaurantId),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Nhắn tin cho quán'),
              ),
            ),
          FloatingActionButton.extended(
            onPressed: _openAddReviewModal,
            backgroundColor: AppTheme.fireCoral,
            foregroundColor: AppTheme.pureWhite,
            icon: const Icon(Icons.star_rate_rounded),
            label: const Text(
              'ĐÁNH GIÁ NGAY',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemCard(MenuItemModel item, bool isDark) {
    return Opacity(
      opacity: item.isAvailable ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder),
        ),
        child: Row(
          children: [
            if (item.imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 62, height: 62, child: _buildImage(item.imageUrl, fit: BoxFit.cover)),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight)),
                  ],
                  if (!item.isAvailable) const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Tạm hết món', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('${item.price.toStringAsFixed(0)}đ',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.fireCoral)),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, ReviewModel review, bool isDark) {
    final currentUser = ApiService.currentUser;
    final isOwner = currentUser != null && review.userId == currentUser.id;
    final isAdmin = ApiService.isAdmin;
    final canModify = isOwner || isAdmin;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBg : AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + name + date + actions
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(review.userAvatarUrl),
                backgroundColor: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                      ),
                    ),
                    Text(
                      '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
              StarRating(rating: review.rating, size: 14),
              // Edit/Delete actions
              if (canModify) ...[
                const SizedBox(width: 8),
                _buildReviewActions(context, review, isDark, isOwner),
              ],
            ],
          ),

          // Recommended dish badge
          if (review.recommendedDish.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.pitchBlack : AppTheme.lightCardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.fireCoral.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.restaurant_menu_rounded, size: 14, color: AppTheme.fireCoral),
                  const SizedBox(width: 6),
                  Text(
                    'Món gợi ý: ${review.recommendedDish}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.fireCoral,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Comment text
          const SizedBox(height: 10),
          Text(
            review.comment,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
            ),
          ),

          // Review image
          if (review.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final imageWidth = constraints.maxWidth > 520 ? 420.0 : constraints.maxWidth;

                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: imageWidth,
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: GestureDetector(
                          onTap: () => _showFullImage(context, review.imageUrls.first),
                          child: _buildImage(
                            review.imageUrls.first,
                            fit: BoxFit.cover,
                            errorColor: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (review.imageUrls.length > 1) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.imageUrls.length - 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final imageUrl = review.imageUrls[index + 1];
                    return GestureDetector(
                      onTap: () => _showFullImage(context, imageUrl),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(width: 76, child: _buildImage(imageUrl, fit: BoxFit.cover)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildReviewActions(BuildContext context, ReviewModel review, bool isDark, bool isOwner) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded,
          color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? AppTheme.darkCardBg : AppTheme.pureWhite,
      itemBuilder: (_) => [
        if (isOwner)
          PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              const Icon(Icons.edit_rounded, size: 18, color: AppTheme.fireCoral),
              const SizedBox(width: 10),
              const Text('Chỉnh sửa'),
            ]),
          ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
            const SizedBox(width: 10),
            const Text('Xóa', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
      onSelected: (value) {
        if (value == 'edit') {
          _openEditReviewModal(review);
        } else if (value == 'delete') {
          _confirmDeleteReview(context, review);
        }
      },
    );
  }

  void _openEditReviewModal(ReviewModel review) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddReviewDialog(
        restaurantId: widget.restaurantId,
        restaurantName: _restaurant?.name ?? '',
        onReviewAdded: _loadRestaurantDetail,
        existingReview: review,
      ),
    );
  }

  void _confirmDeleteReview(BuildContext context, ReviewModel review) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardBg : AppTheme.pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Xóa đánh giá?',
            style: TextStyle(color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                fontWeight: FontWeight.bold)),
        content: Text('Đánh giá này sẽ bị xóa vĩnh viễn. Bạn có chắc không?',
            style: TextStyle(color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy',
                style: TextStyle(color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final result = await ApiService.deleteReview(review.id);
              if (mounted) {
                if (result['success'] == true) {
                  _loadRestaurantDetail();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xóa đánh giá!'),
                        backgroundColor: AppTheme.pitchBlack),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'] ?? 'Có lỗi xảy ra!'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Xóa', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(
      String imageUrl, {
        BoxFit fit = BoxFit.cover,
        Color? errorColor,
      }) {
    final fallback = Container(
      color: errorColor ?? AppTheme.grayBorder,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 32),
    );

    final normalizedUrl = imageUrl.trim();
    if (normalizedUrl.isEmpty) return fallback;

    if (normalizedUrl.startsWith('data:image/')) {
      try {
        return Image.memory(
          base64Decode(normalizedUrl.split(',').last),
          fit: fit,
          errorBuilder: (_, error, stackTrace) => fallback,
        );
      } catch (_) {
        return fallback;
      }
    }

    return Image.network(
      ApiService.resolveImageUrl(normalizedUrl),
      fit: fit,
      errorBuilder: (_, error, stackTrace) => fallback,
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildImage(imageUrl, fit: BoxFit.contain, errorColor: AppTheme.pitchBlack),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
