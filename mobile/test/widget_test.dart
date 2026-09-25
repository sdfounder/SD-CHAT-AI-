import 'package:flutter_test/flutter_test.dart';
import 'package:sd_chat_ai/main.dart';

import 'package:sd_chat_ai/core/services/sync_service.dart';

void main() {
  tearDown(() {
    SyncService.instance.stopAutoSync();
  });

  testWidgets('SDChatApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SDChatApp());
    expect(find.byType(SDChatApp), findsOneWidget);
  });
}
