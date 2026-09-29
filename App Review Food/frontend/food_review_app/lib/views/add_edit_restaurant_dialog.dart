import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/category.dart';
import '../models/menu_item.dart';
import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AddEditRestaurantDialog extends StatefulWidget {
  final RestaurantModel? restaurant;

  const AddEditRestaurantDialog({super.key, this.restaurant});

  @override
  State<AddEditRestaurantDialog> createState() =>
      _AddEditRestaurantDialogState();
}

class _AddEditRestaurantDialogState extends State<AddEditRestaurantDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _addressController;
  late TextEditingController _coverImageUrlController;
  late TextEditingController _latController;
  late TextEditingController _lngController;

  String _selectedCuisine = 'Vietnamese';
  String _selectedPriceRange = '50.000đ - 200.000đ';

  List<CategoryModel> _categories = [];
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;
  bool _isPickingImages = false;
  late bool _isOpen;
  List<String> _imageUrls = [];
  List<MenuItemModel> _menuItems = [];

  final List<String> _priceRangeOptions = const [
    '< 50.000đ',
    '50.000đ - 200.000đ',
    '200.000đ - 500.000đ',
    '> 500.000đ',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.restaurant;
    _nameController = TextEditingController(text: r?.name ?? '');
    _descriptionController = TextEditingController(text: r?.description ?? '');
    _addressController = TextEditingController(text: r?.address ?? '');
    _coverImageUrlController = TextEditingController(
      text: r?.coverImageUrl ?? '',
    );
    _imageUrls = List.of(r?.imageUrls ?? const []);
    _menuItems = List.of(r?.menuItems ?? const []);
    _isOpen = r?.isOpen ?? true;
    _latController = TextEditingController(
      text: (r?.latitude ?? 21.028511).toString(),
    );
    _lngController = TextEditingController(
      text: (r?.longitude ?? 105.854198).toString(),
    );

    if (r != null && r.cuisine.isNotEmpty) {
      _selectedCuisine = r.cuisine;
    }
    if (r != null && r.priceRange.isNotEmpty) {
      _selectedPriceRange = r.priceRange;
    }

    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await ApiService.getCategories();
    final validCats = cats.where((c) => c.name.toLowerCase() != 'all').toList();

    if (mounted) {
      setState(() {
        _categories = validCats;
        if (_categories.isNotEmpty) {
          final exists = _categories.any(
            (c) => c.name.toLowerCase() == _selectedCuisine.toLowerCase(),
          );
          if (!exists) {
            _selectedCuisine = _categories.first.name;
          }
        }
        _isLoadingCategories = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _coverImageUrlController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  bool _isValidUrl(String value) {
    if (value.trim().isEmpty) return false;
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  List<String> get _selectedImageUrls {
    final uniqueUrls = <String>{};
    final coverImage = _coverImageUrlController.text.trim();
    if (coverImage.isNotEmpty) uniqueUrls.add(coverImage);
    for (final imageUrl in _imageUrls) {
      final trimmed = imageUrl.trim();
      if (trimmed.isNotEmpty) uniqueUrls.add(trimmed);
    }
    return uniqueUrls.toList();
  }

  // ✅ Đã sửa: Upload ảnh trực tiếp lên Server thay vì chuyển thành Base64 nặng
  Future<void> _pickImage() async {
    final currentCount = _selectedImageUrls.length;
    final remaining = 5 - currentCount;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mỗi quán chỉ được đăng tối đa 5 ảnh.')),
      );
      return;
    }

    try {
      setState(() => _isPickingImages = true);
      final ImagePicker picker = ImagePicker();
      final files = await picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (files.isNotEmpty) {
        final acceptedFiles = files.take(remaining).toList();
        final List<String> uploadedUrls = [];

        for (final file in acceptedFiles) {
          final bytes = await file.readAsBytes();
          final uploadedUrl = await ApiService.uploadReviewImage(
            bytes,
            file.name,
          );
          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            uploadedUrls.add(uploadedUrl);
          }
        }

        if (!mounted) return;
        setState(() {
          if (_coverImageUrlController.text.isEmpty &&
              uploadedUrls.isNotEmpty) {
            _coverImageUrlController.text = uploadedUrls.first;
          }
          _imageUrls.addAll(uploadedUrls);
        });

        if (files.length > acceptedFiles.length && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chỉ 5 ảnh đầu tiên được thêm vào quán.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Có lỗi xảy ra khi tải ảnh lên. Vui lòng thử lại!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImages = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final isEdit = widget.restaurant != null;
    final selectedCat = _categories.cast<CategoryModel?>().firstWhere(
      (c) => c?.name.toLowerCase() == _selectedCuisine.toLowerCase(),
      orElse: () => null,
    );
    final imageUrls = _selectedImageUrls;
    final coverImageUrl = _coverImageUrlController.text.trim().isNotEmpty
        ? _coverImageUrlController.text.trim()
        : (imageUrls.isNotEmpty ? imageUrls.first : '');

    final model = RestaurantModel(
      id: widget.restaurant?.id ?? 0,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      address: _addressController.text.trim(),
      categoryId: selectedCat?.id ?? widget.restaurant?.categoryId,
      cuisine: _selectedCuisine,
      priceRange: _selectedPriceRange,
      coverImageUrl: coverImageUrl,
      cardImageUrl: widget.restaurant?.cardImageUrl,
      imageUrls: imageUrls,
      rating: widget.restaurant?.rating ?? 5.0,
      reviewCount: widget.restaurant?.reviewCount ?? 0,
      bookmarkCount: widget.restaurant?.bookmarkCount ?? 0,
      createdAt: widget.restaurant?.createdAt,
      latitude: double.tryParse(_latController.text.trim()) ?? 21.028511,
      longitude: double.tryParse(_lngController.text.trim()) ?? 105.854198,
      reviews: widget.restaurant?.reviews ?? [],
      menuItems: _menuItems,
      approvalStatus: widget.restaurant?.approvalStatus ?? 'Draft',
      submittedAt: widget.restaurant?.submittedAt,
      ownerId: widget.restaurant?.ownerId,
      isOpen: _isOpen,
    );

    bool success;
    if (isEdit) {
      success = await ApiService.updateRestaurant(model);
    } else {
      success = await ApiService.createRestaurant(model);
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? 'Cập nhật nhà hàng thành công!'
                  : 'Thêm nhà hàng mới thành công!',
            ),
            backgroundColor: AppTheme.fireCoral,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Có lỗi xảy ra, vui lòng thử lại!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.restaurant != null;

    return Dialog(
      backgroundColor: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'CHỈNH SỬA NHÀ HÀNG' : 'THÊM NHÀ HÀNG MỚI',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDark
                            ? AppTheme.pureWhite
                            : AppTheme.pitchBlack,
                        letterSpacing: 1.0,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Tên Nhà Hàng / Quán Ăn *',
                  _nameController,
                  isDark,
                  required: true,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  'Mô Tả *',
                  _descriptionController,
                  isDark,
                  maxLines: 3,
                  required: true,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  'Địa Chỉ Chi Tiết *',
                  _addressController,
                  isDark,
                  required: true,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cuisine Dropdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ẩm Thực / Thể Loại *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.black.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _isLoadingCategories
                              ? const SizedBox(
                                  height: 48,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : DropdownButtonFormField<String>(
                                  initialValue:
                                      _categories.any(
                                        (c) =>
                                            c.name.toLowerCase() ==
                                            _selectedCuisine.toLowerCase(),
                                      )
                                      ? _categories
                                            .firstWhere(
                                              (c) =>
                                                  c.name.toLowerCase() ==
                                                  _selectedCuisine
                                                      .toLowerCase(),
                                            )
                                            .name
                                      : (_categories.isNotEmpty
                                            ? _categories.first.name
                                            : _selectedCuisine),
                                  style: TextStyle(
                                    color: isDark
                                        ? AppTheme.pureWhite
                                        : AppTheme.pitchBlack,
                                    fontSize: 14,
                                  ),
                                  dropdownColor: isDark
                                      ? AppTheme.pitchBlack
                                      : AppTheme.pureWhite,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: true,
                                    fillColor: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.03),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.black12,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AppTheme.fireCoral,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  items: _categories
                                      .map(
                                        (cat) => DropdownMenuItem(
                                          value: cat.name,
                                          child: Text(cat.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedCuisine = val);
                                    }
                                  },
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // PriceRange Dropdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Khoảng Giá (VND) *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.black.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue:
                                _priceRangeOptions.contains(_selectedPriceRange)
                                ? _selectedPriceRange
                                : _priceRangeOptions[1],
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.pureWhite
                                  : AppTheme.pitchBlack,
                              fontSize: 14,
                            ),
                            dropdownColor: isDark
                                ? AppTheme.pitchBlack
                                : AppTheme.pureWhite,
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.black12,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.fireCoral,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            items: _priceRangeOptions
                                .map(
                                  (opt) => DropdownMenuItem(
                                    value: opt,
                                    child: Text(opt),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedPriceRange = val);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isOpen,
                  activeThumbColor: AppTheme.fireCoral,
                  onChanged: (value) => setState(() => _isOpen = value),
                  title: Text(
                    _isOpen ? 'Quán đang mở cửa' : 'Quán đang đóng cửa',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                    ),
                  ),
                  subtitle: Text(
                    _isOpen
                        ? 'Quán có thể xuất hiện trong gợi ý và nhận đặt bàn.'
                        : 'Quán sẽ được làm mờ và không có trong gợi ý ngẫu nhiên.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.textMutedDark
                          : AppTheme.textMutedLight,
                    ),
                  ),
                ),
                if (isEdit) _buildSystemInformation(isDark),
                const SizedBox(height: 12),
                _buildMenuSection(isDark),
                const SizedBox(height: 12),
                // CoverImageUrl Input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'URL Ảnh Bìa Hoặc Chọn File Ảnh *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white70
                                : Colors.black.withValues(alpha: 0.8),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isPickingImages ? null : _pickImage,
                          icon: _isPickingImages
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 16,
                                ),
                          label: Text(
                            _isPickingImages
                                ? 'ĐANG TẢI...'
                                : 'CHỌN ẢNH TỪ MÁY',
                            style: const TextStyle(fontSize: 11),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.fireCoral,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _coverImageUrlController,
                      maxLines: 1,
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.pureWhite
                            : AppTheme.pitchBlack,
                        fontSize: 13,
                      ),
                      // ✅ Đã xóa onChanged: (_) => setState(() {}) để ngăn đơ/giật lag khi gõ
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng chọn file ảnh hoặc nhập URL ảnh bìa';
                        }
                        final trimmed = val.trim();
                        if (trimmed.startsWith('/api/') ||
                            _isValidUrl(trimmed)) {
                          return null;
                        }
                        return 'URL không hợp lệ! Phải bắt đầu bằng http://, https:// hoặc chọn ảnh từ máy';
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        hintText:
                            'http://... hoặc chọn file ảnh ở nút bên trên',
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppTheme.fireCoral,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    _buildImageGallery(isDark),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Vĩ Độ (Latitude)',
                        _latController,
                        isDark,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        'Kinh Độ (Longitude)',
                        _lngController,
                        isDark,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.fireCoral,
                      foregroundColor: AppTheme.pureWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isEdit ? 'CẬP NHẬT NHÀ HÀNG' : 'THÊM NHÀ HÀNG',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 1.0,
                            ),
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

  Widget _buildMenuSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.restaurant_menu_rounded,
                color: AppTheme.fireCoral,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                'Danh sách món ăn (${_menuItems.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showMenuItemDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Thêm món'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.fireCoral,
                ),
              ),
            ],
          ),
          if (_menuItems.isEmpty)
            Text(
              'Chưa có món nào. Bạn có thể thêm món sau.',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppTheme.textMutedDark
                    : AppTheme.textMutedLight,
              ),
            )
          else
            ...List.generate(_menuItems.length, (index) {
              final item = _menuItems[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.isAvailable
                      ? Icons.check_circle_rounded
                      : Icons.remove_circle_outline_rounded,
                  color: item.isAvailable ? Colors.green : Colors.grey,
                  size: 20,
                ),
                title: Text(
                  item.name,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: item.description.isEmpty
                    ? null
                    : Text(
                        item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${item.price.toStringAsFixed(0)}đ',
                      style: const TextStyle(
                        color: AppTheme.fireCoral,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _showMenuItemDialog(index: index),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.red,
                      ),
                      onPressed: () =>
                          setState(() => _menuItems.removeAt(index)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSystemInformation(bool isDark) {
    final restaurant = widget.restaurant!;
    final muted = isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _systemValue('ID quán', '${restaurant.id}', muted),
          _systemValue('Hồ sơ', restaurant.approvalStatus, muted),
          _systemValue(
            'Chủ sở hữu',
            restaurant.ownerId?.toString() ?? 'Chưa gán',
            muted,
          ),
          _systemValue(
            'Tạo lúc',
            '${restaurant.createdAt.day}/${restaurant.createdAt.month}/${restaurant.createdAt.year}',
            muted,
          ),
          _systemValue(
            'Đánh giá',
            '${restaurant.rating.toStringAsFixed(1)} (${restaurant.reviewCount})',
            muted,
          ),
          _systemValue('Bookmarks', '${restaurant.bookmarkCount}', muted),
          if (restaurant.submittedAt != null)
            _systemValue(
              'Gửi hồ sơ',
              '${restaurant.submittedAt!.day}/${restaurant.submittedAt!.month}/${restaurant.submittedAt!.year}',
              muted,
            ),
        ],
      ),
    );
  }

  Widget _systemValue(String label, String value, Color muted) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: muted,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ],
  );

  Future<void> _showMenuItemDialog({int? index}) async {
    final existing = index == null ? null : _menuItems[index];
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    final priceController = TextEditingController(
      text: existing?.price.toStringAsFixed(0) ?? '',
    );
    final imageController = TextEditingController(
      text: existing?.imageUrl ?? '',
    );
    var isAvailable = existing?.isAvailable ?? true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final item = await showDialog<MenuItemModel>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCardBg : AppTheme.pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                    decoration: const InputDecoration(labelText: 'Mô tả'),
                  ),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Giá (VND) *'),
                  ),
                  TextField(
                    controller: imageController,
                    decoration: const InputDecoration(labelText: 'URL ảnh món'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isAvailable,
                    onChanged: (value) =>
                        setDialogState(() => isAvailable = value),
                    title: const Text('Đang phục vụ'),
                    activeThumbColor: AppTheme.fireCoral,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.fireCoral,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    double.tryParse(priceController.text.trim()) == null) {
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  MenuItemModel(
                    id: existing?.id ?? 0,
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    price: double.parse(priceController.text.trim()),
                    imageUrl: imageController.text.trim(),
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
    imageController.dispose();
    if (item == null || !mounted) return;
    setState(() {
      if (index == null) {
        _menuItems.add(item);
      } else {
        _menuItems[index] = item;
      }
    });
  }

  Widget _buildImageGallery(bool isDark) {
    final imageUrls = _selectedImageUrls;

    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Ảnh đã chọn (${imageUrls.length}/5)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.textMutedDark
                      : AppTheme.textMutedLight,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.photo_library_outlined,
                size: 17,
                color: AppTheme.fireCoral,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: imageUrls
                .map((url) => _buildGalleryTile(url, isDark))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryTile(String url, bool isDark) {
    final isCover = url == _coverImageUrlController.text.trim();
    Widget image = Image.network(
      ApiService.resolveImageUrl(url),
      fit: BoxFit.cover,
      cacheWidth: 184,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.broken_image_rounded, color: Colors.grey),
    );

    return Stack(
      children: [
        Semantics(
          button: true,
          label: isCover ? 'Ảnh bìa' : 'Chọn làm ảnh bìa',
          child: InkWell(
            onTap: () => setState(() => _coverImageUrlController.text = url),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCover
                      ? AppTheme.fireCoral
                      : (isDark ? Colors.white24 : Colors.black12),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: image,
            ),
          ),
        ),
        if (isCover)
          const Positioned(
            left: 4,
            bottom: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.fireCoral,
                borderRadius: BorderRadius.all(Radius.circular(5)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                child: Text(
                  'Bìa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: 3,
          right: 3,
          child: InkWell(
            onTap: () => setState(() {
              _imageUrls.remove(url);
              if (_coverImageUrlController.text.trim() == url) {
                _coverImageUrlController.text = _imageUrls.firstWhere(
                  (imageUrl) => imageUrl != url,
                  orElse: () => '',
                );
              }
            }),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    bool isDark, {
    bool required = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? customValidator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white70
                : Colors.black.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(
            color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
            fontSize: 14,
          ),
          validator:
              customValidator ??
              (required
                  ? (val) => (val == null || val.trim().isEmpty)
                        ? 'Trường này không được để trống'
                        : null
                  : null),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? Colors.white24 : Colors.black12,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppTheme.fireCoral,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
