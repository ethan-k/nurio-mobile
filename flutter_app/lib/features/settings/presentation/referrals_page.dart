import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../shared/presentation/api_gap_card.dart';

class ReferralsPage extends StatelessWidget {
  const ReferralsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GFAppBar(title: const Text('Referrals'), centerTitle: false),
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
                      'Referral Program',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Share your referral code and track earned wallet credits '
                      'from invited members.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ApiGapCard(
              featureLabel: 'Referrals',
              legacyRoutes: const ['GET /settings/referrals'],
              requiredApiEndpoints: const ['GET /api/v1/referrals'],
            ),
          ],
        ),
      ),
    );
  }
}
