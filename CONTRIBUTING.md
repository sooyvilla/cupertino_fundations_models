# Contributing

Read [README](README.md), [the implementation guide](implementation_for_agents.md)
and local repository instructions before changing code. Public documentation is
English. Keep Dart contracts typed, native integration in Swift, iOS deployment
target 15, CocoaPods and Swift Package Manager support, and zero third-party
runtime dependencies unless explicitly approved.

Use native availability checks and local-only privacy defaults. Do not silently
route user data to PCC or an external provider. Preserve the disabled native
image/PCC getter paths until a separately authorized runtime investigation
supports changing them. Document unsupported features honestly.

Update the feature/migration guides for public changes. Keep dated or versioned
release notes in [CHANGELOG](CHANGELOG.md), with the newest release first and
no empty placeholder heading. Preserve historical entries. Update local context.md after a repository iteration; it
is intentionally excluded from the published archive.

Repository policy requires an explicit request before creating/running tests or
running an app, simulator or device. Non-interactive source checks are allowed:

```bash
dart format lib example/lib
flutter analyze --no-pub
dart pub publish --dry-run
```

Use an appropriate Xcode beta for iOS 27 APIs and run a proportional unsigned
build when changing Swift. Record the SDK, build result and any unverified older
SDK/runtime paths. A dry run does not publish. Version bumps, commits, pushes and
publication require the corresponding authorization. Authorized deliveries use
`main`; ordinary editing tasks do not automatically authorize commits or uploads.
