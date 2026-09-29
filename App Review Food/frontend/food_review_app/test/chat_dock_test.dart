import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_review_app/widgets/chat_dock.dart';
import 'package:food_review_app/services/api_service.dart';

void main() {
  testWidgets('Inbox opens, requires login, and minimizes', (tester) async {
    ApiService.currentUser = null;
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => ChatOverlay(child: child!),
        home: const Scaffold(body: Text('Trang chủ')),
      ),
    );
    await tester.tap(find.byTooltip('Tin nhắn'));
    await tester.pump();
    expect(find.text('Đăng nhập để sử dụng tin nhắn.'), findsOneWidget);
    await tester.tap(find.byTooltip('Thu nhỏ'));
    await tester.pump();
    expect(find.text('Đăng nhập để sử dụng tin nhắn.'), findsNothing);
    ChatDock.openRestaurant(1);
    await tester.pump();
    expect(
      find.text('Bạn cần đăng nhập để nhắn tin cho quán.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
