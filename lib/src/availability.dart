/// The model execution target requested by the app.
enum ModelMode {
  /// Uses the on-device Apple model and does not select PCC.
  local,
  /// Requests Apple's PCC model, subject to policy, signing and availability.
  privateCloudCompute,
  /// Selects a route at session creation under the app's cloud policy.
  automatic,
}

/// The policy that controls whether a request may leave the device.
enum CloudPolicy {
  /// Keeps language generation local and rejects a PCC request.
  never,
  /// Permits PCC only when the app explicitly selects that model mode.
  whenExplicit,
  /// Allows automatic PCC selection after the app has obtained user consent.
  automaticWithUserConsent,
}

/// Runtime capabilities exposed by the native Apple stack.
enum ModelCapability {
  /// On-device text generation is exposed by the bridge.
  localText,
  /// The bridge supports cumulative response streams.
  streaming,
  /// Sessions can invoke registered Dart tools.
  toolCalling,
  /// Native guided output is exposed through supported schemas.
  structuredOutput,
  /// The selected runtime exposes local token counting.
  tokenCounting,
  /// Image handling is available; consult details for its actual input path.
  imageInput,
  /// The bridge has a PCC route, subject to its separate access requirements.
  privateCloudCompute,
  /// Native reasoning options are available for a compatible model.
  reasoning,
  /// Native dynamic profiles exist; this flag alone does not expose a Dart API.
  dynamicProfiles,
  /// Compatibility flag for the package's PCC capability, not model quality.
  fullPower,
}

/// Availability result for a requested model mode.
enum AvailabilityStatus {
  /// Generation can currently be attempted on the requested route.
  available,
  /// The native runtime reports an unavailable model without a specific cause.
  unavailable,
  /// No compatible Apple plugin backend is registered for this platform.
  unsupportedPlatform,
  /// The runtime is older than the requested native feature.
  unsupportedOsVersion,
  /// Apple Intelligence is disabled in the system settings.
  appleIntelligenceDisabled,
  /// Required model assets are not ready.
  assetsUnavailable,
  /// The requested language or locale is not supported by the model.
  unsupportedLanguage,
  /// A requested network-backed route cannot access the network.
  networkUnavailable,
  /// The route has exhausted its reported quota.
  quotaExceeded,
  /// PCC signing or host opt-in requirements are not met.
  missingEntitlement,
  /// System or account policy restricts use of this feature.
  restricted,
  /// The bridge cannot identify the native availability state.
  unknown,
}

/// A locale supported by both Apple Foundation Models and live transcription.
final class FoundationModelsLanguage {
  /// Creates the display labels and Speech asset state for one supported locale.
  const FoundationModelsLanguage({
    required this.identifier,
    required this.languageCode,
    required this.displayName,
    required this.nativeDisplayName,
    required this.isTranscriptionAssetInstalled,
  });

  /// Decodes native labels, using the locale identifier for missing labels.
  factory FoundationModelsLanguage.fromMap(Map<Object?, Object?> map) {
    final String identifier = (map['identifier'] as String?) ?? 'und';
    return FoundationModelsLanguage(
      identifier: identifier,
      languageCode: (map['languageCode'] as String?) ?? identifier,
      displayName: (map['displayName'] as String?) ?? identifier,
      nativeDisplayName:
          (map['nativeDisplayName'] as String?) ??
          (map['displayName'] as String?) ??
          identifier,
      isTranscriptionAssetInstalled:
          (map['isTranscriptionAssetInstalled'] as bool?) ?? false,
    );
  }

  /// BCP-47 locale identifier accepted by model and transcription requests.
  final String identifier;

  /// Primary ISO language code, such as `en` or `es`.
  final String languageCode;

  /// Locale name localized for the device's current language.
  final String displayName;

  /// Locale name localized in the represented language.
  final String nativeDisplayName;

  /// Whether the SpeechTranscriber asset is already installed on this device.
  final bool isTranscriptionAssetInstalled;

  /// Serializes the locale descriptor for application-owned storage or transport.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'identifier': identifier,
      'languageCode': languageCode,
      'displayName': displayName,
      'nativeDisplayName': nativeDisplayName,
      'isTranscriptionAssetInstalled': isTranscriptionAssetInstalled,
    };
  }
}

