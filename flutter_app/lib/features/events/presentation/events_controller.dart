import 'package:flutter/foundation.dart';

import '../data/events_repository.dart';
import '../models/event_summary.dart';

class EventsController extends ChangeNotifier {
  EventsController({required EventsRepository repository})
    : _repository = repository;

  final EventsRepository _repository;

  final List<EventSummary> _events = <EventSummary>[];

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String _keyword = '';
  String? _errorMessage;

  List<EventSummary> get events => List<EventSummary>.unmodifiable(_events);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String get keyword => _keyword;
  String? get errorMessage => _errorMessage;

  Future<void> loadInitial({String keyword = ''}) async {
    _keyword = keyword;
    _isLoading = true;
    _errorMessage = null;
    _currentPage = 0;
    _hasMore = true;
    _events.clear();
    notifyListeners();

    try {
      final result = await _repository.fetchEvents(
        page: 1,
        perPage: 20,
        keyword: _keyword,
      );

      _events
        ..clear()
        ..addAll(result.events);
      _currentPage = result.page;
      _hasMore = result.hasMore;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final result = await _repository.fetchEvents(
        page: nextPage,
        perPage: 20,
        keyword: _keyword,
      );

      _events.addAll(result.events);
      _currentPage = result.page;
      _hasMore = result.hasMore;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refresh() {
    return loadInitial(keyword: _keyword);
  }
}
