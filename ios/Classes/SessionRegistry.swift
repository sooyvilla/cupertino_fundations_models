import Foundation
import Flutter
#if canImport(FoundationModels)
import FoundationModels
#endif

actor SessionRegistry {
    private var sessions: [String: NativeSession] = [:]

    func createSession(arguments: [String: Any]) throws -> [String: Any] {
        let id: String = UUID().uuidString
        let mode: String = arguments["mode"] as? String ?? "automatic"
        let cloudPolicy: String = arguments["cloudPolicy"] as? String ?? "never"
        let session: NativeSession = try makeSession(
            id: id,
            mode: mode,
            cloudPolicy: cloudPolicy,
            instructions: arguments["instructions"] as? String,
            metadata: arguments["metadata"] as? [String: Any] ?? [:]
        )
        sessions[id] = session
        return [
            "sessionId": id,
            "mode": session.mode
        ]
    }

    func respond(arguments: [String: Any]) async throws -> [String: Any] {
        guard let id: String = arguments["sessionId"] as? String,
              let session: NativeSession = sessions[id] else {
            throw NativeSessionError.sessionNotFound
        }

        let promptMap: [String: Any] = arguments["prompt"] as? [String: Any] ?? [:]

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *),
           let languageSession: LanguageModelSession = session.languageSession as? LanguageModelSession {
            let prompt: Prompt = try makePrompt(promptMap: promptMap)
            let optionsMap: [String: Any] = arguments["options"] as? [String: Any] ?? [:]
            let options: GenerationOptions = makeGenerationOptions(arguments: optionsMap)
            #if compiler(>=6.4)
            if #available(iOS 27.0, *) {
                let contextOptions: ContextOptions = makeContextOptions(arguments: optionsMap)
                let response = try await languageSession.respond(
                    to: prompt,
                    options: options,
                    contextOptions: contextOptions
                )
                return [
                    "text": response.content,
                    "usedMode": session.mode,
                    "structuredValue": NSNull(),
                    "metadata": responseMetadata(response: response)
                ]
            }
            #endif

            let response = try await languageSession.respond(to: prompt, options: options)
            return [
                "text": response.content,
                "usedMode": session.mode,
                "structuredValue": NSNull(),
                "metadata": [
                    "rawContent": String(describing: response.rawContent)
                ]
            ]
        }
        #endif

        throw NativeSessionError.foundationModelsUnavailable
    }

    func stream(arguments: [String: Any], eventSink: @escaping FlutterEventSink) async {
        do {
            guard let id: String = arguments["sessionId"] as? String,
                  let session: NativeSession = sessions[id] else {
                emit(
                    ErrorMapper.flutterError(
                        code: "invalidRequest",
                        message: "The requested session does not exist."
                    ),
                    to: eventSink
                )
                return
            }

            let requestId: String = arguments["requestId"] as? String ?? UUID().uuidString
            let promptMap: [String: Any] = arguments["prompt"] as? [String: Any] ?? [:]

            #if canImport(FoundationModels)
            if #available(iOS 26.0, *),
               let languageSession: LanguageModelSession = session.languageSession as? LanguageModelSession {
                let prompt: Prompt = try makePrompt(promptMap: promptMap)
                let optionsMap: [String: Any] = arguments["options"] as? [String: Any] ?? [:]
                let options: GenerationOptions = makeGenerationOptions(arguments: optionsMap)
                let stream: LanguageModelSession.ResponseStream<String>
                #if compiler(>=6.4)
                if #available(iOS 27.0, *) {
                    stream = languageSession.streamResponse(
                        to: prompt,
                        options: options,
                        contextOptions: makeContextOptions(arguments: optionsMap)
                    )
                } else {
                    stream = languageSession.streamResponse(to: prompt, options: options)
                }
                #else
                stream = languageSession.streamResponse(to: prompt, options: options)
                #endif
                var latestText: String = ""
                for try await response in stream {
                    latestText = response.content
                    emit([
                        "type": "textDelta",
                        "requestId": requestId,
                        "text": response.content
                    ], to: eventSink)
                }
                emit([
                    "type": "completed",
                    "requestId": requestId,
                    "response": [
                        "text": latestText,
                        "usedMode": session.mode,
                        "structuredValue": NSNull(),
                        "metadata": [:]
                    ]
                ], to: eventSink)
                return
            }
            #endif

            emit(
                ErrorMapper.flutterError(
                    code: "modelUnavailable",
                    message: "Foundation Models streaming is not available in this runtime or SDK."
                ),
                to: eventSink
            )
        } catch {
            emit(ErrorMapper.flutterError(from: error), to: eventSink)
        }
    }

    func disposeSession(id: String?) {
        guard let id else {
            return
        }
        sessions.removeValue(forKey: id)
    }

    private func makeSession(
        id: String,
        mode: String,
        cloudPolicy: String,
        instructions: String?,
        metadata: [String: Any]
    ) throws -> NativeSession {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if mode == "privateCloudCompute" || mode == "automatic" && cloudPolicy != "never" {
                #if compiler(>=6.4)
                if #available(iOS 27.0, *) {
                    let privateCloud: PrivateCloudComputeLanguageModel = PrivateCloudComputeLanguageModel()
                    if case .available = privateCloud.availability {
                        let languageSession: LanguageModelSession = makePrivateCloudSession(
                            model: privateCloud,
                            instructions: instructions
                        )
                        return NativeSession(
                            id: id,
                            mode: "privateCloudCompute",
                            instructions: instructions,
                            metadata: metadata,
                            languageSession: languageSession
                        )
                    }
                    if mode == "privateCloudCompute" {
                        throw NativeSessionError.modelUnavailable(
                            code: "privateCloudUnavailable",
                            message: String(describing: privateCloud.availability),
                            recoverySuggestion: "Check Apple Intelligence, network availability, device eligibility, PCC quota, and iCloud account state."
                        )
                    }
                } else if mode == "privateCloudCompute" {
                    throw NativeSessionError.modelUnavailable(
                        code: "unsupportedOsVersion",
                        message: "Private Cloud Compute requires iOS 27 or later.",
                        recoverySuggestion: "Use offline mode or run on iOS 27 or later."
                    )
                }
                #else
                if mode == "privateCloudCompute" {
                    throw NativeSessionError.modelUnavailable(
                        code: "unsupportedOsVersion",
                        message: "Private Cloud Compute is not available in the SDK used to build this app.",
                        recoverySuggestion: "Build the app with Xcode 27 and the iOS 27 SDK to enable PCC."
                    )
                }
                #endif
            }

            let model: SystemLanguageModel = SystemLanguageModel.default
            switch model.availability {
            case .available:
                let languageSession: LanguageModelSession = makeLocalSession(
                    instructions: instructions
                )
                return NativeSession(
                    id: id,
                    mode: "local",
                    instructions: instructions,
                    metadata: metadata,
                    languageSession: languageSession
                )
            case .unavailable(let reason):
                let reasonText: String = String(describing: reason)
                throw NativeSessionError.modelUnavailable(
                    code: errorCode(from: reasonText),
                    message: reasonText,
                    recoverySuggestion: "Enable Apple Intelligence, verify supported language settings, and wait for model assets to finish downloading."
                )
            @unknown default:
                throw NativeSessionError.modelUnavailable(
                    code: "modelUnavailable",
                    message: "The system returned an unknown Foundation Models availability state.",
                    recoverySuggestion: "Try again on the latest iOS 27 beta or later."
                )
            }
        }
        #endif

        throw NativeSessionError.modelUnavailable(
            code: "modelUnavailable",
            message: "Foundation Models is not available in this runtime or SDK.",
            recoverySuggestion: "Build with an SDK that includes Foundation Models and run on iOS 26 or later."
        )
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func makeLocalSession(instructions: String?) -> LanguageModelSession {
        if let instructions, !instructions.isEmpty {
            return LanguageModelSession(instructions: instructions)
        }
        return LanguageModelSession()
    }

    #if compiler(>=6.4)
        @available(iOS 27.0, *)
        private func makePrivateCloudSession(
            model: PrivateCloudComputeLanguageModel,
            instructions: String?
        ) -> LanguageModelSession {
            if let instructions, !instructions.isEmpty {
                return LanguageModelSession(model: model, instructions: instructions)
            }
            return LanguageModelSession(model: model)
        }
    #endif
    #endif

    private nonisolated func emit(_ value: Any, to eventSink: @escaping FlutterEventSink) {
        DispatchQueue.main.async {
            eventSink(value)
        }
    }

    private nonisolated func errorCode(from reason: String) -> String {
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
        return "modelUnavailable"
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private nonisolated func makeGenerationOptions(arguments: [String: Any]) -> GenerationOptions {
        let samplingMode: GenerationOptions.SamplingMode? = makeSamplingMode(
            name: arguments["samplingMode"] as? String
        )
        let temperature: Double? = doubleValue(from: arguments["temperature"])
        let maximumResponseTokens: Int? = intValue(
            from: arguments["maximumResponseTokens"]
        )

        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            let toolCallingMode: GenerationOptions.ToolCallingMode? = makeToolCallingMode(
                name: arguments["toolCallingPolicy"] as? String
            )
            return GenerationOptions(
                samplingMode: samplingMode,
                temperature: temperature,
                maximumResponseTokens: maximumResponseTokens,
                toolCallingMode: toolCallingMode
            )
        }
        #endif

        return GenerationOptions(
            samplingMode: samplingMode,
            temperature: temperature,
            maximumResponseTokens: maximumResponseTokens
        )
    }

    @available(iOS 26.0, *)
    private nonisolated func makeSamplingMode(name: String?) -> GenerationOptions.SamplingMode? {
        switch name {
        case "greedy":
            return .greedy
        case "randomTopK":
            return .random(top: 40)
        case "randomProbabilityThreshold":
            return .random(probabilityThreshold: 0.95)
        default:
            return nil
        }
    }

    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    private nonisolated func makeToolCallingMode(name: String?) -> GenerationOptions.ToolCallingMode? {
        switch name {
        case "required":
            return .required
        case "disallowed":
            return .disallowed
        default:
            return nil
        }
    }
    #endif

    @available(iOS 26.0, *)
    private nonisolated func makePrompt(promptMap: [String: Any]) throws -> Prompt {
        var parts: [Prompt] = []
        let text: String = promptMap["text"] as? String ?? ""
        if !text.isEmpty {
            parts.append(Prompt(text))
        }

        let attachments: [[String: Any]] = promptMap["attachments"] as? [[String: Any]] ?? []
        for attachment in attachments {
            if let textAttachment: Prompt = try makeTextAttachmentPrompt(attachment: attachment) {
                parts.append(textAttachment)
                continue
            }

            #if compiler(>=6.4)
            if #available(iOS 27.0, *),
               let imageAttachment: Prompt = try makeImageAttachmentPrompt(attachment: attachment) {
                parts.append(imageAttachment)
            }
            #endif
        }

        if parts.isEmpty {
            return Prompt("")
        }
        return Prompt(parts)
    }

    @available(iOS 26.0, *)
    private nonisolated func makeTextAttachmentPrompt(attachment: [String: Any]) throws -> Prompt? {
        let label: String? = attachment["label"] as? String
        let mimeType: String = attachment["mimeType"] as? String ?? ""

        if let path: String = attachment["path"] as? String,
           isTextAttachment(path: path, mimeType: mimeType) {
            let content: String = try String(contentsOfFile: path, encoding: .utf8)
            return Prompt(labeledContent(label: label, content: content))
        }

        if let data: FlutterStandardTypedData = attachment["bytes"] as? FlutterStandardTypedData,
           isTextAttachment(path: nil, mimeType: mimeType),
           let content: String = String(data: data.data, encoding: .utf8) {
            return Prompt(labeledContent(label: label, content: content))
        }

        return nil
    }

    @available(iOS 26.0, *)
    private nonisolated func labeledContent(label: String?, content: String) -> String {
        guard let label, !label.isEmpty else {
            return content
        }
        return "\(label):\n\(content)"
    }

    @available(iOS 26.0, *)
    private nonisolated func isTextAttachment(path: String?, mimeType: String) -> Bool {
        let lowercasedPath: String = path?.lowercased() ?? ""
        let lowercasedMimeType: String = mimeType.lowercased()
        return lowercasedMimeType.hasPrefix("text/") ||
            lowercasedMimeType == "application/json" ||
            lowercasedPath.hasSuffix(".txt") ||
            lowercasedPath.hasSuffix(".md") ||
            lowercasedPath.hasSuffix(".json") ||
            lowercasedPath.hasSuffix(".csv")
    }

    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    private nonisolated func makeImageAttachmentPrompt(attachment: [String: Any]) throws -> Prompt? {
        let mimeType: String = attachment["mimeType"] as? String ?? ""
        guard let path: String = attachment["path"] as? String,
              isImageAttachment(path: path, mimeType: mimeType) else {
            return nil
        }

        let url: URL = URL(fileURLWithPath: path)
        let label: String? = attachment["label"] as? String
        var imageAttachment: Attachment<ImageAttachmentContent> = Attachment(imageURL: url)
        if let label, !label.isEmpty {
            imageAttachment = imageAttachment.label(label)
        }
        return Prompt(imageAttachment)
    }

    @available(iOS 27.0, *)
    private nonisolated func isImageAttachment(path: String, mimeType: String) -> Bool {
        let lowercasedPath: String = path.lowercased()
        let lowercasedMimeType: String = mimeType.lowercased()
        return lowercasedMimeType.hasPrefix("image/") ||
            lowercasedPath.hasSuffix(".png") ||
            lowercasedPath.hasSuffix(".jpg") ||
            lowercasedPath.hasSuffix(".jpeg") ||
            lowercasedPath.hasSuffix(".heic") ||
            lowercasedPath.hasSuffix(".webp")
    }

    @available(iOS 27.0, *)
    private nonisolated func makeContextOptions(arguments: [String: Any]) -> ContextOptions {
        let includeSchemaInPrompt: Bool? = arguments["includeSchemaInPrompt"] as? Bool
        let reasoningLevel: ContextOptions.ReasoningLevel? = makeReasoningLevel(
            name: arguments["reasoningLevel"] as? String
        )
        return ContextOptions(
            includeSchemaInPrompt: includeSchemaInPrompt,
            reasoningLevel: reasoningLevel
        )
    }

    @available(iOS 27.0, *)
    private nonisolated func makeReasoningLevel(name: String?) -> ContextOptions.ReasoningLevel? {
        switch name {
        case "low":
            return .light
        case "medium":
            return .moderate
        case "high":
            return .deep
        default:
            return nil
        }
    }

    @available(iOS 27.0, *)
    private nonisolated func responseMetadata(response: LanguageModelSession.Response<String>) -> [String: Any] {
        return [
            "rawContent": String(describing: response.rawContent),
            "inputTotalTokenCount": response.usage.input.totalTokenCount,
            "inputCachedTokenCount": response.usage.input.cachedTokenCount,
            "outputTotalTokenCount": response.usage.output.totalTokenCount,
            "outputReasoningTokenCount": response.usage.output.reasoningTokenCount,
            "totalTokenCount": response.usage.totalTokenCount
        ]
    }
    #endif

    private nonisolated func intValue(from value: Any?) -> Int? {
        if let int: Int = value as? Int {
            return int
        }
        if let number: NSNumber = value as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private nonisolated func doubleValue(from value: Any?) -> Double? {
        if let double: Double = value as? Double {
            return double
        }
        if let number: NSNumber = value as? NSNumber {
            return number.doubleValue
        }
        return nil
    }
    #endif
}

struct NativeSession {
    let id: String
    let mode: String
    let instructions: String?
    let metadata: [String: Any]
    let languageSession: Any?

    init(id: String, mode: String, instructions: String?, metadata: [String: Any], languageSession: Any? = nil) {
        self.id = id
        self.mode = mode
        self.instructions = instructions
        self.metadata = metadata
        self.languageSession = languageSession
    }
}

enum NativeSessionError: Error {
    case sessionNotFound
    case foundationModelsUnavailable
    case modelUnavailable(code: String, message: String, recoverySuggestion: String)
}
