import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../../l10n/l10n.dart';
import '../../shared/presentation/api_gap_card.dart';

class TicketsPage extends StatelessWidget {
  const TicketsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: GFAppBar(title: Text(l10n.ticketsTitle), centerTitle: false),
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
                      l10n.ticketsHeader,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(l10n.ticketsDescription),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ApiGapCard(
              featureLabel: l10n.ticketsFeatureLabel,
              legacyRoutes: const [
                'GET /settings/tickets',
                'POST /settings/tickets/:id/refund',
                'GET /tickets/:id/confirmation',
              ],
              requiredApiEndpoints: const [
                'GET /api/v1/tickets',
                'POST /api/v1/tickets/:id/refund',
                'GET /api/v1/tickets/:id/confirmation',
              ],
            ),
          ],
        ),
      ),
    );
  }
}
