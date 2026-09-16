import 'package:flutter/material.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../../../shared/models/user_quota.dart';

class QuotaDialog extends StatelessWidget {
  final UserQuota quota;
  final VoidCallback? onRefresh;

  const QuotaDialog({
    super.key,
    required this.quota,
    this.onRefresh,
  });

  static Future<void> show(BuildContext context, UserQuota quota, {VoidCallback? onRefresh}) {
    return showDialog(
      context: context,
      builder: (ctx) => QuotaDialog(quota: quota, onRefresh: onRefresh),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPremium = quota.isPremium;

    return Dialog(
      backgroundColor: SDChatColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isPremium
              ? SDChatColors.primary.withValues(alpha: 0.6)
              : SDChatColors.borderSubtle,
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Plan
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isPremium
                        ? SDChatColors.primary.withValues(alpha: 0.15)
                        : SDChatColors.surfaceHighlight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPremium ? Icons.workspace_premium_rounded : Icons.bolt_rounded,
                    color: isPremium ? SDChatColors.primary : SDChatColors.textSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPremium ? 'Plan Premium Actif' : 'Plan Gratuit (Free)',
                        style: const TextStyle(
                          color: SDChatColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPremium
                            ? 'Accès étendu & prioritaire'
                            : 'Quotas journaliers standards',
                        style: const TextStyle(
                          color: SDChatColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Barre d'utilisation Messages
            _buildUsageSection(
              title: 'Messages Gemini',
              icon: Icons.chat_bubble_outline_rounded,
              used: quota.messagesUsed,
              limit: quota.messagesLimit,
              remaining: quota.messagesRemaining,
              accentColor: quota.isQuotaExceeded ? SDChatColors.error : SDChatColors.primary,
            ),
            const SizedBox(height: 14),

            // Barre d'utilisation Pièces Jointes
            _buildUsageSection(
              title: 'Pièces jointes (Images & TXT)',
              icon: Icons.attach_file_rounded,
              used: quota.attachmentsUsed,
              limit: quota.attachmentsLimit,
              remaining: quota.attachmentsRemaining,
              accentColor: SDChatColors.secondary,
            ),
            const SizedBox(height: 16),

            // Temps de réinitialisation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: SDChatColors.background.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SDChatColors.borderSubtle, width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 15, color: SDChatColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${quota.resetCountdownFormatted} (minuit UTC)',
                      style: const TextStyle(color: SDChatColors.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Si Free : Encart incitation Premium
            if (!isPremium) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      SDChatColors.primary.withValues(alpha: 0.12),
                      SDChatColors.surfaceHighlight,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SDChatColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.star_rounded, color: SDChatColors.primary, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Passez à SD CHAT AI Premium',
                          style: TextStyle(
                            color: SDChatColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• 500 requêtes Gemini par jour\n• Jusqu\'à 50 pièces jointes par jour\n• Génération haute priorité sans attente',
                      style: TextStyle(
                        color: SDChatColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SDChatColors.textSecondary,
                      side: const BorderSide(color: SDChatColors.borderSubtle),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Fermer'),
                  ),
                ),
                if (!isPremium) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: SDChatColors.surface,
                            content: Text(
                              'L\'intégration des abonnements Stripe arrive dans la prochaine étape (Mission 8) !',
                              style: TextStyle(color: SDChatColors.textPrimary),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SDChatColors.primary,
                        foregroundColor: SDChatColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Passer Premium',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageSection({
    required String title,
    required IconData icon,
    required int used,
    required int limit,
    required int remaining,
    required Color accentColor,
  }) {
    final double ratio = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: SDChatColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                color: SDChatColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '$used / $limit',
              style: TextStyle(
                color: used >= limit ? SDChatColors.error : SDChatColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: SDChatColors.surfaceHighlight,
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$remaining restant${remaining > 1 ? 's' : ''}',
          style: TextStyle(
            color: remaining == 0 ? SDChatColors.error : SDChatColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
