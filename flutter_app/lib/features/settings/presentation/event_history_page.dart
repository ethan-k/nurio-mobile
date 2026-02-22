import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../shared/presentation/api_gap_card.dart';

class EventHistoryPage extends StatelessWidget {
  const EventHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GFAppBar(title: const Text('Event History'), centerTitle: false),
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
                      'Attendance History',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Past events, attendance records, and review links will '
                      'appear here once mobile history APIs are available.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ApiGapCard(
              featureLabel: 'Event History',
              legacyRoutes: const ['GET /settings/event_history'],
              requiredApiEndpoints: const ['GET /api/v1/event_history'],
            ),
          ],
        ),
      ),
    );
  }
}
