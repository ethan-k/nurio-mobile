import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../shared/presentation/api_gap_card.dart';

class TicketsPage extends StatelessWidget {
  const TicketsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GFAppBar(title: const Text('Tickets'), centerTitle: false),
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
                      'My Tickets',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tickets are linked to completed orders and refunds. '
                      'This native view is ready and awaits customer ticket APIs.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ApiGapCard(
              featureLabel: 'Tickets',
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
