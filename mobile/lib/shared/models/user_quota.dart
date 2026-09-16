class UserQuota {
  final String userId;
  final String plan;
  final bool isPremium;
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
    required this.plan,
    required this.isPremium,
    required this.messagesLimit,
    required this.messagesUsed,
    required this.messagesRemaining,
    required this.attachmentsLimit,
    required this.attachmentsUsed,
    required this.attachmentsRemaining,
    required this.isQuotaExceeded,
    required this.resetAt,
  });

  factory UserQuota.fromJson(Map<String, dynamic> json) {
    return UserQuota(
      userId: json['user_id'] as String? ?? '',
      plan: json['plan'] as String? ?? 'free',
      isPremium: json['is_premium'] as bool? ?? false,
      messagesLimit: (json['messages_limit'] as num?)?.toInt() ?? 20,
      messagesUsed: (json['messages_used'] as num?)?.toInt() ?? 0,
      messagesRemaining: (json['messages_remaining'] as num?)?.toInt() ?? 20,
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
