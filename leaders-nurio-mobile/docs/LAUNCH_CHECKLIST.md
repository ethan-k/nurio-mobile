# Nurio Study Leader Launch Checklist

## Store and Identity

- [ ] Reserve Apple bundle ID `com.nurio.studyleader.ios`.
- [ ] Reserve Play package `com.nurio.studyleader.android`.
- [ ] Create App Store Connect and Play Console records named `Nurio Study Leader`.
- [ ] Configure Apple signing and Android upload/app-signing keys outside Git.
- [ ] Confirm `nurioleaders://auth-callback` is registered on both platforms and in Rails.
- [ ] Publish Android Digital Asset Links for the release signing certificate before relying on verified `https://studyleaders.nurio.kr` app links.
- [ ] Restrict distribution to iPhone and Android phone for 1.0.

## Authentication and Review Access

- [ ] Enable Sign in with Apple in the public iOS build when other social providers are present, or document a valid Guideline 4.8 exemption.
- [ ] Allowlist the exact Google, Kakao, and Naver production callback URLs documented in `OAUTH_AND_REVIEW_LOGIN.md`.
- [ ] Confirm every provider link sends `platform=native` through the `sign-in-with-oauth` bridge on iOS and Android.
- [ ] Create the Google iOS OAuth client for `com.nurio.studyleader.ios` and inject its client ID, matching Web/server client ID, and reversed client ID.
- [ ] Create a dedicated Study Leader Kakao Native app key; register both native identifiers and all Android signing hashes.
- [ ] Confirm iOS Google and both Kakao clients exchange native provider tokens through the Rails native-auth endpoints.
- [ ] Create a stable approved-leader review account with no real personal or financial data.
- [ ] Populate that account with safe sample Today, Schedule, Notifications, Sessions, and Earnings content.
- [ ] Confirm the five-tap brand gesture reveals the review form in TestFlight and an internal Play build.
- [ ] Confirm wrong credentials, a non-leader review account, and missing review secrets cannot establish a session.
- [ ] Put exact review credentials and any required navigation steps in both store consoles.
- [ ] Verify account deletion can be initiated from Leader Settings.

## App Quality

- [ ] iOS build and tests pass on the current App Store toolchain.
- [ ] Android unit tests, debug build, lint, and release bundle pass with target SDK 36.
- [ ] Cold launch, warm launch, logout, expired session, OAuth cancel/failure, and callback replay are safe.
- [ ] External links and `/admin` never remain in the in-app web view.
- [ ] Native top bars remain hidden after every Hotwire push/modal transition.
- [ ] Schedule gestures, keyboard, file uploads, and safe-area insets work on small and large phones.
- [ ] EN and KO render without missing translations.
- [ ] Production URLs, privacy policy, support URL, and TLS are reachable.

## Policy

- [ ] Apple review notes explain the operational utility beyond a repackaged site: native authentication handoff, app-scoped navigation, deep links, and focused session operations.
- [ ] Store screenshots show only real release UI and representative sample data.
- [ ] No price, ranking, “best,” “#1,” “free,” CTA, or Android references appear in Apple metadata.
- [ ] Google metadata and graphics contain no time-sensitive promotion or misleading feature claims.
- [ ] Apple App Privacy and Google Data Safety answers cover account/contact information, identifiers, user content, diagnostics, and analytics actually collected.
- [ ] Privacy manifest and third-party SDK declarations match the final binary.
- [ ] Content rating and target-audience answers exclude children unless the product policy changes.

## Release Sequence

1. Deploy the Rails native contract and verify production host/OAuth behavior.
2. Upload internal Android and TestFlight builds.
3. Complete authenticated QA and fix parity gaps.
4. Capture final screenshots from the approved release candidates.
5. Upload metadata/assets, privacy answers, review credentials, and review notes.
6. Submit Play production review and App Store review.
7. Monitor crashes, ANRs, authentication failures, and store-review messages daily through launch.
