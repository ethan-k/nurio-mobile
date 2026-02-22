import 'package:flutter_test/flutter_test.dart';
import 'package:nurio_mobile/features/events/models/event_summary.dart';

void main() {
  test('parses events page payload', () {
    final payload = <String, dynamic>{
      'events': [
        {
          'id': 12,
          'title': 'Language Exchange Night',
          'scheduled_at': '2026-02-22T10:00:00Z',
          'ends_at': '2026-02-22T12:00:00Z',
          'location_name': 'Hongdae',
          'location_address': 'Seoul',
          'capacity': 30,
          'available_spots': 8,
          'is_full': false,
          'image_url': 'https://example.com/image.jpg',
          'event_type': {'name': 'Social', 'slug': 'social'},
          'host': {'display_name': 'Nurio Team'},
          'tags': [
            {'name': 'Korean', 'slug': 'korean', 'color': '#111111'},
          ],
        },
      ],
      'pagination': {
        'page': 1,
        'per_page': 20,
        'total_count': 1,
        'total_pages': 1,
        'has_more': false,
      },
    };

    final result = EventsPageResult.fromJson(payload);

    expect(result.events, hasLength(1));
    expect(result.events.first.id, 12);
    expect(result.events.first.eventTypeName, 'Social');
    expect(result.events.first.tags, hasLength(1));
    expect(result.hasMore, isFalse);
  });
}