/// Describes the native platform and Apple Foundation Models support.
final class FoundationModelsCapabilities {
  /// Creates a native feature snapshot; it does not establish current readiness.
  const FoundationModelsCapabilities({
    required this.platform,
    required this.operatingSystemVersion,
    required this.sdkVersion,
    required this.capabilities,
    required this.supportsFullPower,
    required this.preferredMode,
    this.contextSize,
    this.privateCloudContextSize,
    this.supportedLanguages = const <String>[],
    this.details = const <String, Object?>{},
  });

  /// Decodes a native snapshot, ignoring unknown capability names.
  factory FoundationModelsCapabilities.fromMap(Map<Object?, Object?> map) {
    final List<Object?> rawCapabilities =
        (map['capabilities'] as List<Object?>?) ?? <Object?>[];
    final List<Object?> rawLanguages =
        (map['supportedLanguages'] as List<Object?>?) ?? <Object?>[];
    final Map<Object?, Object?> rawDetails =
        (map['details'] as Map<Object?, Object?>?) ?? <Object?, Object?>{};

    return FoundationModelsCapabilities(
      platform: (map['platform'] as String?) ?? 'unknown',
      operatingSystemVersion:
          (map['operatingSystemVersion'] as String?) ?? 'unknown',
      sdkVersion: (map['sdkVersion'] as String?) ?? 'unknown',
      capabilities: rawCapabilities
          .whereType<String>()
          .map(_capabilityFromName)
          .whereType<ModelCapability>()
          .toSet(),
      supportsFullPower: (map['supportsFullPower'] as bool?) ?? false,
      preferredMode: _modeFromName(
        (map['preferredMode'] as String?) ?? ModelMode.local.name,
      ),
      contextSize: map['contextSize'] as int?,
      privateCloudContextSize: map['privateCloudContextSize'] as int?,
      supportedLanguages: rawLanguages.whereType<String>().toList(),
      details: rawDetails.cast<String, Object?>(),
    );
  }

  /// Native host platform, usually ios or macos.
  final String platform;
  /// Operating system version reported by the native host.
  final String operatingSystemVersion;
  /// SDK feature level reported by the bridge.
  final String sdkVersion;
  /// Exposed feature flags; inspect [details] for disabled or limited paths.
  final Set<ModelCapability> capabilities;
  /// Compatibility indication of PCC support, not approval or availability.
  final bool supportsFullPower;
  /// Preferred native route in this capability snapshot.
  final ModelMode preferredMode;
  /// Local context window size in tokens, or null when unavailable.
  final int? contextSize;
  /// PCC context window size, or null when it cannot be safely queried.
  final int? privateCloudContextSize;
  /// Native language identifiers exposed by this snapshot.
  final List<String> supportedLanguages;
  /// Runtime caveats and extra native feature metadata.
  final Map<String, Object?> details;

  /// Whether this snapshot contains the requested feature flag.
  bool supports(ModelCapability capability) =>
      capabilities.contains(capability);

  /// Serializes the snapshot without querying the native host again.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'platform': platform,
      'operatingSystemVersion': operatingSystemVersion,
      'sdkVersion': sdkVersion,
      'capabilities': capabilities
          .map((ModelCapability value) => value.name)
          .toList(),
      'supportsFullPower': supportsFullPower,
      'preferredMode': preferredMode.name,
      'contextSize': contextSize,
      'privateCloudContextSize': privateCloudContextSize,
      'supportedLanguages': supportedLanguages,
      'details': details,
    };
  }
}

/// Diagnostics for Foundation Models availability and language support.
final class FoundationModelsDiagnostics {
  /// Creates a route and locale diagnostic snapshot.
  const FoundationModelsDiagnostics({
    required this.platform,
    required this.operatingSystemVersion,
    required this.sdkVersion,
    required this.currentLocaleIdentifier,
    required this.targetLocaleIdentifier,
    required this.preferredLanguages,
    required this.localAvailability,
    required this.localSupportedLanguages,
    required this.localPreferredLanguageSupport,
    this.localSupportsCurrentLocale,
    this.privateCloudAvailability,
    this.privateCloudSupportsCurrentLocale,
    this.privateCloudSupportedLanguages = const <String>[],
    this.privateCloudPreferredLanguageSupport = const <LanguageSupport>[],
    this.details = const <String, Object?>{},
  });

