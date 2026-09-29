import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/menu_item.dart';
import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'business_profile_submission_screen.dart';

class BusinessRestaurantContentScreen extends StatefulWidget {
  final RestaurantModel restaurant;
  const BusinessRestaurantContentScreen({super.key, required this.restaurant});

  @override
  State<BusinessRestaurantContentScreen> createState() => _BusinessRestaurantContentScreenState();
}

class _BusinessRestaurantContentScreenState extends State<BusinessRestaurantContentScreen> {
  late List<String> _imageUrls;
  late List<MenuItemModel> _menuItems;
  bool _isSaving = false;
  bool _isUploadingImages = false;

  @override
  void initState() {
    super.initState();
    _imageUrls = List.of(widget.restaurant.imageUrls);
    _menuItems = List.of(widget.restaurant.menuItems);
  }

  // ✅ Đã sửa: Upload file bytes trực tiếp lên API để nhận URL thay vì tạo chuỗi Base64
  Future<void> _addPhotos() async {
    final remaining = 5 - _imageUrls.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quán chỉ được đăng tối đa 5 ảnh.')));
      return;
    }

    try {
      setState(() => _isUploadingImages = true);
      final files = await ImagePicker().pickMultiImage(maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
      if (files.isEmpty) return;

      final selected = files.take(remaining).toList();
      final List<String> uploadedUrls = [];

      for (final file in selected) {
        final bytes = await file.readAsBytes();
        final url = await ApiService.uploadReviewImage(bytes, file.name);
        if (url != null && url.isNotEmpty) {
          uploadedUrls.add(url);
        }
      }

      if (!mounted) return;
      setState(() => _imageUrls.addAll(uploadedUrls));

      if (selected.length < files.length) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chỉ thêm ảnh trong giới hạn tối đa 5 ảnh.')));
      }
    } catch (e) {
      debugPrint('Error uploading photos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể tải ảnh lên. Vui lòng thử lại!'), backgroundColor: Colors.orange));
      }
    } finally {
      if (mounted) setState(() => _isUploadingImages = false);
    }
  }

  Future<void> _editMenuItem({int? index}) async {
    final old = index == null ? null : _menuItems[index];
    final name = TextEditingController(text: old?.name ?? '');
    final price = TextEditingController(text: old?.price.toStringAsFixed(0) ?? '');
    final description = TextEditingController(text: old?.description ?? '');
    final item = await showDialog<MenuItemModel>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(index == null ? 'Thêm món ăn' : 'Chỉnh sửa món'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên món *')),
          TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá (VND) *')),
          TextField(controller: description, decoration: const InputDecoration(labelText: 'Mô tả món')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.fireCoral),
            onPressed: () {
              final parsedPrice = double.tryParse(price.text.trim());
              if (name.text.trim().isEmpty || parsedPrice == null) return;
              Navigator.pop(context, MenuItemModel(id: old?.id ?? 0, name: name.text.trim(), description: description.text.trim(), price: parsedPrice, imageUrl: old?.imageUrl ?? '', isAvailable: old?.isAvailable ?? true));
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    name.dispose();
    price.dispose();
    description.dispose();
    if (item == null || !mounted) return;
    setState(() {
      if (index == null) {
        _menuItems.add(item);
      } else {
        _menuItems[index] = item;
      }
    });
  }

  Future<void> _saveAndFinish() async {
    setState(() => _isSaving = true);
    final updated = RestaurantModel(
      id: widget.restaurant.id,
      name: widget.restaurant.name,
      description: widget.restaurant.description,
      address: widget.restaurant.address,
      categoryId: widget.restaurant.categoryId,
      cuisine: widget.restaurant.cuisine,
      priceRange: widget.restaurant.priceRange,
      coverImageUrl: _imageUrls.isEmpty ? widget.restaurant.coverImageUrl : _imageUrls.first,
      imageUrls: _imageUrls,
      rating: widget.restaurant.rating,
      reviewCount: widget.restaurant.reviewCount,
      latitude: widget.restaurant.latitude,
      longitude: widget.restaurant.longitude,
      reviews: widget.restaurant.reviews,
      menuItems: _menuItems,
      approvalStatus: widget.restaurant.approvalStatus,
      ownerId: widget.restaurant.ownerId,
    );
    final saved = await ApiService.updateRestaurant(updated);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (saved) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BusinessProfileSubmissionScreen(restaurant: updated)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể lưu thông tin quán.'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
      appBar: AppBar(title: const Text('Bước 2: Menu & hình ảnh'), backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text('Hoàn thiện quán của bạn', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 6),
            Text('Thêm thực đơn và tối đa 5 ảnh không gian hoặc món ăn.', style: TextStyle(color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight)),
            const SizedBox(height: 24),
            Row(children: [
              Text('Ảnh không gian quán (${_imageUrls.length}/5)', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              const Spacer(),
              TextButton.icon(
                onPressed: _isUploadingImages ? null : _addPhotos,
                icon: _isUploadingImages
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.fireCoral))
                    : const Icon(Icons.add_a_photo_outlined),
                label: Text(_isUploadingImages ? 'Đang tải...' : 'Thêm ảnh'),
              ),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              ...List.generate(_imageUrls.length, (index) => _imageTile(_imageUrls[index], index == 0)),
              if (_imageUrls.length < 5)
                InkWell(
                  onTap: _isUploadingImages ? null : _addPhotos,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(border: Border.all(color: AppTheme.fireCoral), borderRadius: BorderRadius.circular(12)),
                    child: _isUploadingImages
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.fireCoral))
                        : const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.fireCoral),
                  ),
                ),
            ]),
            const SizedBox(height: 26),
            Row(children: [
              Text('Thực đơn (${_menuItems.length} món)', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              const Spacer(),
              FilledButton.icon(onPressed: () => _editMenuItem(), icon: const Icon(Icons.add_rounded), label: const Text('Thêm món'), style: FilledButton.styleFrom(backgroundColor: AppTheme.fireCoral)),
            ]),
            const SizedBox(height: 10),
            if (_menuItems.isEmpty)
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg, borderRadius: BorderRadius.circular(14)), child: const Text('Chưa có món nào. Hãy thêm món đầu tiên của bạn.'))
            else
              ...List.generate(_menuItems.length, (index) {
                final item = _menuItems[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                  subtitle: item.description.isEmpty ? null : Text(item.description),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${item.price.toStringAsFixed(0)}đ', style: const TextStyle(color: AppTheme.fireCoral, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => _editMenuItem(index: index), icon: const Icon(Icons.edit_outlined, size: 18)),
                    IconButton(onPressed: () => setState(() => _menuItems.removeAt(index)), icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red)),
                  ]),
                );
              }),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: (_isSaving || _isUploadingImages) ? null : _saveAndFinish,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: Text(_isSaving ? 'Đang lưu...' : 'Hoàn tất'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.fireCoral, padding: const EdgeInsets.symmetric(vertical: 15)),
            ),
          ]),
        ),
      ),
    );
  }

  // ✅ Đã sửa: Xử lý resolve URL an toàn và mượt mà hơn
  Widget _imageTile(String url, bool isCover) => Stack(children: [
    ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 100,
        height: 100,
        child: Image.network(
          ApiService.resolveImageUrl(url),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)),
        ),
      ),
    ),
    if (isCover)
      const Positioned(
        left: 4,
        bottom: 4,
        child: DecoratedBox(
          decoration: BoxDecoration(color: AppTheme.fireCoral, borderRadius: BorderRadius.all(Radius.circular(4))),
          child: Padding(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: Text('Bìa', style: TextStyle(fontSize: 9, color: Colors.white))),
        ),
      ),
    Positioned(
      top: 4,
      right: 4,
      child: InkWell(
        onTap: () => setState(() => _imageUrls.remove(url)),
        child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close_rounded, size: 14, color: Colors.white)),
      ),
    ),
  ]);
}