# Nurio Study Leader iOS Submission

## App Record

- Name: `Nurio Study Leader`
- Bundle ID: `com.nurio.studyleader.ios`
- SKU: `nurio-study-leader-ios`
- Version/build: `1.0.0` / `1`
- Primary category: Education
- Secondary category: Productivity
- Privacy URL: `https://study.nurio.kr/privacy-policy`
- Support URL: `https://nurio.kr/faq`

## Release Gate

1. Register the bundle ID and select the Nurio Apple Developer team.
2. Add Sign in with Apple capability when social login is enabled.
3. Verify `nurioleaders://auth-callback` in the release build.
4. Build and test on the current 6.9-inch iPhone simulator.
5. Archive with:

```bash
xcodebuild \
  -project ios/NurioStudyLeader.xcodeproj \
  -scheme NurioStudyLeader \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/NurioStudyLeader.xcarchive \
  archive
```

6. Upload through Xcode Organizer, distribute to internal TestFlight, and run the authenticated checklist before submission.

## Review Notes Template

Nurio Study Leader is the operational workspace for approved leaders who deliver Nurio Study sessions. It provides daily session preparation, recurring schedule management, attendance and session completion, leader-only notifications, earnings history, profile management, and account controls.

Sign-in uses a secure external OAuth session and returns through `nurioleaders://auth-callback`. A review account is provided in App Review Information. Please use the populated sample Today, Schedule, Sessions, Notifications, and Earnings states.

The app has no purchase flow or digital goods. Account deletion is available from Settings.

## Required Review Information

- Stable approved-leader demo email/account and exact provider steps.
- Explanation of any one-time OAuth prompt.
- Contact person reachable during review.
- Confirmation that sample data is fictional and contains no real learner or financial information.
- Six authentic iPhone screenshots and localized EN/KO metadata.
