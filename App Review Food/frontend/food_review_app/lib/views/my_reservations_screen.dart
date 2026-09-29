import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'bookmarks_screen.dart';
import 'business_restaurant_management_screen.dart';
import 'business_onboarding_screen.dart';
import 'login_dialog.dart';
import 'map_view_screen.dart';

class MyReservationsScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;

  const MyReservationsScreen({super.key, this.onToggleTheme});
  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  int? _cancelling;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ApiService.getMyReservations();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _time(dynamic value) {
    final parsed = DateTime.parse(value.toString());
    return parsed.isUtc
        ? parsed.toLocal()
        : DateTime.utc(
            parsed.year,
            parsed.month,
            parsed.day,
            parsed.hour,
            parsed.minute,
            parsed.second,
          ).toLocal();
  }

  Future<void> _cancel(Map<String, dynamic> item) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hủy đặt bàn?'),
        content: Text(
          'Bạn muốn hủy bàn tại ${item['restaurantName'] ?? 'quán này'}? Quán sẽ nhận được trạng thái hủy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ bàn'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hủy bàn'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final id = item['id'] as int;
    setState(() => _cancelling = id);
    try {
      await ApiService.cancelMyReservation(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hủy đặt bàn. Bạn có thể đặt quán khác.'),
          ),
        );
        await _load();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _cancelling = null);
    }
  }

  Future<void> _openMap() async {
    final restaurants = await ApiService.getRestaurants();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapViewScreen(restaurants: restaurants),
      ),
    );
  }

  void _showAccountSheet(bool isDark) {
    final user = ApiService.currentUser;
    if (user == null) {
      showDialog<bool>(
        context: context,
        builder: (_) => LoginDialog(
          onLoginSuccess: () {
            setState(() {});
            _load();
          },
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBg : AppTheme.pureWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.fireCoral.withValues(alpha: 0.14),
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: AppTheme.fireCoral,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                    ),
                  ),
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
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: () async {
                await ApiService.logout();
                if (!mounted || !sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                setState(() {});
                _load();
              },
              icon: const Icon(Icons.logout_rounded, color: AppTheme.fireCoral),
            ),
          ],
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
      constraints: const BoxConstraints(maxWidth: 960),
      child: child,
    ),
  );

  Widget _buildModernHeader(bool isDark, bool isWide) => Container(
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
          children: [
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
                          ApiService.currentUser?.fullName.isNotEmpty == true
                              ? 'XIN CHÀO, ${ApiService.currentUser!.fullName.toUpperCase()}'
                              : 'SAVOR & REVIEW',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: isDark
                                ? AppTheme.textMutedDark
                                : AppTheme.textMutedLight,
                          ),
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
                      letterSpacing: -1,
                      color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                    ),
                  ),
                ],
              ),
            ),
            if (isWide) ...[
              _navLink('Khám phá', 0, isDark),
              _navLink('Đã lưu', 1, isDark),
              _navLink(
                ApiService.currentUser?.isBusiness == true
                    ? 'Quản lý quán ăn'
                    : 'Đặt bàn của tôi',
                2,
                isDark,
              ),
              const SizedBox(width: 12),
            ],
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _headerAction(
                  tooltip: 'Tải lại',
                  icon: Icons.refresh_rounded,
                  isDark: isDark,
                  onPressed: _loading ? null : _load,
                ),
                _headerAction(
                  tooltip: 'Xem bản đồ',
                  icon: Icons.map_outlined,
                  isDark: isDark,
                  onPressed: _openMap,
                ),
                _headerAction(
                  tooltip: isDark ? 'Chế độ sáng' : 'Chế độ tối',
                  icon: isDark
                      ? Icons.wb_sunny_rounded
                      : Icons.nightlight_round,
                  isDark: isDark,
                  onPressed: widget.onToggleTheme,
                ),
                if (ApiService.isLoggedIn)
                  GestureDetector(
                    onTap: () => _showAccountSheet(isDark),
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.fireCoral,
                          width: 1.5,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.fireCoral.withValues(
                          alpha: 0.14,
                        ),
                        child: Text(
                          ApiService.currentUser?.fullName.isNotEmpty == true
                              ? ApiService.currentUser!.fullName[0]
                                    .toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: AppTheme.fireCoral,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  _headerAction(
                    tooltip: 'Đăng nhập',
                    icon: Icons.person_outline_rounded,
                    isDark: isDark,
                    onPressed: () => _showAccountSheet(isDark),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _headerAction({
    required String tooltip,
    required IconData icon,
    required bool isDark,
    required VoidCallback? onPressed,
  }) => Tooltip(
    message: tooltip,
    child: IconButton(
      onPressed: onPressed,
      icon: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
          ),
        ),
        child: Icon(
          icon,
          size: 19,
          color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
        ),
      ),
    ),
  );

  Widget _navLink(String label, int index, bool isDark) {
    final isActive = index == 2;
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

  Future<void> _handleNavTap(int index) async {
    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BookmarksScreen()),
      );
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
        builder: (_) => LoginDialog(onLoginSuccess: _load),
      );
    } else {
      _load();
    }
  }

  Widget _buildBottomNavigation(bool isDark) => BottomNavigationBar(
    currentIndex: 2,
    onTap: _handleNavTap,
    backgroundColor: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
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
  );

  int get _activeCount => _items.where((item) {
    final status = item['status'];
    return (status == 'Pending' || status == 'Confirmed') &&
        _time(item['reservationTime']).isAfter(DateTime.now());
  }).length;

  Widget _buildHero(bool isDark) => _pageWidth(
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
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.fireCoral.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.table_restaurant_outlined,
                color: AppTheme.fireCoral,
                size: 27,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LỊCH HẸN ẨM THỰC',
                    style: TextStyle(
                      color: AppTheme.fireCoral,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _loading
                        ? 'Đang cập nhật lịch hẹn…'
                        : _activeCount == 0
                        ? 'Bạn đang không có bàn nào.'
                        : 'Bạn có $_activeCount bàn đang hiệu lực.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Theo dõi trạng thái hoặc hủy bàn trước giờ hẹn.',
                    style: TextStyle(
                      fontSize: 12,
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
      ),
    ),
  );

  Widget _buildBody(bool isDark) => RefreshIndicator(
    color: AppTheme.fireCoral,
    onRefresh: _load,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: _buildHero(isDark)),
        if (_loading)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.fireCoral),
            ),
          )
        else if (_error != null)
          SliverFillRemaining(hasScrollBody: false, child: _errorState(isDark))
        else if (_items.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: _emptyState(isDark))
        else ...[
          SliverToBoxAdapter(
            child: _pageWidth(
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Lịch sử yêu cầu',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverToBoxAdapter(
              child: _pageWidth(
                Column(
                  children: _items
                      .map((item) => _reservationCard(item, isDark))
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  ({String label, Color color, IconData icon}) _status(dynamic raw) =>
      switch (raw) {
        'Pending' => (
          label: 'Chờ quán xác nhận',
          color: AppTheme.fireCoral,
          icon: Icons.schedule_rounded,
        ),
        'Confirmed' => (
          label: 'Đã xác nhận',
          color: const Color(0xFF238B57),
          icon: Icons.check_circle_outline_rounded,
        ),
        'Cancelled' => (
          label: 'Đã hủy',
          color: AppTheme.textMutedLight,
          icon: Icons.cancel_outlined,
        ),
        _ => (
          label: 'Quán từ chối',
          color: const Color(0xFFC62828),
          icon: Icons.do_not_disturb_on_outlined,
        ),
      };

  Widget _reservationCard(Map<String, dynamic> item, bool isDark) {
    final time = _time(item['reservationTime']);
    final status = _status(item['status']);
    final canCancel =
        (item['status'] == 'Pending' || item['status'] == 'Confirmed') &&
        time.isAfter(DateTime.now());
    final busy = _cancelling == item['id'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBg : AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  '${time.day}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: status.color,
                  ),
                ),
                Text(
                  'THG ${time.month}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: status.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item['restaurantName'] ?? 'Quán ăn'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppTheme.pureWhite
                              : AppTheme.pitchBlack,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(status.icon, size: 17, color: status.color),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: status.color,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 5,
                  children: [
                    _detail(
                      Icons.access_time_rounded,
                      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                      isDark,
                    ),
                    _detail(
                      Icons.people_outline_rounded,
                      '${item['partySize']} người',
                      isDark,
                    ),
                  ],
                ),
                if ((item['note'] ?? '').toString().trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Ghi chú: ${item['note']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.textMutedDark
                            : AppTheme.textMutedLight,
                      ),
                    ),
                  ),
                if (canCancel)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.fireCoral,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: busy ? null : () => _cancel(item),
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cancel_outlined, size: 18),
                      label: Text(busy ? 'Đang hủy' : 'Hủy đặt bàn'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String label, bool isDark) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: AppTheme.fireCoral),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
        ),
      ),
    ],
  );

  Widget _emptyState(bool isDark) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.event_seat_outlined,
          size: 62,
          color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
        ),
        const SizedBox(height: 16),
        Text(
          'Chưa có bàn nào được đặt',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Khi đặt bàn, lịch hẹn sẽ xuất hiện tại đây.',
          style: TextStyle(
            color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
          ),
        ),
      ],
    ),
  );

  Widget _errorState(bool isDark) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 44,
            color: AppTheme.fireCoral,
          ),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: _load, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}
