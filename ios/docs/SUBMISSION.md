# Nurio iOS Submission Guide

This document covers the first App Store Connect submission flow for the standalone Hotwire Native iOS shell in `ios/`.

Current scaffold status in this repository:

- Xcode project: `ios/Nurio.xcodeproj`
- Scheme: `Nurio`
- Production bundle identifier: `com.nurio.ios`
- Default start URL: `https://nurio.kr/events`
- OAuth callback scheme: `nurio://auth-callback`

## 1. Prepare The App For Release

Before creating the release build, update the development scaffold to production values in Xcode:

1. Open `ios/Nurio.xcodeproj`.
2. Select the `Nurio` target.
3. In `Signing & Capabilities`:
   - choose the Apple Developer team
   - confirm the production bundle identifier is `com.nurio.ios`
   - confirm automatic signing or set the provisioning profile required by your release process
4. In `General`:
   - set the production display name if it differs from `Nurio`
   - set `Version` to the App Store marketing version
   - set `Build` to the new build number
5. Verify the URL scheme remains `nurio` in `Info.plist`.
6. If production will use associated domains or universal links, add them before the archive. They are intentionally not configured in this scaffold.

Project-specific checks before submission:

- Cold launch lands on `https://nurio.kr/events`
- Customer event browsing works in-app
- OAuth sign-in works through the native callback path
- Admin and tutor routes are not navigated in-app
- Payment and checkout pages still render inside the customer shell

## 2. Create The App Store Connect App

In App Store Connect, create the iOS app record that matches the production bundle identifier:

1. Create the app if it does not exist yet.
2. Use the same bundle identifier configured in Xcode.
3. Set the app name, primary language, and SKU.
4. Add the support URL, marketing URL if used, and privacy policy URL.
5. Fill in the age rating, category, and App Privacy answers.

You will also need store assets for the first submission:

- app description and keywords
- iPhone screenshots
- app icon
- review notes and a test account if App Review needs one

## 3. Validate The Release Build Locally

Run the repository checks first:

```bash
xcodebuild -project ios/Nurio.xcodeproj -scheme Nurio -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' build
xcodebuild -project ios/Nurio.xcodeproj -scheme Nurio -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' test
```

Then archive the release build from the repo root:

```bash
xcodebuild -project ios/Nurio.xcodeproj -scheme Nurio -configuration Release -destination 'generic/platform=iOS' -archivePath build/Nurio.xcarchive archive
```

If the archive fails, the usual causes are:

- production bundle identifier not registered in the Apple Developer account
- signing team or provisioning not configured
- version/build collision with an already uploaded build

## 4. Upload The Build

There are two practical upload flows for this project.

### Xcode Organizer

1. Open `ios/Nurio.xcodeproj` in Xcode.
2. Select any iOS Device or `Any iOS Device (arm64)` as the run destination.
3. Run `Product > Archive`.
4. In Organizer, select the archive.
5. Choose `Distribute App`.
6. Choose `App Store Connect`.
7. Choose `Upload`.
8. Complete the signing and validation steps.

### Command Line Archive, Xcode Upload

1. Run the `xcodebuild ... archive` command above.
2. Open Organizer in Xcode.
3. Locate the generated `Nurio.xcarchive`.
4. Upload it to App Store Connect from Organizer.

This repository does not include a fully automated upload script because the final signing identity, provisioning, and App Store account settings are environment-specific.

## 5. Configure TestFlight

After the upload appears in App Store Connect:

1. Open the build in the `TestFlight` tab.
2. Complete export compliance.
3. Add internal testers first.
4. If external testers are needed, submit the beta build for Beta App Review.

Use TestFlight to verify the production-signed build still matches the required customer-only scope:

- start page is `/events`
- OAuth callback returns to the signed-in web session
- admin and tutor URLs are blocked from in-app navigation
- checkout and payment flows still behave correctly

## 6. Submit For App Review

Once the tested build is ready:

1. Open the app version in App Store Connect.
2. Attach the uploaded build.
3. Complete the submission questionnaires, including export compliance and content rights if prompted.
4. Add review notes for the web-powered sign-in and checkout flows.
5. Submit the app for review.

Recommended review notes for this app:

- The app is a customer-only shell for the Nurio web experience.
- The default landing page is `https://nurio.kr/events`.
- OAuth sign-in uses an external authentication session and returns through `nurio://auth-callback`.
- Admin and tutor routes are intentionally excluded from the app scope.

## 7. First-Submission Checklist

Use this short checklist before pressing submit:

- Production bundle identifier is set in Xcode and App Store Connect
- Version and build number are updated
- Release archive succeeds locally
- TestFlight build opens `https://nurio.kr/events`
- Customer checkout works
- Google, Kakao, and Naver OAuth round-trips succeed
- Privacy Policy URL and support URL are set
- App Review notes are added

## Official Apple References

- [App Store Connect overview](https://developer.apple.com/app-store-connect/)
- [TestFlight overview](https://developer.apple.com/testflight/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
