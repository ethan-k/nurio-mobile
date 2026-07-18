# Nurio Mobile Auth-Aware Cold Start Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route main-app cold launches through `https://nurio.kr/` so Rails sends signed-out members to `/login` and signed-in members to `/events`.

**Architecture:** Keep Rails as the source of truth for session state. The iOS and Android Hotwire navigators will start at the configured site root, while explicit deep links, callbacks, notifications, and invalid-link `/events` fallbacks keep their existing behavior.

**Tech Stack:** Swift, XCTest, Hotwire Native iOS, Kotlin, JUnit 4, Hotwire Native Android, Rails request specs

---

## File Structure

- Modify `ios/AppEnvironment.swift`: expose distinct root cold-start and `/events` fallback URLs.
- Modify `ios/SceneController.swift`: initialize the main navigator with the root cold-start URL.
- Modify `ios/AppRouteCoordinator.swift`: preserve `/events` for invalid and blocked deep-link fallbacks.
- Modify `ios/Tests/NurioTests.swift`: prove the root cold-start URL and unchanged events fallback.
- Create `android/app/src/main/java/com/nurio/android/AppEnvironment.kt`: normalize the configured base URL into a root cold-start location.
- Modify `android/app/src/main/java/com/nurio/android/MainActivity.kt`: initialize the navigator with the tested root location.
- Create `android/app/src/test/java/com/nurio/android/AppEnvironmentTest.kt`: prove root normalization with and without a trailing slash.
- Modify `android/app/build.gradle.kts`: add JUnit 4 for Android local unit tests.
- Modify `ios/README.md`: document the authentication-aware native entry point.
- Modify `ios/docs/SUBMISSION.md`: update cold-launch, TestFlight, and App Review checks.

### Task 1: iOS cold-start routing

**Files:**
- Modify: `ios/Tests/NurioTests.swift`
- Modify: `ios/AppEnvironment.swift`
- Modify: `ios/SceneController.swift`
- Modify: `ios/AppRouteCoordinator.swift`

- [ ] **Step 1: Write failing iOS URL tests**

Add these tests to `NurioTests`:

```swift
func testColdStartURLUsesServerAuthenticationGate() {
    let baseURL = URL(string: "https://nurio.kr")!

    XCTAssertEqual(
        AppEnvironment.coldStartURL(for: baseURL).absoluteString,
        "https://nurio.kr"
    )
}

func testInvalidDeepLinkFallbackRemainsEvents() {
    let baseURL = URL(string: "https://nurio.kr")!

    XCTAssertEqual(
        AppEnvironment.eventsURL(for: baseURL).absoluteString,
        "https://nurio.kr/events"
    )
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
xcodebuild -project ios/Nurio.xcodeproj -scheme Nurio \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' \
  -only-testing:NurioTests/NurioTests/testColdStartURLUsesServerAuthenticationGate \
  -only-testing:NurioTests/NurioTests/testInvalidDeepLinkFallbackRemainsEvents \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL to compile because `AppEnvironment` does not yet define `coldStartURL(for:)` or `eventsURL(for:)`.

- [ ] **Step 3: Add the minimal iOS URL implementation**

Replace the existing `startURL` property in `AppEnvironment` with:

```swift
static var coldStartURL: URL {
    coldStartURL(for: baseURL)
}

static func coldStartURL(for baseURL: URL) -> URL {
    baseURL
}

static var eventsURL: URL {
    eventsURL(for: baseURL)
}

static func eventsURL(for baseURL: URL) -> URL {
    baseURL.appendingPathComponent("events")
}
```

In `SceneController`, configure the navigator with:

```swift
startLocation: AppEnvironment.coldStartURL
```

In both `AppRouteCoordinator` invalid/blocked fallback branches, route to:

```swift
AppEnvironment.eventsURL
```

- [ ] **Step 4: Run the full iOS test target and verify GREEN**

Run:

```bash
xcodebuild -project ios/Nurio.xcodeproj -scheme Nurio \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' \
  test CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST SUCCEEDED **` with all `NurioTests` passing.

- [ ] **Step 5: Commit the iOS behavior**

```bash
git add ios/AppEnvironment.swift ios/SceneController.swift ios/AppRouteCoordinator.swift ios/Tests/NurioTests.swift
git commit -m "fix(ios): use auth-aware cold start"
```

### Task 2: Android cold-start routing

**Files:**
- Modify: `android/app/build.gradle.kts`
- Create: `android/app/src/test/java/com/nurio/android/AppEnvironmentTest.kt`
- Create: `android/app/src/main/java/com/nurio/android/AppEnvironment.kt`
- Modify: `android/app/src/main/java/com/nurio/android/MainActivity.kt`

- [ ] **Step 1: Add Android unit-test infrastructure and failing tests**

Add this dependency to `android/app/build.gradle.kts`:

```kotlin
testImplementation("junit:junit:4.13.2")
```

Create `android/app/src/test/java/com/nurio/android/AppEnvironmentTest.kt`:

