import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _activateDemo() async {
    setState(() => _isLoading = true);
    try {
      await _authService.activateDemoSubscription();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.demoActivated),
            backgroundColor: const Color(0xFF7C3AED),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openStripeCheckout() async {
    // TODO: Replace with your Stripe Payment Link or call the
    // stripe-checkout Edge Function to get a dynamic session URL.
    // Example payment link: https://buy.stripe.com/YOUR_LINK
    const stripeUrl = String.fromEnvironment(
      'STRIPE_PAYMENT_LINK',
      defaultValue: '',
    );

    if (stripeUrl.isEmpty) {
      // Stripe not configured yet – fall back to demo activation
      await _activateDemo();
      return;
    }

    final uri = Uri.parse(stripeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = _authService.isRestaurantOwner;
    final isActive = _authService.isSubscriptionActive;
    final subEnd = _authService.subscriptionEnd;
    final status = _authService.subscriptionStatus;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurple.shade600,
                Colors.deepPurple.shade400,
                Colors.purpleAccent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(AppLocalizations.of(context)!.myPlan, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Current plan card ──────────────────────
                _buildCurrentPlanCard(isOwner, isActive, status, subEnd),
                const SizedBox(height: 32),

                if (isActive) ...[
                  // ── Active owner ──────────────────────────
                  _buildFeatureList(active: true),
                  const SizedBox(height: 24),
                  _buildManageButton(),
                ] else if (isOwner) ...[
                  // ── Owner but subscription inactive ────────
                  _buildInactiveOwnerSection(),
                ] else ...[
                  // ── Free customer: upgrade section ─────────
                  _buildUpgradeSection(),
                ],

                const SizedBox(height: 32),
                _buildFreeSection(isOwner),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPlanCard(
      bool isOwner, bool isActive, String? status, DateTime? subEnd) {
    final Color badgeColor =
        isActive ? const Color(0xFF7C3AED) : (isOwner ? Colors.orange : Colors.blueGrey);
    final String planName =
        isOwner ? AppLocalizations.of(context)!.restaurantOwnerLabel : AppLocalizations.of(context)!.freeCustomerLabel;
    final String subLabel = isActive
        ? AppLocalizations.of(context)!.activePlanBadge
        : (isOwner
            ? (status != null ? status[0].toUpperCase() + status.substring(1) : AppLocalizations.of(context)!.inactivePlanBadge)
            : AppLocalizations.of(context)!.freePlanBadge);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade700, Colors.purple.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  planName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  subLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (isActive && subEnd != null) ...[
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.renewsOn(_formatDate(subEnd)),
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ],
          if (!isOwner) ...[
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.upgradeDescription,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpgradeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pricing card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF7C3AED), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                AppLocalizations.of(context)!.restaurantOwnerPlanTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('€',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const Text('4.99',
                      style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: Text(AppLocalizations.of(context)!.perMonth,
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey.shade600)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)!.cancelAnytime,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildFeatureList(active: false),
        const SizedBox(height: 24),
        _buildSubscribeButton(),
        if (kIsWeb) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _activateDemo,
            icon: const Icon(Icons.science_outlined),
            label: Text(AppLocalizations.of(context)!.activateDemoButton),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              side: BorderSide(color: Colors.grey.shade400),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInactiveOwnerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.subscriptionInactiveWarning,
                  style: TextStyle(color: Colors.orange.shade800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildFeatureList(active: false),
        const SizedBox(height: 24),
        _buildSubscribeButton(label: AppLocalizations.of(context)!.reactivateSubscription),
        if (kIsWeb) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _activateDemo,
            icon: const Icon(Icons.science_outlined),
            label: Text(AppLocalizations.of(context)!.activateDemoButton),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              side: BorderSide(color: Colors.grey.shade400),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeatureList({required bool active}) {
    final l10n = AppLocalizations.of(context)!;
    final features = [
      l10n.featureCreateManually,
      l10n.featureUploadPdf,
      l10n.featureEditProfile,
      l10n.featureManageItems,
      l10n.featureAppearInList,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features
          .map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: active ? const Color(0xFF7C3AED) : const Color(0xFF7C3AED),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(f, style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildSubscribeButton({String? label}) {
    final l10n = AppLocalizations.of(context)!;
    final buttonLabel = label ?? l10n.subscribeNow;
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _openStripeCheckout,
              icon: const Icon(Icons.payment),
              label: Text(buttonLabel,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          );
  }

  Widget _buildManageButton() {
    final l10n = AppLocalizations.of(context)!;
    return OutlinedButton.icon(
      onPressed: () {
        // TODO: redirect to Stripe Customer Portal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.stripePortalNotConfigured),
          ),
        );
      },
      icon: const Icon(Icons.manage_accounts),
      label: Text(l10n.manageSubscription),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF7C3AED),
        side: const BorderSide(color: Color(0xFF7C3AED)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildFreeSection(bool isOwner) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.freeCustomerAccountTitle,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          _featureRow(l10n.featureBrowseMenus, true),
          _featureRow(l10n.featureSaveFavourites, true),
          _featureRow(l10n.featureNoCreditCard, true),
        ],
      ),
    );
  }

  Widget _featureRow(String text, bool included) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            included ? Icons.check : Icons.close,
            size: 18,
            color: included ? const Color(0xFF7C3AED) : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}';
  }
}
