import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../auth/models/account_summary.dart';
import '../../events/models/event_summary.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.account,
    required this.events,
    required this.onOpenEvents,
    required this.onOpenEvent,
    required this.onOpenPassPackages,
    required this.onOpenTickets,
    required this.onOpenPayments,
  });

  final AccountSummary? account;
  final List<EventSummary> events;
  final VoidCallback onOpenEvents;
  final ValueChanged<EventSummary> onOpenEvent;
  final VoidCallback onOpenPassPackages;
  final VoidCallback onOpenTickets;
  final VoidCallback onOpenPayments;

  @override
  Widget build(BuildContext context) {
    final greetingName = account?.displayName.isNotEmpty == true
        ? account!.displayName
        : 'Guest';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Text(
            'Welcome, $greetingName',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Explore events, manage your tickets, and continue checkout.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          _QuickActions(
            onOpenEvents: onOpenEvents,
            onOpenPassPackages: onOpenPassPackages,
            onOpenTickets: onOpenTickets,
            onOpenPayments: onOpenPayments,
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upcoming Events',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              TextButton(onPressed: onOpenEvents, child: const Text('See all')),
            ],
          ),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No events loaded yet.')),
            )
          else
            ...events
                .take(3)
                .map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => onOpenEvent(event),
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            if (event.imageUrl != null &&
                                event.imageUrl!.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  event.imageUrl!,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              )
                            else
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5E7EB),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.event_outlined),
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    event.locationName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onOpenEvents,
    required this.onOpenPassPackages,
    required this.onOpenTickets,
    required this.onOpenPayments,
  });

  final VoidCallback onOpenEvents;
  final VoidCallback onOpenPassPackages;
  final VoidCallback onOpenTickets;
  final VoidCallback onOpenPayments;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      childAspectRatio: 2.7,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _ActionButton(
          icon: Icons.event,
          title: 'Browse Events',
          onTap: onOpenEvents,
        ),
        _ActionButton(
          icon: Icons.local_activity_outlined,
          title: 'Pass Packages',
          onTap: onOpenPassPackages,
        ),
        _ActionButton(
          icon: Icons.receipt_long_outlined,
          title: 'Tickets',
          onTap: onOpenTickets,
        ),
        _ActionButton(
          icon: Icons.credit_card_outlined,
          title: 'Payments',
          onTap: onOpenPayments,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GFButton(
      onPressed: onTap,
      fullWidthButton: true,
      color: const Color(0xFFF3F4F6),
      textColor: Colors.black87,
      type: GFButtonType.solid,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
