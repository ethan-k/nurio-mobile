import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';
import '../../events/models/event_summary.dart';
import '../../shared/presentation/api_gap_card.dart';

class EventCheckoutPage extends StatelessWidget {
  const EventCheckoutPage({
    super.key,
    required this.event,
    required this.isAuthenticated,
    required this.onOpenLogin,
    required this.onOpenPassPackages,
  });

  final EventSummary event;
  final bool isAuthenticated;
  final Future<void> Function() onOpenLogin;
  final VoidCallback onOpenPassPackages;

  @override
  Widget build(BuildContext context) {
    final localeName = Localizations.localeOf(context).toString();
    final startsAt = DateFormat(
      'EEE, MMM d • h:mm a',
      localeName,
    ).format(event.scheduledAt.toLocal());
    final l10n = context.l10n;

    return Scaffold(
      appBar: GFAppBar(title: Text(l10n.checkoutTitle), centerTitle: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              event.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '$startsAt • ${event.locationName.isEmpty ? event.locationAddress : event.locationName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (!isAuthenticated) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.checkoutSignInRequired),
                      const SizedBox(height: 10),
                      GFButton(
                        onPressed: () => onOpenLogin(),
                        text: l10n.signIn,
                        fullWidthButton: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ApiGapCard(
              featureLabel: l10n.checkoutFeatureLabel,
              legacyRoutes: const [
                'GET /orders/new',
                'POST /orders',
                'GET /orders/:id/payment_summary',
                'POST /orders/:id/pay_with_wallet',
                'POST /orders/:id/reserve_wallet_for_split',
                'GET|POST /payments/portone/complete',
              ],
              requiredApiEndpoints: const [
                'POST /api/v1/orders',
                'GET /api/v1/orders/:id/payment_summary',
                'POST /api/v1/orders/:id/pay_with_wallet',
                'POST /api/v1/orders/:id/reserve_wallet_for_split',
                'POST /api/v1/payments/portone/complete',
              ],
            ),
            const SizedBox(height: 12),
            GFButton(
              onPressed: () =>
                  _showBackendGap(context, l10n.checkoutPaymentMethodWallet),
              text: l10n.checkoutWalletButton,
              fullWidthButton: true,
            ),
            const SizedBox(height: 10),
            GFButton(
              onPressed: () =>
                  _showBackendGap(context, l10n.checkoutPaymentMethodCard),
              text: l10n.checkoutCardButton,
              type: GFButtonType.outline,
              fullWidthButton: true,
            ),
            const SizedBox(height: 10),
            GFButton(
              onPressed: onOpenPassPackages,
              text: l10n.checkoutBrowsePassPackagesButton,
              type: GFButtonType.transparent,
              fullWidthButton: true,
            ),
          ],
        ),
      ),
    );
  }

  void _showBackendGap(BuildContext context, String paymentMethod) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.checkoutBackendGap(paymentMethod))),
    );
  }
}
