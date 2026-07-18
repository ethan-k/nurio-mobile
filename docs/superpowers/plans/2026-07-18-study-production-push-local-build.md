# Nurio Study Production Push for Local Builds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every local Nurio Study Debug and Release build package the supplied `nurio-prod` Firebase configuration and remain pointed at `https://study.nurio.kr`.

**Architecture:** The workspace `nurio_study/mobile_certs` directory remains the source of truth. Gradle stages the Android JSON into the Google Services plugin's standard ignored module path before variant processing, while Xcode validates and copies the iOS plist directly from the sibling directory into each built app. Focused shell contract tests and one unified verifier exercise production-shaped Debug and Release builds without printing Firebase values.

**Tech Stack:** Gradle Kotlin DSL, Google Services Gradle plugin, Bash, `jq`, `plutil`, Xcode/XCTest, Firebase Messaging, existing Hotwire Native Study clients.

---

## Scope and existing changes

Work directly on `main`, as requested. Preserve unrelated user-owned `android/gradle.properties`, `study-nurio-mobile/ios/Config/NativeAuth.xcconfig`, development-team/Xcode formatting changes in the Study project file, root Firebase/release files, and Xcode `xcuserdata`.

Do not modify Flutter, main Nurio clients, Rails, admin/tutor features, or store version numbers.

## File map

- Create `study-nurio-mobile/scripts/test_android_production_push_build.sh`: contract test for source identity, staging, plugin output, and Debug/Release Firebase enablement.
- Modify `study-nurio-mobile/android/app/build.gradle.kts`: require and validate the workspace JSON, stage it, and apply Google Services for all variants.
- Create `study-nurio-mobile/scripts/test_ios_production_push_build.sh`: contract test for required plist packaging in Debug and Release simulator apps.
- Modify `study-nurio-mobile/ios/NurioStudy.xcodeproj/project.pbxproj`: point the existing copy phase at the required workspace plist while preserving user changes.
- Create `study-nurio-mobile/scripts/verify_production_push_builds.sh`: run both platform contracts and native test/build suites.
- Modify `study-nurio-mobile/docs/PUSH_NOTIFICATIONS.md`: document always-production sources, behavior, and verification.

## Task 1: Android production Firebase contract

**Files:**
- Create: `study-nurio-mobile/scripts/test_android_production_push_build.sh`
- Modify: `study-nurio-mobile/android/app/build.gradle.kts`

- [ ] **Step 1: Write the failing Android build contract**

Create a Bash test that derives the workspace paths, validates only identifiers, invokes the new preparation task, and verifies Debug/Release output:

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
study_root=$(cd "${script_dir}/.." && pwd)
workspace_root=$(cd "${study_root}/../.." && pwd)
source_config="${workspace_root}/nurio_study/mobile_certs/nurio-study-google-services.json"
staged_config="${study_root}/android/app/google-services.json"

test -f "${source_config}"
test "$(jq -r '.project_info.project_id' "${source_config}")" = "nurio-prod"
jq -e '.client[].client_info.android_client_info.package_name == "com.nurio.study.android"' \
  "${source_config}" >/dev/null

(cd "${study_root}/android" && ./gradlew :app:prepareStudyFirebaseConfig)
cmp -s "${source_config}" "${staged_config}"
(cd "${study_root}/android" && ./gradlew testDebugUnitTest assembleDebug assembleRelease)

for variant in debug release; do
  values="${study_root}/android/app/build/generated/res/google-services/${variant}/values/values.xml"
  test -f "${values}"
  rg -q '<string name="project_id" translatable="false">nurio-prod</string>' "${values}"
done
```

- [ ] **Step 2: Run the contract and verify RED**

Run `bash study-nurio-mobile/scripts/test_android_production_push_build.sh`.

Expected: FAIL because `:app:prepareStudyFirebaseConfig` does not exist and current logic only inspects an optional module-local file.

- [ ] **Step 3: Implement required source validation and staging**

Replace the optional selection in `app/build.gradle.kts` with a required source:

```kotlin
val firebaseSourceFile = rootProject.file(
    "../../../nurio_study/mobile_certs/nurio-study-google-services.json"
)
val firebaseStagedFile = file("google-services.json")

if (!firebaseSourceFile.isFile) {
    throw GradleException("Study production Firebase configuration is missing")
}
```

Parse `firebaseSourceFile` with the existing `JsonSlurper` logic and require project `nurio-prod` plus package `com.nurio.study.android`. Then add:

```kotlin
val prepareStudyFirebaseConfig = tasks.register<Copy>("prepareStudyFirebaseConfig") {
    from(firebaseSourceFile)
    into(projectDir)
    rename { "google-services.json" }
    outputs.file(firebaseStagedFile)
}

apply(plugin = "com.google.gms.google-services")

tasks.matching {
    it.name.startsWith("process") && it.name.endsWith("GoogleServices")
}.configureEach {
    dependsOn(prepareStudyFirebaseConfig)
}
```

Set `BuildConfig.FIREBASE_CONFIGURED` to literal `true`. Stable failures must not include config contents.

- [ ] **Step 4: Run the Android contract and verify GREEN**

Run the Step 2 command. Expected: PASS; unit tests and both app variants assemble with generated `nurio-prod` resources.

- [ ] **Step 5: Commit Android wiring**

Stage only the Gradle file and Android contract script. Commit `build: enable production push in Study Android builds`. Do not stage the ignored generated JSON.

## Task 2: iOS production Firebase contract

**Files:**
- Create: `study-nurio-mobile/scripts/test_ios_production_push_build.sh`
- Modify: `study-nurio-mobile/ios/NurioStudy.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write the failing iOS packaging contract**

