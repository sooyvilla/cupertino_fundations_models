import Flutter
import Foundation

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
            return "contextExceeded"
        }
        if normalized.contains("network") {
            return "networkUnavailable"
        }
        if normalized.contains("quota") || normalized.contains("limit") {
            return "quotaExceeded"
        }
        return "nativeFailure"
    }
}
