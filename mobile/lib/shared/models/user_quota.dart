class UserQuota {
  final String userId;
  final String plan;
  final String planName;
  final bool isPremium;
  final bool canSelectModel;
  final List<String> allowedModels;
  final int messagesLimit;
  final int messagesUsed;
  final int messagesRemaining;
  final int attachmentsLimit;
  final int attachmentsUsed;
  final int attachmentsRemaining;
  final bool isQuotaExceeded;
  final DateTime resetAt;

  const UserQuota({
    required this.userId,
    this.plan = 'free',
    this.planName = 'SD FREE',
    required this.isPremium,
    this.canSelectModel = false,
    this.allowedModels = const [],
    required this.messagesLimit,
    required this.messagesUsed,
    required this.messagesRemaining,
    required this.attachmentsLimit,
    required this.attachmentsUsed,
    required this.attachmentsRemaining,
    required this.isQuotaExceeded,
    required this.resetAt,
  });

  bool get isVip => plan.toLowerCase() == 'vip';
  bool get isBlack => plan.toLowerCase() == 'black';
  bool get isPaidPlan => isPremium || isVip || isBlack;

  factory UserQuota.fromJson(Map<String, dynamic> json) {
    final p = (json['plan'] as String? ?? 'free').toLowerCase();
    final isPrem = json['is_premium'] as bool? ?? (p != 'free');
    final canSelect = json['can_select_model'] as bool? ?? (p == 'vip' || p == 'black');
    final modelsList = (json['allowed_models'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    return UserQuota(
      userId: json['user_id'] as String? ?? '',
      plan: p,
      planName: json['plan_name'] as String? ?? _defaultPlanName(p),
      isPremium: isPrem,
      canSelectModel: canSelect,
      allowedModels: modelsList,
      messagesLimit: (json['messages_limit'] as num?)?.toInt() ?? 5,
      messagesUsed: (json['messages_used'] as num?)?.toInt() ?? 0,
      messagesRemaining: (json['messages_remaining'] as num?)?.toInt() ?? 5,
      attachmentsLimit: (json['attachments_limit'] as num?)?.toInt() ?? 3,
      attachmentsUsed: (json['attachments_used'] as num?)?.toInt() ?? 0,
      attachmentsRemaining: (json['attachments_remaining'] as num?)?.toInt() ?? 3,
      isQuotaExceeded: json['is_quota_exceeded'] as bool? ?? false,
      resetAt: json['reset_at'] != null
          ? DateTime.tryParse(json['reset_at'].toString())?.toLocal() ??
              DateTime.now().add(const Duration(days: 1))
          : DateTime.now().add(const Duration(days: 1)),
    );
  }

  static String _defaultPlanName(String plan) {
    switch (plan.toLowerCase()) {
      case 'black':
        return 'SD BLACK PREMIUM ULTRA';
      case 'vip':
        return 'SD VIP';
      case 'premium':
        return 'SD PREMIUM';
      case 'free':
      default:
        return 'SD FREE';
    }
  }

  /// Format de réinitialisation lisible en français
  String get resetCountdownFormatted {
    final now = DateTime.now();
    final difference = resetAt.difference(now);
    if (difference.isNegative) {
      return 'Bientôt réinitialisé';
    }
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    if (hours > 0) {
      return 'Réinitialisation dans ${hours}h ${minutes}m';
    }
    return 'Réinitialisation dans ${minutes}m';
  }

  /// Pourcentage d'utilisation des messages (0.0 à 1.0)
  double get messageUsageRatio {
    if (messagesLimit <= 0) return 0.0;
    return (messagesUsed / messagesLimit).clamp(0.0, 1.0);
  }
}
