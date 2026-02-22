import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:intl/intl.dart';

import '../models/event_summary.dart';

class EventDetailPage extends StatelessWidget {
  const EventDetailPage({
    super.key,
    required this.event,
    required this.onOpenCheckout,
    required this.onOpenPassPackages,
  });

  final EventSummary event;
  final VoidCallback onOpenCheckout;
  final VoidCallback onOpenPassPackages;

  @override
  Widget build(BuildContext context) {
    final starts = DateFormat(
      'EEE, MMM d • h:mm a',
    ).format(event.scheduledAt.toLocal());
    final ends = DateFormat('h:mm a').format(event.endsAt.toLocal());

    return Scaffold(
      appBar: GFAppBar(title: const Text('Event Details'), centerTitle: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  event.imageUrl!,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              event.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.schedule, label: '$starts - $ends'),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: event.locationName.isNotEmpty
                  ? event.locationName
                  : event.locationAddress,
            ),
            _InfoRow(icon: Icons.person_outline, label: event.hostDisplayName),
            _InfoRow(
              icon: Icons.event_available,
              label: event.isFull
                  ? 'This event is currently full'
                  : '${event.availableSpots} spots remaining',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tag(text: event.eventTypeName),
                for (final tag in event.tags) _Tag(text: tag.name),
              ],
            ),
            const SizedBox(height: 24),
            GFButton(
              onPressed: onOpenCheckout,
              text: 'Get Tickets / Continue to Payment',
              fullWidthButton: true,
            ),
            const SizedBox(height: 10),
            GFButton(
              onPressed: onOpenPassPackages,
              text: 'View Pass Packages',
              type: GFButtonType.outline,
              fullWidthButton: true,
            ),
            const SizedBox(height: 10),
            Text(
              'Checkout and payment run natively in Flutter. '
              'No WebView fallback is used in this app.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF1D4ED8),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
