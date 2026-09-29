import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/category.dart';
import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/minimal_search_bar.dart';
import '../widgets/restaurant_card.dart';
import 'admin_dashboard_screen.dart';
import 'bookmarks_screen.dart';
import 'login_dialog.dart';
import 'map_view_screen.dart';
import 'restaurant_detail_screen.dart';
import 'business_restaurant_management_screen.dart';
import 'business_onboarding_screen.dart';
import 'my_reservations_screen.dart';

/// Breakpoint above which the layout switches from the mobile app shell
/// (bottom navigation bar) to a web-style shell (horizontal nav in the header).
const double kWideBreakpoint = 900;

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const HomeScreen({super.key, required this.onToggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  bool _isMapView = false;
  bool _isCategoryPointerHovering = false;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _categoryScrollController = ScrollController();
  List<CategoryModel> _categories = [];
  List<RestaurantModel> _restaurants = [];

  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _onlyOpenRestaurants = false;
  bool _isLoading = true;
  Timer? _searchDebounce;
  int _filterRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryScrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _scrollCategoriesWithWheel(PointerScrollEvent event) {
    if (!_categoryScrollController.hasClients) return;

    // A vertical mouse wheel naturally feels like horizontal browsing here.
    final delta = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    if (delta == 0) return;

    GestureBinding.instance.pointerSignalResolver.register(event, (signal) {
      if (signal is! PointerScrollEvent ||
          !_categoryScrollController.hasClients) {
        return;
      }

      final position = _categoryScrollController.position;
      final target = (_categoryScrollController.offset + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      _categoryScrollController.jumpTo(target);
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final categoriesFuture = ApiService.getCategories();
    final restaurantsFuture = ApiService.getRestaurants(
      category: _selectedCategory,
      search: _searchQuery,
    );
    final cats = await categoriesFuture;
    final rests = await restaurantsFuture;

    if (mounted) {
      setState(() {
        _categories = cats;
        _restaurants = _prioritizeBusinessRestaurant(rests);
        _isLoading = false;
      });
    }
  }

  Future<void> _filterRestaurants() async {
    final requestId = ++_filterRequestId;
    final rests = await ApiService.getRestaurants(
      category: _selectedCategory,
      search: _searchQuery,
    );
    if (mounted && requestId == _filterRequestId) {
      setState(() {
        _restaurants = _prioritizeBusinessRestaurant(rests);
      });
    }
  }

  List<RestaurantModel> _prioritizeBusinessRestaurant(
    List<RestaurantModel> restaurants,
  ) {
    final user = ApiService.currentUser;
    final sorted = List<RestaurantModel>.of(restaurants);
    sorted.sort((first, second) {
      if (first.isOpen != second.isOpen) return first.isOpen ? -1 : 1;
      if (user == null || !user.isBusiness) return 0;
      final firstIsOwned = first.ownerId == user.id;
      final secondIsOwned = second.ownerId == user.id;
      if (firstIsOwned == secondIsOwned) return 0;
      return firstIsOwned ? -1 : 1;
    });
    return _onlyOpenRestaurants
        ? sorted.where((restaurant) => restaurant.isOpen).toList()
        : sorted;
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    setState(() {
      _selectedCategory = 'All';
      _searchQuery = '';
      _onlyOpenRestaurants = false;
      _searchController.clear();
    });
    _filterRestaurants();
  }

  void _openRandomRestaurant() {
    final openRestaurants = _restaurants
        .where((restaurant) => restaurant.isOpen)
        .toList();
    if (openRestaurants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiện chưa có quán nào đang mở cửa.')),
      );
      return;
    }
    final restaurant =
        openRestaurants[Random().nextInt(openRestaurants.length)];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurantId: restaurant.id),
      ),
    ).then((_) => _loadInitialData());
  }

  void _openAdminPortal() {
    if (ApiService.isAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AdminDashboardScreen(onToggleTheme: widget.onToggleTheme),
        ),
      ).then((_) => _loadInitialData());
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
            ).then((_) => _loadInitialData());
          }
        },
      );
    }
  }

  Future<void> _openBusinessRestaurantManagement() async {
    final user = ApiService.currentUser;
    if (user == null || !user.isBusiness) return;
    final restaurants = await ApiService.getRestaurants(
      ownerId: user.id,
      includeUnapproved: true,
    );
    if (restaurants.isEmpty) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BusinessOnboardingScreen()),
      );
      if (mounted) await _loadInitialData();
      return;
    }
    final approved = restaurants
        .where((restaurant) => restaurant.approvalStatus == 'Approved')
        .toList();
    if (approved.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Từ chối truy cập: quán ăn của bạn chưa được Admin phê duyệt.',
            ),
            backgroundColor: AppTheme.fireCoral,
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    final restaurantDetail = await ApiService.getRestaurantDetail(
      approved.first.id,
    );
    if (!mounted || restaurantDetail == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessRestaurantManagementScreen(
          restaurant: restaurantDetail,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
  }

  void _showLoginDialog({VoidCallback? onSuccess}) {
    showDialog<bool>(
      context: context,
      builder: (_) => LoginDialog(
        onLoginSuccess: () {
          setState(() {});
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
              // Drag Indicator
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Avatar & Name Header
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
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
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: user.isAdmin
                                    ? AppTheme.fireCoral
                                    : (isDark
                                          ? Colors.white12
                                          : Colors.black12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user.role.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: user.isAdmin
                                      ? AppTheme.pureWhite
                                      : (isDark
                                            ? AppTheme.textMutedDark
                                            : AppTheme.textMutedLight),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
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
              Divider(
                color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
                height: 1,
              ),
              const SizedBox(height: 12),

              // Action: Admin Dashboard (if admin)
              if (user.isAdmin) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.fireCoral.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: AppTheme.fireCoral,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Bảng Quản Trị Hệ Thống',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                    ),
                  ),
                  subtitle: const Text(
                    'Quản lý nhà hàng, review, người dùng',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openAdminPortal();
                  },
                ),
                const SizedBox(height: 6),
              ],

              // Action: Logout
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
                subtitle: const Text(
                  'Thoát khỏi phiên làm việc hiện tại',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  await ApiService.logout();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã đăng xuất thành công!'),
                      backgroundColor: AppTheme.pitchBlack,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('all') || lower.contains('tất cả')) {
      return Icons.grid_view_rounded;
    }
    if (lower.contains('viet') || lower.contains('phở')) {
      return Icons.ramen_dining_rounded;
    }
    if (lower.contains('japan') || lower.contains('nhật')) {
      return Icons.set_meal_rounded;
    }
    if (lower.contains('ital') || lower.contains('pizza')) {
      return Icons.local_pizza_rounded;
    }
    if (lower.contains('bake') ||
        lower.contains('cafe') ||
        lower.contains('cà phê')) {
      return Icons.coffee_rounded;
    }
    if (lower.contains('korea') || lower.contains('hàn')) {
      return Icons.local_fire_department_rounded;
    }
    if (lower.contains('fine') || lower.contains('wine')) {
      return Icons.wine_bar_rounded;
    }
    return Icons.restaurant_rounded;
  }

  Widget _pageWidth(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1180),
      child: child,
    ),
  );

  Widget _buildDiscoveryHero(bool isDark) {
    final openCount = _restaurants
        .where((restaurant) => restaurant.isOpen)
        .length;
    final user = ApiService.currentUser;
    final title = user == null
        ? 'Một bữa ăn ngon\nbắt đầu từ đây.'
        : 'Hôm nay, ${user.fullName.split(' ').last}\nmuốn ăn gì?';
    final foreground = isDark ? AppTheme.pureWhite : AppTheme.pitchBlack;
    final muted = isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight;

    return _pageWidth(
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 580;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.fireCoral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'GỢI Ý HÔM NAY',
                    style: TextStyle(
                      color: AppTheme.fireCoral,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: compact ? 25 : 31,
                    height: 1.08,
                    letterSpacing: -1.1,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Khám phá địa điểm phù hợp với khẩu vị của bạn.',
                  style: TextStyle(fontSize: 13, color: muted),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _heroMetric(
                      Icons.restaurant_outlined,
                      '$openCount quán đang mở',
                      isDark,
                    ),
                    _heroMetric(
                      Icons.category_outlined,
                      '${_categories.length} danh mục',
                      isDark,
                    ),
                  ],
                ),
              ],
            );
            final action = Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openRandomRestaurant,
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  width: compact ? double.infinity : 190,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.fireCoral,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.fireCoral.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.casino_rounded, color: Colors.white, size: 28),
                      SizedBox(height: 18),
                      Text(
                        'Chọn ngẫu nhiên',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Để FoodieSpot quyết định',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            );
            return Container(
              padding: EdgeInsets.all(compact ? 20 : 24),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
                ),
              ),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [copy, const SizedBox(height: 18), action],
                    )
                  : Row(
                      children: [
                        Expanded(child: copy),
                        const SizedBox(width: 28),
                        action,
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _heroMetric(IconData icon, String label, bool isDark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: isDark ? Colors.white12 : AppTheme.grayBorder),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.fireCoral),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
          ),
        ),
      ],
    ),
  );

  Widget _sectionCaption(String eyebrow, String title, bool isDark) =>
      _pageWidth(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.fireCoral,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  letterSpacing: -0.6,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                ),
              ),
            ],
          ),
        ),
      );

  // Web-style horizontal nav links, shown in the header once the viewport
  // is wide enough that a bottom nav bar would waste space.
  Widget _navLink(String label, int index, bool isDark, bool isWide) {
    final isActive = _currentNavIndex == index && !_isMapView;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: () => _handleNavTap(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isActive
                  ? (isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive
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

  // Shared handler for both the bottom nav bar (mobile) and the header
  // nav links (web/wide), so the two entry points stay in sync.
  void _handleNavTap(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookmarksScreen(onToggleTheme: widget.onToggleTheme),
        ),
      ).then((_) => _loadInitialData());
      return;
    }
    if (index == 2) {
      if (ApiService.currentUser?.isBusiness == true) {
        _openBusinessRestaurantManagement();
      } else if (!ApiService.isLoggedIn) {
        _showLoginDialog();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MyReservationsScreen(onToggleTheme: widget.onToggleTheme),
          ),
        );
      }
      return;
    }
    setState(() {
      _currentNavIndex = index;
      _isMapView = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasActiveFilter =
        _selectedCategory != 'All' || _searchQuery.isNotEmpty || _onlyOpenRestaurants;
    final currentUser = ApiService.currentUser;
    final hasOwnedRestaurant =
        currentUser?.isBusiness == true &&
        _restaurants.any((restaurant) => restaurant.ownerId == currentUser!.id);
    final isWide = MediaQuery.of(context).size.width >= kWideBreakpoint;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.fireCoral,
          onRefresh: _loadInitialData,
          child: Column(
            children: [
              // Modern Minimalist Header (adds horizontal nav on wide/web)
              _buildModernHeader(isDark, isWide),

              // Main Content (Map View or Scrollable List View)
              Expanded(
                child: _isMapView
                    ? MapViewScreen(restaurants: _restaurants)
                    : CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          SliverToBoxAdapter(
                            child: _buildDiscoveryHero(isDark),
                          ),

                          SliverToBoxAdapter(
                            child: _sectionCaption(
                              'TÌM KIẾM',
                              'Bạn muốn ăn gì?',
                              isDark,
                            ),
                          ),

                          // Minimal Search Bar with quick feedback
                          SliverToBoxAdapter(
                            child: _pageWidth(
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  18,
                                ),
                                child: MinimalSearchBar(
                                  controller: _searchController,
                                  onChanged: (query) {
                                    _searchQuery = query;
                                    _searchDebounce?.cancel();
                                    _searchDebounce = Timer(
                                      const Duration(milliseconds: 300),
                                      _filterRestaurants,
                                    );
                                  },
                                  onClear: () {
                                    _searchDebounce?.cancel();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                    _filterRestaurants();
                                  },
                                ),
                              ),
                            ),
                          ),

                          // Category Carousel with Icons
                          SliverToBoxAdapter(
                            child: _pageWidth(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      8,
                                      20,
                                      10,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'DANH MỤC',
                                          style: TextStyle(
                                            color: AppTheme.fireCoral,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 10,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Khám phá theo khẩu vị',
                                          style: TextStyle(
                                            fontSize: 20,
                                            letterSpacing: -0.6,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? AppTheme.pureWhite
                                                : AppTheme.pitchBlack,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: 62,
                                    child: MouseRegion(
                                      onEnter: (_) => setState(
                                        () => _isCategoryPointerHovering = true,
                                      ),
                                      onExit: (_) => setState(
                                        () =>
                                            _isCategoryPointerHovering = false,
                                      ),
                                      child: Listener(
                                        onPointerSignal: (signal) {
                                          if (signal is PointerScrollEvent) {
                                            _scrollCategoriesWithWheel(signal);
                                          }
                                        },
                                        child: ScrollbarTheme(
                                          data: ScrollbarThemeData(
                                            thumbColor: WidgetStatePropertyAll(
                                              (isDark
                                                      ? AppTheme.pureWhite
                                                      : AppTheme.pitchBlack)
                                                  .withValues(
                                                    alpha:
                                                        _isCategoryPointerHovering
                                                        ? 0.48
                                                        : 0.16,
                                                  ),
                                            ),
                                            thickness: WidgetStatePropertyAll(
                                              _isCategoryPointerHovering
                                                  ? 5
                                                  : 2,
                                            ),
                                            radius: const Radius.circular(99),
                                          ),
                                          child: Scrollbar(
                                            controller:
                                                _categoryScrollController,
                                            thumbVisibility: true,
                                            interactive:
                                                _isCategoryPointerHovering,
                                            scrollbarOrientation:
                                                ScrollbarOrientation.bottom,
                                            child: ListView.builder(
                                              controller:
                                                  _categoryScrollController,
                                              scrollDirection: Axis.horizontal,
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    20,
                                                    0,
                                                    20,
                                                    10,
                                                  ),
                                              itemCount: _categories.length,
                                              itemBuilder: (context, index) {
                                                final categoryName =
                                                    _categories[index].name;
                                                final isSelected =
                                                    _selectedCategory
                                                        .toLowerCase() ==
                                                    categoryName.toLowerCase();
                                                final icon = _getCategoryIcon(
                                                  categoryName,
                                                );

                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 8,
                                                      ),
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      _searchDebounce?.cancel();
                                                      setState(() {
                                                        _selectedCategory =
                                                            categoryName;
                                                      });
                                                      _filterRestaurants();
                                                    },
                                                    child: AnimatedContainer(
                                                      duration: const Duration(
                                                        milliseconds: 200,
                                                      ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 10,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: isSelected
                                                            ? (isDark
                                                                  ? AppTheme
                                                                        .pureWhite
                                                                  : AppTheme
                                                                        .pitchBlack)
                                                            : (isDark
                                                                  ? AppTheme
                                                                        .darkCardBg
                                                                  : AppTheme
                                                                        .lightCardBg),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              30,
                                                            ),
                                                        border: Border.all(
                                                          color: isSelected
                                                              ? (isDark
                                                                    ? AppTheme
                                                                          .pureWhite
                                                                    : AppTheme
                                                                          .pitchBlack)
                                                              : (isDark
                                                                    ? AppTheme
                                                                          .darkGrayBorder
                                                                    : AppTheme
                                                                          .grayBorder),
                                                          width: 1.2,
                                                        ),
                                                        boxShadow: isSelected
                                                            ? [
                                                                BoxShadow(
                                                                  color: Colors
                                                                      .black
                                                                      .withValues(
                                                                        alpha:
                                                                            isDark
                                                                            ? 0.4
                                                                            : 0.08,
                                                                      ),
                                                                  blurRadius:
                                                                      10,
                                                                  offset:
                                                                      const Offset(
                                                                        0,
                                                                        4,
                                                                      ),
                                                                ),
                                                              ]
                                                            : null,
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            icon,
                                                            size: 16,
                                                            color: isSelected
                                                                ? (isDark
                                                                      ? AppTheme
                                                                            .pitchBlack
                                                                      : AppTheme
                                                                            .pureWhite)
                                                                : (isDark
                                                                      ? AppTheme
                                                                            .pureWhite
                                                                      : AppTheme
                                                                            .pitchBlack),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            categoryName,
                                                            style: TextStyle(
                                                              color: isSelected
                                                                  ? (isDark
                                                                        ? AppTheme
                                                                              .pitchBlack
                                                                        : AppTheme
                                                                              .pureWhite)
                                                                  : (isDark
                                                                        ? AppTheme
                                                                              .pureWhite
                                                                        : AppTheme
                                                                              .pitchBlack),
                                                              fontWeight:
                                                                  isSelected
                                                                  ? FontWeight
                                                                        .w700
                                                                  : FontWeight
                                                                        .w500,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Section Title & Filter Summary Row
                          if (!_isLoading &&
                              _restaurants.any(
                                (restaurant) => restaurant.isOpen,
                              ))
                            SliverToBoxAdapter(
                              child: _buildTrendingSection(isDark),
                            ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        hasOwnedRestaurant
                                            ? 'Quán ăn của bạn'
                                            : (_selectedCategory == 'All'
                                                  ? 'Khám phá quán ăn'
                                                  : _selectedCategory),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? AppTheme.pureWhite
                                              : AppTheme.pitchBlack,
                                          letterSpacing: -0.6,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.fireCoral.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          '${_restaurants.length}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.fireCoral,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(children: [
                                    FilterChip(
                                      label: const Text('Đang mở'),
                                      selected: _onlyOpenRestaurants,
                                      selectedColor: AppTheme.fireCoral.withValues(alpha: 0.16),
                                      checkmarkColor: AppTheme.fireCoral,
                                      labelStyle: TextStyle(
                                        color: _onlyOpenRestaurants ? AppTheme.fireCoral : (isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight),
                                        fontWeight: FontWeight.w700,
                                      ),
                                      onSelected: (selected) {
                                        setState(() => _onlyOpenRestaurants = selected);
                                        _filterRestaurants();
                                      },
                                    ),
                                    if (hasActiveFilter) ...[
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: _clearFilters,
                                        child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white10
                                              : Colors.black.withValues(
                                                  alpha: 0.05,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.close_rounded,
                                              size: 14,
                                              color: isDark
                                                  ? AppTheme.textMutedDark
                                                  : AppTheme.textMutedLight,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Xóa bộ lọc',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? AppTheme.textMutedDark
                                                    : AppTheme.textMutedLight,
                                              ),
                                            ),
                                          ],
                                        ),
                                        ),
                                      ),
                                    ],
                                  ]),
                                ],
                              ),
                            ),
                          ),

                          // Restaurant Cards List or Skeleton Loading or Empty State
                          _isLoading
                              ? _buildLoadingSkeleton(isDark)
                              : _restaurants.isEmpty
                              ? _buildEmptyState(isDark)
                              : SliverLayoutBuilder(
                                  builder: (context, constraints) {
                                    // Keep the familiar single-column layout on phones,
                                    // while preventing restaurant images from becoming
                                    // oversized on wide web screens.
                                    final maxCardWidth =
                                        constraints.crossAxisExtent >= 900
                                        ? 390.0
                                        : 600.0;
                                    final contentWidth = max(
                                      0.0,
                                      constraints.crossAxisExtent - 40,
                                    );
                                    final columnCount = max(
                                      1,
                                      ((contentWidth + 16) /
                                              (maxCardWidth + 16))
                                          .ceil(),
                                    );
                                    final cardWidth =
                                        (contentWidth -
                                            (columnCount - 1) * 16) /
                                        columnCount;
                                    // The card's 16:9 image and detail block
                                    // need a height based on its actual grid
                                    // column width, not the viewport width.
                                    final cardHeight = max(
                                      370.0,
                                      cardWidth * 9 / 16 + 182,
                                    );

                                    return SliverPadding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        0,
                                        20,
                                        24,
                                      ),
                                      sliver: SliverGrid(
                                        gridDelegate:
                                            SliverGridDelegateWithMaxCrossAxisExtent(
                                              maxCrossAxisExtent: maxCardWidth,
                                              mainAxisExtent: cardHeight,
                                              mainAxisSpacing: 4,
                                              crossAxisSpacing: 16,
                                            ),
                                        delegate: SliverChildBuilderDelegate((
                                          context,
                                          index,
                                        ) {
                                          final rest = _restaurants[index];
                                          return RestaurantCard(
                                            restaurant: rest,
                                            isBookmarked:
                                                ApiService.isBookmarked(
                                                  rest.id,
                                                ),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      RestaurantDetailScreen(
                                                        restaurantId: rest.id,
                                                      ),
                                                ),
                                              ).then((_) => setState(() {}));
                                            },
                                            onBookmarkToggle: () async {
                                              if (!ApiService.isLoggedIn) {
                                                _showLoginDialog(
                                                  onSuccess: () async {
                                                    await ApiService.toggleBookmark(
                                                      rest.id,
                                                    );
                                                    setState(() {});
                                                  },
                                                );
                                                return;
                                              }
                                              await ApiService.toggleBookmark(
                                                rest.id,
                                              );
                                              setState(() {});
                                            },
                                          );
                                        }, childCount: _restaurants.length),
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),

      // Bottom navigation bar: mobile-only. On wide/web layouts the same
      // destinations live in the header nav links instead (see
      // _buildModernHeader), so the bar is omitted there to avoid duplication.
      bottomNavigationBar: isWide
          ? null
          : Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppTheme.darkGrayBorder
                        : AppTheme.grayBorder,
                    width: 1,
                  ),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentNavIndex,
                onTap: _handleNavTap,
                backgroundColor: isDark
                    ? AppTheme.pitchBlack
                    : AppTheme.pureWhite,
                selectedItemColor: AppTheme.fireCoral,
                unselectedItemColor: isDark
                    ? AppTheme.textMutedDark
                    : AppTheme.textMutedLight,
                showSelectedLabels: true,
                showUnselectedLabels: true,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                elevation: 0,
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
              ),
            ),
    );
  }

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

  // Skeleton Loading Shimmer for high polish
  Widget _buildLoadingSkeleton(bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.04),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.fireCoral,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 160,
                        height: 18,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.black12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }, childCount: 3),
      ),
    );
  }

  Widget _buildTrendingSection(bool isDark) {
    final trending =
        List<RestaurantModel>.of(
          _restaurants.where((restaurant) => restaurant.isOpen),
        )..sort((first, second) {
          final firstScore = first.rating * (first.reviewCount + 1);
          final secondScore = second.rating * (second.reviewCount + 1);
          return secondScore.compareTo(firstScore);
        });

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: AppTheme.fireCoral,
                size: 21,
              ),
              const SizedBox(width: 7),
              Text(
                'Đang thịnh hành',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                ),
              ),
              const Spacer(),
              Text(
                'Top ${min(3, trending.length)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppTheme.textMutedDark
                      : AppTheme.textMutedLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 138,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: min(3, trending.length),
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final restaurant = trending[index];
                final imageUrl =
                    restaurant.cardImageUrl ?? restaurant.coverImageUrl;
                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RestaurantDetailScreen(restaurantId: restaurant.id),
                    ),
                  ).then((_) => _loadInitialData()),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 220,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkCardBg
                          : AppTheme.lightCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.darkGrayBorder
                            : AppTheme.grayBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 86,
                          height: double.infinity,
                          child: Image.network(
                            ApiService.resolveImageUrl(imageUrl),
                            fit: BoxFit.cover,
                            cacheWidth: 172,
                            filterQuality: FilterQuality.low,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: Colors.black12,
                              child: Icon(
                                Icons.restaurant_rounded,
                                color: AppTheme.fireCoral,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  restaurant.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppTheme.pureWhite
                                        : AppTheme.pitchBlack,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 15,
                                      color: AppTheme.fireCoral,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${restaurant.rating.toStringAsFixed(1)} · ${restaurant.reviewCount} đánh giá',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppTheme.textMutedDark
                                            : AppTheme.textMutedLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Empty State with Reset Filters CTA
  Widget _buildEmptyState(bool isDark) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? AppTheme.darkGrayBorder
                        : AppTheme.grayBorder,
                  ),
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  size: 40,
                  color: AppTheme.fireCoral,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Không tìm thấy quán ăn phù hợp',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Thử tìm kiếm với từ khóa khác hoặc chuyển sang thể loại ẩm thực khác.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppTheme.textMutedDark
                      : AppTheme.textMutedLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Xem tất cả nhà hàng'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppTheme.pureWhite
                      : AppTheme.pitchBlack,
                  foregroundColor: isDark
                      ? AppTheme.pitchBlack
                      : AppTheme.pureWhite,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