```kotlin
package com.nurio.android

import org.junit.Assert.assertEquals
import org.junit.Test

class AppEnvironmentTest {
    @Test
    fun `cold start location uses the base URL root`() {
        assertEquals(
            "https://nurio.kr/",
            AppEnvironment.coldStartLocation("https://nurio.kr")
        )
    }

    @Test
    fun `cold start location normalizes a trailing slash`() {
        assertEquals(
            "https://nurio.kr/",
            AppEnvironment.coldStartLocation("https://nurio.kr/")
        )
    }
}
```

- [ ] **Step 2: Run the focused Android test and verify RED**

Run from `android/`:

```bash
ANDROID_HOME=/Users/ws/Library/Android/sdk ./gradlew \
  :app:testDebugUnitTest \
  --tests 'com.nurio.android.AppEnvironmentTest'
```

Expected: FAIL to compile because `AppEnvironment` does not exist.

- [ ] **Step 3: Add the minimal Android implementation**

Create `android/app/src/main/java/com/nurio/android/AppEnvironment.kt`:

```kotlin
package com.nurio.android

internal object AppEnvironment {
    fun coldStartLocation(baseUrl: String): String {
        return "${baseUrl.trimEnd('/')}/"
    }
}
```

Change `MainActivity.navigatorConfigurations()` to use:

```kotlin
startLocation = AppEnvironment.coldStartLocation(BuildConfig.BASE_URL),
```

- [ ] **Step 4: Run Android unit tests and verify GREEN**

Run from `android/`:

```bash
ANDROID_HOME=/Users/ws/Library/Android/sdk ./gradlew :app:testDebugUnitTest
```

Expected: `BUILD SUCCESSFUL` with `AppEnvironmentTest` passing.

- [ ] **Step 5: Commit the Android behavior**

```bash
git add android/app/build.gradle.kts android/app/src/main/java/com/nurio/android/AppEnvironment.kt android/app/src/main/java/com/nurio/android/MainActivity.kt android/app/src/test/java/com/nurio/android/AppEnvironmentTest.kt
git commit -m "fix(android): use auth-aware cold start"
```

### Task 3: Launch documentation

**Files:**
- Modify: `ios/README.md`
- Modify: `ios/docs/SUBMISSION.md`

- [ ] **Step 1: Update the runtime contract**

In `ios/README.md`, replace the `/events` start URL description with:

```markdown
- Start URL: `https://nurio.kr/` (signed-out members continue to `/login`; signed-in members continue to `/events`)
```

In `ios/docs/SUBMISSION.md`, update every cold-launch, default landing, and TestFlight assertion so it states:

```markdown
- Cold launch opens `https://nurio.kr/`: signed-out members continue to `/login`, while signed-in members continue to `/events`.
```

Keep statements about explicit OAuth callbacks, customer-only scope, checkout, and blocked admin/tutor routes unchanged.

- [ ] **Step 2: Verify stale launch claims are removed**

Run:

```bash
rg -n 'Start URL: `https://nurio\.kr/events`|Cold launch lands on `https://nurio\.kr/events`|start page is `/events`|default landing page is `https://nurio\.kr/events`|TestFlight build opens `https://nurio\.kr/events`' ios/README.md ios/docs/SUBMISSION.md
```

Expected: no matches.

- [ ] **Step 3: Commit the documentation**

```bash
git add ios/README.md ios/docs/SUBMISSION.md
git commit -m "docs(mobile): document auth-aware launch"
```

### Task 4: Cross-system verification

**Files:**
- Verify: `ios/AppEnvironment.swift`
- Verify: `ios/SceneController.swift`
- Verify: `ios/AppRouteCoordinator.swift`
- Verify: `android/app/src/main/java/com/nurio/android/AppEnvironment.kt`
- Verify: `android/app/src/main/java/com/nurio/android/MainActivity.kt`
- Verify: `/Users/ws/es/business/nurioworkspace/nurio/spec/requests/landing_native_access_spec.rb`

- [ ] **Step 1: Prove the existing Rails session gate**

Run from `/Users/ws/es/business/nurioworkspace/nurio`:

```bash
mise exec -- bundle exec rspec spec/requests/landing_native_access_spec.rb
```

Expected: all examples pass, including native guest `/` redirecting to `/login` and signed-in native `/` redirecting to `/events`.

- [ ] **Step 2: Build the main Android debug app**

Run from `android/`:

```bash
ANDROID_HOME=/Users/ws/Library/Android/sdk ./gradlew :app:assembleDebug
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 3: Build the main iOS app**

Run:

```bash
xcodebuild -project ios/Nurio.xcodeproj -scheme Nurio \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Verify scope and working-tree isolation**

Run:

```bash
git diff --check
git status --short
git log --oneline -4
```

Expected: no whitespace errors; only the user's pre-existing unrelated files remain dirty; the plan, iOS, Android, and documentation commits are the newest commits.
