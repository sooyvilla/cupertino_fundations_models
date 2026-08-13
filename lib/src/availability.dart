/// The model execution target requested by the app.
enum ModelMode { local, privateCloudCompute, automatic }

/// The policy that controls whether a request may leave the device.
enum CloudPolicy { never, whenExplicit, automaticWithUserConsent }

/// Runtime capabilities exposed by the native Apple stack.
enum ModelCapability {
  localText,
  streaming,
  toolCalling,
  structuredOutput,
  tokenCounting,
  imageInput,
  privateCloudCompute,
  reasoning,
  dynamicProfiles,
  fullPower,
}

/// Availability result for a requested model mode.
enum AvailabilityStatus {
  available,
  unavailable,
  unsupportedPlatform,
  unsupportedOsVersion,
  appleIntelligenceDisabled,
  assetsUnavailable,
  unsupportedLanguage,
  networkUnavailable,
  quotaExceeded,
  missingEntitlement,
  restricted,
  unknown,
}

/// Describes the native platform and Apple Foundation Models support.
final class FoundationModelsCapabilities {
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

  final String platform;
  final String operatingSystemVersion;
  final String sdkVersion;
  final Set<ModelCapability> capabilities;
  final bool supportsFullPower;
  final ModelMode preferredMode;
  final int? contextSize;
  final int? privateCloudContextSize;
  final List<String> supportedLanguages;
  final Map<String, Object?> details;

  bool supports(ModelCapability capability) =>
      capabilities.contains(capability);

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

  final String platform;
  final String operatingSystemVersion;
  final String sdkVersion;
  final String currentLocaleIdentifier;
  final String targetLocaleIdentifier;
  final List<String> preferredLanguages;
  final ModelAvailability localAvailability;
  final bool? localSupportsCurrentLocale;
  final List<String> localSupportedLanguages;
  final List<LanguageSupport> localPreferredLanguageSupport;
  final ModelAvailability? privateCloudAvailability;
  final bool? privateCloudSupportsCurrentLocale;
  final List<String> privateCloudSupportedLanguages;
  final List<LanguageSupport> privateCloudPreferredLanguageSupport;
  final Map<String, Object?> details;

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
  const LanguageSupport({required this.identifier, required this.isSupported});

  factory LanguageSupport.fromMap(Map<Object?, Object?> map) {
    return LanguageSupport(
      identifier: (map['identifier'] as String?) ?? 'unknown',
      isSupported: (map['isSupported'] as bool?) ?? false,
    );
  }

  final String identifier;
  final bool isSupported;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'identifier': identifier,
      'isSupported': isSupported,
    };
  }
}

/// Availability information for one requested model mode.
final class ModelAvailability {
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

  final ModelMode mode;
  final AvailabilityStatus status;
  final bool isAvailable;
  final bool supportsFullPower;
  final String? reason;
  final String? recoverySuggestion;
  final int? contextSize;
  final PrivateCloudQuota? quota;
  final Map<String, Object?> details;

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
enum PrivateCloudQuotaStatus { belowLimit, limitReached, unknown }

final class PrivateCloudQuota {
  const PrivateCloudQuota({
    required this.status,
    required this.isLimitReached,
    required this.isApproachingLimit,
    required this.canRequestLimitIncrease,
    this.resetDate,
    this.details = const <String, Object?>{},
  });

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

  final PrivateCloudQuotaStatus status;
  final bool isLimitReached;
  final bool isApproachingLimit;
  final bool canRequestLimitIncrease;
  final DateTime? resetDate;
  final Map<String, Object?> details;

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
