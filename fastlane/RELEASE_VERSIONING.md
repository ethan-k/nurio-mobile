# Customer beta versioning

`task ios:beta` checks App Store Connect before archiving. If the local marketing
version is at or below an approved/released version, it advances to the next
patch above that version. An open marketing version is retained. The build
number is at least the local build number and greater than the latest TestFlight
build in the selected train; a new marketing version starts at build 1 unless
TestFlight already has builds there. Store lookup errors stop the lane.

If Apple closes the train between that check and upload (error 90186), the lane
advances the patch and rebuilds once. Other upload failures are not retried.

`task android:beta` retains its existing patch/versionCode bump before building.

Both beta lanes commit only their version file after the upload action returns
success. Build/upload failure or Ctrl-C restores the attempt's version changes,
preserving unrelated edits. A successful upload followed by a Git failure keeps
the uploaded version for a manual commit. Other changes to the version file
during release prevent automatic committing. Git commits are local; the lanes
do not push Git branches.

The version file must have no staged or unstaged changes when the lane starts.
Unrelated files may be dirty or staged. Existing running Fastlane processes keep
the code they loaded at startup. Force-killing a process or powering off bypasses
Ruby cleanup. A timeout can leave a store upload's outcome uncertain; check the
store before retrying in that case. Rollback changes local source only.

Run the local regression suite (temporary Git repositories, mocked uploads):

```sh
mise exec ruby -- ruby fastlane/tests/ios_beta_test.rb
```

This runs both Android and iOS cases. It does not build or upload an application.
