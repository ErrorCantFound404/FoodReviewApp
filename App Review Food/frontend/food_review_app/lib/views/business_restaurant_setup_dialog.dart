import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/category.dart';
import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class BusinessRestaurantSetupDialog extends StatefulWidget {
  const BusinessRestaurantSetupDialog({super.key});

  @override
  State<BusinessRestaurantSetupDialog> createState() => _BusinessRestaurantSetupDialogState();
}

class _BusinessRestaurantSetupDialogState extends State<BusinessRestaurantSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _cuisineController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _coverImageController = TextEditingController();
  final _latitudeController = TextEditingController(text: '21.028511');
  final _longitudeController = TextEditingController(text: '105.854198');
  String _priceRange = '50.000đ - 200.000đ';
  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _isLoadingCategories = false;
  List<CategoryModel> _categories = [];

  static const _priceRanges = ['< 50.000đ', '50.000đ - 200.000đ', '200.000đ - 500.000đ', '> 500.000đ'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    final categories = await ApiService.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories.where((category) => category.name.toLowerCase() != 'all').toList();
      _isLoadingCategories = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _cuisineController.dispose();
    _descriptionController.dispose();
    _coverImageController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  // ✅ Đã sửa: Upload file bytes trực tiếp lên API thay vì mã hóa thành chuỗi Base64
  Future<void> _pickCoverImage() async {
    try {
      setState(() => _isUploadingImage = true);
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final uploadedUrl = await ApiService.uploadReviewImage(bytes, file.name);

      if (!mounted) return;
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        setState(() {
          _coverImageController.text = uploadedUrl;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tải ảnh lên thất bại. Vui lòng thử lại!'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      debugPrint('Error picking cover image: $e');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final business = ApiService.currentUser;
    if (business == null) return;
    setState(() => _isSaving = true);

    final profileSaved = await ApiService.updateBusinessProfile(
      businessName: _nameController.text.trim(),
      businessAddress: _addressController.text.trim(),
      email: _emailController.text.trim(),
      businessType: _cuisineController.text.trim(),
    );
    if (!mounted) return;
    if (!profileSaved) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lưu hồ sơ doanh nghiệp. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final coverImage = _coverImageController.text.trim();
    final restaurant = RestaurantModel(
      id: 0,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      address: _addressController.text.trim(),
      cuisine: _cuisineController.text.trim(),
      priceRange: _priceRange,
      coverImageUrl: coverImage,
      imageUrls: coverImage.isEmpty ? const [] : [coverImage],
      rating: 5,
      reviewCount: 0,
      latitude: double.tryParse(_latitudeController.text.trim()) ?? 21.028511,
      longitude: double.tryParse(_longitudeController.text.trim()) ?? 105.854198,
      reviews: const [],
      menuItems: const [],
      ownerId: business.id,
    );

    final createdRestaurant = await ApiService.createBusinessRestaurant(restaurant);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (createdRestaurant != null) {
      Navigator.pop(context, createdRestaurant);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tạo quán. Vui lòng thử lại.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldColor = isDark ? AppTheme.pitchBlack : AppTheme.lightCardBg;
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12));

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkCardBg : AppTheme.pureWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Icon(Icons.storefront_rounded, color: AppTheme.fireCoral),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Tạo quán', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ]),
                const SizedBox(height: 8),
                Text('Nhập đầy đủ thông tin doanh nghiệp và quán đầu tiên. Hồ sơ sẽ được gửi đến Admin để duyệt.', style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight)),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Tên quán *', filled: true, fillColor: fieldColor, border: border),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập tên quán' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: 'Địa chỉ kinh doanh *', filled: true, fillColor: fieldColor, border: border),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập địa chỉ' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: 'Email liên hệ *', filled: true, fillColor: fieldColor, border: border),
                  validator: (value) => value == null || !value.trim().contains('@') ? 'Vui lòng nhập email hợp lệ' : null,
                ),
                const SizedBox(height: 14),
                _isLoadingCategories
                    ? const SizedBox(height: 52, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                    : DropdownButtonFormField<String>(
                        value: _cuisineController.text.isEmpty ? null : _cuisineController.text,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: 'Loại hình ẩm thực *', filled: true, fillColor: fieldColor, border: border),
                        hint: const Text('Chọn loại hình'),
                        items: _categories.map((category) => DropdownMenuItem(value: category.name, child: Text(category.name))).toList(),
                        onChanged: (value) => setState(() => _cuisineController.text = value ?? ''),
                        validator: (value) => value == null || value.isEmpty ? 'Vui lòng chọn loại hình ẩm thực' : null,
                      ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: 'Mô tả quán *', alignLabelWithHint: true, filled: true, fillColor: fieldColor, border: border),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập mô tả quán' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _priceRange,
                  decoration: InputDecoration(labelText: 'Khoảng giá trung bình *', filled: true, fillColor: fieldColor, border: border),
                  items: _priceRanges.map((price) => DropdownMenuItem(value: price, child: Text(price))).toList(),
                  onChanged: (value) => setState(() => _priceRange = value ?? _priceRange),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _coverImageController,
                  maxLines: 1,
                  decoration: InputDecoration(
                    labelText: 'Ảnh bìa quán *',
                    hintText: 'Dán URL hoặc chọn ảnh từ máy',
                    filled: true,
                    fillColor: fieldColor,
                    border: border,
                    suffixIcon: _isUploadingImage
                        ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.fireCoral)),
                    )
                        : IconButton(
                      onPressed: _pickCoverImage,
                      icon: const Icon(Icons.add_photo_alternate_outlined, color: AppTheme.fireCoral),
                    ),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng thêm ảnh bìa' : null,
                  // ✅ Đã xóa: onChanged: (_) => setState(() {}) để hạn chế rebuild liên tục
                ),
                // ✅ Preview ảnh tối ưu
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _coverImageController,
                  builder: (context, value, child) {
                    final text = value.text.trim();
                    if (text.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          ApiService.resolveImageUrl(text),
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                            height: 150,
                            child: Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: TextFormField(controller: _latitudeController, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: 'Vĩ độ *', filled: true, fillColor: fieldColor, border: border), validator: (value) => double.tryParse(value ?? '') == null ? 'Chưa hợp lệ' : null)),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _longitudeController, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: 'Kinh độ *', filled: true, fillColor: fieldColor, border: border), validator: (value) => double.tryParse(value ?? '') == null ? 'Chưa hợp lệ' : null)),
                ]),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.fireCoral, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                  icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_rounded),
                  label: Text(_isSaving ? 'Đang tạo...' : 'Tạo quán'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
