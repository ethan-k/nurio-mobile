# Nurio Mobile

Native mobile apps for Nurio using Hotwire Native.

## Structure

```
nurio-mobile/
├── android/          # Android app (Kotlin)
├── ios/              # iOS app (Swift) - coming soon
└── shared/           # Shared configuration
    └── path-configuration.json
```

## Requirements

### Android
- Android Studio Ladybug (2024.2) or later
- JDK 17+
- Android SDK 28+ (target: 35)

### iOS (coming soon)
- Xcode 15+
- iOS 15+

## Getting Started

### Android

1. Open `android/` folder in Android Studio
2. Sync Gradle dependencies
3. Run on emulator or device

### Development Server

The app connects to `https://nurio.kr` by default. For local development:

1. Update `BASE_URL` in `android/app/build.gradle.kts`
2. Ensure your Rails server is running with `bin/dev`

## Hotwire Native Version

- Android: 1.2.5
- iOS: 1.2.2 (planned)

## Path Configuration

Path rules are defined in `shared/path-configuration.json` and control:
- Modal vs default presentation
- Pull-to-refresh behavior
- Navigation context

## Bridge Components

Bridge components enable communication between web and native code.
(To be implemented as needed)
