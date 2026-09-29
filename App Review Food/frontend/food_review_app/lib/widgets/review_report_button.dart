import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReviewReportButton extends StatefulWidget {
  final int reviewId;
  const ReviewReportButton({super.key, required this.reviewId});
  @override
  State<ReviewReportButton> createState() => _ReviewReportButtonState();
}

class _ReviewReportButtonState extends State<ReviewReportButton> {
  bool _sent = false;
  bool _busy = false;
  Future<void> _report() async {
    var reasonInput = '';
    final form = GlobalKey<FormState>();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Báo cáo đánh giá'),
        content: Form(
          key: form,
          child: TextFormField(
            onChanged: (value) => reasonInput = value,
            minLines: 3,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Lý do báo cáo',
              hintText: 'Nêu rõ nội dung spam, xúc phạm hoặc thông tin sai…',
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Vui lòng nhập lý do.' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(ctx, reasonInput.trim());
              }
            },
            child: const Text('Gửi Admin'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ApiService.reviewReportRequest(
        '',
        body: {'reviewId': widget.reviewId, 'reason': reason},
      );
      if (mounted) {
        setState(() => _sent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã gửi báo cáo. Đánh giá được giữ nguyên trong lúc Admin xét duyệt.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: _busy || _sent ? null : _report,
    icon: const Icon(Icons.flag_outlined, size: 18),
    label: Text(
      _busy
          ? 'Đang gửi…'
          : _sent
          ? 'Đã gửi báo cáo'
          : 'Báo cáo đánh giá',
    ),
  );
}
