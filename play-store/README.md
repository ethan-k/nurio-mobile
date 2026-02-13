# Play Store Submission Assets

## Checklist

### Required Assets

- [x] App Icon (512x512 PNG) - `app-icon-512.png`
- [ ] Feature Graphic (1024x500 PNG) - `feature-graphic.png`
- [ ] Screenshots - Phone (min 2, max 8)
  - [ ] `screenshot-phone-1.png` (1080x1920 or 1080x2400)
  - [ ] `screenshot-phone-2.png`
- [ ] Screenshots - Tablet 7" (optional)
- [ ] Screenshots - Tablet 10" (optional)

### Store Listing Text

- [x] Korean (ko-KR) - `store-listing-ko.md`
- [x] English (en-US) - `store-listing-en.md`

### App Information

| Field | Value |
|-------|-------|
| Package Name | io.nurio.mobile |
| App Category | Social |
| Content Rating | Everyone |
| Target Age | 13+ |
| Privacy Policy | https://nurio.kr/privacy-policy |
| Terms of Service | https://nurio.kr/terms-of-service |
| Support Email | nurio_official@naver.com |
| Website | https://nurio.kr |

### Screenshot Requirements

| Device | Min Size | Max Size | Count |
|--------|----------|----------|-------|
| Phone | 320px | 3840px | 2-8 |
| 7" Tablet | 320px | 3840px | 0-8 |
| 10" Tablet | 320px | 3840px | 0-8 |

Aspect ratio: 16:9 or 9:16

### Feature Graphic Requirements

- Size: 1024 x 500 pixels
- Format: PNG or JPEG
- No transparency
- No rounded corners

### Build Commands

```bash
# Generate release AAB
cd android
./gradlew bundleRelease

# Output location
# app/build/outputs/bundle/release/app-release.aab
```

### Version Increment

Before each release, update in `app/build.gradle.kts`:
- `versionCode` - increment by 1
- `versionName` - semantic version (e.g., "1.0.1")
