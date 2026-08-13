import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif
#if canImport(Speech)
import Speech
#endif

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

        if majorVersion >= 26 {
            capabilities.append(contentsOf: [
                "localText",
                "streaming",
                "toolCalling",
                "structuredOutput"
            ])
            contextSize = 4096
        }

        #if compiler(>=6.4)
        if majorVersion > 26 || majorVersion == 26 && minorVersion >= 4 {
            capabilities.append("tokenCounting")
        }
        if majorVersion >= 27 {
            capabilities.append(contentsOf: [
                "privateCloudCompute",
                "dynamicProfiles",
                "fullPower"
            ])
            privateCloudContextSize = 32768
        }
        #endif

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model: SystemLanguageModel = SystemLanguageModel.default
            contextSize = model.contextSize
            supportedLanguages = languageIdentifiers(from: model.supportedLanguages)
        }
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            let localModel: SystemLanguageModel = SystemLanguageModel.default
            if localModel.capabilities.contains(.reasoning) {
                capabilities.append("reasoning")
            }
            let privateCloudModel: PrivateCloudComputeLanguageModel =
                PrivateCloudComputeLanguageModel()
            let privateCloud: [String: Any] = privateCloudAvailability(
                model: privateCloudModel,
                mode: "privateCloudCompute"
            )
            supportsFullPower = privateCloud["isAvailable"] as? Bool ?? false
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
                "foundationModelsRuntime": majorVersion >= 26,
                "ios27PrimaryRuntime": majorVersion >= 27,
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
        var privateCloudSupportedLanguages: [String] = []
        var privateCloudSupportsCurrentLocale: Any = NSNull()
        var privateCloudPreferredLanguageSupport: [[String: Any]] = []

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
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
            let privateCloud: PrivateCloudComputeLanguageModel = PrivateCloudComputeLanguageModel()
            privateCloudAvailabilityValue = privateCloudAvailability(
                model: privateCloud,
                mode: "privateCloudCompute"
            )
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
            "localAvailability": localAvailability(mode: "local"),
            "localSupportsCurrentLocale": localSupportsCurrentLocale,
            "localSupportedLanguages": localSupportedLanguages,
            "localPreferredLanguageSupport": localPreferredLanguageSupport,
            "privateCloudAvailability": privateCloudAvailabilityValue,
            "privateCloudSupportsCurrentLocale": privateCloudSupportsCurrentLocale,
            "privateCloudSupportedLanguages": privateCloudSupportedLanguages,
            "privateCloudPreferredLanguageSupport": privateCloudPreferredLanguageSupport,
            "details": [
                "foundationModelsRuntime": majorVersion >= 26,
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

        if mode == "automatic" && cloudPolicy != "never" {
            #if canImport(FoundationModels)
            #if compiler(>=6.4)
            if #available(iOS 27.0, *) {
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

        return localAvailability(mode: mode == "automatic" ? "local" : mode)
    }

    private func localAvailability(mode: String) -> [String: Any] {
        let majorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model: SystemLanguageModel = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return [
                    "mode": "local",
                    "status": "available",
                    "isAvailable": true,
                    "supportsFullPower": majorVersion >= 27,
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
                    status: availabilityStatus(from: reasonText),
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

        return [
            "mode": mode,
            "status": "available",
            "isAvailable": true,
            "supportsFullPower": majorVersion >= 27,
            "reason": NSNull(),
            "recoverySuggestion": NSNull(),
            "contextSize": 4096,
            "quota": NSNull(),
            "details": [
                "runtimeChecked": false,
                "ios27PrimaryRuntime": majorVersion >= 27
            ]
        ]
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
            let reasonText: String = String(describing: reason)
            return unavailable(
                mode: mode,
                status: privateCloudStatus(from: reasonText),
                reason: reasonText,
                recoverySuggestion: "Check Apple Intelligence, network availability, device eligibility, PCC quota, and iCloud account state."
            )
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

    private func availabilityStatus(from reason: String) -> String {
        let normalized: String = reason.lowercased()
        if normalized.contains("appleintelligence") || normalized.contains("intelligence") {
            return "appleIntelligenceDisabled"
        }
        if normalized.contains("asset") || normalized.contains("modelnotready") || normalized.contains("not ready") {
            return "assetsUnavailable"
        }
        if normalized.contains("devicenoteligible") || normalized.contains("not eligible") {
            return "unsupportedPlatform"
        }
        if normalized.contains("language") || normalized.contains("locale") {
            return "unsupportedLanguage"
        }
        if normalized.contains("restricted") {
            return "restricted"
        }
        return "unavailable"
    }

    private func privateCloudStatus(from reason: String) -> String {
        let normalized: String = reason.lowercased()
        if normalized.contains("noteligible") || normalized.contains("not eligible") {
            return "unsupportedPlatform"
        }
        if normalized.contains("systemnotready") || normalized.contains("not ready") {
            return "unavailable"
        }
        if normalized.contains("quota") || normalized.contains("limit") {
            return "quotaExceeded"
        }
        if normalized.contains("network") {
            return "networkUnavailable"
        }
        if normalized.contains("appleintelligence") || normalized.contains("intelligence") {
            return "appleIntelligenceDisabled"
        }
        return "unavailable"
    }

    private func operatingSystemVersionString() -> String {
        let version: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private func sdkVersionString() -> String {
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
