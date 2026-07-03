import Flutter
import Foundation

/// Invokes Dart-registered tools from native model sessions.
///
/// The model asks for a tool call in Swift; this bridge forwards it to Dart
/// over the method channel and returns the Dart result as the tool output.
final class ToolBridge: @unchecked Sendable {
    private let methodChannel: FlutterMethodChannel

    init(methodChannel: FlutterMethodChannel) {
        self.methodChannel = methodChannel
    }

    func callTool(
        sessionId: String,
        name: String,
        argumentsJson: String
    ) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                self.methodChannel.invokeMethod(
                    "toolCall",
                    arguments: [
                        "sessionId": sessionId,
                        "toolCallId": UUID().uuidString,
                        "name": name,
                        "argumentsJson": argumentsJson
                    ]
                ) { result in
                    continuation.resume(returning: Self.toolOutput(from: result, name: name))
                }
            }
        }
    }

    private static func toolOutput(from result: Any?, name: String) -> String {
        if let error: FlutterError = result as? FlutterError {
            return "Tool \(name) failed: \(error.message ?? error.code)"
        }
        if result is NSObject && (result as? NSObject) == FlutterMethodNotImplemented {
            return "Tool \(name) is not implemented by the app."
        }
        guard let map: [String: Any] = result as? [String: Any] else {
            return "Tool \(name) returned no result."
        }
        let isError: Bool = map["isError"] as? Bool ?? false
        if isError {
            let message: String = map["message"] as? String ?? "unknown tool failure"
            return "Tool \(name) failed: \(message)"
        }
        let value: Any? = map["value"]
        if let text: String = value as? String {
            return text
        }
        guard let value, !(value is NSNull) else {
            return ""
        }
        if JSONSerialization.isValidJSONObject(value),
           let data: Data = try? JSONSerialization.data(withJSONObject: value),
           let json: String = String(data: data, encoding: .utf8) {
            return json
        }
        return String(describing: value)
    }
}