Create:

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
study_root=$(cd "${script_dir}/.." && pwd)
repo_root=$(cd "${study_root}/.." && pwd)
workspace_root=$(cd "${repo_root}/.." && pwd)
source_config="${workspace_root}/nurio_study/mobile_certs/nurio-study-GoogleService-Info.plist"

test -f "${source_config}"
test "$(plutil -extract PROJECT_ID raw "${source_config}")" = "nurio-prod"
test "$(plutil -extract BUNDLE_ID raw "${source_config}")" = "com.nurio.study.ios"

for configuration in Debug Release; do
  derived="/tmp/nurio-study-production-push-ios-${configuration}"
  xcodebuild build -quiet \
    -derivedDataPath "${derived}" \
    -project "${study_root}/ios/NurioStudy.xcodeproj" \
    -scheme NurioStudy \
    -configuration "${configuration}" \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO

  bundled="${derived}/Build/Products/${configuration}-iphonesimulator/NurioStudy.app/GoogleService-Info.plist"
  test -f "${bundled}"
  test "$(plutil -extract PROJECT_ID raw "${bundled}")" = "nurio-prod"
  test "$(plutil -extract BUNDLE_ID raw "${bundled}")" = "com.nurio.study.ios"
done
```

- [ ] **Step 2: Run the iOS contract and verify RED**

Run `bash study-nurio-mobile/scripts/test_ios_production_push_build.sh`.

Expected: FAIL because the existing phase reads optional `$(SRCROOT)/GoogleService-Info.plist`, leaving the supplied workspace plist unbundled.

- [ ] **Step 3: Require the workspace plist in the existing Xcode phase**

Preserve all current user-owned project-file changes. Change only the Firebase input path to:

```text
"$(SRCROOT)/../../../nurio_study/mobile_certs/nurio-study-GoogleService-Info.plist",
```

Make the shell phase fail with `Study production Firebase configuration is missing` when the input is absent, retain exact project/bundle checks, and copy it to `${SCRIPT_OUTPUT_FILE_0}`. Remove the optional cleanup branch.

- [ ] **Step 4: Run the iOS contract and verify GREEN**

Run the Step 2 command. Expected: PASS for Debug and Release simulator builds, with correct bundled identifiers.

- [ ] **Step 5: Commit only the iOS Firebase hunk**

Use an index-only patch for the project file because it contains overlapping user changes. Stage the new iOS script normally, inspect `git diff --cached`, and commit `build: enable production push in Study iOS builds`.

## Task 3: Unified verifier and runbook

**Files:**
- Create: `study-nurio-mobile/scripts/verify_production_push_builds.sh`
- Modify: `study-nurio-mobile/docs/PUSH_NOTIFICATIONS.md`

- [ ] **Step 1: Add the unified verifier**

Create:

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
study_root=$(cd "${script_dir}/.." && pwd)

bash "${script_dir}/test_android_production_push_build.sh"
bash "${script_dir}/test_ios_production_push_build.sh"

xcodebuild test -quiet \
  -derivedDataPath /tmp/nurio-study-production-push-ios-tests \
  -project "${study_root}/ios/NurioStudy.xcodeproj" \
  -scheme NurioStudy \
  -destination 'platform=iOS Simulator,id=5192666C-2A65-4B3B-B7CF-D34A9ABC0D24' \
  CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 2: Update the push runbook**

Replace config-less/optional language with the exact workspace source paths. State that all builds use production Rails and Firebase, local devices register real production tokens, and the verification entry point is:

```bash
bash study-nurio-mobile/scripts/verify_production_push_builds.sh
```

Retain physical-device acceptance and token/credential logging prohibitions.

- [ ] **Step 3: Run safe static checks**

Run `git diff --check` and an `rg` credential-pattern scan limited to the new scripts/runbook. Expected: no whitespace errors or credential contents.

- [ ] **Step 4: Run the unified verifier**

Expected: Android unit tests and Debug/Release assemblies pass; iOS Debug/Release packaging and full XCTest pass; all built artifacts contain the Study `nurio-prod` config.

- [ ] **Step 5: Commit verifier and docs**

Stage only the verifier and runbook. Commit `test: verify Study production push builds`.

## Task 4: Final review and handoff

- [ ] **Step 1: Audit scope**

Confirm commits contain only intended Android logic, the iOS Firebase-phase hunk, three scripts, and runbook. Confirm external configs, the generated Android copy, user signing edits, root configs, and `xcuserdata` are not committed.

- [ ] **Step 2: Re-run final verification**

Run the unified verifier, `git diff --check`, and `git status --short`.

- [ ] **Step 3: Review and finish on main**

Apply `superpowers:requesting-code-review` locally because delegation is not authorized. Fix confirmed findings, rerun verification, and report the verified commits already on `main`. Do not push or open a PR unless requested.
