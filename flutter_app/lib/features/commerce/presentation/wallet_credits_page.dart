import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../../l10n/l10n.dart';
import '../../shared/presentation/api_gap_card.dart';

class WalletCreditsPage extends StatelessWidget {
  const WalletCreditsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: GFAppBar(
        title: Text(l10n.walletCreditsTitle),
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
                      l10n.walletBalanceHeader,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(l10n.walletCreditsDescription),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ApiGapCard(
              featureLabel: l10n.walletCreditsFeatureLabel,
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