  /// Decodes diagnostics while preserving unavailable optional PCC metadata.
  factory FoundationModelsDiagnostics.fromMap(Map<Object?, Object?> map) {
    final Map<Object?, Object?> rawLocalAvailability =
        (map['localAvailability'] as Map<Object?, Object?>?) ??
        <Object?, Object?>{};
    final Object? rawPrivateCloudAvailabilityValue =
        map['privateCloudAvailability'];
    final Map<Object?, Object?>? rawPrivateCloudAvailability =
        rawPrivateCloudAvailabilityValue is Map<Object?, Object?>
        ? rawPrivateCloudAvailabilityValue
        : null;
    final List<Object?> rawPreferredLanguages =
        (map['preferredLanguages'] as List<Object?>?) ?? <Object?>[];
    final List<Object?> rawLocalLanguages =
        (map['localSupportedLanguages'] as List<Object?>?) ?? <Object?>[];
    final List<Object?> rawPrivateCloudLanguages =
        (map['privateCloudSupportedLanguages'] as List<Object?>?) ??
        <Object?>[];
    final List<Object?> rawLocalSupport =
        (map['localPreferredLanguageSupport'] as List<Object?>?) ?? <Object?>[];
    final List<Object?> rawPrivateCloudSupport =
        (map['privateCloudPreferredLanguageSupport'] as List<Object?>?) ??
        <Object?>[];
    final Map<Object?, Object?> rawDetails =
        (map['details'] as Map<Object?, Object?>?) ?? <Object?, Object?>{};

    return FoundationModelsDiagnostics(
      platform: (map['platform'] as String?) ?? 'unknown',
      operatingSystemVersion:
          (map['operatingSystemVersion'] as String?) ?? 'unknown',
      sdkVersion: (map['sdkVersion'] as String?) ?? 'unknown',
      currentLocaleIdentifier:
          (map['currentLocaleIdentifier'] as String?) ?? 'unknown',
      targetLocaleIdentifier:
          (map['targetLocaleIdentifier'] as String?) ??
          (map['currentLocaleIdentifier'] as String?) ??
          'unknown',
      preferredLanguages: rawPreferredLanguages.whereType<String>().toList(),
      localAvailability: ModelAvailability.fromMap(rawLocalAvailability),
      localSupportsCurrentLocale: map['localSupportsCurrentLocale'] as bool?,
      localSupportedLanguages: rawLocalLanguages.whereType<String>().toList(),
      localPreferredLanguageSupport: _languageSupportListFromValues(
        rawLocalSupport,
      ),
      privateCloudAvailability: rawPrivateCloudAvailability == null
          ? null
          : ModelAvailability.fromMap(rawPrivateCloudAvailability),
      privateCloudSupportsCurrentLocale:
          map['privateCloudSupportsCurrentLocale'] as bool?,
      privateCloudSupportedLanguages: rawPrivateCloudLanguages
          .whereType<String>()
          .toList(),
      privateCloudPreferredLanguageSupport: _languageSupportListFromValues(
        rawPrivateCloudSupport,
      ),
      details: rawDetails.cast<String, Object?>(),
    );
  }

  /// Native platform queried for diagnostics.
  final String platform;
  /// Operating system version of the native host.
  final String operatingSystemVersion;
  /// SDK feature level reported by the bridge.
  final String sdkVersion;
  /// System locale identifier reported by the host.
  final String currentLocaleIdentifier;
  /// Requested diagnostic locale, or the system locale when none was supplied.
  final String targetLocaleIdentifier;
  /// User's preferred language identifiers reported by the system.
  final List<String> preferredLanguages;
  /// Availability of the local model at the time of the query.
  final ModelAvailability localAvailability;
  /// Local model support for [targetLocaleIdentifier], when supplied.
  final bool? localSupportsCurrentLocale;
  /// Local model languages exposed by the native diagnostics.
  final List<String> localSupportedLanguages;
  /// Local model support results for the preferred language identifiers.
  final List<LanguageSupport> localPreferredLanguageSupport;
  /// PCC readiness information, or null when not safely available.
  final ModelAvailability? privateCloudAvailability;
  /// PCC locale-support result, or null when the getter is unavailable.
  final bool? privateCloudSupportsCurrentLocale;
  /// PCC languages when available; an empty list need not mean none are supported.
  final List<String> privateCloudSupportedLanguages;
  /// PCC preferred-language results when the runtime can supply them.
  final List<LanguageSupport> privateCloudPreferredLanguageSupport;
  /// Additional diagnostics, including disabled native getters or host policy.
  final Map<String, Object?> details;

