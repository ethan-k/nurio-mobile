# AGENTS.md

## Product Scope (Required)
- This repository now includes a Flutter customer app at `flutter_app/`.
- Implement and maintain customer-facing features only.
- Do not build, expose, or migrate admin features (`/admin/*`).
- Do not build, expose, or migrate tutor features (`/tutoring*`, `/tutors*`, `tutors.<domain>`).

## Source of Truth
- Customer feature inventory is defined from `/Users/ws/es/business/nurioworkspace/nurio/config/routes.rb`.
- Payment behavior is defined by:
  - `/Users/ws/es/business/nurioworkspace/nurio/app/controllers/orders_controller.rb`
  - `/Users/ws/es/business/nurioworkspace/nurio/app/controllers/payments/portone_controller.rb`
  - `/Users/ws/es/business/nurioworkspace/nurio/app/javascript/controllers/portone_payment_controller.js`

## Architecture Rule
- Preserve broad customer feature support through the Flutter WebView shell unless a native screen is explicitly requested.
- Keep navigation guards that block admin/tutor routes in Flutter route policy code.
- Keep legacy modal route behavior parity from `shared/path-configuration.json`.

## Validation Checklist
- `cd flutter_app && flutter analyze`
- `cd flutter_app && flutter test`
- Verify event browsing -> event detail -> order -> payment summary -> payment completion redirect.
