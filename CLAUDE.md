# CLAUDE.md

## Mission
Migrate and maintain Nurio mobile as a Flutter customer app while preserving existing customer behavior from the Rails web product.

## Hard Constraints
- Customer-facing scope only.
- Exclude all admin surfaces.
- Exclude all tutor/tutoring surfaces.
- Prioritize end-to-end customer flows (event discovery, registration, ticket/pass purchase, payment completion, profile/settings).

## Implementation Guidance
- Flutter app location: `flutter_app/`.
- Keep the web-compatible Flutter shell robust (deep links, external payment redirects, file upload/camera/mic permissions, pull-to-refresh, back navigation).
- Never remove route guards that prevent admin/tutor navigation.
- Preserve legacy path presentation behavior (modal paths from Hotwire path configuration) while in Flutter.

## Feature Parity Standard
A change is incomplete if it breaks any of these user flows:
1. Browse events and open event detail.
2. Register/attend and create order.
3. Complete wallet or PortOne card payment.
4. Access tickets/pass packages/history in settings.
5. Edit user profile/preferences.

## Verification
- `flutter analyze`
- `flutter test`
