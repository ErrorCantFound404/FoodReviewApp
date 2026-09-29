import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class BusinessProfileSubmissionScreen extends StatefulWidget {
  final RestaurantModel restaurant;
  const BusinessProfileSubmissionScreen({super.key, required this.restaurant});

  @override
  State<BusinessProfileSubmissionScreen> createState() => _BusinessProfileSubmissionScreenState();
}

class _BusinessProfileSubmissionScreenState extends State<BusinessProfileSubmissionScreen> {
  bool _isSubmitting = false;

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final success = await ApiService.submitRestaurantProfile(widget.restaurant.id);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.mark_email_read_rounded, color: AppTheme.fireCoral, size: 42),
          title: const Text('Đã gửi hồ sơ'),
          content: const Text('Hồ sơ quán đã được gửi đến Admin Dashboard để kiểm duyệt.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đã hiểu'))],
        ),
      );
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể gửi hồ sơ. Vui lòng thử lại.'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : Colors.black87;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text('Bước 3: Gửi hồ sơ')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Icon(Icons.verified_user_rounded, color: AppTheme.fireCoral, size: 58),
              const SizedBox(height: 16),
              Text('Kiểm tra và gửi hồ sơ', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: text)),
              const SizedBox(height: 8),
              Text('Admin sẽ nhận được thông tin quán để kiểm duyệt trước khi công khai.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight)),
              const SizedBox(height: 26),
              _summaryRow(Icons.storefront_rounded, 'Quán', widget.restaurant.name, isDark),
              _summaryRow(Icons.photo_library_outlined, 'Ảnh', '${widget.restaurant.imageUrls.length}/5 ảnh', isDark),
              _summaryRow(Icons.restaurant_menu_rounded, 'Thực đơn', '${widget.restaurant.menuItems.length} món', isDark),
              _summaryRow(Icons.location_on_outlined, 'Vị trí', '${widget.restaurant.latitude.toStringAsFixed(5)}, ${widget.restaurant.longitude.toStringAsFixed(5)}', isDark),
              const Spacer(),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.fireCoral, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                icon: _isSubmitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded),
                label: Text(_isSubmitting ? 'Đang gửi...' : 'Gửi hồ sơ tới Admin'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value, bool isDark) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [Icon(icon, color: AppTheme.fireCoral), const SizedBox(width: 12), Expanded(child: Text(label, style: TextStyle(color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight))), Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87))]),
      );
}
