import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../shared/presentation/api_gap_card.dart';

class WalletCreditsPage extends StatelessWidget {
  const WalletCreditsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GFAppBar(title: const Text('Wallet Credits'), centerTitle: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Wallet Balance',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Wallet balance, ledger, and credit expiry will be shown '
                      'here via mobile API responses.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ApiGapCard(
              featureLabel: 'Wallet Credits',
              legacyRoutes: const [
                'GET /settings/wallet_credits',
                'POST /orders/:id/pay_with_wallet',
                'POST /pass_packages/:id/pay_with_wallet',
              ],
              requiredApiEndpoints: const [
                'GET /api/v1/wallet_credits',
                'POST /api/v1/orders/:id/pay_with_wallet',
                'POST /api/v1/pass_packages/:id/pay_with_wallet',
              ],
            ),
          ],
        ),
      ),
    );
  }
}
