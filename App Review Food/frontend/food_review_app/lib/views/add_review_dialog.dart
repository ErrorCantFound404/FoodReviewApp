import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/review.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/star_rating.dart';
import 'login_dialog.dart';

class AddReviewDialog extends StatefulWidget {
  final int restaurantId;
  final String restaurantName;
  final VoidCallback onReviewAdded;
  // If provided → edit mode
  final ReviewModel? existingReview;

  const AddReviewDialog({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.onReviewAdded,
    this.existingReview,
  });

  @override
  State<AddReviewDialog> createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends State<AddReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  final _dishController = TextEditingController();
  final _commentController = TextEditingController();

  double _rating = 5.0;
  bool _isSubmitting = false;

  // Image state
  final List<XFile> _pickedImages = [];
  final List<Uint8List> _pickedBytes = [];
  List<String> _existingImageUrls = [];
  bool _isUploadingImage = false;

  bool get _isEditMode => widget.existingReview != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final rev = widget.existingReview!;
      _rating = rev.rating;
      _dishController.text = rev.recommendedDish;
      _commentController.text = rev.comment;
      _existingImageUrls = List.of(rev.imageUrls);
    }
  }

  @override
  void dispose() {
    _dishController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    const maxImages = 5;
    final remaining = maxImages - _existingImageUrls.length - _pickedImages.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mỗi đánh giá chỉ được đăng tối đa 5 ảnh.')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = source == ImageSource.gallery
        ? await picker.pickMultiImage(maxWidth: 800, maxHeight: 800, imageQuality: 70)
        : [
            ?await picker.pickImage(
              source: source,
              maxWidth: 800,
              maxHeight: 800,
              imageQuality: 70,
            ),
          ];
    if (picked.isNotEmpty) {
      final acceptedImages = picked.take(remaining).toList();
      final bytes = await Future.wait(acceptedImages.map((image) => image.readAsBytes()));
      setState(() {
        _pickedImages.addAll(acceptedImages);
        _pickedBytes.addAll(bytes);
      });
      if (picked.length > acceptedImages.length && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chỉ 5 ảnh đầu tiên được thêm vào đánh giá.')),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBg : AppTheme.pureWhite,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Thêm ảnh',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.fireCoral.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.fireCoral),
                ),
                title: Text('Chụp ảnh',
                  style: TextStyle(color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.fireCoral.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.fireCoral),
                ),
                title: Text('Chọn từ thư viện',
                  style: TextStyle(color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_pickedImages.isNotEmpty || _existingImageUrls.isNotEmpty)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  ),
                  title: const Text('Xóa ảnh', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _pickedImages.clear();
                      _pickedBytes.clear();
                      _existingImageUrls = [];
                    });
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitReview() async {
    if (!ApiService.isLoggedIn) {
      _showLoginRequired();
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Upload image first if a new image was picked
    final imageUrls = List<String>.of(_existingImageUrls);
    if (_pickedImages.isNotEmpty) {
      setState(() => _isUploadingImage = true);
      final uploadedImages = await Future.wait(
        List.generate(
          _pickedImages.length,
          (index) => ApiService.uploadReviewImage(_pickedBytes[index], _pickedImages[index].name),
        ),
      );
      setState(() => _isUploadingImage = false);
      imageUrls.addAll(uploadedImages.whereType<String>());
    }

    Map<String, dynamic> result;
    if (_isEditMode) {
      result = await ApiService.updateReview(
        reviewId: widget.existingReview!.id,
        rating: _rating,
        comment: _commentController.text.trim(),
        recommendedDish: _dishController.text.trim(),
        imageUrl: imageUrls.isEmpty ? '' : imageUrls.first,
        imageUrls: imageUrls,
      );
    } else {
      result = await ApiService.addReview(
        restaurantId: widget.restaurantId,
        rating: _rating,
        comment: _commentController.text.trim(),
        recommendedDish: _dishController.text.trim(),
        imageUrl: imageUrls.isEmpty ? '' : imageUrls.first,
        imageUrls: imageUrls,
      );
    }

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (result['success'] == true) {
        widget.onReviewAdded();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Đánh giá đã được cập nhật!'
                : 'Đánh giá của bạn đã được đăng thành công!'),
            backgroundColor: AppTheme.pitchBlack,
          ),
        );
      } else if (result['needLogin'] == true) {
        _showLoginRequired();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Không thể gửi đánh giá!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLoginRequired() {
    showDialog<bool>(
      context: context,
      builder: (_) => LoginDialog(onLoginSuccess: () => setState(() {})),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ApiService.currentUser;

    // Not logged in — show login required state
    if (user == null) {
      return Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          top: 24,
          left: 24,
          right: 24,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBg : AppTheme.pureWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.fireCoral.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.rate_review_rounded, size: 40, color: AppTheme.fireCoral),
            ),
            const SizedBox(height: 20),
            Text(
              'Yêu Cầu Đăng Nhập',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack),
            ),
            const SizedBox(height: 10),
            Text(
              'Bạn cần đăng nhập tài khoản để có thể viết đánh giá nhà hàng.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5,
                color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.fireCoral,
                  foregroundColor: AppTheme.pureWhite,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.login_rounded, size: 20),
                label: const Text('Đăng nhập ngay',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(context);
                  showDialog<bool>(
                    context: context,
                    builder: (_) => LoginDialog(
                      onLoginSuccess: () {
                        Future.delayed(const Duration(milliseconds: 200), () {
                          if (context.mounted) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => AddReviewDialog(
                                restaurantId: widget.restaurantId,
                                restaurantName: widget.restaurantName,
                                onReviewAdded: widget.onReviewAdded,
                              ),
                            );
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    // Logged in — review form
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24, left: 20, right: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBg : AppTheme.pureWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isEditMode ? 'Chỉnh sửa đánh giá' : 'Viết đánh giá',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack),
              ),
              const SizedBox(height: 4),
              Text(widget.restaurantName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppTheme.fireCoral)),
              const SizedBox(height: 16),

              // User info card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.fireCoral.withValues(alpha: 0.15),
                    backgroundImage: user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
                    child: user.avatarUrl.isEmpty
                        ? Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                              color: AppTheme.fireCoral))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                          color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack)),
                      Text('Đánh giá với tư cách cá nhân',
                        style: TextStyle(fontSize: 11,
                          color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight)),
                    ],
                  )),
                  const Icon(Icons.verified_user_rounded, color: AppTheme.fireCoral, size: 18),
                ]),
              ),
              const SizedBox(height: 20),

              // Star rating
              Center(child: Column(children: [
                StarRating(
                  rating: _rating,
                  size: 36,
                  isInteractive: true,
                  onRatingChanged: (r) => setState(() => _rating = r),
                ),
                const SizedBox(height: 8),
                Text('${_rating.toStringAsFixed(1)} / 5.0',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack)),
              ])),
              const SizedBox(height: 20),

              // Recommended dish
              TextFormField(
                controller: _dishController,
                style: TextStyle(color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack),
                decoration: InputDecoration(
                  labelText: 'Món ăn gợi ý (Tùy chọn)',
                  hintText: 'VD: Phở Bò Tái Nạm',
                  prefixIcon: const Icon(Icons.restaurant_menu_rounded, color: AppTheme.fireCoral, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.fireCoral, width: 2)),
                ),
              ),
              const SizedBox(height: 16),

              // Comment
              TextFormField(
                controller: _commentController,
                maxLines: 4,
                style: TextStyle(color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack),
                decoration: InputDecoration(
                  labelText: 'Cảm nhận của bạn',
                  hintText: 'Chia sẻ trải nghiệm về hương vị, dịch vụ, không gian...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.fireCoral, width: 2)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Vui lòng viết cảm nhận';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Image section
              _buildImageSection(isDark),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: (_isSubmitting || _isUploadingImage) ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.fireCoral,
                    foregroundColor: AppTheme.pureWhite,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: (_isSubmitting || _isUploadingImage)
                      ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(color: AppTheme.pureWhite, strokeWidth: 2)),
                          const SizedBox(width: 12),
                          Text(_isUploadingImage ? 'Đang tải ảnh...' : 'Đang gửi...',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ])
                      : Text(_isEditMode ? 'CẬP NHẬT' : 'GỬI ĐÁNH GIÁ',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSectionLegacy(bool isDark) {
    final existingCount = _existingImageUrls.length;
    final totalCount = existingCount + _pickedBytes.length;
    final hasImage = totalCount > 0;
    final existingImageUrl = existingCount == 0 ? '' : _existingImageUrls.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ảnh đính kèm',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight)),
        const SizedBox(height: 8),
        Row(children: [
          // Image preview / add button
          GestureDetector(
            onTap: _showImagePickerOptions,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 90, height: 90,
                child: hasImage
                    ? Stack(fit: StackFit.expand, children: [
                        if (_pickedBytes.isNotEmpty)
                          Image.memory(_pickedBytes.first, fit: BoxFit.cover)
                        else
                          Image.network(existingImageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
                              child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                            )),
                        // Edit overlay
                        Positioned(
                          right: 0, bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: AppTheme.fireCoral,
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(10)),
                            ),
                            child: const Icon(Icons.edit_rounded, size: 14, color: AppTheme.pureWhite),
                          ),
                        ),
                      ])
                    : Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate_rounded,
                            color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight, size: 28),
                          const SizedBox(height: 4),
                          Text('Thêm ảnh', style: TextStyle(fontSize: 11,
                            color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight)),
                        ]),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(
            hasImage
                ? 'Nhấn vào ảnh để thay đổi hoặc xóa'
                : 'Thêm ảnh món ăn hoặc không gian nhà hàng (tùy chọn, tối đa 5MB)',
            style: TextStyle(fontSize: 12, height: 1.5,
              color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight),
          )),
        ]),
      ],
    );
  }

  Widget _buildImageSection(bool isDark) {
    final totalCount = _existingImageUrls.length + _pickedBytes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Ảnh đính kèm',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight,
              ),
            ),
            const Spacer(),
            Text(
              '$totalCount/5 ảnh',
              style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ...List.generate(
              _existingImageUrls.length,
              (index) => _buildReviewImageTile(
                isDark: isDark,
                image: Image.network(_existingImageUrls[index], fit: BoxFit.cover),
                onRemove: () => setState(() => _existingImageUrls.removeAt(index)),
              ),
            ),
            ...List.generate(
              _pickedBytes.length,
              (index) => _buildReviewImageTile(
                isDark: isDark,
                image: Image.memory(_pickedBytes[index], fit: BoxFit.cover),
                onRemove: () => setState(() {
                  _pickedImages.removeAt(index);
                  _pickedBytes.removeAt(index);
                }),
              ),
            ),
            if (totalCount < 5)
              InkWell(
                onTap: _showImagePickerOptions,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_rounded, color: AppTheme.fireCoral, size: 28),
                      SizedBox(height: 4),
                      Text('Thêm ảnh', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Chọn tối đa 5 ảnh món ăn hoặc không gian.',
          style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight),
        ),
      ],
    );
  }

  Widget _buildReviewImageTile({
    required bool isDark,
    required Widget image,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: image,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}
