# Nurio Study Leader iOS Submission

## App Record

- Name: `Nurio Study Leader`
- Bundle ID: `com.nurio.studyleaders.ios`
- SKU: `nurio-study-leader-ios`
- Version/build: `1.0.0` / `1`
- Primary category: Education
- Secondary category: Productivity
- Privacy URL: `https://study.nurio.kr/privacy-policy`
- Support URL: `https://nurio.kr/faq`

## Release Gate

1. Register the bundle ID and select the Nurio Apple Developer team.
2. Add Sign in with Apple capability when social login is enabled.
3. Inject the dedicated Kakao Native app key, Google iOS client ID, matching
   Web/server client ID, and Google reversed client ID through the protected
   native-auth xcconfig.
4. Verify both the Google reversed-client-ID URL scheme and the independent
   `nurioleaders://auth-callback` Rails handoff in the release build.
5. Build and test on the current 6.9-inch iPhone simulator.
6. Archive with:

```bash
xcodebuild \
  -project ios/NurioStudyLeader.xcodeproj \
  -scheme NurioStudyLeader \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/NurioStudyLeader.xcarchive \
  archive
```

7. Upload through Xcode Organizer, distribute to internal TestFlight, and run the authenticated checklist before submission.

## Review Notes Template

Nurio Study Leader is the operational workspace for approved leaders who deliver Nurio Study sessions. It provides daily session preparation, recurring schedule management, attendance and session completion, leader-only notifications, earnings history, profile management, and account controls.

Google and Kakao sign-in use their native iOS SDKs; Naver uses a secure system authentication session. All successful paths finish through a short-lived Rails handoff to `nurioleaders://auth-callback`. App Review does not need to complete social-provider 2FA. On the login screen, tap the Nurio Study Leader brand five times within four seconds, then enter the review credentials provided in App Review Information. The review account contains fictional Today, Schedule, Sessions, Notifications, and Earnings data.

The app has no purchase flow or digital goods. Account deletion is available from Settings.

## Required Review Information

- Stable approved-leader review email and password plus the five-tap brand gesture.
- Explanation of any one-time OAuth prompt.
- Contact person reachable during review.
- Confirmation that sample data is fictional and contains no real learner or financial information.
- Six authentic iPhone screenshots and localized EN/KO metadata.
