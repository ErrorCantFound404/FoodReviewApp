import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Loads independently so refreshing reservations does not reset the edit form.
class RestaurantReservations extends StatefulWidget {
  final int restaurantId;
  const RestaurantReservations({super.key, required this.restaurantId});

  @override
  State<RestaurantReservations> createState() => _RestaurantReservationsState();
}

class _RestaurantReservationsState extends State<RestaurantReservations> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _failed = false;
  final Set<int> _updating = {};
  final Set<int> _deleting = {};
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // SQL datetime2 is returned without an offset; reservations are stored in UTC.
  DateTime _time(dynamic value) {
    final parsed = DateTime.parse(value.toString());
    if (parsed.isUtc) return parsed.toLocal();
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
    ).toLocal();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final items = await ApiService.getRestaurantReservations(
        widget.restaurantId,
      );
      items.sort((a, b) {
        final order = _time(
          a['reservationTime'],
        ).compareTo(_time(b['reservationTime']));
        return order != 0 ? order : (a['id'] as int).compareTo(b['id'] as int);
      });
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> item, bool confirm) async {
    final id = item['id'] as int;
    final label = confirm ? 'xác nhận' : 'từ chối';
    final allowed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${confirm ? 'Xác nhận' : 'Từ chối'} đặt bàn?'),
        content: Text('Bạn muốn $label bàn của ${item['customerName']} chứ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirm ? 'Xác nhận' : 'Từ chối'),
          ),
        ],
      ),
    );
    if (allowed != true || !mounted) return;
    setState(() => _updating.add(id));
    try {
      await ApiService.updateReservationStatus(id, confirm: confirm);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Đã $label yêu cầu đặt bàn.')));
        await _load();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _updating.remove(id));
    }
  }

  Future<void> _deleteOld(Map<String, dynamic> item) async {
    final id = item['id'] as int;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa thông báo đặt bàn?'),
        content: Text(
          'Xóa yêu cầu cũ của ${item['customerName']} khỏi danh sách quản lý? Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _deleting.add(id));
    try {
      await ApiService.deleteOldRestaurantReservation(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa thông báo đặt bàn cũ.')),
        );
        await _load();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _deleting.remove(id));
    }
  }

  Widget _reservationCard(Map<String, dynamic> item) {
    final date = _time(item['reservationTime']);
    final status = switch (item['status']) {
      'Confirmed' => 'Đã xác nhận',
      'Rejected' => 'Đã từ chối',
      'Cancelled' => 'Khách đã hủy',
      _ => 'Chờ xác nhận',
    };
    final isPending = item['status'] == 'Pending';
    final isActive = isPending || item['status'] == 'Confirmed';
    final canDelete = !isActive || !date.isAfter(DateTime.now());
    final id = item['id'] as int;
    final isUpdating = _updating.contains(id);
    final isDeleting = _deleting.contains(id);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text(
                        '${item['customerName']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(status),
                    ],
                  ),
                ),
                if (canDelete)
                  IconButton(
                    tooltip: 'Xóa thông báo cũ',
                    onPressed: isDeleting ? null : () => _deleteOld(item),
                    icon: isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${date.day}/${date.month}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} • ${item['partySize']} người',
            ),
            SelectableText('Điện thoại: ${item['phone']}'),
            if ((item['note'] as String? ?? '').trim().isNotEmpty)
              Text('Ghi chú: ${item['note']}'),
            if (isPending) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: isUpdating
                        ? null
                        : () => _updateStatus(item, false),
                    icon: const Icon(Icons.close),
                    label: const Text('Từ chối'),
                  ),
                  FilledButton.icon(
                    onPressed: isUpdating
                        ? null
                        : () => _updateStatus(item, true),
                    icon: isUpdating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(isUpdating ? 'Đang cập nhật' : 'Xác nhận bàn'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.table_restaurant_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Khách đặt bàn${_loading || _failed ? '' : ' (${_items.length})'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: 'Tải lại đặt bàn',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const Text('Sắp theo giờ hẹn từ sớm đến muộn • Giờ địa phương'),
      const SizedBox(height: 12),
      Container(
        height: 420,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _failed
            ? Center(
                child: TextButton(
                  onPressed: _load,
                  child: const Text('Không thể tải danh sách. Thử lại'),
                ),
              )
            : _items.isEmpty
            ? const Center(child: Text('Quán chưa có yêu cầu đặt bàn.'))
            : Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: _items.length,
                  itemBuilder: (context, index) =>
                      _reservationCard(_items[index]),
                ),
              ),
      ),
    ],
  );
}
