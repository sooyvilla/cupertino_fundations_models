@preconcurrency import Flutter
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
        argumentsJson: String,
        timeoutMilliseconds: Int
    ) async -> String {
        let state: ToolCallContinuationState = ToolCallContinuationState()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                state.install(continuation: continuation)
                let timeoutTask: Task<Void, Never> = Task {
                    do {
                        try await Task.sleep(
                            nanoseconds: UInt64(timeoutMilliseconds) * 1_000_000
                        )
                    } catch {
                        return
                    }
                    state.finish(
                        value: "Tool \(name) timed out after \(timeoutMilliseconds)ms."
                    )
                }
                state.install(timeoutTask: timeoutTask)

                DispatchQueue.main.async {
                    guard state.isPending else {
                        return
                    }
                    self.methodChannel.invokeMethod(
                        "toolCall",
                        arguments: [
                            "sessionId": sessionId,
                            "toolCallId": UUID().uuidString,
                            "name": name,
                            "argumentsJson": argumentsJson
                        ]
                    ) { result in
                        state.finish(
                            value: Self.boundedToolOutput(
                                Self.toolOutput(from: result, name: name)
                            )
                        )
                    }
                }
            }
        } onCancel: {
            state.finish(value: "Tool \(name) was cancelled.")
        }
    }

    private static func boundedToolOutput(_ output: String) -> String {
        let maximumCharacters: Int = 64_000
        guard output.count > maximumCharacters else {
            return output
        }
        return "Tool output exceeded the 64,000-character transport limit. Return a smaller, complete result."
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

private final class ToolCallContinuationState: @unchecked Sendable {
    private let lock: NSLock = NSLock()
    private var continuation: CheckedContinuation<String, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var completedValue: String?

    var isPending: Bool {
        lock.lock()
        defer { lock.unlock() }
        return completedValue == nil
    }

    func install(continuation: CheckedContinuation<String, Never>) {
        lock.lock()
        if let completedValue {
            lock.unlock()
            continuation.resume(returning: completedValue)
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    func install(timeoutTask: Task<Void, Never>) {
        lock.lock()
        if completedValue != nil {
            lock.unlock()
            timeoutTask.cancel()
            return
        }
        self.timeoutTask = timeoutTask
        lock.unlock()
    }

    func finish(value: String) {
        lock.lock()
        guard completedValue == nil else {
            lock.unlock()
            return
        }
        completedValue = value
        let continuation: CheckedContinuation<String, Never>? = continuation
        let timeoutTask: Task<Void, Never>? = timeoutTask
        self.continuation = nil
        self.timeoutTask = nil
        lock.unlock()

        timeoutTask?.cancel()
        continuation?.resume(returning: value)
    }
}
