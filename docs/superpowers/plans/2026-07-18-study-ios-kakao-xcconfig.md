# Nurio Study iOS Kakao xcconfig Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Nurio Study iOS Kakao Native App Key configurable through the standard Xcode `.xcconfig` pattern for both Debug and Release builds.

**Architecture:** The `NurioStudy` target will use one tracked base configuration that defines an empty default and optionally includes an ignored developer-specific override. `Info.plist` will continue consuming `KAKAO_NATIVE_APP_KEY`, so the same configured value supplies both Kakao SDK initialization and the `kakao<key>` callback scheme without changing browser OAuth.

**Tech Stack:** Xcode project build settings, `.xcconfig`, iOS `Info.plist`, `xcodebuild`

---

### Task 1: Wire the Study Kakao key through xcconfig

**Files:**
- Create: `study-nurio-mobile/ios/Config/NativeAuth.xcconfig`
- Create: `study-nurio-mobile/ios/Config/NativeAuth.local.xcconfig.example`
- Create locally but do not commit: `study-nurio-mobile/ios/Config/NativeAuth.local.xcconfig`
- Modify: `study-nurio-mobile/.gitignore`
- Modify: `study-nurio-mobile/ios/NurioStudy.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create a local red-test value**

Create `study-nurio-mobile/ios/Config/NativeAuth.local.xcconfig` with:

```xcconfig
KAKAO_NATIVE_APP_KEY = nurio_study_kakao_config_test
```

- [ ] **Step 2: Run the build-setting check and verify it fails before wiring**

Run:

```bash
xcodebuild -project study-nurio-mobile/ios/NurioStudy.xcodeproj -scheme NurioStudy -configuration Debug -showBuildSettings | rg '^\s*KAKAO_NATIVE_APP_KEY = nurio_study_kakao_config_test$'
```

Expected: exit status `1` because the target does not yet load the local configuration file.

- [ ] **Step 3: Add the tracked and ignored configuration files**

Create `study-nurio-mobile/ios/Config/NativeAuth.xcconfig` with:

```xcconfig
// Shared native-auth build settings. Developer and CI values override these defaults.
KAKAO_NATIVE_APP_KEY =

#include? "NativeAuth.local.xcconfig"
```

Create `study-nurio-mobile/ios/Config/NativeAuth.local.xcconfig.example` with:

```xcconfig
// Copy this file to NativeAuth.local.xcconfig and paste the Nurio Study Native App Key.
KAKAO_NATIVE_APP_KEY = your_nurio_study_kakao_native_app_key
```

Add `ios/Config/NativeAuth.local.xcconfig` to `study-nurio-mobile/.gitignore`.

- [ ] **Step 4: Attach the base configuration to the app target**

Add `NativeAuth.xcconfig` to the Xcode project and set it as `baseConfigurationReference` for the `NurioStudy` target's Debug and Release `XCBuildConfiguration` objects. Remove the empty target-level `KAKAO_NATIVE_APP_KEY = "";` assignments because target settings override base-configuration values.

- [ ] **Step 5: Verify Debug and Release load the local value**

Run the build-setting assertion for both configurations:

```bash
for config in Debug Release; do
  xcodebuild -project study-nurio-mobile/ios/NurioStudy.xcodeproj -scheme NurioStudy -configuration "$config" -showBuildSettings | rg '^\s*KAKAO_NATIVE_APP_KEY = nurio_study_kakao_config_test$'
done
```

Expected: two matching lines and exit status `0`.

- [ ] **Step 6: Verify the resolved app configuration builds**

Run:

```bash
xcodebuild -project study-nurio-mobile/ios/NurioStudy.xcodeproj -scheme NurioStudy -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Leave a safe local handoff file**

Replace the test value in ignored `NativeAuth.local.xcconfig` with:

```xcconfig
// Paste the Nurio Study Native App Key after the equals sign.
KAKAO_NATIVE_APP_KEY =
```

- [ ] **Step 8: Stage only this task and commit**

Stage the two tracked config files, the ignore rule, this plan, and only the Kakao xcconfig hunks from `project.pbxproj`. Do not stage the pre-existing Xcode formatting, development-team, Android, store, or workspace-user changes.

```bash
git commit -m "fix(ios): configure Study Kakao native key"
```
