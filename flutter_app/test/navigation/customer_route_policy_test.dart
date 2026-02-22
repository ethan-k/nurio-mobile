import 'package:flutter_test/flutter_test.dart';
import 'package:nurio_mobile/navigation/customer_route_policy.dart';
import 'package:nurio_mobile/navigation/nav_destination.dart';

void main() {
  final policy = CustomerRoutePolicy(baseUri: Uri.parse('https://nurio.kr'));

  group('CustomerRoutePolicy', () {
    test('allows customer event routes', () {
      expect(
        policy.isAllowedInternal(Uri.parse('https://nurio.kr/events')),
        isTrue,
      );
      expect(
        policy.isAllowedInternal(Uri.parse('https://nurio.kr/orders/new')),
        isTrue,
      );
      expect(
        policy.isAllowedInternal(Uri.parse('https://nurio.kr/pass_packages')),
        isTrue,
      );
    });

    test('blocks admin routes', () {
      expect(
        policy.isAllowedInternal(Uri.parse('https://nurio.kr/admin/events')),
        isFalse,
      );
      expect(
        policy.isAllowedInternal(Uri.parse('https://admin.nurio.kr/events')),
        isFalse,
      );
    });

    test('blocks tutor routes and subdomain', () {
      expect(
        policy.isAllowedInternal(Uri.parse('https://nurio.kr/tutoring')),
        isFalse,
      );
      expect(
        policy.isAllowedInternal(
          Uri.parse('https://nurio.kr/english-tutoring'),
        ),
        isFalse,
      );
      expect(
        policy.isAllowedInternal(Uri.parse('https://tutors.nurio.kr/bookings')),
        isFalse,
      );
    });

    test('marks non-nurio domains and non-http schemes as external', () {
      expect(
        policy.shouldOpenExternally(Uri.parse('https://example.com/page')),
        isTrue,
      );
      expect(policy.shouldOpenExternally(Uri.parse('intent://pay')), isTrue);
      expect(
        policy.shouldOpenExternally(Uri.parse('kakaotalk://send')),
        isTrue,
      );
      expect(
        policy.shouldOpenExternally(Uri.parse('https://nurio.kr/events')),
        isFalse,
      );
    });

    test('maps selected tab destinations', () {
      expect(
        policy.destinationFor(Uri.parse('https://nurio.kr/home')),
        NavDestination.home,
      );
      expect(
        policy.destinationFor(
          Uri.parse('https://nurio.kr/settings/profile/edit'),
        ),
        NavDestination.profile,
      );
      expect(
        policy.destinationFor(Uri.parse('https://nurio.kr/events/10')),
        NavDestination.events,
      );
    });

    test('matches modal route patterns from legacy hotwire path config', () {
      expect(
        policy.shouldPresentAsModal(Uri.parse('https://nurio.kr/orders/new')),
        isTrue,
      );
      expect(
        policy.shouldPresentAsModal(
          Uri.parse('https://nurio.kr/orders/123/payment_summary'),
        ),
        isTrue,
      );
      expect(
        policy.shouldPresentAsModal(
          Uri.parse('https://nurio.kr/events/100/reviews/new'),
        ),
        isTrue,
      );
      expect(
        policy.shouldPresentAsModal(
          Uri.parse('https://nurio.kr/onboardings/wizard?step=profile'),
        ),
        isTrue,
      );
      expect(
        policy.shouldPresentAsModal(Uri.parse('https://nurio.kr/events/100')),
        isFalse,
      );
    });
  });
}
