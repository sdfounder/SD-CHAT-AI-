import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

class SubscriptionDetails {
  final String userId;
  final String planId;
  final String status;
  final bool isPremium;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;

  SubscriptionDetails({
    required this.userId,
    required this.planId,
    required this.status,
    required this.isPremium,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
  });

  factory SubscriptionDetails.fromJson(Map<String, dynamic> json) {
    return SubscriptionDetails(
      userId: json['user_id'] as String? ?? '',
      planId: json['plan_id'] as String? ?? 'free',
      status: json['status'] as String? ?? 'free',
      isPremium: json['is_premium'] as bool? ?? false,
      stripeCustomerId: json['stripe_customer_id'] as String?,
      stripeSubscriptionId: json['stripe_subscription_id'] as String?,
      currentPeriodStart: json['current_period_start'] != null
          ? DateTime.tryParse(json['current_period_start'] as String)
          : null,
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.tryParse(json['current_period_end'] as String)
          : null,
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
    );
  }
}

class BillingService {
  static final BillingService _instance = BillingService._internal();
  factory BillingService() => _instance;
  BillingService._internal();

  final AuthService _auth = AuthService();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${_auth.accessToken ?? ""}',
      };

  /// Récupérer l'état de l'abonnement Stripe depuis le backend
  Future<SubscriptionDetails?> fetchSubscriptionDetails() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/billing/subscription');
    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return SubscriptionDetails.fromJson(data);
      } else {
        debugPrint('Fetch subscription failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Exception fetching subscription: $e');
    }
    return null;
  }

  /// Créer une session Stripe Checkout et retourner l'URL officielle
  Future<String?> createCheckoutSession({
    String? priceId,
    String? successUrl,
    String? cancelUrl,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/billing/checkout');
    try {
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'price_id': ?priceId,
          'success_url': ?successUrl,
          'cancel_url': ?cancelUrl,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data['checkout_url'] as String?;
      } else {
        debugPrint('Create checkout failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception creating checkout: $e');
    }
    return null;
  }

  /// Créer une session Stripe Customer Portal et retourner l'URL sécurisée
  Future<String?> createPortalSession({String? returnUrl}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/billing/portal');
    try {
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'return_url': ?returnUrl,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data['portal_url'] as String?;
      } else {
        debugPrint('Create portal failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception creating portal: $e');
    }
    return null;
  }

  /// Ouvrir une URL dans le navigateur externe sécurisé
  Future<bool> launchExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Exception opening URL: $e');
      return false;
    }
  }
}
