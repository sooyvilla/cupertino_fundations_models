import Flutter
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum ErrorMapper {
    static func flutterError(code: String, message: String, details: [String: Any] = [:]) -> FlutterError {
        return FlutterError(
            code: code,
            message: message,
            details: details
        )
    }

    static func flutterError(from error: Error) -> FlutterError {
        if error is CancellationError {
            return flutterError(code: "cancelled", message: "The request was cancelled.")
        }
        if let nativeError: NativeSessionError = error as? NativeSessionError {
            switch nativeError {
            case .sessionNotFound:
                return flutterError(code: "invalidRequest", message: "The requested session does not exist.")
            case .foundationModelsUnavailable:
                return flutterError(code: "modelUnavailable", message: "Foundation Models is not available in this runtime or SDK.")
            case .invalidRequest(let message):
                return flutterError(code: "invalidRequest", message: message)
            case .modelUnavailable(let code, let message, let recoverySuggestion):
                return flutterError(
                    code: code,
                    message: message,
                    details: [
                        "recoverySuggestion": recoverySuggestion
                    ]
                )
            }
        }

        #if canImport(FoundationModels) && compiler(>=6.4)
        if #available(iOS 27.0, *) {
            if let languageModelError: LanguageModelError = error as? LanguageModelError {
                return languageModelFlutterError(languageModelError)
            }
            if let systemModelError: SystemLanguageModel.Error = error as? SystemLanguageModel.Error {
                return systemModelFlutterError(systemModelError)
            }
            if let sessionError: LanguageModelSession.Error = error as? LanguageModelSession.Error {
                return sessionFlutterError(sessionError)
            }
            if let privateCloudError: PrivateCloudComputeLanguageModel.Error = error as? PrivateCloudComputeLanguageModel.Error {
                return privateCloudFlutterError(privateCloudError)
            }
            if let parsingError: GeneratedContent.ParsingError = error as? GeneratedContent.ParsingError {
                return flutterError(
                    code: "parsingFailure",
                    message: parsingError.localizedDescription
                )
            }
        }
        #endif

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), error is LanguageModelSession.ToolCallError {
            return flutterError(code: "toolFailed", message: error.localizedDescription)
        }
        #endif

        let message: String = error.localizedDescription
        let fallbackDescription: String = String(describing: error)
        let resolvedMessage: String = message.isEmpty ? fallbackDescription : message
        let code: String = errorCode(from: resolvedMessage)
        return flutterError(
            code: code,
            message: resolvedMessage
        )
    }

    private static func errorCode(from message: String) -> String {
        let normalized: String = message.lowercased()
        if normalized.contains("apple intelligence") ||
            normalized.contains("appleintelligence") ||
            normalized.contains("not enabled") {
            return "appleIntelligenceDisabled"
        }
        if normalized.contains("asset") ||
            normalized.contains("download") ||
            normalized.contains("modelnotready") ||
            normalized.contains("not ready") {
            return "assetsUnavailable"
        }
        if normalized.contains("devicenoteligible") || normalized.contains("not eligible") {
            return "unsupportedPlatform"
        }
        if normalized.contains("language") || normalized.contains("locale") {
            return "unsupportedLanguage"
        }
        if normalized.contains("speech") && normalized.contains("permission") {
            return "speechRecognitionDenied"
        }
        if normalized.contains("speech") {
            return "speechRecognitionUnavailable"
        }
        if normalized.contains("context") || normalized.contains("token") {
            return "contextSizeExceeded"
        }
        if normalized.contains("network") {
            return "networkUnavailable"
        }
        if normalized.contains("quota") || normalized.contains("limit") {
            return "quotaExceeded"
        }
        return "nativeFailure"
    }

    #if canImport(FoundationModels) && compiler(>=6.4)
    @available(iOS 27.0, *)
    private static func languageModelFlutterError(_ error: LanguageModelError) -> FlutterError {
        switch error {
        case .contextSizeExceeded(let context):
            return flutterError(
                code: "contextSizeExceeded",
                message: error.localizedDescription,
                details: [
                    "contextSize": context.contextSize,
                    "tokenCount": context.tokenCount,
                    "recoverySuggestion": "Trim the session history or create a new session."
                ]
            )
        case .rateLimited(let context):
            return flutterError(
                code: "rateLimited",
                message: error.localizedDescription,
                details: [
                    "resetDate": millisecondsSinceEpoch(context.resetDate),
                    "recoverySuggestion": "Wait until the model rate limit resets before retrying."
                ]
            )
        case .guardrailViolation:
            return flutterError(
                code: "guardrailViolation",
                message: error.localizedDescription,
                details: ["recoverySuggestion": "Revise the prompt or generated content request."]
            )
        case .refusal:
            return flutterError(
                code: "refusal",
                message: error.localizedDescription,
                details: ["recoverySuggestion": "Offer another way to complete the request without retrying the same prompt unchanged."]
            )
        case .unsupportedCapability(let context):
            return flutterError(
                code: "unsupportedCapability",
                message: error.localizedDescription,
                details: [
                    "capability": String(describing: context.capability),
                    "recoverySuggestion": "Check the selected model capabilities before sending the request."
                ]
            )
        case .unsupportedTranscriptContent:
            return flutterError(
                code: "unsupportedTranscriptContent",
                message: error.localizedDescription,
                details: ["recoverySuggestion": "Remove transcript entries the selected model cannot process."]
            )
        case .unsupportedGenerationGuide(let context):
            return flutterError(
                code: "unsupportedGenerationGuide",
                message: error.localizedDescription,
                details: [
                    "schemaName": context.schemaName as Any,
                    "recoverySuggestion": "Simplify the structured generation schema or guides."
                ]
            )
        case .unsupportedLanguageOrLocale(let context):
            return flutterError(
                code: "unsupportedLanguage",
                message: error.localizedDescription,
                details: [
                    "languageCode": String(describing: context.languageCode),
                    "recoverySuggestion": "Use a language returned by the selected model's supportedLanguages property."
                ]
            )
        case .timeout:
            return flutterError(
                code: "generationTimeout",
                message: error.localizedDescription,
                details: ["recoverySuggestion": "Retry once or reduce the request complexity."]
            )
        @unknown default:
            return flutterError(code: "nativeFailure", message: error.localizedDescription)
        }
    }

    @available(iOS 27.0, *)
    private static func systemModelFlutterError(_ error: SystemLanguageModel.Error) -> FlutterError {
        switch error {
        case .assetsUnavailable:
            return flutterError(
                code: "assetsUnavailable",
                message: error.localizedDescription,
                details: ["recoverySuggestion": "Wait for Apple Intelligence model assets to finish downloading."]
            )
        @unknown default:
            return flutterError(code: "modelUnavailable", message: error.localizedDescription)
        }
    }

    @available(iOS 27.0, *)
    private static func sessionFlutterError(_ error: LanguageModelSession.Error) -> FlutterError {
        switch error {
        case .concurrentRequests:
            return flutterError(
                code: "concurrentRequests",
                message: error.localizedDescription,
                details: ["recoverySuggestion": "Wait for the active response or cancel it before starting another request on the same session."]
            )
        case .transcriptMutationWhileResponding:
            return flutterError(
                code: "transcriptMutationWhileResponding",
                message: error.localizedDescription,
                details: ["recoverySuggestion": "Do not mutate the transcript while the session is responding."]
            )
        @unknown default:
            return flutterError(code: "nativeFailure", message: error.localizedDescription)
        }
    }

    @available(iOS 27.0, *)
    private static func privateCloudFlutterError(
        _ error: PrivateCloudComputeLanguageModel.Error
    ) -> FlutterError {
        switch error {
        case .networkFailure:
            return flutterError(
                code: "networkUnavailable",
                message: error.localizedDescription,
                details: ["recoverySuggestion": "Check the network connection or fall back to the on-device model."]
            )
        case .quotaLimitReached(let context):
            return flutterError(
                code: "quotaExceeded",
                message: error.localizedDescription,
                details: [
                    "resetDate": millisecondsSinceEpoch(context.resetDate),
                    "canRequestLimitIncrease": context.limitIncreaseSuggestion != nil,
                    "recoverySuggestion": "Wait for the PCC quota to reset or fall back to the on-device model."
                ]
            )
        case .serviceUnavailable:
            return flutterError(
                code: "privateCloudServiceUnavailable",
                message: error.localizedDescription,
                details: ["recoverySuggestion": "Fall back to the on-device model and retry PCC later."]
            )
        @unknown default:
            return flutterError(code: "privateCloudUnavailable", message: error.localizedDescription)
        }
    }

    private static func millisecondsSinceEpoch(_ date: Date?) -> Any {
        guard let date else {
            return NSNull()
        }
        return Int64(date.timeIntervalSince1970 * 1000)
    }
    #endif
}
