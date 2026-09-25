import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../../../core/services/billing_service.dart';
import '../../../core/services/chat_api_service.dart';
import '../../../shared/models/user_quota.dart';

class SDPlanItem {
  final String id;
  final String title;
  final String priceGNF;
  final String period;
  final String dailyRequests;
  final String modelAccess;
  final String memory;
  final String fallback;
  final String? badge;
  final List<String> features;
  final Color accentColor;

  const SDPlanItem({
    required this.id,
    required this.title,
    required this.priceGNF,
    required this.period,
    required this.dailyRequests,
    required this.modelAccess,
    required this.memory,
    required this.fallback,
    this.badge,
    required this.features,
    required this.accentColor,
  });
}

const List<SDPlanItem> _kSDPlans = [
  SDPlanItem(
    id: 'free',
    title: 'SD FREE',
    priceGNF: '0 GNF',
    period: 'Gratuit',
    dailyRequests: '5 requêtes / jour',
    modelAccess: 'Modèle économique Gemini',
    memory: 'Contexte standard',
    fallback: 'Routage SD AI Gateway auto',
    accentColor: SDChatColors.secondary,
    features: [
      '5 requêtes IA par jour',
      'Modèle économique Google Gemini',
      'Routage automatique sécurisé',
      '3 pièces jointes par jour',
      'Mode hors ligne & historique local',
    ],
  ),
  SDPlanItem(
    id: 'premium',
    title: 'SD PREMIUM',
    priceGNF: '10 000 GNF',
    period: '/ mois',
    dailyRequests: '10 requêtes / jour',
    modelAccess: 'Modèles autorisés optimisés',
    memory: 'Mémoire conversationnelle active',
    fallback: 'Routage Gateway intelligent',
    badge: 'ACCESSIBLE',
    accentColor: SDChatColors.primary,
    features: [
      '10 requêtes IA par jour',
      'Modèles autorisés & optimisés',
      'Mémoire conversationnelle continue',
      '50 pièces jointes par jour',
      'Dictée vocale et streaming continu',
      'Routage intelligent SD AI Gateway',
    ],
  ),
  SDPlanItem(
    id: 'vip',
    title: 'SD VIP',
    priceGNF: '50 000 GNF',
    period: '/ mois',
    dailyRequests: '25 requêtes / jour',
    modelAccess: 'Sélection manuelle débloquée',
    memory: 'Mémoire avancée longue durée',
    fallback: 'Bascule automatique de secours',
    badge: 'POPULAIRE',
    accentColor: Color(0xFF38BDF8),
    features: [
      '25 requêtes IA par jour',
      'Sélection manuelle du modèle IA activée',
      'Accès aux modèles VIP (Claude, GPT, Gemini Pro)',
      'Mémoire avancée longue durée',
      '100 pièces jointes par jour',
      'Bascule automatique de secours garantie',
    ],
  ),
  SDPlanItem(
    id: 'black',
    title: 'SD BLACK PREMIUM ULTRA',
    priceGNF: '250 000 GNF',
    period: '/ mois',
    dailyRequests: 'Haute capacité (Fair Use)',
    modelAccess: 'Modèles phares (Flagship)',
    memory: 'Priorité SD absolue & illimitée',
    fallback: 'Multi-fournisseur renforcé',
    badge: 'PRESTIGE ULTRA',
    accentColor: Color(0xFFF5C058),
    features: [
      'Haute capacité avec Fair Use garanti',
      'Accès complet aux modèles phares (Flagships)',
      'Sélection manuelle libre de tous les modèles',
      'Priorité SD absolue d\'inférence',
      'Fallback multi-fournisseur renforcé sans coupure',
      'Pièces jointes haute capacité (500/j)',
      'Support VIP dédié et accès anticipé',
    ],
  ),
];

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final BillingService _billingService = BillingService();
  final ChatApiService _chatApi = ChatApiService();

  bool _isLoading = true;
  bool _isActionLoading = false;
  SubscriptionDetails? _subscription;
  UserQuota? _quota;
  String? _errorMessage;
  int _selectedPlanIndex = 1; // Default select SD PREMIUM

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sub = await _billingService.fetchSubscriptionDetails();
      final q = await _chatApi.fetchUserQuota();

      if (mounted) {
        setState(() {
          _subscription = sub;
          _quota = q;
          _isLoading = false;

          // Align selected index with user current plan
          final currentPlan = (q?.plan ?? sub?.planId ?? 'free').toLowerCase();
          final idx = _kSDPlans.indexWhere((p) => p.id == currentPlan);
          if (idx != -1) {
            _selectedPlanIndex = idx;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Impossible de charger vos informations d\'abonnement.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleStripeCheckout(SDPlanItem plan) async {
    HapticFeedback.lightImpact();
    setState(() => _isActionLoading = true);
    try {
      final checkoutUrl = await _billingService.createCheckoutSession(
        successUrl: 'https://sd-chat.ai/billing/success',
        cancelUrl: 'https://sd-chat.ai/billing/cancel',
      );

      if (checkoutUrl != null) {
        final opened = await _billingService.launchExternalUrl(checkoutUrl);
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: SDChatColors.surface,
              content: Text('Impossible d\'ouvrir la page Stripe Checkout.'),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: SDChatColors.surface,
            content: Text('Erreur lors de la génération de la session de paiement.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: SDChatColors.surface,
            content: Text('Erreur: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _showMobileMoneyModal(SDPlanItem plan) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: SDChatColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7900).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_android_rounded, color: Color(0xFFFF7900), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mobile Money Guinée (GNF)',
                          style: TextStyle(
                            color: SDChatColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Orange Money • MTN MoMo Guinée (+224)',
                          style: TextStyle(
                            color: SDChatColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SDChatColors.canvas,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SDChatColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Formule :', style: TextStyle(color: SDChatColors.textMuted, fontSize: 13)),
                        Text(plan.title, style: const TextStyle(color: SDChatColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Montant officiel :', style: TextStyle(color: SDChatColors.textMuted, fontSize: 13)),
                        Text(
                          '${plan.priceGNF} ${plan.period}',
                          style: const TextStyle(color: SDChatColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SDChatColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SDChatColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.info_outline_rounded, color: SDChatColors.warning, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Les passerelles Orange Money et MTN MoMo Guinée sont en phase finale d\'homologation marchande avec les opérateurs télécoms de Conakry. Le paiement international sécurisé par carte Stripe est disponible immédiatement.',
                        style: TextStyle(color: SDChatColors.textSecondary, fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _handleStripeCheckout(plan);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: SDChatColors.primary,
                  foregroundColor: SDChatColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Payer par Carte Bancaire (Stripe)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPaymentPicker(SDPlanItem plan) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: SDChatColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choisir le mode de paiement',
                  style: const TextStyle(
                    color: SDChatColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${plan.title} — ${plan.priceGNF} ${plan.period}',
                  style: const TextStyle(
                    color: SDChatColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: SDChatColors.borderMedium),
                  ),
                  tileColor: SDChatColors.canvas,
                  leading: const Icon(Icons.credit_card_rounded, color: SDChatColors.primary, size: 28),
                  title: const Text('Carte Bancaire Internationale', style: TextStyle(color: SDChatColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14.5)),
                  subtitle: const Text('Stripe Checkout • Visa, Mastercard, Apple Pay', style: TextStyle(color: SDChatColors.textMuted, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: SDChatColors.textSecondary),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleStripeCheckout(plan);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: SDChatColors.borderSubtle),
                  ),
                  tileColor: SDChatColors.canvas,
                  leading: const Icon(Icons.phone_iphone_rounded, color: Color(0xFFFF7900), size: 28),
                  title: const Text('Mobile Money Guinée (GNF)', style: TextStyle(color: SDChatColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14.5)),
                  subtitle: const Text('Orange Money • MTN MoMo (+224)', style: TextStyle(color: SDChatColors.textMuted, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: SDChatColors.textSecondary),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showMobileMoneyModal(plan);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handlePortal() async {
    HapticFeedback.lightImpact();
    setState(() => _isActionLoading = true);
    try {
      final portalUrl = await _billingService.createPortalSession(
        returnUrl: 'https://sd-chat.ai/billing/return',
      );

      if (portalUrl != null) {
        final opened = await _billingService.launchExternalUrl(portalUrl);
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: SDChatColors.surface,
              content: Text('Impossible d\'ouvrir le Portail Client Stripe.'),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: SDChatColors.surface,
            content: Text('Erreur lors de la génération du portail client.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: SDChatColors.surface,
            content: Text('Erreur: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPlanId = (_quota?.plan ?? _subscription?.planId ?? 'free').toLowerCase();
    final isUserPaid = _quota?.isPaidPlan ?? _subscription?.isPremium ?? false;
    final selectedPlan = _kSDPlans[_selectedPlanIndex];
    final isCurrentSelected = (selectedPlan.id == currentPlanId);

    return Scaffold(
      backgroundColor: SDChatColors.background,
      appBar: AppBar(
        backgroundColor: SDChatColors.canvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: SDChatColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.workspace_premium_rounded, color: SDChatColors.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'SD CHAT AI Premium',
              style: TextStyle(
                color: SDChatColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: SDChatColors.primary))
          : RefreshIndicator(
              color: SDChatColors.primary,
              backgroundColor: SDChatColors.surface,
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: SDChatColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: SDChatColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: SDChatColors.error, fontSize: 13),
                        ),
                      ),

                    // Carte d'état actuel de l'utilisateur
                    _buildCurrentStatusCard(currentPlanId, isUserPaid),
                    const SizedBox(height: 20),

                    // Sélecteur des 4 formules officielles SD
                    _buildPlansTabBar(),
                    const SizedBox(height: 16),

                    // Carte détaillée de la formule sélectionnée
                    _buildSelectedPlanCard(selectedPlan, isCurrentSelected),
                    const SizedBox(height: 20),

                    // Bouton d'action principal
                    if (isCurrentSelected && isUserPaid) ...[
                      _buildPortalButton(),
                    ] else if (!isCurrentSelected && selectedPlan.id != 'free') ...[
                      _buildUpgradeButton(selectedPlan),
                    ] else if (isCurrentSelected && selectedPlan.id == 'free') ...[
                      _buildDisabledCurrentButton('Vous utilisez actuellement SD FREE'),
                    ],

                    const SizedBox(height: 24),

                    // Comparatif synthétique des 4 offres
                    _buildComparisonMatrix(),
                    const SizedBox(height: 24),

                    // Garanties de sécurité & souveraineté
                    _buildSecurityBanner(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentStatusCard(String currentPlanId, bool isPaid) {
    final activeItem = _kSDPlans.firstWhere(
      (p) => p.id == currentPlanId,
      orElse: () => _kSDPlans[0],
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SDChatColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPaid ? activeItem.accentColor.withValues(alpha: 0.6) : SDChatColors.borderSubtle,
          width: 1.2,
        ),
        boxShadow: [
          if (isPaid)
            BoxShadow(
              color: activeItem.accentColor.withValues(alpha: 0.1),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: activeItem.accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPaid ? Icons.workspace_premium_rounded : Icons.bolt_rounded,
              color: activeItem.accentColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPaid ? 'Abonnement Actif' : 'Formule par Défaut',
                  style: const TextStyle(
                    color: SDChatColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activeItem.title,
                  style: const TextStyle(
                    color: SDChatColors.textPrimary,
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_subscription?.currentPeriodEnd != null && isPaid) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Renouvellement : ${DateFormat('dd MMMM yyyy', 'fr_FR').format(_subscription!.currentPeriodEnd!)}',
                    style: const TextStyle(color: SDChatColors.textSecondary, fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: activeItem.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: activeItem.accentColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              activeItem.priceGNF,
              style: TextStyle(
                color: activeItem.accentColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansTabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_kSDPlans.length, (index) {
          final plan = _kSDPlans[index];
          final isSelected = index == _selectedPlanIndex;

          return Padding(
            padding: EdgeInsets.only(right: index < _kSDPlans.length - 1 ? 8 : 0),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedPlanIndex = index);
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? plan.accentColor.withValues(alpha: 0.16) : SDChatColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? plan.accentColor : SDChatColors.borderSubtle,
                    width: isSelected ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (plan.badge != null && isSelected) ...[
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(color: plan.accentColor, shape: BoxShape.circle),
                      ),
                    ],
                    Text(
                      plan.title.replaceFirst('SD ', ''),
                      style: TextStyle(
                        color: isSelected ? plan.accentColor : SDChatColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSelectedPlanCard(SDPlanItem plan, bool isCurrent) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: SDChatColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: plan.accentColor.withValues(alpha: 0.5), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: plan.accentColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                plan.title,
                style: const TextStyle(
                  color: SDChatColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (plan.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: plan.accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: plan.accentColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    plan.badge!,
                    style: TextStyle(color: plan.accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                plan.priceGNF,
                style: const TextStyle(
                  color: SDChatColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                plan.period,
                style: const TextStyle(
                  color: SDChatColors.textMuted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: SDChatColors.borderSubtle, height: 1),
          const SizedBox(height: 16),
          ...plan.features.map((f) => _buildFeatureRow(f, plan.accentColor)),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String label, Color checkColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, size: 18, color: checkColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: SDChatColors.textSecondary,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton(SDPlanItem plan) {
    return ElevatedButton(
      onPressed: _isActionLoading ? null : () => _showPaymentPicker(plan),
      style: ElevatedButton.styleFrom(
        backgroundColor: plan.accentColor,
        foregroundColor: SDChatColors.background,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _isActionLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: SDChatColors.background),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.flash_on_rounded, size: 19),
                const SizedBox(width: 8),
                Text(
                  'Passer à ${plan.title} (${plan.priceGNF})',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDisabledCurrentButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: SDChatColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SDChatColors.borderSubtle),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(color: SDChatColors.textMuted, fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildPortalButton() {
    return OutlinedButton(
      onPressed: _isActionLoading ? null : _handlePortal,
      style: OutlinedButton.styleFrom(
        foregroundColor: SDChatColors.textPrimary,
        side: const BorderSide(color: SDChatColors.borderHighlight),
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _isActionLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: SDChatColors.primary),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.manage_accounts_rounded, size: 18, color: SDChatColors.primary),
                SizedBox(width: 8),
                Text(
                  'Gérer mon abonnement actif (Portail)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildComparisonMatrix() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SDChatColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SDChatColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grille Officielle des 4 Plans SD',
            style: TextStyle(color: SDChatColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          _buildMatrixRow('SD FREE', '0 GNF', '5 req/j', 'Modèle auto'),
          const Divider(color: SDChatColors.borderSubtle, height: 16),
          _buildMatrixRow('SD PREMIUM', '10 000 GNF', '10 req/j', 'Mémoire active'),
          const Divider(color: SDChatColors.borderSubtle, height: 16),
          _buildMatrixRow('SD VIP', '50 000 GNF', '25 req/j', 'Choix du modèle débloqué'),
          const Divider(color: SDChatColors.borderSubtle, height: 16),
          _buildMatrixRow('SD BLACK ULTRA', '250 000 GNF', 'Fair Use Max', 'Modèles Phares VIP'),
        ],
      ),
    );
  }

  Widget _buildMatrixRow(String plan, String price, String quota, String advantage) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan, style: const TextStyle(color: SDChatColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
              Text(price, style: const TextStyle(color: SDChatColors.primary, fontSize: 11.5)),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(quota, style: const TextStyle(color: SDChatColors.textSecondary, fontSize: 12)),
        ),
        Expanded(
          flex: 4,
          child: Text(advantage, style: const TextStyle(color: SDChatColors.textMuted, fontSize: 11.5), textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _buildSecurityBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SDChatColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SDChatColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.shield_outlined, size: 18, color: SDChatColors.textMuted),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Paiements sécurisés par Stripe et Mobile Money Guinée. Aucune donnée bancaire n\'est stockée par nos serveurs. Conforme aux normes SD de protection de la vie privée.',
              style: TextStyle(
                color: SDChatColors.textMuted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
