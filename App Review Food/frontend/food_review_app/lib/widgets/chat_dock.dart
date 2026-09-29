import 'dart:async';
import 'package:flutter/material.dart';
import '../app_navigator.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../views/business_restaurant_management_screen.dart';

class ChatOverlay extends StatefulWidget {
  final Widget child;
  const ChatOverlay({super.key, required this.child});

  @override
  State<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends State<ChatOverlay> {
  late final OverlayEntry _entry = OverlayEntry(
    builder: (_) => ChatDock(child: widget.child),
  );

  @override
  void didUpdateWidget(covariant ChatOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);

  @override
  void dispose() {
    _entry.remove();
    _entry.dispose();
    super.dispose();
  }
}

class ChatDock extends StatefulWidget {
  final Widget child;
  const ChatDock({super.key, required this.child});

  static final ValueNotifier<int?> restaurantRequest = ValueNotifier(null);
  static void openRestaurant(int id) => restaurantRequest.value = id;

  @override
  State<ChatDock> createState() => _ChatDockState();
}

class _ChatDockState extends State<ChatDock> with WidgetsBindingObserver {
  Timer? _timer;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _inbox = [], _messages = [];
  int? _userId, _conversation;
  String _title = 'Tin nhắn';
  String? _error;
  bool _open = false, _fetching = false, _sending = false, _active = true;
  bool _openingManagement = false;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ChatDock.restaurantRequest.addListener(_start);
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      final user = ApiService.currentUser?.id;
      if (user != _userId) {
        setState(() {
          _userId = user;
          _inbox = [];
          _messages = [];
          _conversation = null;
          _open = false;
          _error = null;
          _input.clear();
        });
      }
      if (_active && user != null && (_open || _ticks++ % 4 == 0)) {
        _refresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
  }

