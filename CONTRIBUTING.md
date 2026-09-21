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

Update README, usage, agent instructions, the example and relevant migration
notes for public changes. Keep the [PCC guide](doc/private-cloud-compute.md)
aligned with official eligibility/signing requirements; date source checks and
do not infer access from the host flag. Keep dated or versioned
release notes in [CHANGELOG](CHANGELOG.md), with the newest release first and
no empty placeholder heading. Preserve historical entries. Update local context.md after a repository iteration; it
is intentionally excluded from the published archive.

Follow the active repository/user instructions: tests, analysis, formatting,
builds, validators, apps, simulators and devices require an explicit request.
Reading source and reviewing the diff do not authorize those operations.
When validation is requested, use an appropriate Xcode beta for iOS 27 APIs and
record the exact checks, SDK, results and unverified runtime paths. A publication
dry run does not publish. Version bumps, commits, pushes and
publication require the corresponding authorization. Authorized deliveries use
`main`; ordinary editing tasks do not automatically authorize commits or uploads.
