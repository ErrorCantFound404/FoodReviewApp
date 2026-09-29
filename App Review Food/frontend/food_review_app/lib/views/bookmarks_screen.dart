import 'dart:math';

import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/restaurant_card.dart';
import 'admin_dashboard_screen.dart';
import 'login_dialog.dart';
import 'restaurant_detail_screen.dart';
import 'business_restaurant_management_screen.dart';
import 'business_onboarding_screen.dart';
import 'my_reservations_screen.dart';

class BookmarksScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;

  const BookmarksScreen({super.key, this.onToggleTheme});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<RestaurantModel> _bookmarks = [];
  bool _isLoading = true;
  bool _isMapView = false;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    if (!ApiService.isLoggedIn) {
      if (mounted) {
        setState(() {
          _bookmarks = [];
          _isLoading = false;
        });
      }
      return;
    }

    setState(() => _isLoading = true);
    final data = await ApiService.getBookmarks();
    if (mounted) {
      setState(() {
        _bookmarks = data;
        _isLoading = false;
      });
    }
  }

  void _openAdminPortal() {
    if (ApiService.isAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AdminDashboardScreen(onToggleTheme: widget.onToggleTheme),
        ),
      ).then((_) => _loadBookmarks());
    } else if (ApiService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tài khoản của bạn không có quyền truy cập Admin!'),
          backgroundColor: AppTheme.fireCoral,
        ),
      );
    } else {
      _showLoginDialog(
        onSuccess: () {
          if (ApiService.isAdmin) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AdminDashboardScreen(onToggleTheme: widget.onToggleTheme),
              ),
            ).then((_) => _loadBookmarks());
          }
        },
      );
    }
  }

  void _showLoginDialog({VoidCallback? onSuccess}) {
    showDialog<bool>(
      context: context,
      builder: (_) => LoginDialog(
        onLoginSuccess: () {
          setState(() {});
          _loadBookmarks();
          onSuccess?.call();
        },
      ),
    );
  }

  void _showUserProfileSheet(bool isDark) {
    final user = ApiService.currentUser;
    if (user == null) {
      _showLoginDialog();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBg : AppTheme.pureWhite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.fireCoral.withValues(alpha: 0.15),
                    backgroundImage: user.avatarUrl.isNotEmpty
                        ? NetworkImage(user.avatarUrl)
                        : null,
                    child: user.avatarUrl.isEmpty
                        ? Text(
                            user.fullName.isNotEmpty
                                ? user.fullName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.fireCoral,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppTheme.pureWhite
                                : AppTheme.pitchBlack,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${user.username}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppTheme.textMutedDark
                                : AppTheme.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppTheme.fireCoral,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Đăng Xuất Tài Khoản',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppTheme.fireCoral,
                  ),
                ),
                onTap: () async {
                  await ApiService.logout();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  setState(() {});
                  _loadBookmarks();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _navLink(String title, int index, bool isDark, bool isWide) {
    final isSelected = index == 1;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (index == 0) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            } else if (index == 2) {
              if (ApiService.currentUser?.isBusiness == true) {
                final user = ApiService.currentUser!;
                ApiService.getRestaurants(
                  ownerId: user.id,
                  includeUnapproved: true,
                ).then((restaurants) async {
                  final approved = restaurants
                      .where((r) => r.approvalStatus == 'Approved')
                      .toList();
                  if (approved.isNotEmpty && mounted) {
                    final detail = await ApiService.getRestaurantDetail(
                      approved.first.id,
                    );
                    if (detail != null && mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BusinessRestaurantManagementScreen(
                            restaurant: detail,
                            onToggleTheme: widget.onToggleTheme,
                          ),
                        ),
                      );
                    }
                  }
                });
              } else if (!ApiService.isLoggedIn) {
                _showLoginDialog();
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyReservationsScreen(
                      onToggleTheme: widget.onToggleTheme,
                    ),
                  ),
                );
              }
            }
          },
          borderRadius: BorderRadius.circular(99),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? (isDark ? AppTheme.pureWhite : AppTheme.pitchBlack)
                    : (isDark
                          ? AppTheme.textMutedDark
                          : AppTheme.textMutedLight),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
      body: SafeArea(
        child: Column(
          children: [
            _buildModernHeader(isDark, isWide),
            Expanded(child: _buildBody(isDark)),
          ],
        ),
      ),
      bottomNavigationBar: isWide ? null : _buildBottomNavigation(isDark),
    );
  }

  Widget _pageWidth(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1180),
      child: child,
    ),
  );

  // Modern Minimalist Header. On wide/web viewports it also renders the
  // horizontal nav links that replace the bottom nav bar.
  Widget _buildModernHeader(bool isDark, bool isWide) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
            width: isWide ? 1 : 0,
          ),
        ),
      ),
      child: _pageWidth(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Branding & User Greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.fireCoral,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            ApiService.isLoggedIn
                                ? 'XIN CHÀO, ${ApiService.currentUser!.fullName.toUpperCase()}'
                                : 'SAVOR & REVIEW',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppTheme.textMutedDark
                                  : AppTheme.textMutedLight,
                              letterSpacing: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'FoodieSpot',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppTheme.pureWhite
                            : AppTheme.pitchBlack,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),

              // Horizontal nav links — web/wide layout only.
              if (isWide) ...[
                _navLink('Khám phá', 0, isDark, isWide),
                _navLink('Đã lưu', 1, isDark, isWide),
                _navLink(
                  ApiService.currentUser?.isBusiness == true
                      ? 'Quản lý quán ăn'
                      : 'Đặt bàn của tôi',
                  2,
                  isDark,
                  isWide,
                ),
                const SizedBox(width: 12),
              ],

              // Header Quick Actions
              Row(
                children: [
                  // Admin Quick Badge (Only visible when Admin is logged in)
                  if (ApiService.isAdmin) ...[
                    IconButton(
                      onPressed: _openAdminPortal,
                      tooltip: 'Bảng quản trị Admin',
                      icon: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppTheme.fireCoral.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.fireCoral,
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 19,
                          color: AppTheme.fireCoral,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],

                  // Map/List Mode Switch
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isMapView = !_isMapView;
                      });
                    },
                    tooltip: _isMapView
                        ? 'Xem dạng danh sách'
                        : 'Xem trên bản đồ',
                    icon: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _isMapView
                            ? AppTheme.fireCoral
                            : (isDark
                                  ? AppTheme.darkCardBg
                                  : AppTheme.lightCardBg),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isMapView
                              ? AppTheme.fireCoral
                              : (isDark
                                    ? AppTheme.darkGrayBorder
                                    : AppTheme.grayBorder),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _isMapView
                            ? Icons.format_list_bulleted_rounded
                            : Icons.map_outlined,
                        size: 19,
                        color: _isMapView
                            ? AppTheme.pureWhite
                            : (isDark
                                  ? AppTheme.pureWhite
                                  : AppTheme.pitchBlack),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Theme Switcher
                  IconButton(
                    onPressed: widget.onToggleTheme,
                    tooltip: isDark ? 'Chế độ sáng' : 'Chế độ tối',
                    icon: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkCardBg
                            : AppTheme.lightCardBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? AppTheme.darkGrayBorder
                              : AppTheme.grayBorder,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        isDark
                            ? Icons.wb_sunny_rounded
                            : Icons.nightlight_round,
                        size: 19,
                        color: isDark
                            ? AppTheme.pureWhite
                            : AppTheme.pitchBlack,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // User Profile or Login Pill
                  if (ApiService.isLoggedIn)
                    GestureDetector(
                      onTap: () => _showUserProfileSheet(isDark),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.fireCoral,
                            width: 1.8,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor: AppTheme.fireCoral.withValues(
                            alpha: 0.15,
                          ),
                          backgroundImage:
                              (ApiService.currentUser!.avatarUrl.isNotEmpty)
                              ? NetworkImage(ApiService.currentUser!.avatarUrl)
                              : null,
                          child: (ApiService.currentUser!.avatarUrl.isEmpty)
                              ? Text(
                                  ApiService.currentUser!.fullName.isNotEmpty
                                      ? ApiService.currentUser!.fullName[0]
                                            .toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.fireCoral,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () => _showLoginDialog(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.pureWhite
                              : AppTheme.pitchBlack,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.login_rounded,
                              size: 15,
                              color: isDark
                                  ? AppTheme.pitchBlack
                                  : AppTheme.pureWhite,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Đăng nhập',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppTheme.pitchBlack
                                    : AppTheme.pureWhite,
                                letterSpacing: 0.2,
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
      ),
    );
  }

  Widget _buildSavedHero(bool isDark) => _pageWidth(
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final text = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'BỘ SƯU TẬP CỦA BẠN',
                  style: TextStyle(
                    color: AppTheme.fireCoral,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Nơi bạn muốn\nquay lại.',
                  style: TextStyle(
                    fontSize: compact ? 25 : 30,
                    height: 1.08,
                    letterSpacing: -1,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoading
                      ? 'Đang cập nhật danh sách đã lưu…'
                      : '${_bookmarks.length} quán được bạn đánh dấu cho lần ghé tiếp theo.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.textMutedDark
                        : AppTheme.textMutedLight,
                  ),
                ),
              ],
            );
            final action = FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.fireCoral,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('Khám phá quán'),
            );
            return compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [text, const SizedBox(height: 18), action],
                  )
                : Row(
                    children: [
                      Expanded(child: text),
                      action,
                    ],
                  );
          },
        ),
      ),
    ),
  );

  Widget _buildBody(bool isDark) {
    if (!ApiService.isLoggedIn) return _loginRequired(isDark);
    return RefreshIndicator(
      color: AppTheme.fireCoral,
      onRefresh: _loadBookmarks,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: _buildSavedHero(isDark)),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.fireCoral),
              ),
            )
          else if (_bookmarks.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _emptyState(isDark),
            )
          else ...[
            SliverToBoxAdapter(
              child: _pageWidth(
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Đã lưu gần đây',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: isDark
                                ? AppTheme.pureWhite
                                : AppTheme.pitchBlack,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tải lại',
                        onPressed: _loadBookmarks,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final maxCardWidth = constraints.crossAxisExtent >= 900
                    ? 390.0
                    : 600.0;
                final contentWidth = max(
                  0.0,
                  constraints.crossAxisExtent > 1240
                      ? 1180.0
                      : constraints.crossAxisExtent - 40,
                );
                final columnCount = max(
                  1,
                  ((contentWidth + 16) / (maxCardWidth + 16)).ceil(),
                );
                final cardWidth =
                    (contentWidth - (columnCount - 1) * 16) / columnCount;
                // RestaurantCard has a 16:9 image followed by its details.
                // Derive its grid height from the actual column width so the
                // details never overflow below the card on narrow web views.
                // Keep a small buffer for the card's bottom margin and
                // fractional web-pixel rounding.
                final cardHeight = max(370.0, cardWidth * 9 / 16 + 182);

                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    constraints.crossAxisExtent > 1240
                        ? (constraints.crossAxisExtent - 1180) / 2
                        : 20,
                    0,
                    constraints.crossAxisExtent > 1240
                        ? (constraints.crossAxisExtent - 1180) / 2
                        : 20,
                    24,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: maxCardWidth,
                      mainAxisExtent: cardHeight,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = _bookmarks[index];
                      return RestaurantCard(
                        restaurant: item,
                        isBookmarked: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RestaurantDetailScreen(restaurantId: item.id),
                            ),
                          ).then((_) => _loadBookmarks());
                        },
                        onBookmarkToggle: () async {
                          await ApiService.toggleBookmark(item.id);
                          await _loadBookmarks();
                        },
                      );
                    }, childCount: _bookmarks.length),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _loginRequired(bool isDark) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.fireCoral.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bookmark_border_rounded,
                  size: 42,
                  color: AppTheme.fireCoral,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Lưu lại điều bạn thích',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Đăng nhập để tạo danh sách các quán bạn muốn ghé lại.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: isDark
                      ? AppTheme.textMutedDark
                      : AppTheme.textMutedLight,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.fireCoral,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => LoginDialog(onLoginSuccess: _loadBookmarks),
                ),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Đăng nhập ngay'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _emptyState(bool isDark) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_outline_rounded,
            size: 62,
            color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
          ),
          const SizedBox(height: 16),
          Text(
            'Danh sách của bạn đang trống',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn biểu tượng bookmark trên một quán để lưu lại.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildBottomNavigation(bool isDark) => BottomNavigationBar(
    currentIndex: 1,
    onTap: (index) async {
      if (index == 0) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else if (index == 1) {
        _loadBookmarks();
      } else if (ApiService.currentUser?.isBusiness == true) {
        final user = ApiService.currentUser!;
        final restaurants = await ApiService.getRestaurants(
          ownerId: user.id,
          includeUnapproved: true,
        );
        if (restaurants.isEmpty && mounted) {
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const BusinessOnboardingScreen()),
          );
          return;
        }
        final approved = restaurants
            .where((restaurant) => restaurant.approvalStatus == 'Approved')
            .toList();
        if (approved.isEmpty || !mounted) return;
        final detail = await ApiService.getRestaurantDetail(approved.first.id);
        if (detail != null && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BusinessRestaurantManagementScreen(
                restaurant: detail,
                onToggleTheme: widget.onToggleTheme,
              ),
            ),
          );
        }
      } else if (!ApiService.isLoggedIn) {
        showDialog<bool>(
          context: context,
          builder: (_) => LoginDialog(onLoginSuccess: _loadBookmarks),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MyReservationsScreen(onToggleTheme: widget.onToggleTheme),
          ),
        );
      }
    },
    backgroundColor: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
    selectedItemColor: AppTheme.fireCoral,
    unselectedItemColor: isDark
        ? AppTheme.textMutedDark
        : AppTheme.textMutedLight,
    items: [
      const BottomNavigationBarItem(
        icon: Icon(Icons.explore_outlined),
        activeIcon: Icon(Icons.explore_rounded),
        label: 'Khám phá',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.bookmark_outline_rounded),
        activeIcon: Icon(Icons.bookmark_rounded),
        label: 'Đã lưu',
      ),
      if (ApiService.currentUser?.isBusiness == true)
        const BottomNavigationBarItem(
          icon: Icon(Icons.storefront_outlined),
          activeIcon: Icon(Icons.storefront_rounded),
          label: 'Quản lý quán ăn',
        ),
      if (ApiService.currentUser?.isBusiness != true)
        const BottomNavigationBarItem(
          icon: Icon(Icons.table_restaurant_outlined),
          activeIcon: Icon(Icons.table_restaurant),
          label: 'Đặt bàn của tôi',
        ),
    ],
  );
}
