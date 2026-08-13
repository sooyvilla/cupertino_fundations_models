import Flutter
import UIKit

public final class CupertinoFoundationModelsPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private let methodChannelName: String = "cupertino_fundations_models/methods"
    private let eventChannelName: String = "cupertino_fundations_models/events"
    private let transcriptionEventChannelName: String = "cupertino_fundations_models/transcription_events"
    private let registry: SessionRegistry = SessionRegistry()
    private let availabilityService: AvailabilityService = AvailabilityService()
    private let fileSelectionService: FileSelectionService = FileSelectionService()
    private let speechTranscriptionService: SpeechTranscriptionService = SpeechTranscriptionService()
    private let liveTranscriptionService: LiveTranscriptionService = LiveTranscriptionService()
    private var requestTasks: [String: Task<Void, Never>] = [:]
    private var streamTasks: [String: Task<Void, Never>] = [:]
    private var transcriptionTasks: [String: Task<Void, Never>] = [:]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance: CupertinoFoundationModelsPlugin = CupertinoFoundationModelsPlugin()
        let methodChannel: FlutterMethodChannel = FlutterMethodChannel(
            name: instance.methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        let eventChannel: FlutterEventChannel = FlutterEventChannel(
            name: instance.eventChannelName,
            binaryMessenger: registrar.messenger()
        )
        let transcriptionEventChannel: FlutterEventChannel = FlutterEventChannel(
            name: instance.transcriptionEventChannelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
        transcriptionEventChannel.setStreamHandler(instance.liveTranscriptionService)

        let toolBridge: ToolBridge = ToolBridge(methodChannel: methodChannel)
        let registry: SessionRegistry = instance.registry
        Task {
            await registry.configure(toolBridge: toolBridge)
        }
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
            Task {
                do {
                    let response: [String: Any] = try await registry.createSession(arguments: arguments)
                    complete(result, response)
                } catch {
                    complete(result, ErrorMapper.flutterError(from: error))
                }
            }
        case "countTokens":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            Task {
                do {
                    let count: Int = try await registry.countTokens(arguments: arguments)
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
            let task: Task<Void, Never> = Task { [weak self] in
                do {
                    guard let self else {
                        return
                    }
                    let response: [String: Any] = try await self.speechTranscriptionService.transcribeAudio(
                        arguments: arguments
                    )
                    self.complete(result, response)
                } catch {
                    self?.complete(result, ErrorMapper.flutterError(from: error))
                }
                DispatchQueue.main.async {
                    self?.transcriptionTasks.removeValue(forKey: requestId)
                }
            }
            transcriptionTasks[requestId]?.cancel()
            transcriptionTasks[requestId] = task
        case "cancelTranscription":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            let requestId: String = arguments["requestId"] as? String ?? ""
            transcriptionTasks.removeValue(forKey: requestId)?.cancel()
            result(nil)
        case "respond":
            runSessionRequest(call: call, result: result) { registry, arguments in
                try await registry.respond(arguments: arguments)
            }
        case "generateStructured":
            runSessionRequest(call: call, result: result) { registry, arguments in
                try await registry.respondStructured(arguments: arguments)
            }
        case "prewarm":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            Task {
                do {
                    try await registry.prewarm(arguments: arguments)
                    complete(result, nil)
                } catch {
                    complete(result, ErrorMapper.flutterError(from: error))
                }
            }
        case "cancelActiveRequest":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            let sessionId: String = arguments["sessionId"] as? String ?? ""
            requestTasks.removeValue(forKey: sessionId)?.cancel()
            streamTasks.removeValue(forKey: sessionId)?.cancel()
            result(nil)
        case "disposeSession":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            let sessionId: String = arguments["sessionId"] as? String ?? ""
            requestTasks.removeValue(forKey: sessionId)?.cancel()
            streamTasks.removeValue(forKey: sessionId)?.cancel()
            Task {
                await registry.disposeSession(id: arguments["sessionId"] as? String)
                complete(result, nil)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        let payload: [String: Any] = MessageCodec.dictionary(from: arguments)
        let sessionId: String = payload["sessionId"] as? String ?? ""
        let registry: SessionRegistry = self.registry
        let task: Task<Void, Never> = Task {
            await registry.stream(arguments: payload, eventSink: events)
        }
        streamTasks[sessionId]?.cancel()
        streamTasks[sessionId] = task
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        let payload: [String: Any] = MessageCodec.dictionary(from: arguments)
        let sessionId: String = payload["sessionId"] as? String ?? ""
        streamTasks.removeValue(forKey: sessionId)?.cancel()
        return nil
    }

    private func runSessionRequest(
        call: FlutterMethodCall,
        result: @escaping FlutterResult,
        operation: @escaping (SessionRegistry, [String: Any]) async throws -> [String: Any]
    ) {
        let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
        let sessionId: String = arguments["sessionId"] as? String ?? ""
        let registry: SessionRegistry = self.registry
        let task: Task<Void, Never> = Task { [weak self] in
            do {
                let response: [String: Any] = try await operation(registry, arguments)
                self?.complete(result, response)
            } catch {
                self?.complete(result, ErrorMapper.flutterError(from: error))
            }
            DispatchQueue.main.async {
                self?.requestTasks.removeValue(forKey: sessionId)
            }
        }
        requestTasks[sessionId]?.cancel()
        requestTasks[sessionId] = task
    }

    private func complete(_ result: @escaping FlutterResult, _ value: Any?) {
        DispatchQueue.main.async {
            result(value)
        }
    }
}
