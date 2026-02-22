import '../../../core/network/api_client.dart';
import '../models/event_summary.dart';

class EventsRepository {
  EventsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<EventsPageResult> fetchEvents({
    required int page,
    required int perPage,
    String? keyword,
    String? eventType,
    List<String>? tags,
  }) async {
    final json = await _apiClient.getJson(
      '/api/v1/events',
      queryParameters: <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
        if (eventType != null && eventType.trim().isNotEmpty)
          'event_type': eventType,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
      },
    );

    return EventsPageResult.fromJson(json);
  }
}
