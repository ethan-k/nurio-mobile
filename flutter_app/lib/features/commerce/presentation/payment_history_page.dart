import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../../l10n/l10n.dart';
import '../../shared/presentation/api_gap_card.dart';

class PaymentHistoryPage extends StatelessWidget {
  const PaymentHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: GFAppBar(
        title: Text(l10n.paymentHistoryTitle),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.paymentsHeader,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(l10n.paymentsDescription),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ApiGapCard(
              featureLabel: l10n.paymentHistoryFeatureLabel,
              legacyRoutes: const ['GET /settings/payments', 'GET /orders/:id'],
              requiredApiEndpoints: const [
                'GET /api/v1/payments',
                'GET /api/v1/orders/:id',
              ],
            ),
          ],
        ),
      ),
    );
  }
}
