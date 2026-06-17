import Flutter
import UIKit

public final class CupertinoFoundationModelsPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private let methodChannelName: String = "cupertino_fundations_models/methods"
    private let eventChannelName: String = "cupertino_fundations_models/events"
    private let registry: SessionRegistry = SessionRegistry()
    private let availabilityService: AvailabilityService = AvailabilityService()
    private let fileSelectionService: FileSelectionService = FileSelectionService()
    private let speechTranscriptionService: SpeechTranscriptionService = SpeechTranscriptionService()
    private var streamTask: Task<Void, Never>?

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
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getCapabilities":
            result(availabilityService.capabilities())
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
        case "pickFile":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            fileSelectionService.pickFile(arguments: arguments, result: result)
        case "transcribeAudio":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            Task {
                do {
                    let response: [String: Any] = try await speechTranscriptionService.transcribeAudio(arguments: arguments)
                    complete(result, response)
                } catch {
                    complete(result, ErrorMapper.flutterError(from: error))
                }
            }
        case "respond":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            Task {
                do {
                    let response: [String: Any] = try await registry.respond(arguments: arguments)
                    complete(result, response)
                } catch {
                    complete(result, ErrorMapper.flutterError(from: error))
                }
            }
        case "generateStructured":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
            Task {
                do {
                    let response: [String: Any] = try await registry.respond(arguments: arguments)
                    complete(result, response)
                } catch {
                    complete(result, ErrorMapper.flutterError(from: error))
                }
            }
        case "prewarm":
            result(nil)
        case "cancelActiveRequest":
            result(nil)
        case "disposeSession":
            let arguments: [String: Any] = MessageCodec.dictionary(from: call.arguments)
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
        streamTask = Task {
            await registry.stream(arguments: payload, eventSink: events)
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        streamTask?.cancel()
        streamTask = nil
        return nil
    }

    private func complete(_ result: @escaping FlutterResult, _ value: Any?) {
        DispatchQueue.main.async {
            result(value)
        }
    }
}
