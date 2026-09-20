@preconcurrency import Flutter
import UIKit

@MainActor
public final class CupertinoFoundationModelsPlugin: NSObject, @preconcurrency FlutterPlugin {
    private static let methodChannelName: String = "cupertino_fundations_models/methods"
    private static let transcriptionEventChannelName: String = "cupertino_fundations_models/transcription_events"
    private let registry: SessionRegistry
    private let availabilityService: AvailabilityService = AvailabilityService()
    private let fileSelectionService: FileSelectionService = FileSelectionService()
    private let speechTranscriptionService: SpeechTranscriptionService = SpeechTranscriptionService()
    private let liveTranscriptionService: LiveTranscriptionService = LiveTranscriptionService()
    private var methodChannel: FlutterMethodChannel?
    private var requestTasks: [String: TrackedTask] = [:]
    private var streamTasks: [String: TrackedStreamTask] = [:]
    private var transcriptionTasks: [String: TrackedTask] = [:]
    private var cancellationTasks: [String: TrackedTask] = [:]
    private var disposingSessionIds: Set<String> = []

    private init(registry: SessionRegistry) {
        self.registry = registry
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel: FlutterMethodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        let toolBridge: ToolBridge = ToolBridge(methodChannel: methodChannel)
        let instance: CupertinoFoundationModelsPlugin = CupertinoFoundationModelsPlugin(
            registry: SessionRegistry(toolBridge: toolBridge)
        )
        let transcriptionEventChannel: FlutterEventChannel = FlutterEventChannel(
            name: transcriptionEventChannelName,
            binaryMessenger: registrar.messenger()
        )
        instance.methodChannel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        transcriptionEventChannel.setStreamHandler(instance.liveTranscriptionService)

    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getCapabilities":
            result(availabilityService.capabilities())
        case "getSupportedLanguages":
            Task { [weak self] in
                let languages: [[String: Any]] = await self?.availabilityService.supportedLanguages() ?? []
                self?.complete(result, languages)
            }
        case "getDiagnostics":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            result(availabilityService.diagnostics(arguments: arguments))
        case "checkAvailability":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            result(availabilityService.availability(arguments: arguments))
        case "createSession":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            let message: FlutterChannelValue<[String: Any]> = FlutterChannelValue(arguments)
            Task {
                do {
                    let response: FlutterChannelValue<[String: Any]> = try await registry
                        .createSession(arguments: message)
                    complete(result, response.value)
                } catch {
                    complete(result, ErrorMapper.flutterError(from: error))
                }
            }
        case "countTokens":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            if arguments["target"] as? String == "transcript" {
                runSessionRequest(arguments: arguments, result: result) { registry, arguments in
                    let count: Int = try await registry.countTokens(arguments: arguments)
                    return FlutterChannelValue(count as Any?)
                }
                return
            }
            Task {
                do {
                    let count: Int = try await registry.countTokens(
                        arguments: FlutterChannelValue(arguments)
                    )
                    complete(result, count)
                } catch {
                    complete(result, ErrorMapper.flutterError(from: error))
                }
            }
        case "pickFile":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            fileSelectionService.pickFile(arguments: arguments, result: result)
        case "transcribeAudio":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            let requestId: String = arguments["requestId"] as? String ?? UUID().uuidString
            guard transcriptionTasks[requestId] == nil else {
                result(ErrorMapper.flutterError(
                    code: "concurrentRequests",
                    message: "This transcription request is already active."
                ))
                return
            }
            let taskToken: UUID = UUID()
            let task: Task<Void, Never> = Task { [weak self] in
                let completion: Any?
                do {
                    guard let self else {
                        return
                    }
                    let response: FlutterChannelValue<[String: Any]> = try await self
                        .speechTranscriptionService.transcribeAudio(
                            arguments: FlutterChannelValue(arguments)
                        )
                    completion = response.value
                } catch {
                    completion = ErrorMapper.flutterError(from: error)
                }
                guard let self else {
                    return
                }
                self.removeTranscriptionTask(requestId: requestId, token: taskToken)
                self.complete(result, completion)
            }
            transcriptionTasks[requestId] = TrackedTask(token: taskToken, task: task)
        case "cancelTranscription":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            let requestId: String = arguments["requestId"] as? String ?? ""
            let task: Task<Void, Never>? = transcriptionTasks.removeValue(forKey: requestId)?.task
            finishCancellation(tasks: task.map { [$0] } ?? [], result: result)
        case "respond":
            runSessionRequest(call: call, result: result) { registry, arguments in
                let response: FlutterChannelValue<[String: Any]> = try await registry.respond(
                    arguments: arguments
                )
                return FlutterChannelValue(response.value as Any?)
            }
        case "generateStructured":
            runSessionRequest(call: call, result: result) { registry, arguments in
                let response: FlutterChannelValue<[String: Any]> = try await registry
                    .respondStructured(arguments: arguments)
                return FlutterChannelValue(response.value as Any?)
            }
        case "prewarm":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            runSessionRequest(arguments: arguments, result: result) { registry, arguments in
                try await registry.prewarm(arguments: arguments)
                return FlutterChannelValue(nil as Any?)
            }
        case "startStream":
            startStream(call: call, result: result)
        case "cancelStream":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            let requestId: String = arguments["requestId"] as? String ?? ""
            let sessionId: String = arguments["sessionId"] as? String ?? ""
            let task: Task<Void, Never>?
            if let trackedTask: TrackedStreamTask = streamTasks[requestId] {
                task = cancelSessionTasks(sessionId: trackedTask.sessionId)
            } else {
                task = cancellationTasks[sessionId]?.task
            }
            Task {
                await task?.value
                complete(result, nil)
            }
        case "cancelActiveRequest":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            let sessionId: String = arguments["sessionId"] as? String ?? ""
            let task: Task<Void, Never> = cancelSessionTasks(sessionId: sessionId)
            Task {
                await task.value
                complete(result, nil)
            }
        case "disposeSession":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            let sessionId: String = arguments["sessionId"] as? String ?? ""
            disposingSessionIds.insert(sessionId)
            let cancellation: Task<Void, Never> = cancelSessionTasks(sessionId: sessionId)
            Task {
                await cancellation.value
                await registry.disposeSession(id: sessionId)
                disposingSessionIds.remove(sessionId)
                complete(result, nil)
            }
        case "stopLiveTranscription":
            Task {
                await liveTranscriptionService.stop()
                complete(result, nil)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func runSessionRequest(
        call: FlutterMethodCall,
        result: @escaping FlutterResult,
        operation: @escaping @Sendable (
            SessionRegistry,
            FlutterChannelValue<[String: Any]>
        ) async throws -> FlutterChannelValue<Any?>
    ) {
        let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
        runSessionRequest(arguments: arguments, result: result, operation: operation)
    }

    private func runSessionRequest(
        arguments: [String: Any],
        result: @escaping FlutterResult,
        operation: @escaping @Sendable (
            SessionRegistry,
            FlutterChannelValue<[String: Any]>
        ) async throws -> FlutterChannelValue<Any?>
    ) {
        let sessionId: String = arguments["sessionId"] as? String ?? ""
        guard !hasActiveRequest(sessionId: sessionId) else {
            result(ErrorMapper.flutterError(
                code: "concurrentRequests",
                message: "This session already has an active request.",
                details: [
                    "recoverySuggestion": "Wait for the active request or cancel it before starting another request on the same session."
                ]
            ))
            return
        }

        let registry: SessionRegistry = self.registry
        let message: FlutterChannelValue<[String: Any]> = FlutterChannelValue(arguments)
        let taskToken: UUID = UUID()
        let task: Task<Void, Never> = Task { [weak self] in
            let completion: Any?
            do {
                let response: FlutterChannelValue<Any?> = try await operation(
                    registry,
                    message
                )
                completion = response.value
            } catch {
                completion = ErrorMapper.flutterError(from: error)
            }
            guard let self else {
                return
            }
            self.removeRequestTask(sessionId: sessionId, token: taskToken)
            self.complete(result, completion)
        }
        requestTasks[sessionId] = TrackedTask(token: taskToken, task: task)
    }

    private func startStream(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
        let sessionId: String = arguments["sessionId"] as? String ?? ""
        let requestId: String = arguments["requestId"] as? String ?? ""
        guard !sessionId.isEmpty, !requestId.isEmpty else {
            result(ErrorMapper.flutterError(
                code: "invalidRequest",
                message: "A sessionId and requestId are required to start streaming."
            ))
            return
        }
        guard !hasActiveRequest(sessionId: sessionId) else {
            result(ErrorMapper.flutterError(
                code: "concurrentRequests",
                message: "This session already has an active request.",
                details: [
                    "recoverySuggestion": "Wait for the active request or cancel it before starting another request on the same session."
                ]
            ))
            return
        }

        let registry: SessionRegistry = self.registry
        let message: FlutterChannelValue<[String: Any]> = FlutterChannelValue(arguments)
        let taskToken: UUID = UUID()
        let task: Task<Void, Never> = Task { [weak self] in
            await registry.stream(
                arguments: message,
                onEvent: { [weak self] event in
                    Task { @MainActor [weak self] in
                        if event.value["type"] as? String == "completed" {
                            self?.removeStreamTask(requestId: requestId, token: taskToken)
                        }
                        self?.emitStreamEvent(
                            sessionId: sessionId,
                            requestId: requestId,
                            event: event.value
                        )
                    }
                },
                onError: { [weak self] error in
                    Task { @MainActor [weak self] in
                        self?.removeStreamTask(requestId: requestId, token: taskToken)
                        self?.emitStreamError(
                            sessionId: sessionId,
                            requestId: requestId,
                            error: error.value
                        )
                    }
                }
            )
            self?.removeStreamTask(requestId: requestId, token: taskToken)
        }
        streamTasks[requestId] = TrackedStreamTask(
            token: taskToken,
            sessionId: sessionId,
            task: task
        )
        result(nil)
    }

    private func emitStreamEvent(
        sessionId: String,
        requestId: String,
        event: [String: Any]
    ) {
        methodChannel?.invokeMethod(
            "streamEvent",
            arguments: [
                "sessionId": sessionId,
                "requestId": requestId,
                "event": event
            ]
        )
    }

    private func emitStreamError(
        sessionId: String,
        requestId: String,
        error: FlutterError
    ) {
        methodChannel?.invokeMethod(
            "streamEvent",
            arguments: [
                "sessionId": sessionId,
                "requestId": requestId,
                "error": [
                    "code": error.code,
                    "message": error.message as Any,
                    "details": error.details as Any
                ]
            ]
        )
    }

    private func hasActiveRequest(sessionId: String) -> Bool {
        return cancellationTasks[sessionId] != nil || disposingSessionIds.contains(sessionId) ||
            requestTasks[sessionId] != nil || streamTasks.values.contains {
            $0.sessionId == sessionId
        }
    }

    private func takeTasks(sessionId: String) -> [Task<Void, Never>] {
        var tasks: [Task<Void, Never>] = []
        if let requestTask: TrackedTask = requestTasks.removeValue(forKey: sessionId) {
            tasks.append(requestTask.task)
        }
        let requestIds: [String] = streamTasks.compactMap { requestId, trackedTask in
            trackedTask.sessionId == sessionId ? requestId : nil
        }
        for requestId in requestIds {
            if let streamTask: TrackedStreamTask = streamTasks.removeValue(forKey: requestId) {
                tasks.append(streamTask.task)
            }
        }
        return tasks
    }

    private func finishCancellation(
        tasks: [Task<Void, Never>],
        result: @escaping FlutterResult
    ) {
        Task { [weak self] in
            for task in tasks {
                task.cancel()
            }
            for task in tasks {
                await task.value
            }
            self?.complete(result, nil)
        }
    }

    private func cancelSessionTasks(sessionId: String) -> Task<Void, Never> {
        if let existing: TrackedTask = cancellationTasks[sessionId] {
            return existing.task
        }
        let tasks: [Task<Void, Never>] = takeTasks(sessionId: sessionId)
        let token: UUID = UUID()
        let cancellation: Task<Void, Never> = Task { [weak self] in
            for task in tasks {
                task.cancel()
            }
            for task in tasks {
                await task.value
            }
            if self?.cancellationTasks[sessionId]?.token == token {
                self?.cancellationTasks.removeValue(forKey: sessionId)
            }
        }
        cancellationTasks[sessionId] = TrackedTask(token: token, task: cancellation)
        return cancellation
    }

    private func removeRequestTask(sessionId: String, token: UUID) {
        guard requestTasks[sessionId]?.token == token else {
            return
        }
        requestTasks.removeValue(forKey: sessionId)
    }

    private func removeStreamTask(requestId: String, token: UUID) {
        guard streamTasks[requestId]?.token == token else {
            return
        }
        streamTasks.removeValue(forKey: requestId)
    }

    private func removeTranscriptionTask(requestId: String, token: UUID) {
        guard transcriptionTasks[requestId]?.token == token else {
            return
        }
        transcriptionTasks.removeValue(forKey: requestId)
    }

    private func complete(_ result: @escaping FlutterResult, _ value: Any?) {
        result(value)
    }
}

private struct TrackedTask {
    let token: UUID
    let task: Task<Void, Never>
}

private struct TrackedStreamTask {
    let token: UUID
    let sessionId: String
    let task: Task<Void, Never>
}
