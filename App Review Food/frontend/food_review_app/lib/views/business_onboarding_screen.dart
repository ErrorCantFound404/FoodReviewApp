import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'business_restaurant_setup_dialog.dart';
import 'business_restaurant_content_screen.dart';

class BusinessOnboardingScreen extends StatelessWidget {
  const BusinessOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.pureWhite : AppTheme.pitchBlack;
    final mutedColor = isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.pitchBlack : AppTheme.pureWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
        ),
        title: Text('Trung tâm doanh nghiệp', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppTheme.fireCoral,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.storefront_rounded, color: Colors.white, size: 38),
                      const SizedBox(height: 16),
                      const Text('Chào mừng đối tác mới!',
                          style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                        'Hồ sơ ${user?.businessName.isNotEmpty == true ? user!.businessName : user?.fullName ?? ''} đã sẵn sàng để bắt đầu.',
                        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('Bắt đầu kinh doanh', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 10),
                _StepCard(
                  number: '1',
                  title: 'Tạo quán đầu tiên',
                  description: 'Thêm địa chỉ, ảnh và thông tin nổi bật của quán.',
                  action: FilledButton.icon(
                    onPressed: () async {
                      final created = await showDialog<RestaurantModel>(
                        context: context,
                        builder: (_) => const BusinessRestaurantSetupDialog(),
                      );
                      if (created != null && context.mounted) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => BusinessRestaurantContentScreen(restaurant: created)),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_business_rounded),
                    label: const Text('Tạo quán'),
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.fireCoral, foregroundColor: Colors.white),
                  ),
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _StepCard(
                  number: '2',
                  title: 'Hoàn thiện thực đơn',
                  description: 'Thêm món ăn, giá và ảnh món để khách dễ lựa chọn.',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _StepCard(
                  number: '3',
                  title: 'Chờ duyệt hồ sơ',
                  description: 'Thông tin quán sẽ được kiểm tra trước khi hiển thị công khai.',
                  isDark: isDark,
                ),
                const SizedBox(height: 20),
                Text('Bạn có thể quay lại trang chủ bất cứ lúc nào.', style: TextStyle(color: mutedColor, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoCard({required this.icon, required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(icon, color: AppTheme.fireCoral, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
          ])),
        ]),
      );
}

class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final Widget? action;
  final bool isDark;

  const _StepCard({required this.number, required this.title, required this.description, required this.isDark, this.action});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 15, backgroundColor: AppTheme.fireCoral.withValues(alpha: 0.14), child: Text(number, style: const TextStyle(color: AppTheme.fireCoral, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 3),
            Text(description, style: TextStyle(fontSize: 12, height: 1.35, color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight)),
            if (action != null) ...[const SizedBox(height: 10), action!],
          ])),
        ]),
      );
}
