import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd_chat_ai/core/services/billing_service.dart';
import 'package:sd_chat_ai/features/premium/screens/premium_screen.dart';

void main() {
  group('SD CHAT AI - Premium & Stripe Tests (Mission 8)', () {
    test('1. SubscriptionDetails.fromJson parses free state correctly', () {
      final json = {
        'user_id': 'user-123',
        'plan_id': 'free',
        'status': 'free',
        'is_premium': false,
        'stripe_customer_id': null,
        'stripe_subscription_id': null,
        'current_period_start': null,
        'current_period_end': null,
        'cancel_at_period_end': false,
      };

      final sub = SubscriptionDetails.fromJson(json);

      expect(sub.userId, 'user-123');
      expect(sub.planId, 'free');
      expect(sub.status, 'free');
      expect(sub.isPremium, false);
      expect(sub.stripeCustomerId, isNull);
      expect(sub.stripeSubscriptionId, isNull);
      expect(sub.cancelAtPeriodEnd, false);
    });

    test('2. SubscriptionDetails.fromJson parses active premium state correctly', () {
      final json = {
        'user_id': 'premium-user-456',
        'plan_id': 'premium',
        'status': 'active',
        'is_premium': true,
        'stripe_customer_id': 'cus_test_123',
        'stripe_subscription_id': 'sub_test_456',
        'current_period_start': '2026-09-01T00:00:00Z',
        'current_period_end': '2026-10-01T00:00:00Z',
        'cancel_at_period_end': false,
      };

      final sub = SubscriptionDetails.fromJson(json);

      expect(sub.userId, 'premium-user-456');
      expect(sub.planId, 'premium');
      expect(sub.status, 'active');
      expect(sub.isPremium, true);
      expect(sub.stripeCustomerId, 'cus_test_123');
      expect(sub.stripeSubscriptionId, 'sub_test_456');
      expect(sub.currentPeriodEnd, isNotNull);
      expect(sub.cancelAtPeriodEnd, false);
    });

    testWidgets('3. PremiumScreen loads and renders top bar and title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PremiumScreen(),
        ),
      );

      expect(find.text('SD CHAT AI Premium'), findsOneWidget);
    });
  });
}