  Future<void> _start() async {
    final restaurant = ChatDock.restaurantRequest.value;
    if (restaurant == null) return;
    ChatDock.restaurantRequest.value = null;
    final user = ApiService.currentUser?.id;

    setState(() {
      _userId = user;
      _open = true;
      _conversation = null;
      _messages = [];
      _error = null;
      _input.clear();
    });

    if (user == null) {
      setState(() => _error = 'Bạn cần đăng nhập để nhắn tin cho quán.');
      return;
    }

    try {
      final data = await ApiService.chatRequest(
        '/restaurant/$restaurant',
        body: {},
      );
      if (!mounted || ApiService.currentUser?.id != user) return;

      setState(() {
        _conversation = data['id'] as int;
        _title = 'Nhắn tin với quán';
      });
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _refresh({bool older = false}) async {
    if (_fetching || _userId == null) return;
    _fetching = true;
    final user = _userId, conversation = _conversation;

    try {
      final inbox = await ApiService.chatRequest('') as List;
      List<dynamic>? messages;
      if (_open && conversation != null) {
        final before = older && _messages.isNotEmpty
            ? '?before=${_messages.first['id']}'
            : '';
        messages = await ApiService.chatRequest('/$conversation/messages$before') as List;
      }

      if (!mounted || ApiService.currentUser?.id != user || conversation != _conversation) {
        return;
      }

      setState(() {
        _inbox = inbox;
        _error = null;
        if (messages != null) {
          final merged = <int, dynamic>{
            for (final m in _messages) m['id'] as int: m,
            for (final m in messages) m['id'] as int: m,
          };
          _messages = merged.values.toList()
            ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
        }
      });

      if (_open && conversation != null && messages != null && messages.isNotEmpty) {
        await ApiService.chatRequest(
          '/$conversation/read',
          body: {'throughId': messages.last['id']},
        );
      }
    } catch (e) {
      if (mounted && user == ApiService.currentUser?.id) {
        setState(() => _error = '$e');
      }
    } finally {
      _fetching = false;
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim(), conversation = _conversation;
    if (text.isEmpty || conversation == null || _sending) return;
    final user = ApiService.currentUser?.id;
    setState(() => _sending = true);

    try {
      final message = await ApiService.chatRequest(
        '/$conversation/messages',
        body: {'text': text},
      );
      if (!mounted || user != ApiService.currentUser?.id || conversation != _conversation) {
        return;
      }

      setState(() {
        _messages = [
          ..._messages.where((m) => m['id'] != message['id']),
          message,
        ];
        _input.clear();
        _error = null;
      });

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Map<String, dynamic>? get _activeConversation {
    for (final item in _inbox) {
      if (item['id'] == _conversation) {
        return Map<String, dynamic>.from(item as Map);
      }
    }
    return null;
  }

  String _messageText(dynamic message) {
    final isMyMessage = message['senderId'] == _userId;
    final targetedText = isMyMessage ? message['customerText'] : message['ownerText'];
    final text = (targetedText ?? '').toString().trim();
    return text.isNotEmpty ? text : '${message['text'] ?? ''}';
  }

  Future<void> _openRestaurantManagement() async {
    final conversation = _activeConversation;
    final user = ApiService.currentUser;
    if (conversation == null || user?.isBusiness != true || _openingManagement) return;

    setState(() => _openingManagement = true);
    try {
      final restaurant = await ApiService.getRestaurantDetail(
        conversation['restaurantId'] as int,
      );
      if (restaurant == null || restaurant.ownerId != user!.id) {
        throw Exception('Bạn không có quyền quản lý quán này.');
      }
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => BusinessRestaurantManagementScreen(restaurant: restaurant),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _openingManagement = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _scrollController.dispose();
    ChatDock.restaurantRequest.removeListener(_start);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unread = _inbox.fold<int>(0, (sum, c) => sum + ((c['unread'] ?? 0) as int));

    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: !_open
                  ? _buildFloatingButton(unread)
                  : _buildChatBox(context, scheme, theme),
            ),
          ),
        ),
      ],
    );
  }

  /// Nút nổi Mở Chat
  Widget _buildFloatingButton(int unread) {
    return Material(
      key: const ValueKey('FloatingButton'),
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _userId = ApiService.currentUser?.id;
            _open = true;
          });
          _refresh();
        },
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.fireCoral, Color(0xFFFF6F59)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.fireCoral.withValues(alpha: 0.38),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Badge(
              isLabelVisible: unread > 0,
              backgroundColor: Colors.white,
              textColor: AppTheme.fireCoral,
              label: Text('$unread', style: const TextStyle(fontWeight: FontWeight.bold)),
              child: const Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Khung Cửa Sổ Chat Box
  Widget _buildChatBox(BuildContext context, ColorScheme scheme, ThemeData theme) {
    final width = (MediaQuery.sizeOf(context).width - 32).clamp(0.0, 380.0);
    final height = (MediaQuery.sizeOf(context).height - MediaQuery.viewInsetsOf(context).bottom - 100)
        .clamp(260.0, 560.0);

    return Material(
      key: const ValueKey('ChatWindow'),
      color: scheme.surface,
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4), width: 1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.fireCoral, Color(0xFFFF6F59)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  if (_conversation != null)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _conversation = null;
                          _messages = [];
                          _input.clear();
                        });
                        _refresh();
                      },
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      tooltip: 'Trở về danh sách',
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _conversation == null ? 'Tin nhắn' : _title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Hỗ trợ & Trò chuyện trực tiếp',
                          style: TextStyle(fontSize: 11, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  if (ApiService.currentUser?.isBusiness == true && _activeConversation != null)
                    IconButton(
                      tooltip: 'Quản lý quán',
                      onPressed: _openingManagement ? null : _openRestaurantManagement,
                      icon: _openingManagement
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.storefront_outlined, color: Colors.white),
                    ),
                  IconButton(
                    tooltip: 'Thu nhỏ',
                    onPressed: () => setState(() => _open = false),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Error Bar
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: scheme.errorContainer,
                child: Text(
                  _error!,
                  style: TextStyle(color: scheme.onErrorContainer, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Body Area
            Expanded(
              child: _userId == null
                  ? _buildEmptyState(
                icon: Icons.lock_outline_rounded,
                message: 'Vui lòng đăng nhập để gửi tin nhắn.',
              )
                  : _conversation == null
                  ? _buildInboxList(scheme)
                  : _buildMessageList(scheme, theme),
            ),

            // Input Area
            if (_conversation != null) _buildInputBox(scheme),
          ],
        ),
      ),
    );
  }

  /// Danh sách hộp thư (Inbox)
  Widget _buildInboxList(ColorScheme scheme) {
    if (_inbox.isEmpty) {
      return _buildEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        message: 'Chưa có cuộc trò chuyện nào.\nHãy mở trang quán ăn để bắt đầu!',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _inbox.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final c = _inbox[index];
        final unreadCount = (c['unread'] ?? 0) as int;
        final bool isUnread = unreadCount > 0;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.fireCoral.withValues(alpha: 0.12),
            child: const Icon(Icons.storefront_rounded, color: AppTheme.fireCoral, size: 22),
          ),
          title: Text(
            '${c['restaurantName']} • ${c['customerName']}',
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              c['lastMessage'] ?? 'Bắt đầu trò chuyện',
              style: TextStyle(
                fontSize: 12.5,
                color: isUnread ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing: isUnread
              ? Badge(
            backgroundColor: AppTheme.fireCoral,
            label: Text('$unreadCount'),
          )
              : Icon(Icons.chevron_right_rounded, color: scheme.outline),
          onTap: () {
            setState(() {
              _conversation = c['id'];
              _title = '${c['restaurantName']} • ${c['customerName']}';
              _messages = [];
              _input.clear();
            });
            _refresh();
          },
        );
      },
    );
  }

  /// Danh sách tin nhắn nhắn trong cuộc trò chuyện
  Widget _buildMessageList(ColorScheme scheme, ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: _messages.length + 1,
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return Center(
            child: TextButton(
              onPressed: () => _refresh(older: true),
              child: const Text('Tải tin nhắn cũ hơn', style: TextStyle(fontSize: 12)),
            ),
          );
        }

        final m = _messages[_messages.length - 1 - index];
        final isMine = m['senderId'] == _userId;
        final time = DateTime.tryParse('${m['createdAt']}')?.toLocal();

        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 270),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMine ? AppTheme.fireCoral : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _messageText(m),
                  style: TextStyle(
                    color: isMine ? Colors.white : scheme.onSurface,
                    fontSize: 13.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time == null
                          ? ''
                          : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.75)
                            : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    if (isMine && m['isRead'] == true) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done_all_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Khung nhập tin nhắn
  Widget _buildInputBox(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              enabled: !_sending,
              maxLength: 2000,
              minLines: 1,
              maxLines: 3,
              style: TextStyle(color: scheme.onSurface, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Nhập tin nhắn…',
                hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5),
                counterText: '',
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _sending ? null : _send,
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.fireCoral,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(10),
            ),
            icon: _sending
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
                : const Icon(Icons.send_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  /// Trạng thái trống
  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: AppTheme.fireCoral.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}