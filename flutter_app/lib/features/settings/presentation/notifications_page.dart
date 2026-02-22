import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../../l10n/l10n.dart';
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: GFAppBar(
        title: Text(l10n.notificationsTitle),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              title: Text(l10n.notificationsEventRemindersTitle),
              subtitle: Text(l10n.notificationsEventRemindersSubtitle),
              value: _eventReminders,
              onChanged: (value) {
                setState(() {
                  _eventReminders = value;
                });
              },
            ),
            SwitchListTile(
              title: Text(l10n.notificationsPaymentUpdatesTitle),
              subtitle: Text(l10n.notificationsPaymentUpdatesSubtitle),
              value: _paymentUpdates,
              onChanged: (value) {
                setState(() {
                  _paymentUpdates = value;
                });
              },
            ),
            SwitchListTile(
              title: Text(l10n.notificationsMarketingTitle),
              subtitle: Text(l10n.notificationsMarketingSubtitle),
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
                  SnackBar(content: Text(l10n.notificationsSyncApiNotExposed)),
                );
              },
              text: l10n.savePreferences,
              fullWidthButton: true,
            ),
            const SizedBox(height: 12),
            ApiGapCard(
              featureLabel: l10n.notificationPreferencesFeatureLabel,
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
