import 'package:flutter/material.dart';

import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ReservationDialog extends StatefulWidget {
  final RestaurantModel restaurant;
  const ReservationDialog({super.key, required this.restaurant});
  @override
  State<ReservationDialog> createState() => _ReservationDialogState();
}

class _ReservationDialogState extends State<ReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: ApiService.currentUser?.fullName ?? '');
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 19, minute: 0);
  int _partySize = 2;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose(); _phoneController.dispose(); _noteController.dispose(); super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final when = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    if (!when.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn thời gian trong tương lai.'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSubmitting = true);
    final result = await ApiService.createReservation(restaurantId: widget.restaurant.id, customerName: _nameController.text.trim(), phone: _phoneController.text.trim(), reservationTime: when, partySize: _partySize, note: _noteController.text.trim());
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (result['success'] == true) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi yêu cầu đặt bàn. Quán sẽ sớm xác nhận.'), backgroundColor: AppTheme.fireCoral));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Không thể đặt bàn.'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Đặt bàn tại ${widget.restaurant.name}'),
    content: SizedBox(width: 420, child: Form(key: _formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Họ tên *'), validator: (value) => value == null || value.trim().isEmpty ? 'Vui lòng nhập họ tên.' : null),
      TextFormField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Số điện thoại *'), validator: (value) => value == null || value.trim().length < 8 ? 'Số điện thoại không hợp lệ.' : null),
      const SizedBox(height: 14),
      Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () async { final date = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90))); if (date != null && mounted) setState(() => _date = date); }, icon: const Icon(Icons.calendar_today_outlined), label: Text('${_date.day}/${_date.month}/${_date.year}'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: () async { final time = await showTimePicker(context: context, initialTime: _time); if (time != null && mounted) setState(() => _time = time); }, icon: const Icon(Icons.access_time_rounded), label: Text(_time.format(context))))]),
      const SizedBox(height: 14),
      DropdownButtonFormField<int>(value: _partySize, decoration: const InputDecoration(labelText: 'Số người'), items: List.generate(10, (index) => DropdownMenuItem(value: index + 1, child: Text('${index + 1} người'))), onChanged: (value) => setState(() => _partySize = value ?? 2)),
      TextFormField(controller: _noteController, maxLines: 2, decoration: const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)')),
    ])))),
    actions: [TextButton(onPressed: _isSubmitting ? null : () => Navigator.pop(context), child: const Text('Hủy')), FilledButton(onPressed: _isSubmitting ? null : _submit, style: FilledButton.styleFrom(backgroundColor: AppTheme.fireCoral), child: Text(_isSubmitting ? 'Đang gửi...' : 'Gửi yêu cầu'))],
  );
}
