import Foundation
import Flutter
import ImageIO
import PDFKit
import UIKit
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

actor SessionRegistry {
    private var sessions: [String: NativeSession] = [:]
    private var toolBridge: ToolBridge?

    func configure(toolBridge: ToolBridge) {
        self.toolBridge = toolBridge
    }

    func createSession(arguments: [String: Any]) throws -> [String: Any] {
        let id: String = UUID().uuidString
        let mode: String = arguments["mode"] as? String ?? "automatic"
        let cloudPolicy: String = arguments["cloudPolicy"] as? String ?? "never"
        let session: NativeSession = try makeSession(
            id: id,
            mode: mode,
            cloudPolicy: cloudPolicy,
            instructions: arguments["instructions"] as? String,
            useCase: arguments["useCase"] as? String,
            transcriptErrorHandlingPolicy: arguments["transcriptErrorHandlingPolicy"] as? String,
            toolMaps: arguments["tools"] as? [[String: Any]] ?? [],
            metadata: arguments["metadata"] as? [String: Any] ?? [:]
        )
        sessions[id] = session
        return [
            "sessionId": id,
            "mode": session.mode
        ]
    }

    func prewarm(arguments: [String: Any]) throws {
        guard let id: String = arguments["sessionId"] as? String,
              let session: NativeSession = sessions[id] else {
            throw NativeSessionError.sessionNotFound
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *),
           let languageSession: LanguageModelSession = session.languageSession as? LanguageModelSession {
            if let promptMap: [String: Any] = arguments["promptPrefix"] as? [String: Any] {
                let prompt: Prompt = try makePrompt(promptMap: promptMap)
                languageSession.prewarm(promptPrefix: prompt)
            } else {
                languageSession.prewarm()
            }
        }
        #endif
    }

    func countTokens(arguments: [String: Any]) async throws -> Int {
        #if canImport(FoundationModels) && compiler(>=6.4)
        if #available(iOS 26.4, *) {
            let model: SystemLanguageModel = SystemLanguageModel.default
            switch arguments["target"] as? String {
            case "prompt":
                let promptMap: [String: Any] = arguments["prompt"] as? [String: Any] ?? [:]
                return try await model.tokenCount(for: makePrompt(promptMap: promptMap))
            case "transcript":
                guard let id: String = arguments["sessionId"] as? String,
                      let session: NativeSession = sessions[id] else {
                    throw NativeSessionError.sessionNotFound
                }
                guard session.mode == "local",
                      let languageSession: LanguageModelSession = session.languageSession as? LanguageModelSession else {
                    throw NativeSessionError.modelUnavailable(
                        code: "unsupportedCapability",
                        message: "Transcript token counting is available only for local SystemLanguageModel sessions.",
                        recoverySuggestion: "Count the prompt before sending it or create a local session."
                    )
                }
                return try await model.tokenCount(for: languageSession.transcript)
            default:
                throw NativeSessionError.invalidRequest("A supported token count target is required.")
            }
        }
        #endif

        throw NativeSessionError.modelUnavailable(
            code: "unsupportedOsVersion",
            message: "Token counting requires iOS 26.4 or later and a build made with Xcode 27.",
            recoverySuggestion: "Build with Xcode 27 and run on iOS 26.4 or later."
        )
    }

    func respondStructured(arguments: [String: Any]) async throws -> [String: Any] {
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
            let schemaMap: [String: Any] = arguments["schema"] as? [String: Any] ?? [:]
            let schema: GenerationSchema = try SchemaMapper.generationSchema(from: schemaMap)
            #if compiler(>=6.4)
            if #available(iOS 27.0, *) {
                let response = try await languageSession.respond(
                    to: prompt,
                    schema: schema,
                    options: options,
                    contextOptions: makeContextOptions(arguments: optionsMap)
                )
                let jsonString: String = response.content.jsonString
                return [
                    "text": jsonString,
                    "usedMode": session.mode,
                    "structuredValue": SchemaMapper.structuredValue(fromJsonString: jsonString),
                    "metadata": [
                        "rawContent": String(describing: response.rawContent)
                    ],
                    "usage": responseUsage(response.usage)
                ]
            }
            #endif

            let includeSchemaInPrompt: Bool = optionsMap["includeSchemaInPrompt"] as? Bool ?? true
            let response = try await languageSession.respond(
                to: prompt,
                schema: schema,
                includeSchemaInPrompt: includeSchemaInPrompt,
                options: options
            )
            let jsonString: String = response.content.jsonString
            return [
                "text": jsonString,
                "usedMode": session.mode,
                "structuredValue": SchemaMapper.structuredValue(fromJsonString: jsonString),
                "metadata": [:],
                "usage": NSNull()
            ]
        }
        #endif

        throw NativeSessionError.foundationModelsUnavailable
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
                    "metadata": [
                        "rawContent": String(describing: response.rawContent)
                    ],
                    "usage": responseUsage(response.usage)
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
                ],
                "usage": NSNull()
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
                emit(FlutterEndOfEventStream, to: eventSink)
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
                var latestUsage: Any = NSNull()
                for try await response in stream {
                    latestText = response.content
                    #if compiler(>=6.4)
                    if #available(iOS 27.0, *) {
                        latestUsage = responseUsage(response.usage)
                    }
                    #endif
                    emit([
                        "type": "textSnapshot",
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
                        "metadata": [:],
                        "usage": latestUsage
                    ]
                ], to: eventSink)
                emit(FlutterEndOfEventStream, to: eventSink)
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
            emit(FlutterEndOfEventStream, to: eventSink)
        } catch {
            emit(ErrorMapper.flutterError(from: error), to: eventSink)
            emit(FlutterEndOfEventStream, to: eventSink)
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
        useCase: String?,
        transcriptErrorHandlingPolicy: String?,
        toolMaps: [[String: Any]],
        metadata: [String: Any]
    ) throws -> NativeSession {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let tools: [any Tool] = try makeTools(id: id, toolMaps: toolMaps)

            if mode == "privateCloudCompute" || mode == "automatic" && cloudPolicy != "never" {
                #if compiler(>=6.4)
                if #available(iOS 27.0, *) {
                    let privateCloud: PrivateCloudComputeLanguageModel = PrivateCloudComputeLanguageModel()
                    if case .available = privateCloud.availability {
                        let languageSession: LanguageModelSession = makePrivateCloudSession(
                            model: privateCloud,
                            tools: tools,
                            instructions: instructions
                        )
                        applyTranscriptErrorHandlingPolicy(
                            transcriptErrorHandlingPolicy,
                            to: languageSession
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

            let model: SystemLanguageModel = useCase == "contentTagging"
                ? SystemLanguageModel(useCase: .contentTagging)
                : SystemLanguageModel.default
            switch model.availability {
            case .available:
                let languageSession: LanguageModelSession = makeLocalSession(
                    model: model,
                    tools: tools,
                    instructions: instructions
                )
                #if compiler(>=6.4)
                if #available(iOS 27.0, *) {
                    applyTranscriptErrorHandlingPolicy(
                        transcriptErrorHandlingPolicy,
                        to: languageSession
                    )
                }
                #endif
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
    private func makeTools(id: String, toolMaps: [[String: Any]]) throws -> [any Tool] {
        guard let toolBridge, !toolMaps.isEmpty else {
            return []
        }
        var tools: [any Tool] = []
        for toolMap in toolMaps {
            guard let name: String = toolMap["name"] as? String, !name.isEmpty else {
                continue
            }
            let parametersMap: [String: Any] = toolMap["parameters"] as? [String: Any]
                ?? ["type": "object", "properties": [:]]
            let parameters: GenerationSchema = try SchemaMapper.generationSchema(from: parametersMap)
            tools.append(
                DynamicTool(
                    name: name,
                    description: toolMap["description"] as? String ?? "",
                    parameters: parameters,
                    sessionId: id,
                    bridge: toolBridge
                )
            )
        }
        return tools
    }

    @available(iOS 26.0, *)
    private func makeLocalSession(
        model: SystemLanguageModel,
        tools: [any Tool],
        instructions: String?
    ) -> LanguageModelSession {
        if let instructions, !instructions.isEmpty {
            return LanguageModelSession(model: model, tools: tools, instructions: instructions)
        }
        return LanguageModelSession(model: model, tools: tools)
    }

    #if compiler(>=6.4)
        @available(iOS 27.0, *)
        private func makePrivateCloudSession(
            model: PrivateCloudComputeLanguageModel,
            tools: [any Tool],
            instructions: String?
        ) -> LanguageModelSession {
            if let instructions, !instructions.isEmpty {
                return LanguageModelSession(model: model, tools: tools, instructions: instructions)
            }
            return LanguageModelSession(model: model, tools: tools)
        }

        @available(iOS 27.0, *)
        private func applyTranscriptErrorHandlingPolicy(
            _ name: String?,
            to session: LanguageModelSession
        ) {
            switch name {
            case "revertTranscript":
                session.transcriptErrorHandlingPolicy = .revertTranscript
            case "preserveTranscript":
                session.transcriptErrorHandlingPolicy = .preserveTranscript
            default:
                session.transcriptErrorHandlingPolicy = nil
            }
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
            arguments: arguments
        )
        let temperature: Double? = doubleValue(from: arguments["temperature"])
        let maximumResponseTokens: Int? = intValue(
            from: arguments["maximumResponseTokens"]
        )

        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            let toolCallingMode: GenerationOptions.ToolCallingMode? = makeToolCallingMode(
                name: arguments["toolCallingMode"] as? String
            )
            return GenerationOptions(
                samplingMode: samplingMode,
                temperature: temperature,
                maximumResponseTokens: maximumResponseTokens,
                toolCallingMode: toolCallingMode
            )
        }
        return GenerationOptions(
            samplingMode: samplingMode,
            temperature: temperature,
            maximumResponseTokens: maximumResponseTokens
        )
        #else
        return GenerationOptions(
            sampling: samplingMode,
            temperature: temperature,
            maximumResponseTokens: maximumResponseTokens
        )
        #endif
    }

    @available(iOS 26.0, *)
    private nonisolated func makeSamplingMode(
        arguments: [String: Any]
    ) -> GenerationOptions.SamplingMode? {
        let seedValue: Int? = intValue(from: arguments["samplingSeed"])
        let seed: UInt64? = seedValue.flatMap { value in
            value >= 0 ? UInt64(value) : nil
        }
        switch arguments["samplingMode"] as? String {
        case "greedy":
            return .greedy
        case "randomTopK":
            let top: Int = max(1, intValue(from: arguments["samplingTopK"]) ?? 40)
            #if compiler(>=6.4)
            return .random(top: top, seed: seed)
            #else
            return .random(top: top)
            #endif
        case "randomProbabilityThreshold":
            let threshold: Double = doubleValue(
                from: arguments["samplingProbabilityThreshold"]
            ) ?? 0.95
            #if compiler(>=6.4)
            return .random(
                probabilityThreshold: min(max(threshold, 0), 1),
                seed: seed
            )
            #else
            return .random(probabilityThreshold: min(max(threshold, 0), 1))
            #endif
        default:
            return nil
        }
    }

    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    private nonisolated func makeToolCallingMode(name: String?) -> GenerationOptions.ToolCallingMode? {
        switch name {
        case "allowed":
            return .allowed
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
                continue
            }
            #endif

            let mimeType: String = attachment["mimeType"] as? String ?? ""
            if mimeType.lowercased().hasPrefix("audio/") {
                throw NativeSessionError.invalidRequest(
                    "Audio cannot be attached directly to an Apple Foundation Models prompt. Transcribe it first with transcribeAudio()."
                )
            }
            let path: String = (attachment["path"] as? String)?.lowercased() ?? ""
            if path.hasSuffix(".doc") || path.hasSuffix(".docx") {
                throw NativeSessionError.invalidRequest(
                    "Word documents are not supported on iOS. Export the document as a text-based PDF or UTF-8 text file and attach it again."
                )
            }
            throw NativeSessionError.invalidRequest(
                "The attachment is unsupported, empty, corrupt, or inaccessible. Use a valid image, UTF-8 text, JSON, CSV, Markdown, or PDF file."
            )
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
        let path: String? = attachment["path"] as? String

        if isPdfAttachment(path: path, mimeType: mimeType) {
            guard let data: Data = try attachmentData(attachment),
                  let document: PDFDocument = PDFDocument(data: data) else {
                throw NativeSessionError.invalidRequest(
                    "The PDF attachment could not be opened."
                )
            }
            let content: String = (0..<document.pageCount)
                .compactMap { document.page(at: $0)?.string }
                .joined(separator: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else {
                throw NativeSessionError.invalidRequest(
                    "The PDF does not contain extractable text. Convert scanned pages to images or run OCR before attaching it."
                )
            }
            return Prompt(labeledContent(label: label, content: content))
        }

        guard isTextAttachment(path: path, mimeType: mimeType) else {
            return nil
        }
        guard let data: Data = try attachmentData(attachment) else {
            throw NativeSessionError.invalidRequest(
                "The text attachment could not be read."
            )
        }
        guard data.count <= 5 * 1024 * 1024 else {
            throw NativeSessionError.invalidRequest(
                "Text attachments must be 5 MB or smaller."
            )
        }
        guard let content: String = String(data: data, encoding: .utf8) else {
            throw NativeSessionError.invalidRequest(
                "Text attachments must use UTF-8 encoding."
            )
        }
        return Prompt(labeledContent(label: label, content: content))
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

    @available(iOS 26.0, *)
    private nonisolated func isPdfAttachment(path: String?, mimeType: String) -> Bool {
        let lowercasedPath: String = path?.lowercased() ?? ""
        return mimeType.lowercased() == "application/pdf" || lowercasedPath.hasSuffix(".pdf")
    }

    @available(iOS 26.0, *)
    private nonisolated func attachmentData(_ attachment: [String: Any]) throws -> Data? {
        if let path: String = attachment["path"] as? String, !path.isEmpty {
            guard FileManager.default.isReadableFile(atPath: path) else {
                throw NativeSessionError.invalidRequest(
                    "The attachment file is missing or cannot be read."
                )
            }
            return try Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe])
        }
        if let typedData: FlutterStandardTypedData = attachment["bytes"] as? FlutterStandardTypedData {
            return typedData.data
        }
        if let values: [Any] = attachment["bytes"] as? [Any] {
            var bytes: [UInt8] = []
            bytes.reserveCapacity(values.count)
            for value in values {
                let int: Int?
                if let number: NSNumber = value as? NSNumber {
                    int = number.intValue
                } else {
                    int = value as? Int
                }
                guard let int, (0...255).contains(int) else {
                    throw NativeSessionError.invalidRequest(
                        "Attachment bytes must contain values between 0 and 255."
                    )
                }
                bytes.append(UInt8(int))
            }
            return Data(bytes)
        }
        return nil
    }

    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    private nonisolated func makeImageAttachmentPrompt(attachment: [String: Any]) throws -> Prompt? {
        let mimeType: String = attachment["mimeType"] as? String ?? ""
        let label: String? = attachment["label"] as? String
        let path: String? = attachment["path"] as? String
        let declaredAsImage: Bool = isImageAttachment(path: path, mimeType: mimeType)
        guard let data: Data = try attachmentData(attachment), !data.isEmpty else {
            if declaredAsImage {
                throw NativeSessionError.invalidRequest(
                    "The image attachment is empty or cannot be read."
                )
            }
            return nil
        }
        guard data.count <= 50 * 1024 * 1024 else {
            throw NativeSessionError.invalidRequest(
                "Image attachments must be 50 MB or smaller."
            )
        }
        guard let source: CGImageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            if declaredAsImage {
                throw NativeSessionError.invalidRequest(
                    "The image format is corrupt or unsupported by iOS."
                )
            }
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 4096,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage: CGImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            throw NativeSessionError.invalidRequest(
                "The image could not be decoded."
            )
        }
        return Prompt(visionImageContext(cgImage: cgImage, label: label))
    }

    @available(iOS 27.0, *)
    private nonisolated func visionImageContext(cgImage: CGImage, label: String?) -> String {
        let handler: VNImageRequestHandler = VNImageRequestHandler(cgImage: cgImage)
        let textRequest: VNRecognizeTextRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        try? handler.perform([textRequest])

        let classificationRequest: VNClassifyImageRequest = VNClassifyImageRequest()
        try? handler.perform([classificationRequest])

        let barcodeRequest: VNDetectBarcodesRequest = VNDetectBarcodesRequest()
        try? handler.perform([barcodeRequest])

        let recognizedText: String = (textRequest.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
        let classifications: String = (classificationRequest.results ?? [])
            .filter { $0.confidence >= 0.1 }
            .prefix(8)
            .map {
                "\($0.identifier) (\(Int(($0.confidence * 100).rounded()))%)"
            }
            .joined(separator: ", ")
        let barcodes: String = (barcodeRequest.results ?? [])
            .compactMap { $0.payloadStringValue }
            .joined(separator: ", ")
        let resolvedLabel: String = (label?.isEmpty == false ? label : nil) ?? "unlabeled image"
        let resolvedClassifications: String = classifications.isEmpty
            ? "No reliable visual classifications detected."
            : classifications
        let resolvedText: String = recognizedText.isEmpty
            ? "No readable text detected."
            : recognizedText
        let resolvedBarcodes: String = barcodes.isEmpty
            ? "No barcode payloads detected."
            : barcodes

        return """
        Image attachment: \(resolvedLabel)
        Pixel size: \(cgImage.width) x \(cgImage.height)
        Visual classifications: \(resolvedClassifications)
        Recognized text:
        \(resolvedText)
        Barcode payloads: \(resolvedBarcodes)
        Use these on-device Vision results as evidence when answering the user's request about the image.
        """
    }

    @available(iOS 27.0, *)
    private nonisolated func isImageAttachment(path: String?, mimeType: String) -> Bool {
        let lowercasedPath: String = path?.lowercased() ?? ""
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
            arguments: arguments
        )
        return ContextOptions(
            includeSchemaInPrompt: includeSchemaInPrompt,
            reasoningLevel: reasoningLevel
        )
    }

    @available(iOS 27.0, *)
    private nonisolated func makeReasoningLevel(
        arguments: [String: Any]
    ) -> ContextOptions.ReasoningLevel? {
        switch arguments["reasoningLevel"] as? String {
        case "light":
            return .light
        case "moderate":
            return .moderate
        case "deep":
            return .deep
        case "custom":
            guard let value: String = arguments["customReasoningLevel"] as? String,
                  !value.isEmpty else {
                return nil
            }
            return .custom(value)
        default:
            return nil
        }
    }

    @available(iOS 27.0, *)
    private nonisolated func responseUsage(_ usage: LanguageModelSession.Usage) -> [String: Any] {
        return [
            "inputTokenCount": usage.input.totalTokenCount,
            "cachedInputTokenCount": usage.input.cachedTokenCount,
            "outputTokenCount": usage.output.totalTokenCount,
            "reasoningTokenCount": usage.output.reasoningTokenCount,
            "totalTokenCount": usage.totalTokenCount
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

#if canImport(FoundationModels)
/// Tool declared in Dart and executed through the ToolBridge.
@available(iOS 26.0, *)
struct DynamicTool: Tool {
    let name: String
    let description: String
    let parameters: GenerationSchema
    let sessionId: String
    let bridge: ToolBridge

    func call(arguments: GeneratedContent) async throws -> String {
        await bridge.callTool(
            sessionId: sessionId,
            name: name,
            argumentsJson: arguments.jsonString
        )
    }
}
#endif

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
    case invalidRequest(String)
    case modelUnavailable(code: String, message: String, recoverySuggestion: String)
}