  /// Serializes the diagnostic snapshot and its nested availability results.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'platform': platform,
      'operatingSystemVersion': operatingSystemVersion,
      'sdkVersion': sdkVersion,
      'currentLocaleIdentifier': currentLocaleIdentifier,
      'targetLocaleIdentifier': targetLocaleIdentifier,
      'preferredLanguages': preferredLanguages,
      'localAvailability': localAvailability.toMap(),
      'localSupportsCurrentLocale': localSupportsCurrentLocale,
      'localSupportedLanguages': localSupportedLanguages,
      'localPreferredLanguageSupport': localPreferredLanguageSupport
          .map((LanguageSupport value) => value.toMap())
          .toList(growable: false),
      'privateCloudAvailability': privateCloudAvailability?.toMap(),
      'privateCloudSupportsCurrentLocale': privateCloudSupportsCurrentLocale,
      'privateCloudSupportedLanguages': privateCloudSupportedLanguages,
      'privateCloudPreferredLanguageSupport':
          privateCloudPreferredLanguageSupport
              .map((LanguageSupport value) => value.toMap())
              .toList(growable: false),
      'details': details,
    };
  }
}

/// Support result for one locale or preferred language identifier.
final class LanguageSupport {
  /// Creates a support result for one locale or language identifier.
  const LanguageSupport({required this.identifier, required this.isSupported});

  /// Decodes a result, conservatively treating absent support as false.
  factory LanguageSupport.fromMap(Map<Object?, Object?> map) {
    return LanguageSupport(
      identifier: (map['identifier'] as String?) ?? 'unknown',
      isSupported: (map['isSupported'] as bool?) ?? false,
    );
  }

  /// Locale or language identifier queried by the native host.
  final String identifier;
  /// Whether the queried native model supports that identifier.
  final bool isSupported;

  /// Serializes this single support result.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'identifier': identifier,
      'isSupported': isSupported,
    };
  }
}

/// Availability information for one requested model mode.
final class ModelAvailability {
  /// Creates readiness information for one requested model route.
  const ModelAvailability({
    required this.mode,
    required this.status,
    required this.isAvailable,
    required this.supportsFullPower,
    this.reason,
    this.recoverySuggestion,
    this.contextSize,
    this.quota,
    this.details = const <String, Object?>{},
  });

  /// Decodes readiness, preserving missing context and quota information.
  factory ModelAvailability.fromMap(Map<Object?, Object?> map) {
    final Map<Object?, Object?> rawQuota =
        (map['quota'] as Map<Object?, Object?>?) ?? <Object?, Object?>{};
    final Map<Object?, Object?> rawDetails =
        (map['details'] as Map<Object?, Object?>?) ?? <Object?, Object?>{};

    return ModelAvailability(
      mode: _modeFromName((map['mode'] as String?) ?? ModelMode.local.name),
      status: _statusFromName(
        (map['status'] as String?) ?? AvailabilityStatus.unknown.name,
      ),
      isAvailable: (map['isAvailable'] as bool?) ?? false,
      supportsFullPower: (map['supportsFullPower'] as bool?) ?? false,
      reason: map['reason'] as String?,
      recoverySuggestion: map['recoverySuggestion'] as String?,
      contextSize: map['contextSize'] as int?,
      quota: rawQuota.isEmpty ? null : PrivateCloudQuota.fromMap(rawQuota),
      details: rawDetails.cast<String, Object?>(),
    );
  }

  /// Model route associated with this query.
  final ModelMode mode;
  /// Typed readiness state and known reason for unavailability.
  final AvailabilityStatus status;
  /// Whether generation can be attempted now; readiness can subsequently change.
  final bool isAvailable;
  /// Compatibility PCC capability indication, not a permission grant.
  final bool supportsFullPower;
  /// Native explanation of the current state, when available.
  final String? reason;
  /// Suggested recovery action, when the native bridge can identify one.
  final String? recoverySuggestion;
  /// Selected route's context window size in tokens, when exposed.
  final int? contextSize;
  /// Native PCC quota details, or null when not reported.
  final PrivateCloudQuota? quota;
  /// Extra native readiness, SDK and host-policy information.
  final Map<String, Object?> details;

