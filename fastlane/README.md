fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios validate

```sh
[bundle exec] fastlane ios validate
```

Check App Store Connect credentials without building or uploading

### ios build

```sh
[bundle exec] fastlane ios build
```

Archive and export a signed App Store IPA (no upload)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Build and upload to App Store Connect for release review (metadata untouched)

----


## Android

### android validate

```sh
[bundle exec] fastlane android validate
```

Check the Play publisher credentials without building or uploading

### android build

```sh
[bundle exec] fastlane android build
```

Build the signed release AAB (no upload)

### android beta

```sh
[bundle exec] fastlane android beta
```

Build and upload to the Play Console internal track (auto-bumps versionCode ahead of Play)

### android promote

```sh
[bundle exec] fastlane android promote
```

Promote the internal build to production (no rebuild)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
