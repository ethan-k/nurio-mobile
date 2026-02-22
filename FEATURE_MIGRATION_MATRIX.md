# Customer Feature Migration Matrix (Rails -> Flutter)

## Investigation Sources
- `/Users/ws/es/business/nurioworkspace/nurio/config/routes.rb`
- `/Users/ws/es/business/nurioworkspace/nurio/app/controllers/orders_controller.rb`
- `/Users/ws/es/business/nurioworkspace/nurio/app/controllers/pass_packages_controller.rb`
- `/Users/ws/es/business/nurioworkspace/nurio/app/controllers/payments/portone_controller.rb`
- `/Users/ws/es/business/nurioworkspace/nurio/app/javascript/controllers/portone_payment_controller.js`

## Scope Decision
- Included: customer-facing routes and flows.
- Excluded: admin and tutoring/tutor surfaces.
- Native-only constraint: no WebView fallback.

## Backend API Reality (Current)
Available mobile JSON API endpoints:
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `GET /api/v1/auth/me`
- `DELETE /api/v1/auth/logout`
- `GET /api/v1/events`

Not yet available as customer mobile JSON APIs:
- Orders, payment summary, wallet/split payment, PortOne completion
- Pass package listing/purchase for customer flows
- Tickets, payment history, wallet credits, referrals, event history, notification preferences, profile update

## Flutter Coverage (`flutter_app/`)

### Implemented Native + API Ready
- Auth session lifecycle (login/refresh/me/logout)
- Event browsing with search and pagination
- Event detail presentation
- Customer tab shell (home/events/profile)

### Implemented Native + API Gap State
- Event checkout/payment entry (`EventCheckoutPage`)
- Pass packages screen (`PassPackagesPage`)
- Tickets screen (`TicketsPage`)
- Payment history screen (`PaymentHistoryPage`)
- Wallet credits screen (`WalletCreditsPage`)
- Edit profile screen (`EditProfilePage`)
- Notifications screen (`NotificationsPage`)
- Referrals screen (`ReferralsPage`)
- Event history screen (`EventHistoryPage`)

API-gap states are explicit in-app via `ApiGapCard` and do not use WebView fallback.

## Explicitly Blocked from Migration
- `/admin/*`
- `/tutoring*`, `/tutors*`, `tutors.<domain>`
- tutoring API namespace routes (`/api/v1/tutors*`, `/api/v1/bookings*`, `/api/v1/slot_holds*`, `/api/v1/credits*`, `/api/v1/tutor*`)

## Removed Legacy WebView Components
- `flutter_app/lib/ui/nurio_shell_page.dart`
- `flutter_app/lib/features/web/presentation/web_flow_page.dart`
- `flutter_app/lib/navigation/customer_route_policy.dart`
- `flutter_app/lib/navigation/nav_destination.dart`

## Next Backend Requirements for Full Payment Completion
Required customer mobile APIs to move from native placeholders to full native execution:
- `POST /api/v1/orders`
- `GET /api/v1/orders/:id/payment_summary`
- `POST /api/v1/orders/:id/pay_with_wallet`
- `POST /api/v1/orders/:id/reserve_wallet_for_split`
- `POST /api/v1/payments/portone/complete`
- `GET /api/v1/pass_packages`
- `POST /api/v1/pass_packages/:id/orders`
- `GET /api/v1/tickets`
- `GET /api/v1/payments`
- `GET /api/v1/wallet_credits`
- `GET /api/v1/referrals`
- `GET /api/v1/event_history`
- `PATCH /api/v1/profile`
- `GET /api/v1/settings/notifications`
