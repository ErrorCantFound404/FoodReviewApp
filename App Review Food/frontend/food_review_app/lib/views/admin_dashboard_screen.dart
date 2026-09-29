import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/restaurant.dart';
import '../models/review.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'add_edit_restaurant_dialog.dart';
import 'review_reports_panel.dart';

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;

  const AdminDashboardScreen({super.key, this.onToggleTheme});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  Map<String, dynamic> _stats = {};
  List<RestaurantModel> _restaurants = [];
  List<ReviewModel> _reviews = [];
  List<CategoryModel> _categories = [];
  List<UserModel> _users = [];
  final TextEditingController _restaurantSearchController =
      TextEditingController();
  String _restaurantQuery = '';
  String _restaurantCategoryFilter = 'Tất cả';
  String _reviewFilter = 'Tất cả';
  String _userFilter = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _restaurantSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final stats = await ApiService.getAdminStats();
    final restaurants = await ApiService.getRestaurants(
      includeUnapproved: true,
    );
    final reviews = await ApiService.getAllReviews();
    final categories = await ApiService.getCategories();
    final users = await ApiService.getUsers();

    if (mounted) {
      setState(() {
        _stats = stats;
        _restaurants = restaurants;
        _reviews = reviews;
        _categories = categories;
        _users = users;
        _isLoading = false;
      });
    }
  }

  Future<void> _openAddEditRestaurant([RestaurantModel? rest]) async {
    // The table intentionally uses lightweight restaurant summaries for
    // smooth web scrolling. Fetch the complete gallery and menu only when
    // an Admin opens the edit form, so saving never overwrites them.
    var restaurantForEdit = rest;
    if (rest != null) {
      restaurantForEdit = await ApiService.getRestaurantDetail(rest.id) ?? rest;
      if (!mounted) return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AddEditRestaurantDialog(restaurant: restaurantForEdit),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _deleteRestaurant(RestaurantModel rest) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác Nhận Xóa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa nhà hàng "${rest.name}"? Tất cả đánh giá thuộc nhà hàng cũng sẽ bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.fireCoral,
            ),
            child: const Text('XÓA', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await ApiService.deleteRestaurant(rest.id);
      if (ok) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa nhà hàng thành công!'),
              backgroundColor: AppTheme.fireCoral,
            ),
          );
        }
      }
    }
  }

  Future<void> _reviewRestaurant(
    RestaurantModel restaurant,
    bool approved,
  ) async {
    final action = approved ? 'phê duyệt' : 'từ chối';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${approved ? 'Phê duyệt' : 'Từ chối'} hồ sơ?'),
        content: Text(
          'Bạn có chắc muốn $action hồ sơ của "${restaurant.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: approved ? Colors.green : Colors.red,
            ),
            child: Text(approved ? 'Phê duyệt' : 'Từ chối'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await ApiService.reviewRestaurantProfile(
      restaurant.id,
      approved: approved,
    );
    if (success) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Đã $action hồ sơ nhà hàng.')));
      }
    }
  }

  Future<void> _showRestaurantDetails(
    RestaurantModel summary, {
    bool showApprovalActions = false,
  }) async {
    final restaurant =
        await ApiService.getRestaurantDetail(summary.id) ?? summary;
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? AppTheme.darkCardBg : AppTheme.pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        restaurant.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      _approvalDetailRow(
                        Icons.tag_rounded,
                        'ID quán',
                        '${restaurant.id}',
                        isDark,
                      ),
                      _approvalDetailRow(
                        Icons.toggle_on_outlined,
                        'Hoạt động',
                        restaurant.isOpen ? 'Đang mở' : 'Đang đóng',
                        isDark,
                      ),
                      _approvalDetailRow(
                        Icons.verified_outlined,
                        'Trạng thái hồ sơ',
                        restaurant.approvalStatus,
                        isDark,
                      ),
                      _approvalDetailRow(
                        Icons.star_rounded,
                        'Đánh giá',
                        '${restaurant.rating.toStringAsFixed(1)} (${restaurant.reviewCount} lượt)',
                        isDark,
                      ),
                      _approvalDetailRow(
                        Icons.bookmark_outline_rounded,
                        'Được lưu',
                        '${restaurant.bookmarkCount} lượt',
                        isDark,
                      ),
                      _approvalDetailRow(
                        Icons.category_outlined,
                        'Loại hình',
                        restaurant.cuisine,
                        isDark,
                      ),
                      _approvalDetailRow(
                        Icons.sell_outlined,
                        'ID thể loại',
                        restaurant.categoryId?.toString() ?? 'Chưa gán',
                        isDark,
                      ),
                      _approvalDetailRow(
                        Icons.payments_outlined,
                        'Khoảng giá',
                        restaurant.priceRange,
                        isDark,
                      ),
                      _approvalDetailRow(
                        Icons.location_on_outlined,
                        'Địa chỉ',
                        restaurant.address,
                        isDark,
                      ),
                      _approvalDetailRow(
                        Icons.pin_drop_outlined,
                        'Tọa độ',
                        '${restaurant.latitude}, ${restaurant.longitude}',
                        isDark,
                      ),
                      _approvalDetailRow(
                        Icons.person_outline_rounded,
                        'ID chủ sở hữu',
                        restaurant.ownerId?.toString() ?? 'Chưa gán',
                        isDark,
                      ),
                      _approvalDetailRow(
                        Icons.calendar_today_outlined,
                        'Tạo lúc',
                        '${restaurant.createdAt.day}/${restaurant.createdAt.month}/${restaurant.createdAt.year}',
                        isDark,
                      ),
                      if (restaurant.submittedAt != null)
                        _approvalDetailRow(
                          Icons.schedule_outlined,
                          'Gửi hồ sơ',
                          '${restaurant.submittedAt!.day}/${restaurant.submittedAt!.month}/${restaurant.submittedAt!.year}',
                          isDark,
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'Mô tả',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        restaurant.description,
                        style: TextStyle(
                          height: 1.45,
                          color: isDark
                              ? AppTheme.textMutedDark
                              : AppTheme.textMutedLight,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Ảnh quán (${restaurant.imageUrls.length}/5)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: restaurant.imageUrls.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) => ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 130,
                              child: _approvalImage(
                                restaurant.imageUrls[index],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Thực đơn (${restaurant.menuItems.length} món)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (restaurant.menuItems.isEmpty)
                        Text(
                          'Chưa có món nào.',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.textMutedDark
                                : AppTheme.textMutedLight,
                          ),
                        )
                      else
                        ...restaurant.menuItems.map(
                          (item) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.name),
                            subtitle: item.description.isEmpty
                                ? null
                                : Text(item.description),
                            trailing: Text(
                              '${item.price.toStringAsFixed(0)}đ',
                              style: const TextStyle(
                                color: AppTheme.fireCoral,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'Đánh giá hiện có: ${restaurant.reviews.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (showApprovalActions)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _reviewRestaurant(restaurant, false);
                          },
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Từ chối'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _reviewRestaurant(restaurant, true);
                          },
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Phê duyệt'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _approvalDetailRow(
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.fireCoral, size: 18),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _approvalImage(String url) {
    if (url.startsWith('data:image/')) {
      try {
        return Image.memory(
          base64Decode(url.split(',').last),
          fit: BoxFit.cover,
        );
      } catch (_) {
        return const ColoredBox(
          color: Colors.black12,
          child: Icon(Icons.broken_image_rounded),
        );
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Colors.black12,
        child: Icon(Icons.broken_image_rounded),
      ),
    );
  }

  RestaurantModel? _restaurantForReview(ReviewModel review) {
    for (final restaurant in _restaurants) {
      if (restaurant.id == review.restaurantId) return restaurant;
    }
    return null;
  }

  void _showReviewedRestaurant(ReviewModel review) {
    final restaurant = _restaurantForReview(review);
    if (restaurant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy quán của đánh giá này.')),
      );
      return;
    }
    _showRestaurantDetails(restaurant);
  }

  Future<void> _deleteReview(ReviewModel rev) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa Đánh Giá'),
        content: const Text('Bạn có chắc chắn muốn xóa bài đánh giá này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.fireCoral,
            ),
            child: const Text('XÓA', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await ApiService.deleteReview(rev.id);
      if (result['success'] == true) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa bài đánh giá!'),
              backgroundColor: AppTheme.fireCoral,
            ),
          );
        }
      }
    }
  }

  Future<void> _openAddCategoryDialog() async {
    final nameController = TextEditingController();
    const iconOptions = <String>[
      'utensils',
      'soup',
      'coffee',
      'pizza',
      'cake',
      'fastfood',
      'local_dining',
      'ramen_dining',
    ];
    var selectedIcon = iconOptions.first;

    final result = await showDialog<({String name, String icon})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Dialog(
            backgroundColor: isDark ? AppTheme.darkCardBg : AppTheme.pureWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.fireCoral.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _categoryIcon(selectedIcon),
                            color: AppTheme.fireCoral,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tạo thể loại mới',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppTheme.pureWhite
                                  : AppTheme.pitchBlack,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dùng thể loại để phân nhóm và lọc nhà hàng trong ứng dụng.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppTheme.textMutedDark
                            : AppTheme.textMutedLight,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Tên thể loại',
                        hintText: 'Ví dụ: Hàn Quốc',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Chọn biểu tượng',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.pureWhite
                            : AppTheme.pitchBlack,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: iconOptions.map((iconName) {
                        final selected = iconName == selectedIcon;
                        return Tooltip(
                          message: iconName,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () =>
                                setDialogState(() => selectedIcon = iconName),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.fireCoral
                                    : (isDark
                                          ? AppTheme.pitchBlack
                                          : AppTheme.lightCardBg),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? AppTheme.fireCoral
                                      : (isDark
                                            ? AppTheme.darkGrayBorder
                                            : AppTheme.grayBorder),
                                ),
                              ),
                              child: Icon(
                                _categoryIcon(iconName),
                                size: 20,
                                color: selected
                                    ? Colors.white
                                    : (isDark
                                          ? AppTheme.pureWhite
                                          : AppTheme.pitchBlack),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Hủy'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(context, (
                            name: nameController.text.trim(),
                            icon: selectedIcon,
                          )),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Tạo thể loại'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.fireCoral,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    // The dialog route still renders during its closing animation. Defer
    // disposal until that animation is fully finished.
    Future<void>.delayed(
      const Duration(milliseconds: 300),
      nameController.dispose,
    );

    if (result != null && result.name.isNotEmpty) {
      final exists = _categories.any(
        (category) => category.name.toLowerCase() == result.name.toLowerCase(),
      );
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thể loại này đã tồn tại.')),
          );
        }
        return;
      }
      await ApiService.createCategory(result.name, result.icon);
      _loadData();
    }
  }

  Future<void> _deleteCategory(CategoryModel cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác Nhận Xóa Thể Loại'),
        content: Text('Bạn có chắc chắn muốn xóa thể loại "${cat.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.fireCoral,
            ),
            child: const Text('XÓA', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService.deleteCategory(cat.id);
      if (res['success'] == true) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Đã xóa thể loại thành công!'),
              backgroundColor: AppTheme.fireCoral,
            ),
          );
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'CẢNH BÁO XÓA THỂ LOẠI',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Text(res['message'] ?? 'Không thể xóa thể loại này!'),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.fireCoral,
                  ),
                  child: const Text(
                    'ĐÃ HIỂU',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  IconData _categoryIcon(String icon) => switch (icon.toLowerCase()) {
    'coffee' => Icons.coffee_outlined,
    'pizza' => Icons.local_pizza_outlined,
    'cake' => Icons.cake_outlined,
    'fastfood' => Icons.fastfood_outlined,
    'local_dining' => Icons.local_dining_outlined,
    'ramen_dining' => Icons.ramen_dining_outlined,
    'soup' => Icons.soup_kitchen_outlined,
    _ => Icons.restaurant_menu_rounded,
  };

  // User Management Dialog (Add / Edit User)
  Future<void> _openAddEditUserDialog([UserModel? user]) async {
    final isEdit = user != null;
    final usernameController = TextEditingController(
      text: user?.username ?? '',
    );
    final fullNameController = TextEditingController(
      text: user?.fullName ?? '',
    );
    final passwordController = TextEditingController();
    final avatarController = TextEditingController(text: user?.avatarUrl ?? '');
    String selectedRole = user?.role ?? 'User';
    var isPasswordVisible = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.fireCoral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: AppTheme.fireCoral,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEdit ? 'Chỉnh sửa tài khoản' : 'Tạo tài khoản mới',
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: usernameController,
                    enabled: !isEdit, // Cannot edit username once created
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập',
                      prefixIcon: Icon(Icons.account_circle_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: !isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: isEdit
                          ? 'Mật khẩu mới (Bỏ trống nếu không đổi)'
                          : 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: isPasswordVisible
                            ? 'Ẩn mật khẩu'
                            : 'Hiện mật khẩu',
                        onPressed: () => setDialogState(
                          () => isPasswordVisible = !isPasswordVisible,
                        ),
                        icon: Icon(
                          isPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Vai trò (Role)',
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'User',
                        child: Text('Thực khách (User)'),
                      ),
                      DropdownMenuItem(
                        value: 'Admin',
                        child: Text('Quản trị viên (Admin)'),
                      ),
                      DropdownMenuItem(
                        value: 'Business',
                        child: Text('Doanh nghiệp (Business)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedRole = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: avatarController,
                    decoration: const InputDecoration(
                      labelText: 'Link Avatar URL (Tùy chọn)',
                      prefixIcon: Icon(Icons.image_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('HỦY'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.fireCoral,
              ),
              child: Text(
                isEdit ? 'LƯU' : 'THÊM',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      Map<String, dynamic> res;
      if (isEdit) {
        res = await ApiService.updateUser(
          user.id,
          fullName: fullNameController.text.trim(),
          role: selectedRole,
          password: passwordController.text.trim().isEmpty
              ? null
              : passwordController.text.trim(),
          avatarUrl: avatarController.text.trim().isEmpty
              ? null
              : avatarController.text.trim(),
        );
      } else {
        if (usernameController.text.trim().isEmpty ||
            passwordController.text.trim().isEmpty ||
            fullNameController.text.trim().isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Vui lòng nhập đầy đủ tên đăng nhập, mật khẩu và họ tên!',
                ),
                backgroundColor: AppTheme.fireCoral,
              ),
            );
          }
          return;
        }
        res = await ApiService.createUser(
          username: usernameController.text.trim(),
          password: passwordController.text.trim(),
          fullName: fullNameController.text.trim(),
          role: selectedRole,
          avatarUrl: avatarController.text.trim(),
        );
      }

      if (res['success'] == true) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Thao tác thành công!'),
              backgroundColor: AppTheme.pitchBlack,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Thao tác thất bại!'),
              backgroundColor: AppTheme.fireCoral,
            ),
          );
        }
      }
    }
  }

  void _showUserDetails(UserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleColor = user.isAdmin
        ? const Color(0xFF8E44AD)
        : user.isBusiness
        ? const Color(0xFF1976D2)
        : AppTheme.fireCoral;
    final lastLogin = user.lastLoginAt == null
        ? 'Chưa có dữ liệu đăng nhập'
        : '${user.lastLoginAt!.day}/${user.lastLoginAt!.month}/${user.lastLoginAt!.year} · ${user.lastLoginAt!.hour.toString().padLeft(2, '0')}:${user.lastLoginAt!.minute.toString().padLeft(2, '0')}';
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? AppTheme.darkCardBg : AppTheme.pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: roleColor.withValues(alpha: 0.15),
                      child: Text(
                        user.fullName.isEmpty
                            ? 'U'
                            : user.fullName[0].toUpperCase(),
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppTheme.pureWhite
                                  : AppTheme.pitchBlack,
                            ),
                          ),
                          Text(
                            '@${user.username}',
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.textMutedDark
                                  : AppTheme.textMutedLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    children: [
                      _userDetailRow(
                        Icons.badge_outlined,
                        'Vai trò',
                        user.role,
                        roleColor,
                        isDark,
                      ),
                      _userDetailRow(
                        Icons.bookmark_outline_rounded,
                        'Quán đã lưu',
                        '${user.bookmarkCount} quán',
                        AppTheme.fireCoral,
                        isDark,
                      ),
                      _userDetailRow(
                        Icons.rate_review_outlined,
                        'Đã đánh giá',
                        '${user.reviewCount} lần',
                        Colors.amber.shade700,
                        isDark,
                      ),
                      _userDetailRow(
                        Icons.calendar_today_outlined,
                        'Tạo tài khoản',
                        '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                        Colors.teal,
                        isDark,
                      ),
                      _userDetailRow(
                        Icons.login_rounded,
                        'Lần cuối đăng nhập',
                        lastLogin,
                        const Color(0xFF238B57),
                        isDark,
                      ),
                      if (user.isBusiness) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Quán của doanh nghiệp (${user.businessRestaurants.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppTheme.pureWhite
                                : AppTheme.pitchBlack,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (user.businessRestaurants.isEmpty)
                          Text(
                            'Chưa có quán nào được tạo.',
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.textMutedDark
                                  : AppTheme.textMutedLight,
                            ),
                          )
                        else
                          ...user.businessRestaurants.map(
                            (restaurant) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.storefront_outlined,
                                color: roleColor,
                              ),
                              title: Text(restaurant),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openAddEditUserDialog(user);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Chỉnh sửa'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.fireCoral,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _userDetailRow(
    IconData icon,
    String label,
    String value,
    Color color,
    bool isDark,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppTheme.textMutedDark
                      : AppTheme.textMutedLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // Delete User Dialog
  Future<void> _deleteUser(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('XÁC NHẬN XÓA NGƯỜI DÙNG'),
        content: Text(
          'Bạn có chắc chắn muốn xóa tài khoản "${user.fullName}" (@${user.username})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.fireCoral,
            ),
            child: const Text('XÓA', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService.deleteUser(user.id);
      if (res['success'] == true) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Đã xóa người dùng thành công!'),
              backgroundColor: AppTheme.pitchBlack,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Không thể xóa người dùng này!'),
              backgroundColor: AppTheme.fireCoral,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
      body: SafeArea(
        child: Column(
          children: [
            _buildDashboardHeader(isDark),
            _buildDashboardTabs(isDark),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.fireCoral,
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(isDark),
                        _buildRestaurantsTab(isDark),
                        _buildApprovalTab(isDark),
                        _buildReviewsTab(isDark),
                        _buildCategoriesTab(isDark),
                        _buildUsersTab(isDark),
                        const ReviewReportsPanel(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  int get _pendingRestaurantCount => _restaurants
      .where((restaurant) => restaurant.approvalStatus == 'Pending')
      .length;

  Widget _buildDashboardHeader(bool isDark) => Container(
    decoration: BoxDecoration(
      color: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
      border: Border(
        bottom: BorderSide(
          color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
        ),
      ),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 650;
              final brand = Column(
                mainAxisSize: MainAxisSize.min,
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
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_pendingRestaurantCount > 0)
                    ActionChip(
                      avatar: const Icon(
                        Icons.fact_check_outlined,
                        size: 17,
                        color: AppTheme.fireCoral,
                      ),
                      label: Text('$_pendingRestaurantCount hồ sơ chờ duyệt'),
                      onPressed: () => _tabController.animateTo(2),
                      backgroundColor: AppTheme.fireCoral.withValues(
                        alpha: 0.1,
                      ),
                      side: BorderSide(
                        color: AppTheme.fireCoral.withValues(alpha: 0.25),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Về trang chủ',
                    onPressed: () => Navigator.of(
                      context,
                    ).popUntil((route) => route.isFirst),
                    icon: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: const BoxDecoration(
                        color: AppTheme.fireCoral,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.home_outlined,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: isDark ? 'Chế độ sáng' : 'Chế độ tối',
                    onPressed: widget.onToggleTheme,
                    icon: _headerActionIcon(
                      isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                      isDark,
                    ),
                  ),
                  if (ApiService.currentUser != null)
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
                          child: Text(
                            ApiService.currentUser!.fullName.isNotEmpty
                                ? ApiService.currentUser!.fullName[0]
                                      .toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              color: AppTheme.fireCoral,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [brand, const SizedBox(height: 12), actions],
                    )
                  : Row(
                      children: [
                        Expanded(child: brand),
                        const SizedBox(width: 16),
                        actions,
                      ],
                    );
            },
          ),
        ),
      ),
    ),
  );

  Widget _headerActionIcon(IconData icon, bool isDark) => Container(
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
  );

  // Mirrors the profile sheet used on Home so the account experience is
  // consistent wherever an administrator opens it.
  void _showUserProfileSheet(bool isDark) {
    final user = ApiService.currentUser;
    if (user == null) return;
    final pageMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
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
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.fireCoral.withValues(alpha: 0.14),
                  backgroundImage: user.avatarUrl.isNotEmpty
                      ? NetworkImage(user.avatarUrl)
                      : null,
                  child: user.avatarUrl.isEmpty
                      ? Text(
                          user.fullName.isNotEmpty
                              ? user.fullName[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                            color: AppTheme.fireCoral,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppTheme.pureWhite
                              : AppTheme.pitchBlack,
                        ),
                      ),
                      Text(
                        '@${user.username} · ${user.role}',
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
            const SizedBox(height: 20),
            Divider(
              color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
            ),
            const SizedBox(height: 8),
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
                ),
              ),
              title: const Text(
                'Đăng Xuất Tài Khoản',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.fireCoral,
                ),
              ),
              subtitle: const Text(
                'Thoát khỏi phiên làm việc hiện tại',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () async {
                await ApiService.logout();
                if (!mounted || !sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                Navigator.of(context).popUntil((route) => route.isFirst);
                pageMessenger.showSnackBar(
                  const SnackBar(content: Text('Đã đăng xuất thành công!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTabs(bool isDark) => Material(
    color: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
    child: TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      indicatorColor: AppTheme.fireCoral,
      indicatorWeight: 3,
      labelColor: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
      unselectedLabelColor: isDark
          ? AppTheme.textMutedDark
          : AppTheme.textMutedLight,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      tabs: const [
        Tab(icon: Icon(Icons.dashboard_outlined), text: 'Tổng quan'),
        Tab(icon: Icon(Icons.storefront_outlined), text: 'Nhà hàng'),
        Tab(icon: Icon(Icons.fact_check_outlined), text: 'Duyệt hồ sơ'),
        Tab(icon: Icon(Icons.rate_review_outlined), text: 'Đánh giá'),
        Tab(icon: Icon(Icons.category_outlined), text: 'Thể loại'),
        Tab(icon: Icon(Icons.people_outline_rounded), text: 'Người dùng'),
        Tab(icon: Icon(Icons.flag_outlined), text: 'Báo cáo'),
      ],
    ),
  );

  // 1. OVERVIEW TAB
  Widget _buildOverviewTab(bool isDark) {
    final latestReview = _reviews.isEmpty
        ? null
        : _reviews.reduce(
            (newest, review) =>
                review.createdAt.isAfter(newest.createdAt) ? review : newest,
          );
    final latestRestaurantMatches = latestReview == null
        ? <RestaurantModel>[]
        : _restaurants
              .where((restaurant) => restaurant.id == latestReview.restaurantId)
              .toList();
    final latestRestaurantName = latestRestaurantMatches.isNotEmpty
        ? latestRestaurantMatches.first.name
        : (_stats['latestReview']?['restaurantName']?.toString() ?? 'Quán ăn');
    final openRestaurantCount =
        _stats['openRestaurants'] ??
        _restaurants.where((restaurant) => restaurant.isOpen).length;
    final closedRestaurantCount =
        _stats['closedRestaurants'] ??
        _restaurants.where((restaurant) => !restaurant.isOpen).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
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
                final compact = constraints.maxWidth < 520;
                final copy = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOÀN CẢNH HỆ THỐNG',
                      style: TextStyle(
                        color: AppTheme.fireCoral,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _pendingRestaurantCount == 0
                          ? 'Mọi thứ đang được vận hành ổn định.'
                          : 'Có $_pendingRestaurantCount hồ sơ cần bạn xem xét.',
                      style: TextStyle(
                        fontSize: compact ? 21 : 25,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                        color: isDark
                            ? AppTheme.pureWhite
                            : AppTheme.pitchBlack,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Theo dõi quán ăn, cộng đồng và chất lượng nội dung từ một nơi.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppTheme.textMutedDark
                            : AppTheme.textMutedLight,
                      ),
                    ),
                  ],
                );
                final action = OutlinedButton.icon(
                  onPressed: _pendingRestaurantCount == 0
                      ? null
                      : () => _tabController.animateTo(2),
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Xem hồ sơ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.fireCoral,
                    side: BorderSide(
                      color: AppTheme.fireCoral.withValues(alpha: 0.5),
                    ),
                  ),
                );
                return compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [copy, const SizedBox(height: 16), action],
                      )
                    : Row(
                        children: [
                          Expanded(child: copy),
                          const SizedBox(width: 20),
                          action,
                        ],
                      );
              },
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth >= 1100
                  ? 4
                  : constraints.maxWidth >= 700
                  ? 3
                  : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _buildStatCard(
                    'Tổng Nhà Hàng',
                    '${_stats['totalRestaurants'] ?? 0}',
                    Icons.storefront,
                    AppTheme.fireCoral,
                    isDark,
                  ),
                  _buildStatCard(
                    'Đang mở',
                    '$openRestaurantCount',
                    Icons.storefront_rounded,
                    const Color(0xFF238B57),
                    isDark,
                  ),
                  _buildStatCard(
                    'Đang đóng',
                    '$closedRestaurantCount',
                    Icons.storefront_outlined,
                    Colors.blueGrey,
                    isDark,
                  ),
                  _buildStatCard(
                    'Tổng đánh giá',
                    '${_stats['totalReviews'] ?? _reviews.length}',
                    Icons.rate_review_outlined,
                    Colors.blueAccent,
                    isDark,
                  ),
                  _buildStatCard(
                    'Rating trung bình',
                    '${_stats['averageSystemRating'] ?? 0.0} ★',
                    Icons.star_rounded,
                    Colors.amber,
                    isDark,
                  ),
                  _buildStatCard(
                    'Tổng người dùng',
                    '${_stats['totalUsers'] ?? _users.length}',
                    Icons.people_outline_rounded,
                    Colors.teal,
                    isDark,
                  ),
                  _buildStatCard(
                    'Đang online',
                    '${_stats['onlineUsers'] ?? 0}',
                    Icons.circle,
                    const Color(0xFF238B57),
                    isDark,
                  ),
                  _buildStatCard(
                    'Nhà hàng được lưu',
                    '${_stats['totalBookmarks'] ?? 0}',
                    Icons.bookmark_outline_rounded,
                    Colors.purpleAccent,
                    isDark,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          if (latestReview != null) ...[
            _buildLatestReviewCard(
              review: latestReview,
              restaurantName: latestRestaurantName,
              isDark: isDark,
            ),
            const SizedBox(height: 28),
          ],
          Text(
            'NHÀ HÀNG MỚI CẬP NHẬT',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _restaurants.take(5).length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final r = _restaurants[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          (r.cardImageUrl ?? r.coverImageUrl).startsWith(
                            'data:image/',
                          )
                          ? Image.memory(
                              base64Decode(
                                (r.cardImageUrl ?? r.coverImageUrl)
                                    .split(',')
                                    .last,
                              ),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              ApiService.resolveImageUrl(
                                r.cardImageUrl ?? r.coverImageUrl,
                              ),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.store, size: 24),
                                  ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${r.cuisine} • ${r.priceRange}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        Text(
                          ' ${r.rating.toStringAsFixed(1)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.textMutedDark
                        : AppTheme.textMutedLight,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestReviewCard({
    required ReviewModel review,
    required String restaurantName,
    required bool isDark,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: AppTheme.fireCoral.withValues(alpha: isDark ? 0.35 : 0.2),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.fireCoral.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.rate_review_outlined,
            color: AppTheme.fireCoral,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BÌNH LUẬN MỚI NHẤT · $restaurantName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppTheme.fireCoral,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                review.comment.trim().isEmpty
                    ? '${review.userName} vừa để lại ${review.rating.toStringAsFixed(1)} sao.'
                    : '“${review.comment.trim()}”',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${review.userName} · ${review.rating.toStringAsFixed(1)} ★',
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
  );

  Widget _restaurantStatusChip({
    required String label,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: isDark ? 0.18 : 0.1),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: 0.28)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );

  // 2. RESTAURANTS TAB
  Widget _buildRestaurantsTab(bool isDark) {
    final query = _restaurantQuery.trim().toLowerCase();
    final visibleRestaurants = _restaurants.where((restaurant) {
      final categoryMatches =
          _restaurantCategoryFilter == 'Tất cả' ||
          restaurant.cuisine.toLowerCase() ==
              _restaurantCategoryFilter.toLowerCase();
      final searchMatches =
          query.isEmpty ||
          restaurant.name.toLowerCase().contains(query) ||
          restaurant.cuisine.toLowerCase().contains(query) ||
          restaurant.address.toLowerCase().contains(query);
      return categoryMatches && searchMatches;
    }).toList();
    final categoryNames =
        <String>{
              ..._categories.map((category) => category.name),
              ..._restaurants.map((restaurant) => restaurant.cuisine),
            }
            .where((name) => name.isNotEmpty && name.toLowerCase() != 'all')
            .toList()
          ..sort();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'DANH SÁCH NHÀ HÀNG (${visibleRestaurants.length})',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                    letterSpacing: 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openAddEditRestaurant(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('THÊM MỚI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.fireCoral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _restaurantStatusChip(
                label:
                    '${_restaurants.where((restaurant) => restaurant.isOpen).length} đang mở',
                color: const Color(0xFF238B57),
                icon: Icons.storefront_rounded,
                isDark: isDark,
              ),
              _restaurantStatusChip(
                label:
                    '${_restaurants.where((restaurant) => !restaurant.isOpen).length} đang đóng',
                color: Colors.blueGrey,
                icon: Icons.storefront_outlined,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _restaurantSearchController,
            onChanged: (value) => setState(() => _restaurantQuery = value),
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, thể loại hoặc địa chỉ',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _restaurantQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _restaurantSearchController.clear();
                        setState(() => _restaurantQuery = '');
                      },
                    ),
              filled: true,
              fillColor: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['Tất cả', ...categoryNames].map((categoryName) {
                final selected = categoryName == _restaurantCategoryFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(categoryName),
                    selected: selected,
                    selectedColor: AppTheme.fireCoral.withValues(alpha: 0.16),
                    labelStyle: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppTheme.fireCoral
                          : (isDark
                                ? AppTheme.textMutedDark
                                : AppTheme.textMutedLight),
                    ),
                    side: BorderSide(
                      color: selected
                          ? AppTheme.fireCoral.withValues(alpha: 0.5)
                          : (isDark
                                ? AppTheme.darkGrayBorder
                                : AppTheme.grayBorder),
                    ),
                    onSelected: (_) => setState(
                      () => _restaurantCategoryFilter = categoryName,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: visibleRestaurants.isEmpty
                ? Center(
                    child: Text(
                      'Không tìm thấy nhà hàng phù hợp.',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.textMutedDark
                            : AppTheme.textMutedLight,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: visibleRestaurants.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final r = visibleRestaurants[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child:
                                  (r.cardImageUrl ?? r.coverImageUrl)
                                      .startsWith('data:image/')
                                  ? Image.memory(
                                      base64Decode(
                                        (r.cardImageUrl ?? r.coverImageUrl)
                                            .split(',')
                                            .last,
                                      ),
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(
                                      ApiService.resolveImageUrl(
                                        r.cardImageUrl ?? r.coverImageUrl,
                                      ),
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                width: 60,
                                                height: 60,
                                                color: Colors.grey.shade300,
                                                child: const Icon(
                                                  Icons.store,
                                                  size: 28,
                                                ),
                                              ),
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  if (r.approvalStatus == 'Pending')
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(
                                          alpha: 0.16,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'CHỜ DUYỆT HỒ SƠ',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    '${r.cuisine} • ${r.priceRange}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    r.address,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Xem chi tiết',
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    color: AppTheme.fireCoral,
                                  ),
                                  onPressed: () => _showRestaurantDetails(r),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.blueAccent,
                                  ),
                                  onPressed: () => _openAddEditRestaurant(r),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppTheme.fireCoral,
                                  ),
                                  onPressed: () => _deleteRestaurant(r),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalTab(bool isDark) {
    final pendingRestaurants = _restaurants
        .where((restaurant) => restaurant.approvalStatus == 'Pending')
        .toList();
    if (pendingRestaurants.isEmpty) {
      return Center(
        child: Text(
          'Không có hồ sơ nhà hàng nào đang chờ duyệt.',
          style: TextStyle(
            color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: pendingRestaurants.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final restaurant = pendingRestaurants[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBg : AppTheme.pureWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      restaurant.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const Chip(
                    label: Text(
                      'CHỜ DUYỆT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: Color(0xFFFFE0B2),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                restaurant.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark
                      ? AppTheme.textMutedDark
                      : AppTheme.textMutedLight,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${restaurant.cuisine} • ${restaurant.priceRange}',
                style: const TextStyle(
                  color: AppTheme.fireCoral,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                restaurant.address,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppTheme.textMutedDark
                      : AppTheme.textMutedLight,
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final buttonWidth = constraints.maxWidth < 500
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 20) / 3;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: buttonWidth,
                        child: OutlinedButton.icon(
                      onPressed: () => _showRestaurantDetails(
                        restaurant,
                        showApprovalActions: true,
                      ),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Xem chi tiết'),
                    ),
                  ),
                      SizedBox(
                        width: buttonWidth,
                        child: OutlinedButton.icon(
                      onPressed: () => _reviewRestaurant(restaurant, false),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Từ chối'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                      SizedBox(
                        width: buttonWidth,
                        child: FilledButton.icon(
                      onPressed: () => _reviewRestaurant(restaurant, true),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Phê duyệt'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 4. REVIEWS TAB
  Widget _buildReviewsTab(bool isDark) {
    final visibleReviews = _reviews.where((review) {
      return switch (_reviewFilter) {
        'Tích cực' => review.rating >= 4,
        'Cần xem xét' => review.rating <= 2,
        _ => true,
      };
    }).toList();
    final averageRating = _reviews.isEmpty
        ? 0.0
        : _reviews.fold<double>(0, (sum, review) => sum + review.rating) /
              _reviews.length;
    final lowRatingCount = _reviews
        .where((review) => review.rating <= 2)
        .length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ĐÁNH GIÁ CỘNG ĐỒNG (${_reviews.length})',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Text(
                'TB ${averageRating.toStringAsFixed(1)} ★',
                style: const TextStyle(
                  color: AppTheme.fireCoral,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [
                  ('Tất cả', '${_reviews.length} lượt'),
                  (
                    'Tích cực',
                    '${_reviews.where((review) => review.rating >= 4).length} lượt',
                  ),
                  ('Cần xem xét', '$lowRatingCount lượt'),
                ].map((filter) {
                  final selected = _reviewFilter == filter.$1;
                  return ChoiceChip(
                    label: Text('${filter.$1} · ${filter.$2}'),
                    selected: selected,
                    selectedColor: AppTheme.fireCoral.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: selected
                          ? AppTheme.fireCoral
                          : (isDark
                                ? AppTheme.textMutedDark
                                : AppTheme.textMutedLight),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    onSelected: (_) =>
                        setState(() => _reviewFilter = filter.$1),
                  );
                }).toList(),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: visibleReviews.isEmpty
                ? Center(
                    child: Text(
                      'Không có đánh giá trong nhóm này.',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.textMutedDark
                            : AppTheme.textMutedLight,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: visibleReviews.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final rev = visibleReviews[index];
                      final restaurant = _restaurantForReview(rev);
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundImage: NetworkImage(
                                        rev.userAvatarUrl,
                                      ),
                                      backgroundColor: AppTheme.fireCoral
                                          .withValues(alpha: 0.2),
                                      child: Text(
                                        rev.userName.isNotEmpty
                                            ? rev.userName[0]
                                            : 'U',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.fireCoral,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        rev.userName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    Text(
                                      ' ${rev.rating.toStringAsFixed(1)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppTheme.fireCoral,
                                        size: 20,
                                      ),
                                      onPressed: () => _deleteReview(rev),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              rev.comment,
                              style: const TextStyle(fontSize: 13),
                            ),
                            if (rev.recommendedDish.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Món đề xuất: ${rev.recommendedDish}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.fireCoral,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    restaurant == null
                                        ? 'Quán: không còn tồn tại'
                                        : 'Quán: ${restaurant.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppTheme.textMutedDark
                                          : AppTheme.textMutedLight,
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: restaurant == null
                                      ? null
                                      : () => _showReviewedRestaurant(rev),
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 17,
                                  ),
                                  label: const Text('Chi tiết'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.fireCoral,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 4. CATEGORIES TAB
  Widget _buildCategoriesTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'DANH SÁCH THỂ LOẠI (${_categories.length})',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                  letterSpacing: 1.0,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openAddCategoryDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('THÊM THỂ LOẠI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.fireCoral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final restaurantCount = _restaurants
                    .where(
                      (restaurant) =>
                          restaurant.categoryId == cat.id ||
                          restaurant.cuisine.toLowerCase() ==
                              cat.name.toLowerCase(),
                    )
                    .length;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              _categoryIcon(cat.icon),
                              color: AppTheme.fireCoral,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cat.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.fireCoral.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '$restaurantCount quán',
                          style: const TextStyle(
                            color: AppTheme.fireCoral,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () => _deleteCategory(cat),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 5. USERS TAB (User Management Section)
  Widget _buildUsersTab(bool isDark) {
    final visibleUsers = _users.where((user) {
      return switch (_userFilter) {
        'Admin' => user.isAdmin,
        'Business' => user.isBusiness,
        'User' => !user.isAdmin && !user.isBusiness,
        _ => true,
      };
    }).toList();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'DANH SÁCH NGƯỜI DÙNG (${_users.length})',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                  letterSpacing: 1.0,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openAddEditUserDialog(),
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('THÊM NGƯỜI DÙNG'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.fireCoral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Tất cả', 'User', 'Admin', 'Business'].map((filter) {
              final selected = _userFilter == filter;
              final color = switch (filter) {
                'Admin' => const Color(0xFF8E44AD),
                'Business' => const Color(0xFF1976D2),
                _ => AppTheme.fireCoral,
              };
              final count = switch (filter) {
                'Admin' => _users.where((user) => user.isAdmin).length,
                'Business' => _users.where((user) => user.isBusiness).length,
                'User' =>
                  _users
                      .where((user) => !user.isAdmin && !user.isBusiness)
                      .length,
                _ => _users.length,
              };
              return ChoiceChip(
                label: Text('$filter · $count'),
                selected: selected,
                selectedColor: color.withValues(alpha: 0.16),
                labelStyle: TextStyle(
                  color: selected
                      ? color
                      : (isDark
                            ? AppTheme.textMutedDark
                            : AppTheme.textMutedLight),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                onSelected: (_) => setState(() => _userFilter = filter),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: visibleUsers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final u = visibleUsers[index];
                final isAdminRole = u.isAdmin;
                final isBusinessRole = u.isBusiness;
                final roleColor = isAdminRole
                    ? const Color(0xFF8E44AD)
                    : isBusinessRole
                    ? const Color(0xFF1976D2)
                    : AppTheme.fireCoral;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: roleColor,
                        backgroundImage: u.avatarUrl.isNotEmpty
                            ? NetworkImage(u.avatarUrl)
                            : null,
                        child: u.avatarUrl.isEmpty
                            ? Text(
                                u.fullName.isNotEmpty
                                    ? u.fullName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
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
                                    u.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: roleColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    u.role,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: roleColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${u.username}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.visibility_outlined,
                              color: AppTheme.fireCoral,
                            ),
                            tooltip: 'Xem chi tiết',
                            onPressed: () => _showUserDetails(u),
                          ),
                          IconButton(
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.blueAccent,
                            ),
                            tooltip: 'Chỉnh sửa',
                            onPressed: () => _openAddEditUserDialog(u),
                          ),
                          IconButton(
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.delete_outline,
                              color: u.isAdmin
                                  ? (isDark
                                        ? Colors.white24
                                        : Colors.grey.shade400)
                                  : AppTheme.fireCoral,
                            ),
                            tooltip: u.isAdmin
                                ? 'Không thể xóa tài khoản Admin'
                                : 'Xóa tài khoản',
                            onPressed: u.isAdmin
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Tài khoản Quản trị viên (Admin) không thể bị xóa!',
                                        ),
                                        backgroundColor: AppTheme.fireCoral,
                                      ),
                                    );
                                  }
                                : () => _deleteUser(u),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
