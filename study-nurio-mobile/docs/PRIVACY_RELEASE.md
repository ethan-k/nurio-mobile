# Nurio Study AI Practice Privacy Release Gate

This checklist covers the customer-facing Hotwire Native apps in `study-nurio-mobile/`. It records the version-controlled evidence for AI Practice, but it does not change App Store Connect, Play Console, provider contracts, or the public privacy policy.

## Audited data path

AI Practice is delivered by the Rails-owned `study.nurio.kr` page inside the native WebView.

1. The learner explicitly starts a numeric `/practice/:id` session before the WebView can request microphone capture.
2. Browser media APIs capture the learner's voice. Depending on server configuration, the WebView sends audio through a Nurio Rails upload/proxy or directly to a realtime AI service with a short-lived server-issued credential.
3. Nurio links the resulting learner transcript and any retained practice recording to the authenticated learner's AI Practice session. The learner can review that private content; Study leaders receive derived learning signals, not the recording or transcript.
4. When objective speech assessment is enabled, Nurio can send a bounded audio sample and server-owned transcript/reference text to Microsoft Azure Speech. The returned pronunciation and fluency assessment is stored with the learner's private practice context.

Code-supported boundaries observed during this audit:

| Mode | Off-device boundary | Learner data involved |
| --- | --- | --- |
| Direct realtime | Study WebView → Google Gemini Live | Microphone audio and provider-generated conversation transcript |
| Proxied realtime | Study WebView → Nurio Rails → Google Gemini Live | Microphone audio and conversation transcript |
| HTTP fallback | Study WebView → Nurio Rails → configured STT provider | Uploaded voice clip; the configured provider can be OpenAI, Google Gemini, Soniox, or ElevenLabs |
| AI reply and review | Nurio Rails → configured AI model provider | Learner transcript plus the minimum session context needed for the reply or private review |
| Objective assessment | Nurio Rails → Microsoft Azure Speech | Bounded audio sample plus the server-owned transcript/reference text |

The server-selected realtime, speech-to-text, text-generation, and speech-assessment providers can change by deployment configuration. Before release, verify the active production provider inventory against the public Study privacy policy and the applicable processor agreements. Do not infer provider processing region, retention, or deletion behavior from the mobile code.

## Version-controlled declarations

### iOS

`ios/PrivacyInfo.xcprivacy` declares the two AI Practice data categories introduced by this flow:

- `NSPrivacyCollectedDataTypeAudioData` for the learner's voice recordings.
- `NSPrivacyCollectedDataTypeOtherUserContent` for learner-authored text and speech-derived transcripts.

Both are linked to the learner's account, are used for app functionality, and are not used for tracking. The manifest is bundled by the `NurioStudy` target and is protected by `NurioStudyTests`.

These feature declarations are not a substitute for an app-wide privacy inventory. The release owner must also reconcile account, authentication, push-notification, payment, diagnostic, and other web-surface data with App Store Connect before publishing.

### Android

`android/app/src/main/AndroidManifest.xml` already declares `android.permission.RECORD_AUDIO`. Google Play Data safety answers are submitted in Play Console; there is no Android manifest metadata entry that can truthfully publish those answers, so this change does not add one.

## External store actions

These steps require the authorized store owner and are intentionally not automated by this repository.

### App Store Connect

- [ ] In **App Privacy**, include **Audio Data** and **Other User Content** for AI Practice.
- [ ] For both types, confirm **linked to the user**, **not used for tracking**, and **App Functionality** against the production behavior.
- [ ] Reconcile those feature entries with the complete app-wide data inventory; do not publish a "no data collected" answer.
- [ ] Set the public Study privacy policy URL and confirm its processor/overseas-transfer table names every production AI provider. Microsoft Azure must be covered before Azure assessment is enabled for users.
- [ ] Publish the updated answers and verify the product-page preview before attaching the release build.

### Google Play Console

- [ ] In **Data safety**, include **Audio files → Voice or sound recordings** for microphone audio.
- [ ] Include **Messages → Other in-app messages** for learner practice text and speech-derived transcripts.
- [ ] Confirm both are collected for **App functionality** and that collection is optional at the app level because learners can use the Study service without starting AI Practice.
- [ ] Decide whether each provider transfer qualifies as service-provider processing or data sharing from the applicable contracts; do not infer that answer from transport code alone.
- [ ] Reconcile the AI Practice entries with the complete package-wide data inventory and publish the updated Data safety form and privacy policy URL.

## Pre-release acceptance

- [ ] `plutil -lint ios/PrivacyInfo.xcprivacy` passes.
- [ ] The iOS test suite confirms the privacy manifest is bundled and contains the linked, non-tracking Audio Data and Other User Content declarations.
- [ ] A production-signed iOS build and Android build show the bilingual in-app explanation immediately before the OS microphone prompt.
- [ ] On physical devices, declining permission leaves the learner outside voice capture; granting permission records only on an active `/practice/:id` session; ending or leaving practice stops capture.
- [ ] The learner review can access its private transcript/recording, while another account and a Study leader cannot.
- [ ] The public Study privacy policy matches the enabled provider set, including processor identity, transfer facts, and retention terms approved by the privacy owner.
- [ ] App Store Connect App Privacy and Google Play Data safety changes are published before the AI Practice pilot is enabled in a store build.
- [ ] App Review/payment classification for the membership-included digital AI feature is approved; do not reuse a blanket claim that the app provides no digital content or features.

## Official platform references

- [Apple: Describing data use in privacy manifests](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)
- [Apple: Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Google Play: Provide information for the Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469)
