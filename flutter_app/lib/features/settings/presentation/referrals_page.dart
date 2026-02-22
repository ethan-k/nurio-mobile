import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../../l10n/l10n.dart';
import '../../shared/presentation/api_gap_card.dart';

class ReferralsPage extends StatelessWidget {
  const ReferralsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: GFAppBar(title: Text(l10n.referralsTitle), centerTitle: false),
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
                      l10n.referralsHeader,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(l10n.referralsDescription),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ApiGapCard(
              featureLabel: l10n.referralsFeatureLabel,
              legacyRoutes: const ['GET /settings/referrals'],
              requiredApiEndpoints: const ['GET /api/v1/referrals'],
            ),
          ],
        ),
      ),
    );
  }
}
