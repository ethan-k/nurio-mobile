import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../shared/presentation/api_gap_card.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _eventReminders = true;
  bool _paymentUpdates = true;
  bool _marketing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GFAppBar(title: const Text('Notifications'), centerTitle: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              title: const Text('Event reminders'),
              subtitle: const Text(
                'Upcoming event reminders and check-in notices.',
              ),
              value: _eventReminders,
              onChanged: (value) {
                setState(() {
                  _eventReminders = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Payment updates'),
              subtitle: const Text(
                'Order/payment completion and refund updates.',
              ),
              value: _paymentUpdates,
              onChanged: (value) {
                setState(() {
                  _paymentUpdates = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Marketing updates'),
              subtitle: const Text('Campaigns and pass-package promotions.'),
              value: _marketing,
              onChanged: (value) {
                setState(() {
                  _marketing = value;
                });
              },
            ),
            const SizedBox(height: 10),
            GFButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Notification preference sync API is not exposed yet.',
                    ),
                  ),
                );
              },
              text: 'Save Preferences',
              fullWidthButton: true,
            ),
            const SizedBox(height: 12),
            ApiGapCard(
              featureLabel: 'Notification Preferences',
              legacyRoutes: const [
                'GET /settings/notifications',
                'GET /account_notifications',
                'PATCH /account_notifications/:id',
              ],
              requiredApiEndpoints: const [
                'GET /api/v1/settings/notifications',
                'GET /api/v1/account_notifications',
                'PATCH /api/v1/account_notifications/:id',
              ],
            ),
          ],
        ),
      ),
    );
  }
}
