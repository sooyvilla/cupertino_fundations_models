# Failures, fixes and recovery

This ledger separates user-reported symptoms, confirmed native crash evidence,
source findings and validation limits. It consolidates the available project
history and the August 12 / September 1, 2026 support sessions. It is not a claim
that every past conversation or every possible crash was recovered.

## Historical reports from the example

| Symptom and evidence | Cause / mitigation in the current source | Recovery and remaining limit |
| --- | --- | --- |
| July 3: first streamed reply left the chat locked | The generation event channel did not close. Current generation transport uses request-scoped callbacks and closes on terminal results. | Handle both completion and stream errors; always clear sending state. |
| August 12: sending a message crashed in Hybrid and Offline | Diagnostic collection read PCC `supportedLanguages`; repeated `EXC_BAD_ACCESS`, `SIGSEGV` and `SIGBUS` were traced to Apple runtime getters. Availability checks alone did not prevent it. | Keep PCC language/capability getters disabled. Local requests must not probe those getters. |
| August 12: images crashed repeatedly after text started working | Separate reports reached `Attachment(imageURL:)`, attachment labeling and conversion into `Prompt`, terminating before Swift could throw. | Native image ABI remains disabled. Vision supplies OCR/classification/barcode text; it is not general vision inference. |
| August 12: selected documents produced confusing errors | Unsupported Office/binary inputs, file extraction and route-exhaustion errors were conflated. | Use validated UTF-8/text PDF; unsupported input returns an actionable typed error. The hybrid router is removed in 0.3.0. |
| August 12: transcription sometimes crashed or took too long | Audio format assertions, asynchronous start/cancel races and locale/asset preparation were investigated; no single cause was established for every slow request. | Validate microphone formats, prefer SpeechAnalyzer, await cleanup, inspect engine/assets. First-use asset downloads can still be slow. |
| September 1: cloud selection immediately crashed; transcription backend was unclear | PCC construction without configured host opt-in was unsafe in the beta path. Model choice and Speech mode were conflated in the example. | PCC stays opt-in and requires Apple's signing entitlement. Model and Speech selectors are separate; Speech server is not PCC. |
| September 1: cancellation-related Runner SIGTRAP | A stored report preceded the successful physical matrix and terminated inside Foundation Models cancellation code. | Keep session reservation until native work terminates. Later beta-8 checks passed; this does not establish beta-27.2 runtime safety. |
| September 1: required tools repeated calls | Apple's required-tool mode lacked an application exit budget. | Bound calls with `maximumToolCalls`; a budget breach is a request failure, not a successful answer. |
| September 1: simultaneous streams and rapid reuse could interfere | Shared listeners, late task cleanup and incomplete cancellation could affect another request. | Per-request stream IDs, tokenized tracking and single-flight session lifecycle. |

The historical September 1 physical matrix reported 15 passing executable checks
on iOS 27 beta 8. PCC generation, native image attachment ABI, long-duration
stress and all manual UI flows were not covered. That report is preserved in
[the historical audit](ios-27-current-audit-2026-09-01.md), and is not reused as
proof for the changed code or iOS 27.2.

## Source findings fixed in the 0.3.0 iteration

| Finding | Correction |
| --- | --- |
| A second facade replaced the first facade's MethodChannel receiver | Default facades share one transport and its session/request registry. |
| Explicit PCC bypassed `CloudPolicy.never`; automatic plus `whenExplicit` could select PCC | Cloud policy is checked before constructing PCC; automatic cloud selection requires `automaticWithUserConsent`. |
| Per-request cloud policy was serialized but ignored | Null inherits session selection; `never` rejects an existing PCC session. |
| `localeIdentifier` preflight was ignored by availability | Local availability and optional session preflight now validate the requested locale. |
| Repeated cancellation could clear a session's cancellation reservation early | Native callers share the cancellation task; Dart disposal/cancellation also share their pending futures. |
| Microphone cancellation returned before asynchronous startup/cleanup finished | Cleanup retains startup and is explicitly awaited; a second live capture is rejected. |
| Missing host Speech/microphone usage strings could reach privacy APIs | Native preflight rejects missing/empty keys before requesting access. |
| Unknown schemas became strings; missing array items were invented | Unsupported shapes/constraints and invalid required/enum declarations are rejected. |
| Generation arguments relied partly on debug-only assertions | Serialization validates ranges in release code, alongside native validation. |
| Late tool callbacks, malformed arguments and oversized output were unsafe | Skip callbacks already completed/cancelled, reject non-object JSON and report oversized output instead of truncating it. |
| iOS 26 failures depended on localized message matching | Known legacy generation errors now map through typed cases. |
| Empty text and failed image preprocessing could look like usable content | Empty text is rejected and Vision errors propagate. |

These are source corrections. See the [current validation record](ios-27.2-audit-2026-09-19.md)
for checks actually executed. No new runtime coverage is implied by this table.

## Recover by error code

- `appleIntelligenceDisabled`, `assetsUnavailable`: check Apple Intelligence,
  supported device/Siri languages and completed model downloads. Recheck when
  settings change; do not loop requests while assets are missing.
- `unsupportedPlatform`, `unsupportedOsVersion`, `unsupportedCapability`:
  disable the unsupported feature or select an explicitly supported configuration.
- `unsupportedLanguage`: select a supported locale; changing instructions alone
  cannot add language support.
- `missingEntitlement`: obtain and sign with Apple's managed PCC entitlement,
  then enable the host plist flag. The flag alone does not grant access.
- `invalidRequest`: fix conflicting policy, schema, options, file format or
  missing host usage descriptions. Retry only after changing the cause.
- `contextSizeExceeded`: split input or create a new session; account for
  instructions, schema, tools, history and output, not only the user prompt.
- `concurrentRequests`: wait for request/cancellation cleanup; do not force reuse.
- `guardrailViolation`, `refusal`: provide an appropriate alternative; do not
  automatically send the same request to another provider.
- `generationTimeout`, `transcriptionTimeout`, `cancelled`: clear loading state,
  await cleanup and reconcile tool side effects before retrying.
- `speechRecognitionDenied`: request permissions at the point of use; offer
  Settings/manual input after denial.
- `speechRecognitionUnavailable`: inspect locale, assets and microphone/audio
  availability. A server fallback needs an app policy that permits it.
- `quotaExceeded`, `networkUnavailable`, `privateCloudServiceUnavailable`:
  report the PCC state; use a separately chosen local task if suitable.

If a process terminates, collect the `.ips` stack, OS build, Xcode/SDK build,
package version, selected mode, operation and reproduction steps. Remove user
prompts, transcripts, credentials, file contents and device identifiers before
sharing a report. A native abort cannot be recovered by a Dart `try/catch`.
