import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:intl/intl.dart';

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
    final startsAt = DateFormat(
      'EEE, MMM d • h:mm a',
    ).format(event.scheduledAt.toLocal());

    return Scaffold(
      appBar: GFAppBar(title: const Text('Checkout'), centerTitle: false),
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
                      const Text(
                        'Sign in is required before creating an order or paying.',
                      ),
                      const SizedBox(height: 10),
                      GFButton(
                        onPressed: () => onOpenLogin(),
                        text: 'Sign In',
                        fullWidthButton: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ApiGapCard(
              featureLabel: 'Checkout and Payment',
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
              onPressed: () => _showBackendGap(context, 'wallet payment'),
              text: 'Pay with Wallet Credits',
              fullWidthButton: true,
            ),
            const SizedBox(height: 10),
            GFButton(
              onPressed: () => _showBackendGap(context, 'PortOne card payment'),
              text: 'Pay with Card (PortOne)',
              type: GFButtonType.outline,
              fullWidthButton: true,
            ),
            const SizedBox(height: 10),
            GFButton(
              onPressed: onOpenPassPackages,
              text: 'Browse Pass Packages',
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
      SnackBar(
        content: Text(
          'Cannot execute $paymentMethod yet. Mobile checkout API endpoints '
          'must be added on the backend.',
        ),
      ),
    );
  }
}
