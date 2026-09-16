import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd_chat_ai/shared/models/user_quota.dart';
import 'package:sd_chat_ai/features/chat/widgets/quota_dialog.dart';

void main() {
  group('SD CHAT AI - Quota & Entitlements Tests (Mission 7)', () {
    test('1. UserQuota.fromJson parses Free plan correctly', () {
      final json = {
        'user_id': '00000000-0000-0000-0000-000000000001',
        'plan': 'free',
        'is_premium': false,
        'messages_limit': 20,
        'messages_used': 5,
        'messages_remaining': 15,
        'attachments_limit': 3,
        'attachments_used': 1,
        'attachments_remaining': 2,
        'is_quota_exceeded': false,
        'reset_at': '2026-09-17T00:00:00Z',
      };

      final quota = UserQuota.fromJson(json);

      expect(quota.userId, '00000000-0000-0000-0000-000000000001');
      expect(quota.plan, 'free');
      expect(quota.isPremium, false);
      expect(quota.messagesLimit, 20);
      expect(quota.messagesUsed, 5);
      expect(quota.messagesRemaining, 15);
      expect(quota.attachmentsLimit, 3);
      expect(quota.attachmentsUsed, 1);
      expect(quota.attachmentsRemaining, 2);
      expect(quota.isQuotaExceeded, false);
      expect(quota.messageUsageRatio, 0.25);
    });

    test('2. UserQuota.fromJson parses Premium plan correctly', () {
      final json = {
        'user_id': 'premium-user-42',
        'plan': 'premium',
        'is_premium': true,
        'messages_limit': 500,
        'messages_used': 100,
        'messages_remaining': 400,
        'attachments_limit': 50,
        'attachments_used': 5,
        'attachments_remaining': 45,
        'is_quota_exceeded': false,
        'reset_at': '2026-09-17T00:00:00Z',
      };

      final quota = UserQuota.fromJson(json);

      expect(quota.plan, 'premium');
      expect(quota.isPremium, true);
      expect(quota.messagesLimit, 500);
      expect(quota.messagesRemaining, 400);
      expect(quota.attachmentsLimit, 50);
      expect(quota.attachmentsRemaining, 45);
      expect(quota.messageUsageRatio, 0.2);
    });

    testWidgets('3. QuotaDialog displays Free plan quotas and upgrade CTA', (tester) async {
      final quota = UserQuota(
        userId: 'test-user',
        plan: 'free',
        isPremium: false,
        messagesLimit: 20,
        messagesUsed: 20,
        messagesRemaining: 0,
        attachmentsLimit: 3,
        attachmentsUsed: 3,
        attachmentsRemaining: 0,
        isQuotaExceeded: true,
        resetAt: DateTime.now().add(const Duration(hours: 4)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuotaDialog(quota: quota),
          ),
        ),
      );

      expect(find.text('Plan Gratuit (Free)'), findsOneWidget);
      expect(find.text('20 / 20'), findsNWidgets(1));
      expect(find.text('0 restant'), findsNWidgets(2));
      expect(find.text('Passez à SD CHAT AI Premium'), findsOneWidget);
      expect(find.text('Passer Premium'), findsOneWidget);
    });

    testWidgets('4. QuotaDialog displays Premium plan without upgrade button', (tester) async {
      final quota = UserQuota(
        userId: 'test-user-prem',
        plan: 'premium',
        isPremium: true,
        messagesLimit: 500,
        messagesUsed: 42,
        messagesRemaining: 458,
        attachmentsLimit: 50,
        attachmentsUsed: 2,
        attachmentsRemaining: 48,
        isQuotaExceeded: false,
        resetAt: DateTime.now().add(const Duration(hours: 12)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuotaDialog(quota: quota),
          ),
        ),
      );

      expect(find.text('Plan Premium Actif'), findsOneWidget);
      expect(find.text('42 / 500'), findsOneWidget);
      expect(find.text('458 restants'), findsOneWidget);
      // Pas de bouton 'Passer Premium' si déjà Premium
      expect(find.text('Passer Premium'), findsNothing);
      expect(find.text('Fermer'), findsOneWidget);
    });
  });
}
