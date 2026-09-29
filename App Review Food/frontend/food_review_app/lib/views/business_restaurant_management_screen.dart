import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../models/menu_item.dart';
import '../models/restaurant.dart';
import '../models/review.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/review_report_button.dart';
import '../widgets/restaurant_reservations.dart';
import 'bookmarks_screen.dart';
import 'map_view_screen.dart';

class BusinessRestaurantManagementScreen extends StatefulWidget {
  final RestaurantModel restaurant;
  final VoidCallback? onToggleTheme;

  const BusinessRestaurantManagementScreen({
    super.key,
    required this.restaurant,
    this.onToggleTheme,
  });

  @override
  State<BusinessRestaurantManagementScreen> createState() =>
      _BusinessRestaurantManagementScreenState();
}

class _BusinessRestaurantManagementScreenState
    extends State<BusinessRestaurantManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reviewsScrollController = ScrollController();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _cuisineController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late String _priceRange;
  late List<String> _imageUrls;
  late List<MenuItemModel> _menuItems;
  bool _isSaving = false;
  bool _isUploadingImages = false;
  late bool _isOpen;

  static const _priceRanges = [
    '< 50.000đ',
    '50.000đ - 200.000đ',
    '200.000đ - 500.000đ',
    '> 500.000đ',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.restaurant.name);
    _addressController = TextEditingController(text: widget.restaurant.address);
    _cuisineController = TextEditingController(text: widget.restaurant.cuisine);
    _descriptionController = TextEditingController(text: widget.restaurant.description);
    _latitudeController = TextEditingController(text: widget.restaurant.latitude.toString());
    _longitudeController = TextEditingController(text: widget.restaurant.longitude.toString());
    _priceRange = _priceRanges.contains(widget.restaurant.priceRange)
        ? widget.restaurant.priceRange
        : _priceRanges[1];
    _imageUrls = List.of(widget.restaurant.imageUrls);
    if (_imageUrls.isEmpty && widget.restaurant.coverImageUrl.isNotEmpty) {
      _imageUrls.add(widget.restaurant.coverImageUrl);
    }
    _menuItems = List.of(widget.restaurant.menuItems);
    _isOpen = widget.restaurant.isOpen;
  }

  @override
  void dispose() {
    _reviewsScrollController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _cuisineController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final remaining = 5 - _imageUrls.length;
    if (remaining <= 0) {
      _showMessage('Quán chỉ được đăng tối đa 5 ảnh.');
      return;
    }

    try {
      setState(() => _isUploadingImages = true);
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (files.isEmpty) return;

      final selectedFiles = files.take(remaining).toList();
      final uploadedUrls = await Future.wait(selectedFiles.map((file) async {
        final bytes = await file.readAsBytes();
        return ApiService.uploadReviewImage(bytes, file.name);
      }));
      if (!mounted) return;

      final successfulUrls = uploadedUrls.whereType<String>().where((url) => url.isNotEmpty).toList();
      setState(() => _imageUrls.addAll(successfulUrls));
      if (successfulUrls.length != selectedFiles.length) {
        _showMessage('Một số ảnh chưa tải lên được. Bạn có thể thử lại.', isError: true);
      }
      if (files.length > selectedFiles.length) {
        _showMessage('Chỉ thêm ảnh trong giới hạn tối đa 5 ảnh.');
      }
    } catch (_) {
      if (mounted) _showMessage('Không thể tải ảnh lên. Vui lòng thử lại.', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingImages = false);
    }
  }

  Future<void> _editMenuItem({int? index}) async {
    final existing = index == null ? null : _menuItems[index];
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descriptionController = TextEditingController(text: existing?.description ?? '');
    final priceController = TextEditingController(
      text: existing?.price.toStringAsFixed(0) ?? '',
    );
    var isAvailable = existing?.isAvailable ?? true;

    final result = await showDialog<MenuItemModel>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(index == null ? 'Thêm món ăn' : 'Chỉnh sửa món ăn'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Tên món *'),
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Mô tả món'),
                    maxLines: 2,
                  ),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Giá (VND) *'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Đang phục vụ'),
                    value: isAvailable,
                    activeThumbColor: AppTheme.fireCoral,
                    onChanged: (value) => setDialogState(() => isAvailable = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.fireCoral),
              onPressed: () {
                final price = double.tryParse(priceController.text.trim());
                if (nameController.text.trim().isEmpty || price == null || price < 0) return;
                Navigator.pop(
                  context,
                  MenuItemModel(
                    id: existing?.id ?? 0,
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    price: price,
                    imageUrl: existing?.imageUrl ?? '',
                    isAvailable: isAvailable,
                  ),
                );
              },
              child: const Text('Lưu món'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _menuItems.add(result);
      } else {
        _menuItems[index] = result;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageUrls.isEmpty) {
      _showMessage('Vui lòng giữ lại ít nhất một ảnh bìa cho quán.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final updatedRestaurant = RestaurantModel(
      id: widget.restaurant.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      address: _addressController.text.trim(),
      categoryId: widget.restaurant.categoryId,
      cuisine: _cuisineController.text.trim(),
      priceRange: _priceRange,
      coverImageUrl: _imageUrls.first,
      imageUrls: _imageUrls,
      rating: widget.restaurant.rating,
      reviewCount: widget.restaurant.reviewCount,
      latitude: double.parse(_latitudeController.text.trim()),
      longitude: double.parse(_longitudeController.text.trim()),
      reviews: widget.restaurant.reviews,
      menuItems: _menuItems,
      approvalStatus: widget.restaurant.approvalStatus,
      submittedAt: widget.restaurant.submittedAt,
      ownerId: widget.restaurant.ownerId,
      createdAt: widget.restaurant.createdAt,
      isOpen: _isOpen,
    );
    final saved = await ApiService.updateRestaurant(updatedRestaurant);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (saved) {
      _showMessage('Đã lưu thay đổi cho quán.');
    } else {
      _showMessage('Không thể lưu thay đổi. Vui lòng thử lại.', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : AppTheme.fireCoral),
    );
  }

  Future<void> _reloadRestaurant() async {
    if (_isSaving || _isUploadingImages) return;
    setState(() => _isSaving = true);
    final refreshed = await ApiService.getRestaurantDetail(widget.restaurant.id);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (refreshed == null) {
      _showMessage('Không thể tải lại dữ liệu quán.', isError: true);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessRestaurantManagementScreen(
          restaurant: refreshed,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.pureWhite : AppTheme.pitchBlack;
    final mutedColor = isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
      body: SafeArea(
        child: Column(children: [
          _buildModernHeader(isDark),
          Expanded(child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildHeader(textColor, mutedColor, isDark),
                const SizedBox(height: 24),
                RestaurantReservations(restaurantId: widget.restaurant.id),
                const SizedBox(height: 24),
                _buildPerformanceSummary(textColor, mutedColor, isDark),
                const SizedBox(height: 24),
                _sectionTitle(Icons.map_outlined, 'Vị trí quán', textColor),
                const SizedBox(height: 12),
                _buildOpenStreetMap(isDark),
                const SizedBox(height: 24),
                _sectionTitle(Icons.edit_note_rounded, 'Thông tin quán', textColor),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isOpen,
                  activeThumbColor: Colors.green,
                  title: Text(_isOpen ? 'Đang mở cửa' : 'Tạm đóng cửa', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  subtitle: Text(_isOpen ? 'Quán được ưu tiên hiển thị và có thể được chọn ngẫu nhiên.' : 'Quán sẽ không được ưu tiên và không xuất hiện trong gợi ý ngẫu nhiên.', style: TextStyle(color: mutedColor, fontSize: 12)),
                  onChanged: (value) => setState(() => _isOpen = value),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Tên quán *', border: OutlineInputBorder()),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập tên quán.' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Địa chỉ *', border: OutlineInputBorder()),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập địa chỉ.' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _cuisineController,
                  decoration: const InputDecoration(labelText: 'Loại hình ẩm thực *', border: OutlineInputBorder()),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập loại hình ẩm thực.' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Mô tả quán *', border: OutlineInputBorder()),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập mô tả quán.' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _priceRange,
                  decoration: const InputDecoration(labelText: 'Khoảng giá trung bình', border: OutlineInputBorder()),
                  items: _priceRanges.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                  onChanged: (value) => value == null ? null : setState(() => _priceRange = value),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _coordinateField('Vĩ độ', _latitudeController)),
                    const SizedBox(width: 12),
                    Expanded(child: _coordinateField('Kinh độ', _longitudeController)),
                  ],
                ),
                const SizedBox(height: 26),
                _sectionTitle(Icons.photo_library_outlined, 'Ảnh quán (${_imageUrls.length}/5)', textColor),
                const SizedBox(height: 6),
                Text('Chạm vào ảnh để đặt làm ảnh bìa.', style: TextStyle(color: mutedColor, fontSize: 13)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ...List.generate(_imageUrls.length, (index) => _imageTile(_imageUrls[index], index == 0, isDark)),
                    if (_imageUrls.length < 5) _addPhotoTile(),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    _sectionTitle(Icons.restaurant_menu_rounded, 'Thực đơn (${_menuItems.length} món)', textColor),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.fireCoral),
                      onPressed: () => _editMenuItem(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Thêm món'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_menuItems.isEmpty)
                  _emptyMenuCard(mutedColor, isDark)
                else
                  ...List.generate(_menuItems.length, (index) => _menuTile(_menuItems[index], index, textColor, mutedColor)),
                const SizedBox(height: 28),
                _sectionTitle(Icons.rate_review_outlined, 'Bình luận từ khách hàng (${widget.restaurant.reviews.length})', textColor),
                const SizedBox(height: 12),
                if (widget.restaurant.reviews.isEmpty)
                  _emptyReviewsCard(mutedColor, isDark)
                else
                  Container(
                    height: (MediaQuery.sizeOf(context).height * 0.55).clamp(260.0, 520.0),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder),
                    ),
                    child: Scrollbar(
                      controller: _reviewsScrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: _reviewsScrollController,
                        primary: false,
                        padding: const EdgeInsets.all(12),
                        itemCount: widget.restaurant.reviews.length,
                        itemBuilder: (context, index) => _reviewCard(
                          widget.restaurant.reviews[index], textColor, mutedColor, isDark,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 30),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.fireCoral,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: (_isSaving || _isUploadingImages) ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(_isSaving ? 'Đang lưu...' : 'Lưu thay đổi'),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      )),
        ]),
      ),
      bottomNavigationBar: _buildBottomNavigation(isDark),
    );
  }

  Widget _buildModernHeader(bool isDark) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final user = ApiService.currentUser;
    final muted = isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight;
    final text = isDark ? AppTheme.pureWhite : AppTheme.pitchBlack;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.fireCoral, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Flexible(child: Text(
                    user?.fullName.isNotEmpty == true ? 'XIN CHÀO, ${user!.fullName.toUpperCase()}' : 'SAVOR & REVIEW',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: muted),
                  )),
                ]),
                const SizedBox(height: 3),
                Text('FoodieSpot', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -1, color: text)),
              ])),
              if (isWide) ...[
                TextButton(onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), child: Text('Khám phá', style: TextStyle(color: muted))),
                TextButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BookmarksScreen(onToggleTheme: widget.onToggleTheme))), child: Text('Đã lưu', style: TextStyle(color: muted))),
                TextButton(onPressed: null, child: Text('Quản lý quán ăn', style: TextStyle(color: AppTheme.fireCoral, fontWeight: FontWeight.w800))),
                const SizedBox(width: 8),
              ],
              IconButton(
                tooltip: 'Xem bản đồ',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapViewScreen(restaurants: [widget.restaurant]))),
                icon: Icon(Icons.map_outlined, color: muted),
              ),
              IconButton(
                tooltip: isDark ? 'Chế độ sáng' : 'Chế độ tối',
                onPressed: widget.onToggleTheme,
                icon: Icon(isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round, color: muted),
              ),
              GestureDetector(
                onTap: _showAccountSheet,
                child: Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.fireCoral, width: 1.5)),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.fireCoral.withValues(alpha: 0.14),
                    child: Text(user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'U', style: const TextStyle(color: AppTheme.fireCoral, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showAccountSheet() {
    final user = ApiService.currentUser;
    if (user == null) return;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(radius: 26, backgroundColor: AppTheme.fireCoral.withValues(alpha: 0.14), child: Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U', style: const TextStyle(color: AppTheme.fireCoral, fontWeight: FontWeight.w800))),
            const SizedBox(height: 10),
            Text(user.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text('Tài khoản doanh nghiệp', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.fireCoral),
              title: const Text('Đăng xuất', style: TextStyle(color: AppTheme.fireCoral, fontWeight: FontWeight.w700)),
              onTap: () async {
                await ApiService.logout();
                if (!mounted || !sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(bool isDark) => BottomNavigationBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (index == 1) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BookmarksScreen()));
          }
        },
        backgroundColor: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
        selectedItemColor: AppTheme.fireCoral,
        unselectedItemColor: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore_rounded), label: 'Khám phá'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_outline_rounded), activeIcon: Icon(Icons.bookmark_rounded), label: 'Đã lưu'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront_outlined), activeIcon: Icon(Icons.storefront_rounded), label: 'Quản lý quán ăn'),
        ],
      );

  Widget _buildHeader(Color textColor, Color mutedColor, bool isDark) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder),
        ),
        child: Row(
          children: [
            const CircleAvatar(radius: 26, backgroundColor: AppTheme.fireCoral, child: Icon(Icons.storefront_rounded, color: Colors.white)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_nameController.text, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 3),
                Text('ID #${widget.restaurant.id} • Tạo ${_formatReviewDate(widget.restaurant.createdAt)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mutedColor, fontSize: 12)),
              ]),
            ),
            IconButton(
              tooltip: 'Tải lại dữ liệu',
              onPressed: _isSaving ? null : _reloadRestaurant,
              icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
              child: const Text('Đã duyệt', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      );

  Widget _sectionTitle(IconData icon, String title, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, color: AppTheme.fireCoral, size: 21), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color))],
      );

  Widget _buildPerformanceSummary(Color textColor, Color mutedColor, bool isDark) {
    final totalStars = widget.restaurant.reviews.fold<double>(0, (sum, review) => sum + review.rating);
    final averageRating = widget.restaurant.reviews.isEmpty
        ? widget.restaurant.rating
        : totalStars / widget.restaurant.reviews.length;
    return Row(
      children: [
        Expanded(child: _summaryCard(Icons.star_rounded, '${averageRating.toStringAsFixed(1)} / 5', 'Điểm trung bình', Colors.amber.shade800, textColor, mutedColor, isDark)),
        const SizedBox(width: 10),
        Expanded(child: _summaryCard(Icons.auto_awesome_rounded, totalStars.toStringAsFixed(1), 'Tổng số sao', AppTheme.fireCoral, textColor, mutedColor, isDark)),
        const SizedBox(width: 10),
        Expanded(child: _summaryCard(Icons.bookmark_rounded, '${widget.restaurant.bookmarkCount}', 'Lượt lưu', Colors.indigo, textColor, mutedColor, isDark)),
      ],
    );
  }

  Widget _summaryCard(IconData icon, String value, String label, Color accent, Color textColor, Color mutedColor, bool isDark) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(height: 9),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: mutedColor), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );

  Widget _buildOpenStreetMap(bool isDark) {
    final location = LatLng(widget.restaurant.latitude, widget.restaurant.longitude);
    return Container(
      height: 250,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder),
      ),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: location,
          initialZoom: 15,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.food_review_app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: location,
                width: 46,
                height: 46,
                child: const Icon(Icons.location_on_rounded, size: 42, color: AppTheme.fireCoral),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coordinateField(String label, TextEditingController controller) => TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (value) => double.tryParse(value?.trim() ?? '') == null ? 'Không hợp lệ' : null,
      );

  Widget _addPhotoTile() => InkWell(
        onTap: _isUploadingImages ? null : _addPhotos,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(border: Border.all(color: AppTheme.fireCoral), borderRadius: BorderRadius.circular(14)),
          child: Center(
            child: _isUploadingImages
                ? const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.fireCoral)
                : const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.fireCoral, size: 30),
          ),
        ),
      );

  Widget _imageTile(String url, bool isCover, bool isDark) => Stack(
        children: [
          InkWell(
            onTap: () => setState(() {
              _imageUrls.remove(url);
              _imageUrls.insert(0, url);
            }),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 112,
              height: 112,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isCover ? AppTheme.fireCoral : (isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder), width: isCover ? 2 : 1),
              ),
              child: _restaurantImage(url),
            ),
          ),
          if (isCover)
            const Positioned(
              left: 5,
              bottom: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppTheme.fireCoral, borderRadius: BorderRadius.all(Radius.circular(5))),
                child: Padding(padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2), child: Text('Bìa', style: TextStyle(color: Colors.white, fontSize: 10))),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: () => setState(() => _imageUrls.remove(url)),
              borderRadius: BorderRadius.circular(16),
              child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close_rounded, size: 15, color: Colors.white)),
            ),
          ),
        ],
      );

  Widget _restaurantImage(String url) {
    if (url.startsWith('data:image/')) {
      try {
        return Image.memory(base64Decode(url.split(',').last), fit: BoxFit.cover, cacheWidth: 224, filterQuality: FilterQuality.low);
      } catch (_) {
        return const Icon(Icons.broken_image_rounded);
      }
    }
    return Image.network(
      ApiService.resolveImageUrl(url),
      fit: BoxFit.cover,
      cacheWidth: 224,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded),
    );
  }

  Widget _emptyMenuCard(Color mutedColor, bool isDark) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg, borderRadius: BorderRadius.circular(14)),
        child: Text('Chưa có món ăn. Hãy thêm món đầu tiên của quán.', style: TextStyle(color: mutedColor)),
      );

  Widget _emptyReviewsCard(Color mutedColor, bool isDark) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg, borderRadius: BorderRadius.circular(14)),
        child: Text('Quán chưa nhận được bình luận nào từ khách hàng.', style: TextStyle(color: mutedColor)),
      );

  Widget _reviewCard(ReviewModel review, Color textColor, Color mutedColor, bool isDark) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: AppTheme.fireCoral.withValues(alpha: 0.14),
              backgroundImage: review.userAvatarUrl.isNotEmpty ? NetworkImage(review.userAvatarUrl) : null,
              child: review.userAvatarUrl.isEmpty ? const Icon(Icons.person_rounded, color: AppTheme.fireCoral) : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(review.userName, style: TextStyle(fontWeight: FontWeight.bold, color: textColor))),
            ...List.generate(5, (index) => Icon(index < review.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber.shade800, size: 16)),
          ]),
          if (review.recommendedDish.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Món gợi ý: ${review.recommendedDish}', style: TextStyle(color: AppTheme.fireCoral, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(review.comment, style: TextStyle(color: mutedColor, height: 1.35)),
          ],
          if (review.imageUrls.isNotEmpty || review.imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (review.imageUrls.isNotEmpty ? review.imageUrls : [review.imageUrl])
                  .where((url) => url.trim().isNotEmpty).toSet().map((url) => Tooltip(
                    message: 'Xem ảnh đánh giá',
                    child: InkWell(
                      onTap: () => _showReviewPhoto(url),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(width: 96, height: 96, child: _restaurantImage(url)),
                      ),
                    ),
                  )).toList(),
            ),
          ],
          const SizedBox(height: 8),
          Text(_formatReviewDate(review.createdAt), style: TextStyle(fontSize: 11, color: mutedColor)),
          if (ApiService.currentUser?.id == widget.restaurant.ownerId)
            ReviewReportButton(key: ValueKey(review.id), reviewId: review.id),
        ]),
      );

  String _formatReviewDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  void _showReviewPhoto(String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 900,
          height: MediaQuery.sizeOf(dialogContext).height * 0.8,
          child: Column(children: [
            Align(alignment: Alignment.centerRight, child: IconButton(
              tooltip: 'Đóng ảnh', icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(dialogContext),
            )),
            Expanded(child: InteractiveViewer(
              minScale: 1, maxScale: 4,
              child: _reviewFullImage(url),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _reviewFullImage(String url) {
    Widget error(BuildContext context, Object error, StackTrace? stack) =>
        const Center(child: Text('Không thể tải ảnh.'));
    if (url.startsWith('data:image/')) {
      try {
        return Image.memory(base64Decode(url.split(',').last), fit: BoxFit.contain, errorBuilder: error);
      } catch (_) {
        return const Center(child: Text('Ảnh không hợp lệ.'));
      }
    }
    return Image.network(ApiService.resolveImageUrl(url), fit: BoxFit.contain, errorBuilder: error);
  }

  Widget _menuTile(MenuItemModel item, int index, Color textColor, Color mutedColor) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(item.isAvailable ? Icons.check_circle_rounded : Icons.pause_circle_outline_rounded, color: item.isAvailable ? Colors.green : mutedColor),
        title: Text(item.name, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
        subtitle: item.description.isEmpty ? null : Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${item.price.toStringAsFixed(0)}đ', style: const TextStyle(color: AppTheme.fireCoral, fontWeight: FontWeight.bold)),
            IconButton(onPressed: () => _editMenuItem(index: index), icon: const Icon(Icons.edit_outlined, size: 19)),
            IconButton(onPressed: () => setState(() => _menuItems.removeAt(index)), icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 19)),
          ],
        ),
      );
}