  /// Serializes readiness without rechecking the selected route.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'mode': mode.name,
      'status': status.name,
      'isAvailable': isAvailable,
      'supportsFullPower': supportsFullPower,
      'reason': reason,
      'recoverySuggestion': recoverySuggestion,
      'contextSize': contextSize,
      'quota': quota?.toMap(),
      'details': details,
    };
  }
}

/// Daily quota details for Private Cloud Compute when Apple exposes them.
enum PrivateCloudQuotaStatus {
  /// The native runtime reports quota remains available.
  belowLimit,
  /// The native runtime reports the current limit was reached.
  limitReached,
  /// Quota information is unavailable or cannot be interpreted.
  unknown,
}

/// Optional PCC quota information; this object does not request a limit increase.
final class PrivateCloudQuota {
  /// Creates a snapshot of the quota information exposed by Apple.
  const PrivateCloudQuota({
    required this.status,
    required this.isLimitReached,
    required this.isApproachingLimit,
    required this.canRequestLimitIncrease,
    this.resetDate,
    this.details = const <String, Object?>{},
  });

  /// Decodes quota fields and an optional reset timestamp.
  factory PrivateCloudQuota.fromMap(Map<Object?, Object?> map) {
    final Map<Object?, Object?> rawDetails =
        (map['details'] as Map<Object?, Object?>?) ?? <Object?, Object?>{};

    return PrivateCloudQuota(
      status: _quotaStatusFromName((map['status'] as String?) ?? 'unknown'),
      isLimitReached: (map['isLimitReached'] as bool?) ?? false,
      isApproachingLimit: (map['isApproachingLimit'] as bool?) ?? false,
      canRequestLimitIncrease:
          (map['canRequestLimitIncrease'] as bool?) ?? false,
      resetDate: _dateFromMilliseconds(map['resetDate']),
      details: rawDetails.cast<String, Object?>(),
    );
  }

  /// Native quota state, or unknown when not supplied.
  final PrivateCloudQuotaStatus status;
  /// Whether the runtime reports that the quota is exhausted.
  final bool isLimitReached;
  /// Whether the runtime reports that the quota is close to its limit.
  final bool isApproachingLimit;
  /// Native eligibility indicator; no increase-request API is exposed here.
  final bool canRequestLimitIncrease;
  /// Quota reset timestamp, when supplied by the runtime.
  final DateTime? resetDate;
  /// Additional native quota metadata.
  final Map<String, Object?> details;

  /// Serializes quota information with the reset date in epoch milliseconds.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'status': status.name,
      'isLimitReached': isLimitReached,
      'isApproachingLimit': isApproachingLimit,
      'canRequestLimitIncrease': canRequestLimitIncrease,
      'resetDate': resetDate?.millisecondsSinceEpoch,
      'details': details,
    };
  }
}

ModelCapability? _capabilityFromName(String name) {
  for (final ModelCapability value in ModelCapability.values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}

ModelMode _modeFromName(String name) {
  for (final ModelMode value in ModelMode.values) {
    if (value.name == name) {
      return value;
    }
  }
  return ModelMode.local;
}

AvailabilityStatus _statusFromName(String name) {
  for (final AvailabilityStatus value in AvailabilityStatus.values) {
    if (value.name == name) {
      return value;
    }
  }
  return AvailabilityStatus.unknown;
}

DateTime? _dateFromMilliseconds(Object? value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return null;
}

PrivateCloudQuotaStatus _quotaStatusFromName(String name) {
  for (final PrivateCloudQuotaStatus value in PrivateCloudQuotaStatus.values) {
    if (value.name == name) {
      return value;
    }
  }
  return PrivateCloudQuotaStatus.unknown;
}

List<LanguageSupport> _languageSupportListFromValues(List<Object?> values) {
  return values
      .whereType<Map<Object?, Object?>>()
      .map(LanguageSupport.fromMap)
      .toList(growable: false);
}
