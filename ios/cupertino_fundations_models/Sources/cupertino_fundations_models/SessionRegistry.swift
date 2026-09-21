import Foundation
@preconcurrency import Flutter
import ImageIO
import PDFKit
import UIKit
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

actor SessionRegistry {
    private var sessions: [String: NativeSession] = [:]
    private let toolBridge: ToolBridge

    init(toolBridge: ToolBridge) {
        self.toolBridge = toolBridge
    }

    func createSession(
        arguments message: FlutterChannelValue<[String: Any]>
    ) throws -> FlutterChannelValue<[String: Any]> {
        let arguments: [String: Any] = message.value
        let id: String = UUID().uuidString
        let mode: String = arguments["mode"] as? String ?? "automatic"
        let cloudPolicy: String = arguments["cloudPolicy"] as? String ?? "never"
        let session: NativeSession = try makeSession(
            id: id,
            mode: mode,
            cloudPolicy: cloudPolicy,
            instructions: arguments["instructions"] as? String,
            localeIdentifier: arguments["localeIdentifier"] as? String,
            useCase: arguments["useCase"] as? String,
            transcriptErrorHandlingPolicy: arguments["transcriptErrorHandlingPolicy"] as? String,
            toolMaps: arguments["tools"] as? [[String: Any]] ?? [],
            metadata: arguments["metadata"] as? [String: Any] ?? [:]
        )
        sessions[id] = session
        var runtimeMetadata: [String: Any] = [
            "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            "effectiveModel": session.mode,
            "useCase": session.useCase
        ]
        if let sdkVersion: String = Bundle.main.object(forInfoDictionaryKey: "DTSDKName") as? String,
           !sdkVersion.isEmpty {
            runtimeMetadata["sdkVersion"] = sdkVersion
        }
        return FlutterChannelValue([
            "sessionId": id,
            "mode": session.mode,
            "runtimeMetadata": runtimeMetadata
        ])
    }

    func prewarm(arguments message: FlutterChannelValue<[String: Any]>) throws {
        let arguments: [String: Any] = message.value
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

    func countTokens(arguments message: FlutterChannelValue<[String: Any]>) async throws -> Int {
        let arguments: [String: Any] = message.value
        #if canImport(FoundationModels) && compiler(>=6.4)
        if #available(iOS 26.4, *) {
            switch arguments["target"] as? String {
            case "prompt":
                let promptMap: [String: Any] = arguments["prompt"] as? [String: Any] ?? [:]
                return try await SystemLanguageModel.default.tokenCount(for: makePrompt(promptMap: promptMap))
            case "transcript":
                guard let id: String = arguments["sessionId"] as? String,
                      let session: NativeSession = sessions[id] else {
                    throw NativeSessionError.sessionNotFound
                }
                guard session.mode == "local",
                      let model: SystemLanguageModel = session.localModel as? SystemLanguageModel,
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

    func measureTokenBudget(
        arguments message: FlutterChannelValue<[String: Any]>
    ) async throws -> FlutterChannelValue<[String: Any]> {
        let arguments: [String: Any] = message.value
        guard let id: String = arguments["sessionId"] as? String,
              let session: NativeSession = sessions[id] else {
            throw NativeSessionError.sessionNotFound
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), arguments["schema"] != nil {
            guard let schemaMap: [String: Any] = arguments["schema"] as? [String: Any] else {
                throw NativeSessionError.invalidSchema(path: "#", reason: "A schema must be a map.")
            }
            _ = try SchemaMapper.generationSchema(from: schemaMap)
        }
        #endif
        let unavailableReason: String = session.mode == "privateCloudCompute"
            ? "Token measurement is unavailable for Private Cloud Compute sessions."
            : "Token measurement requires iOS 26.4 or later and a build made with Xcode 27."
        #if canImport(FoundationModels) && compiler(>=6.4)
        if #available(iOS 26.4, *), session.mode == "local",
           let model: SystemLanguageModel = session.localModel as? SystemLanguageModel,
           let languageSession: LanguageModelSession = session.languageSession as? LanguageModelSession,
           let tools: [any Tool] = session.tools as? [any Tool] {
            let promptMap: [String: Any] = arguments["prompt"] as? [String: Any] ?? [:]
            let schema: GenerationSchema?
            if arguments["schema"] != nil {
                let schemaMap: [String: Any] = arguments["schema"] as! [String: Any]
                schema = try SchemaMapper.generationSchema(from: schemaMap)
            } else {
                schema = nil
            }
            let promptCount: Int = try await model.tokenCount(for: makePrompt(promptMap: promptMap))
            let instructionCount: Int
            if let instructions: String = session.instructions, !instructions.isEmpty {
                instructionCount = try await model.tokenCount(for: Instructions(instructions))
            } else {
                instructionCount = 0
            }
            let toolCount: Int
            if tools.isEmpty {
                toolCount = 0
            } else {
                toolCount = try await model.tokenCount(for: tools)
            }
            let schemaCount: Int
            if let schema {
                schemaCount = try await model.tokenCount(for: schema)
            } else {
                schemaCount = 0
            }
            let transcriptCount: Int = try await model.tokenCount(for: languageSession.transcript)
            return FlutterChannelValue(tokenBudget(
                mode: session.mode,
                prompt: exactTokenComponent(promptCount),
                instructions: exactTokenComponent(instructionCount),
                tools: exactTokenComponent(toolCount),
                schema: exactTokenComponent(schemaCount),
                transcript: exactTokenComponent(transcriptCount),
                maximumResponseTokens: intValue(from: (arguments["options"] as? [String: Any])?["maximumResponseTokens"]),
                contextWindowTokens: model.contextSize,
                modelIdentifier: "\(session.mode):\(session.useCase)"
            ))
        }
        #endif
        let unavailable: [String: Any] = unavailableTokenComponent(reason: unavailableReason)
        return FlutterChannelValue(tokenBudget(
            mode: session.mode,
            prompt: unavailable,
            instructions: unavailable,
            tools: unavailable,
            schema: unavailable,
            transcript: unavailable,
            maximumResponseTokens: intValue(from: (arguments["options"] as? [String: Any])?["maximumResponseTokens"]),
            contextWindowTokens: nil,
            modelIdentifier: "\(session.mode):\(session.useCase)"
        ))
    }

    func respondStructured(
        arguments message: FlutterChannelValue<[String: Any]>
    ) async throws -> FlutterChannelValue<[String: Any]> {
        let arguments: [String: Any] = message.value
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
            let options: GenerationOptions = try makeGenerationOptions(arguments: optionsMap)
            try await prepareToolBudget(session: session, arguments: optionsMap)
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
                return FlutterChannelValue([
                    "text": jsonString,
                    "usedMode": session.mode,
                    "structuredValue": try SchemaMapper.structuredValue(fromJsonString: jsonString),
                    "metadata": [
                        "rawContent": String(describing: response.rawContent)
                    ],
                    "usage": responseUsage(response.usage),
                    "termination": ["status": "completed", "reason": "unknown", "structuredContentComplete": response.rawContent.isComplete]
                ])
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
            return FlutterChannelValue([
                "text": jsonString,
                "usedMode": session.mode,
                "structuredValue": try SchemaMapper.structuredValue(fromJsonString: jsonString),
                "metadata": [:],
                "usage": NSNull(),
                "termination": ["status": "completed", "reason": "unknown", "structuredContentComplete": response.rawContent.isComplete]
            ])
        }
        #endif

        throw NativeSessionError.foundationModelsUnavailable
    }

    func respond(
        arguments message: FlutterChannelValue<[String: Any]>
    ) async throws -> FlutterChannelValue<[String: Any]> {
        let arguments: [String: Any] = message.value
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
            let options: GenerationOptions = try makeGenerationOptions(arguments: optionsMap)
            try await prepareToolBudget(session: session, arguments: optionsMap)
            #if compiler(>=6.4)
            if #available(iOS 27.0, *) {
                let contextOptions: ContextOptions = makeContextOptions(arguments: optionsMap)
                let response = try await languageSession.respond(
                    to: prompt,
                    options: options,
                    contextOptions: contextOptions
                )
                return FlutterChannelValue([
                    "text": response.content,
                    "usedMode": session.mode,
                    "structuredValue": NSNull(),
                    "metadata": [
                        "rawContent": String(describing: response.rawContent)
                    ],
                    "usage": responseUsage(response.usage),
                    "termination": ["status": "completed", "reason": "unknown", "structuredContentComplete": NSNull()]
                ])
            }
            #endif

            let response = try await languageSession.respond(to: prompt, options: options)
            return FlutterChannelValue([
                "text": response.content,
                "usedMode": session.mode,
                "structuredValue": NSNull(),
                "metadata": [
                    "rawContent": String(describing: response.rawContent)
                ],
                "usage": NSNull(),
                "termination": ["status": "completed", "reason": "unknown", "structuredContentComplete": NSNull()]
            ])
        }
        #endif

        throw NativeSessionError.foundationModelsUnavailable
    }

    func stream(
        arguments message: FlutterChannelValue<[String: Any]>,
        onEvent: @escaping @Sendable (FlutterChannelValue<[String: Any]>) -> Void,
        onError: @escaping @Sendable (FlutterChannelValue<FlutterError>) -> Void
    ) async {
        let arguments: [String: Any] = message.value
        do {
            guard let id: String = arguments["sessionId"] as? String,
                  let session: NativeSession = sessions[id] else {
                onError(FlutterChannelValue(
                    ErrorMapper.flutterError(
                        code: "invalidRequest",
                        message: "The requested session does not exist."
                    )
                ))
                return
            }

            let requestId: String = arguments["requestId"] as? String ?? UUID().uuidString
            let promptMap: [String: Any] = arguments["prompt"] as? [String: Any] ?? [:]

            #if canImport(FoundationModels)
            if #available(iOS 26.0, *),
               let languageSession: LanguageModelSession = session.languageSession as? LanguageModelSession {
                let prompt: Prompt = try makePrompt(promptMap: promptMap)
                let optionsMap: [String: Any] = arguments["options"] as? [String: Any] ?? [:]
                let options: GenerationOptions = try makeGenerationOptions(arguments: optionsMap)
                try await prepareToolBudget(session: session, arguments: optionsMap)
                if arguments["schema"] != nil {
                    guard let schemaMap: [String: Any] = arguments["schema"] as? [String: Any] else {
                        throw NativeSessionError.invalidRequest("A structured stream requires a schema map.")
                    }
                    let schema: GenerationSchema = try SchemaMapper.generationSchema(from: schemaMap)
                    let stream: LanguageModelSession.ResponseStream<GeneratedContent>
                    #if compiler(>=6.4)
                    if #available(iOS 27.0, *) {
                        var schemaOptionsMap: [String: Any] = optionsMap
                        schemaOptionsMap["includeSchemaInPrompt"] = optionsMap["includeSchemaInPrompt"] as? Bool ?? true
                        stream = languageSession.streamResponse(
                            to: prompt,
                            schema: schema,
                            options: options,
                            contextOptions: makeContextOptions(arguments: schemaOptionsMap)
                        )
                    } else {
                        let includeSchemaInPrompt: Bool = optionsMap["includeSchemaInPrompt"] as? Bool ?? true
                        stream = languageSession.streamResponse(
                            to: prompt,
                            schema: schema,
                            includeSchemaInPrompt: includeSchemaInPrompt,
                            options: options
                        )
                    }
                    #else
                    let includeSchemaInPrompt: Bool = optionsMap["includeSchemaInPrompt"] as? Bool ?? true
                    stream = languageSession.streamResponse(
                        to: prompt,
                        schema: schema,
                        includeSchemaInPrompt: includeSchemaInPrompt,
                        options: options
                    )
                    #endif
                    var latestRawContent: GeneratedContent?
                    var latestUsage: Any = NSNull()
                    for try await snapshot in stream {
                        latestRawContent = snapshot.rawContent
                        #if compiler(>=6.4)
                        if #available(iOS 27.0, *) {
                            latestUsage = responseUsage(snapshot.usage)
                        }
                        #endif
                        onEvent(FlutterChannelValue([
                            "type": "textSnapshot",
                            "requestId": requestId,
                            "text": snapshot.rawContent.jsonString
                        ]))
                    }
                    try Task.checkCancellation()
                    guard let rawContent: GeneratedContent = latestRawContent,
                          rawContent.isComplete else {
                        throw NativeSessionError.modelUnavailable(
                            code: "parsingFailure",
                            message: "The structured stream ended without complete JSON content.",
                            recoverySuggestion: "Retry the request or simplify the schema."
                        )
                    }
                    let jsonString: String = rawContent.jsonString
                    onEvent(FlutterChannelValue([
                        "type": "completed",
                        "requestId": requestId,
                        "response": [
                            "text": jsonString,
                            "usedMode": session.mode,
                            "structuredValue": try SchemaMapper.structuredValue(fromJsonString: jsonString),
                            "metadata": [:],
                            "usage": latestUsage,
                            "termination": ["status": "completed", "reason": "unknown", "structuredContentComplete": true]
                        ]
                    ]))
                    return
                }

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
                    onEvent(FlutterChannelValue([
                        "type": "textSnapshot",
                        "requestId": requestId,
                        "text": response.content
                    ]))
                }
                try Task.checkCancellation()
                onEvent(FlutterChannelValue([
                    "type": "completed",
                    "requestId": requestId,
                    "response": [
                        "text": latestText,
                        "usedMode": session.mode,
                        "structuredValue": NSNull(),
                        "metadata": [:],
                        "usage": latestUsage,
                        "termination": ["status": "completed", "reason": "unknown", "structuredContentComplete": NSNull()]
                    ]
                ]))
                return
            }
            #endif

            onError(FlutterChannelValue(
                ErrorMapper.flutterError(
                    code: "modelUnavailable",
                    message: "Foundation Models streaming is not available in this runtime or SDK."
                )
            ))
        } catch {
            onError(FlutterChannelValue(ErrorMapper.flutterError(from: error)))
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
        localeIdentifier: String?,
        useCase: String?,
        transcriptErrorHandlingPolicy: String?,
        toolMaps: [[String: Any]],
        metadata: [String: Any]
    ) throws -> NativeSession {
        guard ["local", "automatic", "privateCloudCompute"].contains(mode),
              ["never", "whenExplicit", "automaticWithUserConsent"].contains(cloudPolicy) else {
            throw NativeSessionError.invalidRequest("Unknown model mode or cloud policy.")
        }
        if mode == "privateCloudCompute" && cloudPolicy == "never" {
            throw NativeSessionError.invalidRequest("CloudPolicy.never forbids Private Cloud Compute. Use local mode or explicitly authorize PCC.")
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let toolCallBudget: ToolCallBudget? = toolMaps.isEmpty ? nil : ToolCallBudget()
            let tools: [any Tool] = try makeTools(
                id: id,
                toolMaps: toolMaps,
                budget: toolCallBudget
            )

            if mode == "privateCloudCompute" || mode == "automatic" && cloudPolicy == "automaticWithUserConsent" {
                #if compiler(>=6.4)
                if #available(iOS 27.0, *) {
                    if !PrivateCloudComputeAccess.isEnabled {
                        if mode == "privateCloudCompute" {
                            throw NativeSessionError.modelUnavailable(
                                code: "missingEntitlement",
                                message: PrivateCloudComputeAccess.unavailableReason,
                                recoverySuggestion: PrivateCloudComputeAccess.recoverySuggestion
                            )
                        }
                    } else {
                        let privateCloud: PrivateCloudComputeLanguageModel =
                            PrivateCloudComputeLanguageModel()
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
                                languageSession: languageSession,
                                tools: tools,
                                useCase: "general",
                                toolCallBudget: toolCallBudget
                            )
                        }
                        if mode == "privateCloudCompute" {
                            let statusCode: String
                            switch privateCloud.availability {
                            case .available:
                                statusCode = "privateCloudUnavailable"
                            case .unavailable(let reason):
                                switch reason {
                                case .deviceNotEligible:
                                    statusCode = "unsupportedPlatform"
                                case .systemNotReady:
                                    statusCode = "privateCloudUnavailable"
                                @unknown default:
                                    statusCode = "privateCloudUnavailable"
                                }
                            @unknown default:
                                statusCode = "privateCloudUnavailable"
                            }
                            throw NativeSessionError.modelUnavailable(
                                code: statusCode,
                                message: String(describing: privateCloud.availability),
                                recoverySuggestion: "Check Apple Intelligence, network availability, device eligibility, PCC entitlement, quota, and iCloud account state."
                            )
                        }
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
                if let localeIdentifier, !model.supportsLocale(Locale(identifier: localeIdentifier)) {
                    throw NativeSessionError.modelUnavailable(
                        code: "unsupportedLanguage",
                        message: "The on-device model does not support the requested locale.",
                        recoverySuggestion: "Choose a supported locale and create a new session."
                    )
                }
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
                    languageSession: languageSession,
                    localModel: model,
                    tools: tools,
                    useCase: useCase == "contentTagging" ? "contentTagging" : "general",
                    toolCallBudget: toolCallBudget
                )
            case .unavailable(let reason):
                let reasonText: String = String(describing: reason)
                throw NativeSessionError.modelUnavailable(
                    code: ErrorMapper.localAvailabilityCode(reason),
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
    private func makeTools(
        id: String,
        toolMaps: [[String: Any]],
        budget: ToolCallBudget?
    ) throws -> [any Tool] {
        guard !toolMaps.isEmpty else {
            return []
        }
        var tools: [any Tool] = []
        var names: Set<String> = []
        for toolMap in toolMaps {
            guard let name: String = toolMap["name"] as? String, !name.isEmpty else {
                throw NativeSessionError.invalidRequest("Every tool must have a non-empty name.")
            }
            guard names.insert(name).inserted else {
                throw NativeSessionError.invalidRequest("Tool names must be unique within a session.")
            }
            let timeoutMilliseconds: Int = intValue(
                from: toolMap["timeoutMilliseconds"]
            ) ?? 20_000
            guard (1...600_000).contains(timeoutMilliseconds) else {
                throw NativeSessionError.invalidRequest(
                    "Tool timeouts must be between 1 millisecond and 10 minutes."
                )
            }
            let parametersMap: [String: Any] = toolMap["parameters"] as? [String: Any]
                ?? ["type": "object", "properties": [:]]
            guard parametersMap["type"] as? String == "object" else {
                throw NativeSessionError.invalidRequest("Tool parameters must use an object schema.")
            }
            let parameters: GenerationSchema = try SchemaMapper.generationSchema(from: parametersMap)
            tools.append(
                DynamicTool(
                    name: name,
                    description: toolMap["description"] as? String ?? "",
                    parameters: parameters,
                    sessionId: id,
                    bridge: toolBridge,
                    budget: budget,
                    timeoutMilliseconds: timeoutMilliseconds
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

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func prepareToolBudget(
        session: NativeSession,
        arguments: [String: Any]
    ) async throws {
        try Task.checkCancellation()
        if session.mode == "privateCloudCompute", arguments["cloudPolicy"] as? String == "never" {
            throw NativeSessionError.invalidRequest("This request forbids cloud use. Create a local session for this request.")
        }
        let mode: String = arguments["toolCallingMode"] as? String ?? "allowed"
        #if compiler(<6.4)
        if mode != "allowed" || (arguments["reasoningLevel"] as? String ?? "automatic") != "automatic" {
            throw NativeSessionError.modelUnavailable(
                code: "unsupportedCapability",
                message: "This build cannot apply explicit tool calling modes or reasoning levels.",
                recoverySuggestion: "Build with Xcode 27 or use the default generation options."
            )
        }
        #endif
        if #available(iOS 27.0, *) {
            if mode == "required" && session.toolCallBudget == nil {
                throw NativeSessionError.invalidRequest("Required tool calling needs at least one registered tool.")
            }
        } else if mode != "allowed" || (arguments["reasoningLevel"] as? String ?? "automatic") != "automatic" {
            throw NativeSessionError.modelUnavailable(
                code: "unsupportedCapability",
                message: "Explicit tool calling modes and reasoning levels require iOS 27.",
                recoverySuggestion: "Use the default options on iOS 26."
            )
        }
        guard let budget: ToolCallBudget = session.toolCallBudget else {
            return
        }
        let maximumCalls: Int = intValue(from: arguments["maximumToolCalls"]) ?? 16
        guard (1...128).contains(maximumCalls) else {
            throw NativeSessionError.invalidRequest(
                "maximumToolCalls must be between 1 and 128."
            )
        }
        await budget.reset(maximumCalls: maximumCalls)
    }

    @available(iOS 26.0, *)
    private nonisolated func makeGenerationOptions(arguments: [String: Any]) throws -> GenerationOptions {
        let samplingMode: GenerationOptions.SamplingMode? = try makeSamplingMode(
            arguments: arguments
        )
        let temperature: Double? = doubleValue(from: arguments["temperature"])
        let maximumResponseTokens: Int? = intValue(
            from: arguments["maximumResponseTokens"]
        )
        if let temperature,
           !temperature.isFinite || temperature < 0 || temperature > 1 {
            throw NativeSessionError.invalidRequest(
                "Generation temperature must be a finite value between zero and one."
            )
        }
        if let maximumResponseTokens, maximumResponseTokens <= 0 {
            throw NativeSessionError.invalidRequest(
                "maximumResponseTokens must be greater than zero."
            )
        }

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
    ) throws -> GenerationOptions.SamplingMode? {
        let seedValue: Int? = intValue(from: arguments["samplingSeed"])
        let seed: UInt64? = seedValue.flatMap { value in
            value >= 0 ? UInt64(value) : nil
        }
        switch arguments["samplingMode"] as? String {
        case "greedy":
            return .greedy
        case "randomTopK":
            let top: Int = intValue(from: arguments["samplingTopK"]) ?? 40
            guard top > 0 else {
                throw NativeSessionError.invalidRequest(
                    "samplingTopK must be greater than zero."
                )
            }
            #if compiler(>=6.4)
            return .random(top: top, seed: seed)
            #else
            return .random(top: top)
            #endif
        case "randomProbabilityThreshold":
            let threshold: Double = doubleValue(
                from: arguments["samplingProbabilityThreshold"]
            ) ?? 0.95
            guard threshold.isFinite, threshold >= 0, threshold <= 1 else {
                throw NativeSessionError.invalidRequest(
                    "samplingProbabilityThreshold must be a finite value between zero and one."
                )
            }
            #if compiler(>=6.4)
            return .random(
                probabilityThreshold: threshold,
                seed: seed
            )
            #else
            return .random(probabilityThreshold: threshold)
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
            guard let data: Data = try attachmentData(
                attachment,
                maximumBytes: 20 * 1024 * 1024
            ),
                  let document: PDFDocument = PDFDocument(data: data) else {
                throw NativeSessionError.invalidRequest(
                    "The PDF attachment could not be opened."
                )
            }
            var pages: [String] = []
            var extractedByteCount: Int = 0
            for index in 0..<document.pageCount {
                guard let pageText: String = document.page(at: index)?.string else {
                    continue
                }
                extractedByteCount += pageText.lengthOfBytes(using: .utf8)
                guard extractedByteCount <= 5 * 1024 * 1024 else {
                    throw NativeSessionError.invalidRequest(
                        "Extracted PDF text must be 5 MB or smaller. Split the document before attaching it."
                    )
                }
                pages.append(pageText)
            }
            let content: String = pages
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
        guard let data: Data = try attachmentData(
            attachment,
            maximumBytes: 5 * 1024 * 1024
        ) else {
            throw NativeSessionError.invalidRequest(
                "The text attachment could not be read."
            )
        }
        guard let content: String = String(data: data, encoding: .utf8) else {
            throw NativeSessionError.invalidRequest(
                "Text attachments must use UTF-8 encoding."
            )
        }
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NativeSessionError.invalidRequest("The text attachment is empty.")
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
    private nonisolated func attachmentData(
        _ attachment: [String: Any],
        maximumBytes: Int
    ) throws -> Data? {
        if let path: String = attachment["path"] as? String, !path.isEmpty {
            guard FileManager.default.isReadableFile(atPath: path) else {
                throw NativeSessionError.invalidRequest(
                    "The attachment file is missing or cannot be read."
                )
            }
            let attributes: [FileAttributeKey: Any] = try FileManager.default.attributesOfItem(
                atPath: path
            )
            let fileSize: Int64 = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard fileSize <= Int64(maximumBytes) else {
                throw NativeSessionError.invalidRequest(
                    "The attachment exceeds the allowed size of \(maximumBytes / 1024 / 1024) MB."
                )
            }
            let data: Data = try Data(
                contentsOf: URL(fileURLWithPath: path),
                options: [.mappedIfSafe]
            )
            guard data.count <= maximumBytes else {
                throw NativeSessionError.invalidRequest(
                    "The attachment exceeds the allowed size of \(maximumBytes / 1024 / 1024) MB."
                )
            }
            return data
        }
        if let typedData: FlutterStandardTypedData = attachment["bytes"] as? FlutterStandardTypedData {
            guard typedData.data.count <= maximumBytes else {
                throw NativeSessionError.invalidRequest(
                    "The attachment exceeds the allowed size of \(maximumBytes / 1024 / 1024) MB."
                )
            }
            return typedData.data
        }
        if let values: [Any] = attachment["bytes"] as? [Any] {
            guard values.count <= maximumBytes else {
                throw NativeSessionError.invalidRequest(
                    "The attachment exceeds the allowed size of \(maximumBytes / 1024 / 1024) MB."
                )
            }
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
        guard let data: Data = try attachmentData(
            attachment,
            maximumBytes: 50 * 1024 * 1024
        ), !data.isEmpty else {
            if declaredAsImage {
                throw NativeSessionError.invalidRequest(
                    "The image attachment is empty or cannot be read."
                )
            }
            return nil
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
            kCGImageSourceThumbnailMaxPixelSize: 2048,
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
        return Prompt(try visionImageContext(cgImage: cgImage, label: label))
    }

    @available(iOS 27.0, *)
    private nonisolated func visionImageContext(cgImage: CGImage, label: String?) throws -> String {
        let handler: VNImageRequestHandler = VNImageRequestHandler(cgImage: cgImage)
        let textRequest: VNRecognizeTextRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        let classificationRequest: VNClassifyImageRequest = VNClassifyImageRequest()
        let barcodeRequest: VNDetectBarcodesRequest = VNDetectBarcodesRequest()
        try handler.perform([textRequest, classificationRequest, barcodeRequest])

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

    private nonisolated func exactTokenComponent(_ count: Int) -> [String: Any] {
        ["count": count, "precision": "exact", "reason": NSNull()]
    }

    private nonisolated func unavailableTokenComponent(reason: String) -> [String: Any] {
        ["count": NSNull(), "precision": "unavailable", "reason": reason]
    }

    private nonisolated func tokenBudget(
        mode: String,
        prompt: [String: Any],
        instructions: [String: Any],
        tools: [String: Any],
        schema: [String: Any],
        transcript: [String: Any],
        maximumResponseTokens: Int?,
        contextWindowTokens: Int?,
        modelIdentifier: String?
    ) -> [String: Any] {
        [
            "mode": mode,
            "components": [
                "prompt": prompt,
                "instructions": instructions,
                "tools": tools,
                "schema": schema,
                "transcript": transcript
            ],
            "maximumResponseTokens": maximumResponseTokens ?? NSNull(),
            "contextWindowTokens": contextWindowTokens ?? NSNull(),
            "modelIdentifier": modelIdentifier ?? NSNull()
        ]
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
    let budget: ToolCallBudget?
    let timeoutMilliseconds: Int

    func call(arguments: GeneratedContent) async throws -> String {
        if let budget {
            try await budget.consume()
        }
        return await bridge.callTool(
            sessionId: sessionId,
            name: name,
            argumentsJson: arguments.jsonString,
            timeoutMilliseconds: timeoutMilliseconds
        )
    }
}
#endif

actor ToolCallBudget {
    private var maximumCalls: Int = 16
    private var consumedCalls: Int = 0

    func reset(maximumCalls: Int) {
        self.maximumCalls = maximumCalls
        consumedCalls = 0
    }

    func consume() throws {
        guard consumedCalls < maximumCalls else {
            throw ToolCallBudgetError.maximumCallsExceeded(maximumCalls)
        }
        consumedCalls += 1
    }
}

enum ToolCallBudgetError: LocalizedError {
    case maximumCallsExceeded(Int)

    var errorDescription: String? {
        switch self {
        case .maximumCallsExceeded(let maximumCalls):
            return "The model exceeded the per-request limit of \(maximumCalls) tool calls."
        }
    }
}

struct NativeSession {
    let id: String
    let mode: String
    let instructions: String?
    let metadata: [String: Any]
    let languageSession: Any?
    let localModel: Any?
    let tools: Any?
    let useCase: String
    let toolCallBudget: ToolCallBudget?

    init(
        id: String,
        mode: String,
        instructions: String?,
        metadata: [String: Any],
        languageSession: Any? = nil,
        localModel: Any? = nil,
        tools: Any? = nil,
        useCase: String = "general",
        toolCallBudget: ToolCallBudget? = nil
    ) {
        self.id = id
        self.mode = mode
        self.instructions = instructions
        self.metadata = metadata
        self.languageSession = languageSession
        self.localModel = localModel
        self.tools = tools
        self.useCase = useCase
        self.toolCallBudget = toolCallBudget
    }
}

enum NativeSessionError: Error {
    case sessionNotFound
    case foundationModelsUnavailable
    case invalidRequest(String)
    case invalidSchema(path: String, reason: String)
    case modelUnavailable(code: String, message: String, recoverySuggestion: String)
}
