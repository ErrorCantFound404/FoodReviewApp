import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReviewReportsPanel extends StatefulWidget {
  const ReviewReportsPanel({super.key});
  @override
  State<ReviewReportsPanel> createState() => _ReviewReportsPanelState();
}

class _ReviewReportsPanelState extends State<ReviewReportsPanel> {
  List<dynamic> _reports = [];
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};
  Widget _image(String url) {
    try {
      if (url.startsWith('data:image/')) {
        return Image.memory(
          base64Decode(url.substring(url.indexOf(',') + 1)),
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) => const Icon(Icons.broken_image),
        );
      }
      return Image.network(
        ApiService.resolveImageUrl(url),
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) => const Icon(Icons.broken_image),
      );
    } catch (_) {
      return const Icon(Icons.broken_image);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.reviewReportRequest('') as List;
      if (mounted) setState(() => _reports = data);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve(int id, bool remove) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(remove ? 'Xóa đánh giá bị báo cáo?' : 'Bác báo cáo?'),
        content: Text(
          remove
              ? 'Đánh giá sẽ bị xóa và điểm sao quán được tính lại.'
              : 'Đánh giá của khách sẽ được giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy.add(id));
    try {
      await ApiService.reviewReportRequest(
        '/$id/${remove ? 'remove' : 'dismiss'}',
        body: {},
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        title: const Text('Báo cáo đánh giá chờ xử lý'),
        trailing: IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null)
        Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
      if (!_loading && _error == null && _reports.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Không có báo cáo đang chờ.'),
        ),
      Expanded(
        child: ListView.builder(
          itemCount: _reports.length,
          itemBuilder: (context, index) {
            final r = _reports[index];
            final review = r['review'];
            final id = r['id'] as int;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r['restaurantName'] ?? 'Quán đã xóa'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Người báo cáo: ${r['reporterName'] ?? ''}'),
                    Text('Lý do: ${r['reason']}'),
                    const Divider(),
                    if (review == null)
                      const Text('Đánh giá không còn tồn tại.')
                    else ...[
                      Text('${review['userName']} • ${review['rating']} sao'),
                      Text('${review['comment']}'),
                      if ((review['recommendedDish'] ?? '') != '')
                        Text('Món gợi ý: ${review['recommendedDish']}'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            {
                                  for (final image
                                      in ((review['images'] as List?) ?? []))
                                    (image['imageUrl'] ?? '') as String,
                                  if ((review['imageUrl'] ?? '') != '')
                                    review['imageUrl'] as String,
                                }
                                .where((url) => url.isNotEmpty)
                                .map<Widget>(
                                  (url) => SizedBox(
                                    width: 120,
                                    height: 100,
                                    child: _image(url),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                    Wrap(
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed: _busy.contains(id)
                              ? null
                              : () => _resolve(id, false),
                          child: const Text('Bác báo cáo / Giữ đánh giá'),
                        ),
                        FilledButton(
                          onPressed: _busy.contains(id)
                              ? null
                              : () => _resolve(id, true),
                          child: const Text('Duyệt / Xóa đánh giá'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}
