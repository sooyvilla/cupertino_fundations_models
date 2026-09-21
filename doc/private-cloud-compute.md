# Private Cloud Compute setup

For package **0.4.1**. Apple requirements checked September 21, 2026;
recheck the linked pages before applying because eligibility and beta APIs can
change. This guide does not establish that your account or app is approved.

## Eligibility and requesting access

Apple currently requires enrollment in the
[App Store Small Business Program](https://developer.apple.com/app-store/small-business-program/),
fewer than two million first-time App Store downloads under its eligibility
rules, and an assigned PCC entitlement. Eligible developers have no PCC cloud
API cost. Apple describes App Store distribution and testing through TestFlight
or ad hoc; test installs do not count toward that download threshold. If an app
exceeds the threshold or enrollment ends, Apple describes notification and a
six-month migration period. See [Accessing Private Cloud Compute](https://developer.apple.com/private-cloud-compute/)
for the exact current conditions.

1. Have the Apple Developer team's **Account Holder** open Apple's
   [PCC entitlement request](https://developer.apple.com/contact/request/private-cloud-compute/).
   It requires Apple sign-in. Follow the current form; this package cannot
   submit or approve the request, and this guide does not promise an approval time.
2. In Certificates, Identifiers & Profiles, select the app identifier and use
   **Capability Requests** to request/check managed-capability access where
   offered. Keep the correct team and Bundle ID selected.
3. After approval, enable the capability for the app identifier or add the
   approved capability to the app target in Xcode's Signing & Capabilities.
   See Apple's [managed capability workflow](https://developer.apple.com/help/account/capabilities/capability-requests/).
4. Refresh provisioning profiles for the intended distribution method and sign
   the host app with the approved entitlement. Match its team and Bundle ID.
   Profiles authorize app services; a source plist alone is insufficient.
   See [provisioning profiles](https://developer.apple.com/help/account/provisioning-profiles/provisioning-profile-updates).

## Two different host settings

The signed app needs Apple's Boolean entitlement, normally in the host's
`.entitlements` file selected by `CODE_SIGN_ENTITLEMENTS`:

```xml
<key>com.apple.developer.private-cloud-compute</key>
<true/>
```

Apple must grant this [managed entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.private-cloud-compute).
Adding the XML does not grant access or update provisioning profiles.

Only after approval and signing are configured, enable this package's separate
guard in the **host Info.plist**:

```xml
<key>CupertinoFoundationModelsPrivateCloudComputeEnabled</key>
<true/>
```

This flag defaults to false. It permits native PCC initialization; it neither
requests nor verifies Apple's signing entitlement. `missingEntitlement` can
also mean this package guard is off, so that status is not an account audit.
The example leaves it off. Configuration belongs to the consuming app, not the
plugin pod, Swift package, or a Dart define. Rebuild/re-sign the host after
changing native configuration; a Dart hot reload cannot change its signature.

## Runtime and application requirements

- This plugin exposes PCC only on iOS 27+, built with an SDK exposing PCC
  (Xcode 27+/Swift 6.4). Its iOS 15 deployment target does not enable PCC there.
- Use an Apple Intelligence-capable device, enabled Apple Intelligence, a
  supported region and a working network. PCC needs no app-supplied API key.
- Handle daily user limits, network errors and service availability. iCloud+
  can increase user access; it is not a replacement for the developer entitlement.
  See Apple's [PCC integration guide](https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute).
- Obtain the app's authorization to send the selected content to Apple cloud.
  `CloudPolicy` expresses that decision; the plugin does not present a consent UI.
- Check availability before creating the session and handle failures during
  generation too. A preflight cannot reserve quota or guarantee a later request.

After the app has authorized this cloud task, use an explicit route:

```dart
final models = CupertinoFoundationModels();
final availability = await models.checkAvailability(
  mode: ModelMode.privateCloudCompute,
  cloudPolicy: CloudPolicy.whenExplicit,
);
if (!availability.isAvailable) {
  throw StateError(availability.reason ?? 'PCC is unavailable.');
}
final session = await models.createSession(
  options: const SessionOptions(
    mode: ModelMode.privateCloudCompute,
    cloudPolicy: CloudPolicy.whenExplicit,
  ),
);
try {
  final response = await session.respond(
    const Prompt.text('Summarize: The appointment is on Friday.'),
    options: const GenerationOptions(maximumResponseTokens: 128),
  );
  print(response.text);
} finally {
  await session.dispose();
}
```

Catch `FoundationModelsException` at the feature boundary. The same session can
use `streamStructured(prompt: ..., schema: ...)` as shown in the
[usage guide](usage.md#guided-streaming). `automatic` + `whenExplicit` remains
local; `automaticWithUserConsent` can select PCC at session creation. A request
cannot switch an existing session's backend, and `CloudPolicy.never` rejects a
PCC request. No automatic external-provider fallback is implemented.

## Limits and troubleshooting

Inspect `ModelAvailability.reason`, `recoverySuggestion` and `quota`, and use
`getDiagnostics()` for SDK/runtime information. Check `quota.status`,
`isApproachingLimit` and `resetDate` when provided; do not hardcode a daily
request count. The package exposes quota information, not a UI for purchasing
more access. See [recovery by error code](troubleshooting.md#recover-by-error-code).

Treat schema, instructions, history, tools and output as part of the context
budget. Validate facts and business rules even when JSON follows the schema.
Only the completed structured response is final data. PCC budget measurements
are unavailable in this SDK; the plugin never counts cloud requests with the
local tokenizer. Nullable actual usage, unknown native stop reasons, stream
deadlines and opt-in output capture are described in [usage](usage.md). Reconcile tool side
effects before retries; cancellation does not undo application writes.

Apple approval, a successful build, and a successful on-device model request do
not establish working PCC. This release has no new entitled-device/runtime
validation. TestFlight/ad hoc on a suitable device remains a separate integration
step. The plugin does not verify the host signature, and its unsafe PCC language
and capability getters remain disabled. Speech server recognition is a separate
service with separate permissions; it does not grant PCC access.
