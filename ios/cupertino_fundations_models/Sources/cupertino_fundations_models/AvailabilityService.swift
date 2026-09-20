import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif
#if canImport(Speech)
import Speech
#endif

@MainActor
final class AvailabilityService {
    func capabilities() -> [String: Any] {
        let majorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let minorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.minorVersion
        var capabilities: [String] = []
        var contextSize: Int?
        var privateCloudContextSize: Int?
        var preferredMode: String = "local"
        var supportsFullPower: Bool = false
        var supportedLanguages: [String] = []
        var foundationModelsRuntime: Bool = false
        var dynamicProfilesSdkAvailable: Bool = false

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            foundationModelsRuntime = true
            capabilities.append(contentsOf: [
                "localText",
                "streaming",
                "toolCalling",
                "structuredOutput"
            ])
            let model: SystemLanguageModel = SystemLanguageModel.default
            contextSize = model.contextSize
            supportedLanguages = languageIdentifiers(from: model.supportedLanguages)
        }
        #if compiler(>=6.4)
        if majorVersion > 26 || majorVersion == 26 && minorVersion >= 4 {
            capabilities.append("tokenCounting")
        }
        if #available(iOS 27.0, *) {
            dynamicProfilesSdkAvailable = true
            capabilities.append("privateCloudCompute")
            privateCloudContextSize = 32768
            let localModel: SystemLanguageModel = SystemLanguageModel.default
            if localModel.capabilities.contains(.reasoning) {
                capabilities.append("reasoning")
            }
            if PrivateCloudComputeAccess.isEnabled {
                let privateCloudModel: PrivateCloudComputeLanguageModel =
                    PrivateCloudComputeLanguageModel()
                let privateCloud: [String: Any] = privateCloudAvailability(
                    model: privateCloudModel,
                    mode: "privateCloudCompute"
                )
                supportsFullPower = privateCloud["isAvailable"] as? Bool ?? false
                if supportsFullPower {
                    capabilities.append("fullPower")
                }
            }
            preferredMode = supportsFullPower ? "privateCloudCompute" : "local"
        } else {
            preferredMode = "local"
        }
        #endif
        #endif

        return [
            "platform": "iOS",
            "operatingSystemVersion": operatingSystemVersionString(),
            "sdkVersion": sdkVersionString(),
            "capabilities": Array(Set(capabilities)).sorted(),
            "supportsFullPower": supportsFullPower,
            "preferredMode": preferredMode,
            "contextSize": contextSize as Any,
            "privateCloudContextSize": privateCloudContextSize as Any,
            "supportedLanguages": supportedLanguages,
            "details": [
                "foundationModelsRuntime": foundationModelsRuntime,
                "ios27PrimaryRuntime": majorVersion >= 27,
                "appleDynamicProfilesSdkAvailable": dynamicProfilesSdkAvailable,
                "dynamicProfilesExposedByPackage": false,
                "privateCloudHostOptIn": PrivateCloudComputeAccess.isEnabled,
                "nativeImageAttachmentsUsable": false,
                "imageFallback": "visionPreprocessing"
            ]
        ]
    }

    func supportedLanguages() async -> [[String: Any]] {
        #if canImport(FoundationModels) && canImport(Speech)
        if #available(iOS 26.0, *) {
            let model: SystemLanguageModel = SystemLanguageModel.default
            let speechLocales: [Locale] = await SpeechTranscriber.supportedLocales
            let installedLocales: [Locale] = await SpeechTranscriber.installedLocales
            let installedIdentifiers: Set<String> = Set(
                installedLocales.map { normalizedLocaleIdentifier($0.identifier) }
            )
            let displayLocale: Locale = Locale.current
            var languagesByIdentifier: [String: [String: Any]] = [:]

            for locale in speechLocales where model.supportsLocale(locale) {
                let identifier: String = normalizedLocaleIdentifier(locale.identifier)
                let nativeLocale: Locale = Locale(identifier: identifier)
                let displayName: String = displayLocale.localizedString(
                    forIdentifier: identifier
                ) ?? identifier
                let nativeDisplayName: String = nativeLocale.localizedString(
                    forIdentifier: identifier
                ) ?? displayName
                languagesByIdentifier[identifier.lowercased()] = [
                    "identifier": identifier,
                    "languageCode": locale.language.languageCode?.identifier ?? identifier,
                    "displayName": displayName,
                    "nativeDisplayName": nativeDisplayName,
                    "isTranscriptionAssetInstalled": installedIdentifiers.contains(
                        normalizedLocaleIdentifier(identifier)
                    )
                ]
            }

            return languagesByIdentifier.values.sorted { first, second in
                let firstName: String = first["displayName"] as? String ?? ""
                let secondName: String = second["displayName"] as? String ?? ""
                return firstName.localizedStandardCompare(secondName) == .orderedAscending
            }
        }
        #endif

        return []
    }

    func diagnostics(arguments: [String: Any]) -> [String: Any] {
        let majorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let currentLocale: Locale = Locale.current
        let targetLocaleIdentifier: String = arguments["localeIdentifier"] as? String ?? currentLocale.identifier
        let targetLocale: Locale = Locale(identifier: targetLocaleIdentifier)
        var localSupportedLanguages: [String] = []
        var localSupportsCurrentLocale: Any = NSNull()
        var localPreferredLanguageSupport: [[String: Any]] = []
        var privateCloudAvailabilityValue: Any = NSNull()
        let privateCloudSupportedLanguages: [String] = []
        let privateCloudSupportsCurrentLocale: Any = NSNull()
        let privateCloudPreferredLanguageSupport: [[String: Any]] = []
        var foundationModelsRuntime: Bool = false

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            foundationModelsRuntime = true
            let model: SystemLanguageModel = SystemLanguageModel.default
            localSupportedLanguages = languageIdentifiers(from: model.supportedLanguages)
            localSupportsCurrentLocale = model.supportsLocale(targetLocale)
            localPreferredLanguageSupport = Locale.preferredLanguages.map { identifier in
                return [
                    "identifier": identifier,
                    "isSupported": model.supportsLocale(Locale(identifier: identifier))
                ]
            }
        }
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            if PrivateCloudComputeAccess.isEnabled {
                let privateCloud: PrivateCloudComputeLanguageModel = PrivateCloudComputeLanguageModel()
                privateCloudAvailabilityValue = privateCloudAvailability(
                    model: privateCloud,
                    mode: "privateCloudCompute"
                )
            } else {
                privateCloudAvailabilityValue = privateCloudOptInUnavailable(
                    mode: "privateCloudCompute"
                )
            }
        } else if majorVersion >= 27 {
            privateCloudAvailabilityValue = unavailable(
                mode: "privateCloudCompute",
                status: "unsupportedOsVersion",
                reason: "Private Cloud Compute is not available in the SDK used to build this app.",
                recoverySuggestion: "Build the app with Xcode 27 and the iOS 27 SDK to enable PCC."
            )
        }
        #endif
        #endif

        return [
            "platform": "iOS",
            "operatingSystemVersion": operatingSystemVersionString(),
            "sdkVersion": sdkVersionString(),
            "currentLocaleIdentifier": currentLocale.identifier,
            "targetLocaleIdentifier": targetLocaleIdentifier,
            "preferredLanguages": Locale.preferredLanguages,
            "localAvailability": localAvailability(mode: "local", localeIdentifier: targetLocaleIdentifier),
            "localSupportsCurrentLocale": localSupportsCurrentLocale,
            "localSupportedLanguages": localSupportedLanguages,
            "localPreferredLanguageSupport": localPreferredLanguageSupport,
            "privateCloudAvailability": privateCloudAvailabilityValue,
            "privateCloudSupportsCurrentLocale": privateCloudSupportsCurrentLocale,
            "privateCloudSupportedLanguages": privateCloudSupportedLanguages,
            "privateCloudPreferredLanguageSupport": privateCloudPreferredLanguageSupport,
            "details": [
                "foundationModelsRuntime": foundationModelsRuntime,
                "ios27PrimaryRuntime": majorVersion >= 27,
                "canReadSiriLanguage": false,
                "canReadPrivateCloudLanguageSupport": false
            ]
        ]
    }

    func availability(arguments: [String: Any]) -> [String: Any] {
        let mode: String = arguments["mode"] as? String ?? "automatic"
        let cloudPolicy: String = arguments["cloudPolicy"] as? String ?? "never"
        let majorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion

        if majorVersion < 26 {
            return unavailable(
                mode: mode,
                status: "unsupportedOsVersion",
                reason: "Foundation Models requires iOS 26 or later.",
                recoverySuggestion: "Run on a device with iOS 27 for the strongest model support."
            )
        }

        if mode == "privateCloudCompute" {
            guard cloudPolicy != "never" else {
                return unavailable(
                    mode: mode,
                    status: "restricted",
                    reason: "CloudPolicy.never forbids Private Cloud Compute.",
                    recoverySuggestion: "Use local mode or explicitly authorize PCC with CloudPolicy.whenExplicit."
                )
            }
            if majorVersion < 27 {
                return unavailable(
                    mode: mode,
                    status: "unsupportedOsVersion",
                    reason: "Private Cloud Compute requires iOS 27 or later.",
                    recoverySuggestion: "Use local mode on iOS 26 or upgrade the device to iOS 27."
                )
            }

            #if canImport(FoundationModels)
            #if compiler(>=6.4)
            if #available(iOS 27.0, *) {
                guard PrivateCloudComputeAccess.isEnabled else {
                    return privateCloudOptInUnavailable(mode: "privateCloudCompute")
                }
                return privateCloudAvailability(
                    model: PrivateCloudComputeLanguageModel(),
                    mode: "privateCloudCompute"
                )
            }
            #endif
            #endif

            return unavailable(
                mode: "privateCloudCompute",
                status: "unsupportedOsVersion",
                reason: "Private Cloud Compute is not available in the SDK used to build this app.",
                recoverySuggestion: "Build the app with Xcode 27 and the iOS 27 SDK to enable PCC."
            )
        }

        if mode == "automatic" && cloudPolicy == "automaticWithUserConsent" {
            #if canImport(FoundationModels)
            #if compiler(>=6.4)
            if #available(iOS 27.0, *), PrivateCloudComputeAccess.isEnabled {
                let privateCloud: [String: Any] = privateCloudAvailability(
                    model: PrivateCloudComputeLanguageModel(),
                    mode: "privateCloudCompute"
                )
                if privateCloud["isAvailable"] as? Bool ?? false {
                    return privateCloud
                }
            }
            #endif
            #endif
        }

        return localAvailability(
            mode: mode == "automatic" ? "local" : mode,
            localeIdentifier: arguments["localeIdentifier"] as? String
        )
    }

    private func localAvailability(mode: String, localeIdentifier: String? = nil) -> [String: Any] {
        let majorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model: SystemLanguageModel = SystemLanguageModel.default
            switch model.availability {
            case .available:
                if let localeIdentifier, !model.supportsLocale(Locale(identifier: localeIdentifier)) {
                    return unavailable(
                        mode: "local",
                        status: "unsupportedLanguage",
                        reason: "The on-device model does not support the requested locale.",
                        recoverySuggestion: "Choose a locale supported by the on-device model."
                    )
                }
                return [
                    "mode": "local",
                    "status": "available",
                    "isAvailable": true,
                    "supportsFullPower": false,
                    "reason": NSNull(),
                    "recoverySuggestion": NSNull(),
                    "contextSize": model.contextSize,
                    "quota": NSNull(),
                    "details": [
                        "runtimeChecked": true,
                        "ios27PrimaryRuntime": majorVersion >= 27
                    ]
                ]
            case .unavailable(let reason):
                let reasonText: String = String(describing: reason)
                return unavailable(
                    mode: "local",
                    status: ErrorMapper.localAvailabilityCode(reason),
                    reason: reasonText,
                    recoverySuggestion: "Check Apple Intelligence settings, supported language, model assets, and device compatibility."
                )
            @unknown default:
                return unavailable(
                    mode: "local",
                    status: "unknown",
                    reason: "The system returned an unknown Foundation Models availability state.",
                    recoverySuggestion: "Try again on the latest iOS 27 beta or later."
                )
            }
        }
        #endif

        return unavailable(
            mode: mode,
            status: "unsupportedOsVersion",
            reason: "Foundation Models is not available in the SDK used to build this app.",
            recoverySuggestion: "Build with an Xcode SDK that includes Foundation Models and retry on iOS 26 or later."
        )
    }

    #if canImport(FoundationModels) && compiler(>=6.4)
    @available(iOS 27.0, *)
    private func privateCloudAvailability(
        model: PrivateCloudComputeLanguageModel,
        mode: String
    ) -> [String: Any] {
        switch model.availability {
        case .available:
            let quota: [String: Any] = privateCloudQuota(model.quotaUsage)
            return [
                "mode": mode,
                "status": "available",
                "isAvailable": true,
                "supportsFullPower": true,
                "reason": NSNull(),
                "recoverySuggestion": NSNull(),
                "contextSize": 32768,
                "quota": quota,
                "details": [
                    "requiresNetwork": true,
                    "runtimeChecked": true
                ]
            ]
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return unavailable(
                    mode: mode,
                    status: "unsupportedPlatform",
                    reason: String(describing: reason),
                    recoverySuggestion: "Use a device and account eligible for Apple Intelligence and Private Cloud Compute."
                )
            case .systemNotReady:
                return unavailable(
                    mode: mode,
                    status: "unavailable",
                    reason: String(describing: reason),
                    recoverySuggestion: "Check Apple Intelligence, network availability, PCC entitlement, quota, and iCloud account state."
                )
            @unknown default:
                return unavailable(
                    mode: mode,
                    status: "unknown",
                    reason: String(describing: reason),
                    recoverySuggestion: "Retry on the latest iOS 27 beta or later."
                )
            }
        @unknown default:
            return unavailable(
                mode: mode,
                status: "unknown",
                reason: "The system returned an unknown Private Cloud Compute availability state.",
                recoverySuggestion: "Try again on the latest iOS 27 beta or later."
            )
        }
    }
    #endif

    #if canImport(FoundationModels) && compiler(>=6.4)
    @available(iOS 27.0, *)
    private func privateCloudQuota(
        _ quota: PrivateCloudComputeLanguageModel.QuotaUsage
    ) -> [String: Any] {
        let status: String
        let isApproachingLimit: Bool
        switch quota.status {
        case .belowLimit(let details):
            status = "belowLimit"
            isApproachingLimit = details.isApproachingLimit
        case .limitReached:
            status = "limitReached"
            isApproachingLimit = true
        @unknown default:
            status = "unknown"
            isApproachingLimit = false
        }

        return [
            "status": status,
            "isLimitReached": quota.isLimitReached,
            "isApproachingLimit": isApproachingLimit,
            "canRequestLimitIncrease": quota.limitIncreaseSuggestion != nil,
            "resetDate": quota.resetDate.map {
                Int64($0.timeIntervalSince1970 * 1000)
            } as Any,
            "details": [:]
        ]
    }
    #endif

    private func privateCloudOptInUnavailable(mode: String) -> [String: Any] {
        return unavailable(
            mode: mode,
            status: "missingEntitlement",
            reason: PrivateCloudComputeAccess.unavailableReason,
            recoverySuggestion: PrivateCloudComputeAccess.recoverySuggestion
        )
    }

    private func unavailable(mode: String, status: String, reason: String, recoverySuggestion: String) -> [String: Any] {
        return [
            "mode": mode,
            "status": status,
            "isAvailable": false,
            "supportsFullPower": false,
            "reason": reason,
            "recoverySuggestion": recoverySuggestion,
            "contextSize": NSNull(),
            "quota": NSNull(),
            "details": [:]
        ]
    }

    private func operatingSystemVersionString() -> String {
        let version: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private func sdkVersionString() -> String {
        if let sdkName: String = Bundle.main.object(
            forInfoDictionaryKey: "DTSDKName"
        ) as? String, !sdkName.isEmpty {
            return sdkName
        }
        #if compiler(>=6.4)
        return "27-or-newer"
        #else
        return "unknown"
        #endif
    }

    private func normalizedLocaleIdentifier(_ identifier: String) -> String {
        return identifier.replacingOccurrences(of: "_", with: "-")
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func languageIdentifiers(from languages: Set<Locale.Language>) -> [String] {
        return languages
            .map { language in language.minimalIdentifier }
            .sorted()
    }
    #endif

}
