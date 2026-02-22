class EventTag {
  const EventTag({required this.name, required this.slug, required this.color});

  final String name;
  final String slug;
  final String color;

  factory EventTag.fromJson(Map<String, dynamic> json) {
    return EventTag(
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      color: (json['color'] as String?) ?? '',
    );
  }
}

class EventSummary {
  const EventSummary({
    required this.id,
    required this.title,
    required this.scheduledAt,
    required this.endsAt,
    required this.locationName,
    required this.locationAddress,
    required this.capacity,
    required this.availableSpots,
    required this.isFull,
    required this.imageUrl,
    required this.eventTypeName,
    required this.eventTypeSlug,
    required this.hostDisplayName,
    required this.tags,
  });

  final int id;
  final String title;
  final DateTime scheduledAt;
  final DateTime endsAt;
  final String locationName;
  final String locationAddress;
  final int capacity;
  final int availableSpots;
  final bool isFull;
  final String? imageUrl;
  final String eventTypeName;
  final String eventTypeSlug;
  final String hostDisplayName;
  final List<EventTag> tags;

  factory EventSummary.fromJson(Map<String, dynamic> json) {
    final eventType =
        (json['event_type'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final host =
        (json['host'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    final tagsRaw = json['tags'];
    final tags = <EventTag>[];
    if (tagsRaw is List) {
      for (final item in tagsRaw) {
        if (item is Map<String, dynamic>) {
          tags.add(EventTag.fromJson(item));
        }
      }
    }

    return EventSummary(
      id: _intValue(json['id']),
      title: (json['title'] as String?) ?? '',
      scheduledAt: DateTime.parse(
        (json['scheduled_at'] as String?) ?? '',
      ).toUtc(),
      endsAt: DateTime.parse((json['ends_at'] as String?) ?? '').toUtc(),
      locationName: (json['location_name'] as String?) ?? '',
      locationAddress: (json['location_address'] as String?) ?? '',
      capacity: _intValue(json['capacity']),
      availableSpots: _intValue(json['available_spots']),
      isFull: (json['is_full'] as bool?) ?? false,
      imageUrl: json['image_url'] as String?,
      eventTypeName: (eventType['name'] as String?) ?? '',
      eventTypeSlug: (eventType['slug'] as String?) ?? '',
      hostDisplayName: (host['display_name'] as String?) ?? '',
      tags: tags,
    );
  }

  static int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }
}

class EventsPageResult {
  const EventsPageResult({
    required this.events,
    required this.page,
    required this.perPage,
    required this.totalCount,
    required this.totalPages,
    required this.hasMore,
  });

  final List<EventSummary> events;
  final int page;
  final int perPage;
  final int totalCount;
  final int totalPages;
  final bool hasMore;

  factory EventsPageResult.fromJson(Map<String, dynamic> json) {
    final eventsRaw = json['events'];
    final events = <EventSummary>[];

    if (eventsRaw is List) {
      for (final item in eventsRaw) {
        if (item is Map<String, dynamic>) {
          events.add(EventSummary.fromJson(item));
        }
      }
    }

    final pagination =
        (json['pagination'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return EventsPageResult(
      events: events,
      page: _intValue(pagination['page']),
      perPage: _intValue(pagination['per_page']),
      totalCount: _intValue(pagination['total_count']),
      totalPages: _intValue(pagination['total_pages']),
      hasMore: (pagination['has_more'] as bool?) ?? false,
    );
  }

  static int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }
}
