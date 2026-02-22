# CLAUDE.md

## Mission
Migrate and maintain Nurio mobile as a Flutter customer app with native screens for customer features.

## Hard Constraints
- Customer-facing scope only.
- Exclude all admin surfaces.
- Exclude all tutor/tutoring surfaces.
- Native-only implementation: no WebView fallback.

## Implementation Guidance
- Flutter app location: `flutter_app/`.
- Prioritize end-to-end customer journeys in native Flutter modules:
  - event discovery
  - event detail
  - checkout/payment entry points
  - tickets/pass packages/history/settings hubs
- If backend mobile endpoints are missing, keep the screen native and surface clear API dependency messaging.

## Scope Guard
Never implement or expose:
- `/admin/*`
- `/tutoring*`
- `/tutors*`
- tutoring API namespaces

## Verification
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
