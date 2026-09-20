@preconcurrency import AVFoundation
@preconcurrency import Flutter
import Foundation
import Speech

@MainActor
final class LiveTranscriptionService: NSObject, @preconcurrency FlutterStreamHandler {
    private let audioEngine: AVAudioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var analyzerFinishInput: (() -> Void)?
    private var analyzerCancel: (() async -> Void)?
    private var analyzerResultsTask: Task<Void, Never>?
    private var captureProvider: AnyObject?
    private var captureSession: AVCaptureSession?
    private let captureQueue: DispatchQueue = DispatchQueue(
        label: "cupertino_fundations_models.live_capture",
        qos: .userInitiated
    )
    private var cleanupTask: Task<Void, Never>?
    private var cleanupToken: UUID?
    private var startTask: Task<Void, Never>?
    private var activeToken: UUID?
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        let cleanupTask: Task<Void, Never>? = stopCapture()
        let payload: [String: Any] = MessageCodec.dictionary(from: arguments)
        let token: UUID = UUID()
        activeToken = token
        eventSink = events
        startTask = Task { [weak self] in
            await cleanupTask?.value
            guard !Task.isCancelled else {
                return
            }
            await self?.start(arguments: payload, token: token)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        _ = stopCapture()
        eventSink = nil
        return nil
    }

    func stop() async {
        let pendingCleanup: Task<Void, Never>? = stopCapture()
        eventSink = nil
        await pendingCleanup?.value
    }

    private func start(arguments: [String: Any], token: UUID) async {
        do {
            try SpeechPermissions.validate(requiresMicrophone: true)
        } catch {
            fail(
                token: token,
                code: "invalidRequest",
                message: "The host app is missing a speech or microphone usage description.",
                recoverySuggestion: "Add NSSpeechRecognitionUsageDescription and NSMicrophoneUsageDescription to Info.plist."
            )
            return
        }
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await requestSpeechAuthorization()
        guard isActive(token) else {
            return
        }
        guard speechStatus == .authorized else {
            fail(
                token: token,
                code: "speechRecognitionDenied",
                message: "Speech recognition permission is not authorized.",
                recoverySuggestion: "Enable Speech Recognition permission for this app in Settings."
            )
            return
        }

        let microphoneAllowed: Bool = await requestMicrophoneAuthorization()
        guard isActive(token) else {
            return
        }
        guard microphoneAllowed else {
            fail(
                token: token,
                code: "speechRecognitionDenied",
                message: "Microphone permission is not authorized.",
                recoverySuggestion: "Enable Microphone permission for this app in Settings."
            )
            return
        }

        let localeIdentifier: String = arguments["localeIdentifier"] as? String ?? "en_US"
        let requestedMode: String = arguments["mode"] as? String ?? "onDevice"

        if #available(iOS 26.0, *), requestedMode != "server" {
            let started: Bool = await startAnalyzer(
                arguments: arguments,
                localeIdentifier: localeIdentifier,
                token: token
            )
            if started || !isActive(token) {
                return
            }
        }

        startLegacyRecognizer(
            arguments: arguments,
            localeIdentifier: localeIdentifier,
            requestedMode: requestedMode,
            token: token
        )
    }

    @available(iOS 26.0, *)
    private func startAnalyzer(
        arguments: [String: Any],
        localeIdentifier: String,
        token: UUID
    ) async -> Bool {
        guard SpeechTranscriber.isAvailable,
              let analyzerLocale: Locale = await SpeechTranscriber.supportedLocale(
                  equivalentTo: Locale(identifier: localeIdentifier)
              ),
              isActive(token) else {
            return false
        }

        let reportPartials: Bool = arguments["reportPartialResults"] as? Bool ?? true
        let transcriber: SpeechTranscriber = SpeechTranscriber(
            locale: analyzerLocale,
            transcriptionOptions: [],
            reportingOptions: reportPartials ? [.volatileResults] : [],
            attributeOptions: []
        )
        let modules: [any SpeechModule] = [transcriber]

        do {
            if let installationRequest: AssetInstallationRequest = try await AssetInventory
                .assetInstallationRequest(supporting: modules) {
                try await installationRequest.downloadAndInstall()
            }
            guard isActive(token) else {
                return false
            }

            let analyzer: SpeechAnalyzer = SpeechAnalyzer(modules: modules)
            analyzerCancel = {
                await analyzer.cancelAndFinishNow()
            }
            try await analyzer.prepareToAnalyze(in: nil)
            guard isActive(token) else {
                await analyzer.cancelAndFinishNow()
                return false
            }
            startAnalyzerResults(
                transcriber: transcriber,
                token: token,
                localeIdentifier: localeIdentifier
            )

            #if compiler(>=6.4)
            if #available(iOS 27.0, *) {
                return try await startCaptureProvider(
                    analyzer: analyzer,
                    modules: modules,
                    token: token
                )
            }
            #endif

            guard let analyzerFormat: AVAudioFormat = await SpeechAnalyzer
                .bestAvailableAudioFormat(compatibleWith: modules),
                isActive(token) else {
                await cleanupCaptureComponentsNow()
                return false
            }

            let session: AVAudioSession = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode: AVAudioInputNode = audioEngine.inputNode
            let tapFormat: AVAudioFormat = inputNode.outputFormat(forBus: 0)
            guard isValidAudioFormat(tapFormat) else {
                throw NativeSessionError.modelUnavailable(
                    code: "speechRecognitionUnavailable",
                    message: "The microphone returned an invalid audio format.",
                    recoverySuggestion: "Disconnect conflicting audio devices and retry microphone transcription."
                )
            }
            let converter: AVAudioConverter? = AVAudioConverter(
                from: tapFormat,
                to: analyzerFormat
            )
            let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
            analyzerFinishInput = {
                inputBuilder.finish()
            }

            try await analyzer.start(inputSequence: inputSequence)
            guard isActive(token) else {
                await cleanupCaptureComponentsNow()
                return false
            }

            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 2048, format: tapFormat) { buffer, _ in
                if tapFormat == analyzerFormat {
                    inputBuilder.yield(AnalyzerInput(buffer: buffer))
                    return
                }
                guard let converter else {
                    return
                }
                let ratio: Double = analyzerFormat.sampleRate / tapFormat.sampleRate
                let capacity: AVAudioFrameCount = AVAudioFrameCount(
                    Double(buffer.frameLength) * ratio
                ) + 1024
                guard let converted: AVAudioPCMBuffer = AVAudioPCMBuffer(
                    pcmFormat: analyzerFormat,
                    frameCapacity: capacity
                ) else {
                    return
                }
                var conversionError: NSError?
                var consumed: Bool = false
                converter.convert(to: converted, error: &conversionError) { _, outStatus in
                    if consumed {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    consumed = true
                    outStatus.pointee = .haveData
                    return buffer
                }
                if conversionError == nil && converted.frameLength > 0 {
                    inputBuilder.yield(AnalyzerInput(buffer: converted))
                }
            }
            audioEngine.prepare()
            try audioEngine.start()
            return true
        } catch {
            await cleanupCaptureComponentsNow()
            return false
        }
    }

    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    private func startCaptureProvider(
        analyzer: SpeechAnalyzer,
        modules: [any SpeechModule],
        token: UUID
    ) async throws -> Bool {
        guard let device: AVCaptureDevice = AVCaptureDevice.default(for: .audio) else {
            throw NativeSessionError.modelUnavailable(
                code: "speechRecognitionUnavailable",
                message: "No microphone capture device is available.",
                recoverySuggestion: "Connect or enable a microphone and retry."
            )
        }

        let provider: CaptureInputSequenceProvider = try await CaptureInputSequenceProvider
            .providerWithSession(from: device, compatibleWith: modules)
        guard isActive(token) else {
            await analyzer.cancelAndFinishNow()
            return false
        }

        try await analyzer.start(inputSequence: provider.analyzerInputs)
        guard isActive(token) else {
            await analyzer.cancelAndFinishNow()
            return false
        }

        captureProvider = provider
        captureSession = provider.captureSession
        await startCaptureSession(provider.captureSession)
        guard isActive(token) else {
            await cleanupCaptureComponentsNow()
            return false
        }
        guard provider.captureSession.isRunning else {
            throw NativeSessionError.modelUnavailable(
                code: "speechRecognitionUnavailable",
                message: "The microphone capture session could not start.",
                recoverySuggestion: "Check microphone access and retry."
            )
        }
        return true
    }
    #endif

    @available(iOS 26.0, *)
    private func startAnalyzerResults(
        transcriber: SpeechTranscriber,
        token: UUID,
        localeIdentifier: String
    ) {
        analyzerResultsTask = Task { [weak self] in
            var finalizedText: String = ""
            do {
                for try await result in transcriber.results {
                    guard !Task.isCancelled else {
                        return
                    }
                    let segmentText: String = String(result.text.characters)
                    if result.isFinal {
                        finalizedText += segmentText
                        self?.emit(
                            token: token,
                            text: finalizedText,
                            isFinal: false,
                            mode: "onDevice",
                            localeIdentifier: localeIdentifier,
                            engine: "speechAnalyzer"
                        )
                    } else {
                        self?.emit(
                            token: token,
                            text: finalizedText + segmentText,
                            isFinal: false,
                            mode: "onDevice",
                            localeIdentifier: localeIdentifier,
                            engine: "speechAnalyzer"
                        )
                    }
                }
                self?.emit(
                    token: token,
                    text: finalizedText,
                    isFinal: true,
                    mode: "onDevice",
                    localeIdentifier: localeIdentifier,
                    engine: "speechAnalyzer"
                )
            } catch is CancellationError {
                return
            } catch {
                self?.fail(
                    token: token,
                    code: "speechRecognitionUnavailable",
                    message: error.localizedDescription,
                    recoverySuggestion: "Retry live transcription or check speech assets."
                )
            }
        }
    }

    private func startLegacyRecognizer(
        arguments: [String: Any],
        localeIdentifier: String,
        requestedMode: String,
        token: UUID
    ) {
        guard isActive(token),
              let recognizer: SFSpeechRecognizer = SFSpeechRecognizer(
                  locale: Locale(identifier: localeIdentifier)
              ),
              recognizer.isAvailable else {
            fail(
                token: token,
                code: "speechRecognitionUnavailable",
                message: "Speech recognition is not available for \(localeIdentifier).",
                recoverySuggestion: "Use a supported speech recognition locale and check on-device assets."
            )
            return
        }

        let mode: String = requestedMode == "automatic"
            ? (recognizer.supportsOnDeviceRecognition ? "onDevice" : "server")
            : requestedMode
        if mode == "onDevice" && !recognizer.supportsOnDeviceRecognition {
            fail(
                token: token,
                code: "speechRecognitionUnavailable",
                message: "On-device speech recognition is not supported for \(localeIdentifier).",
                recoverySuggestion: "Use server transcription mode or another supported locale."
            )
            return
        }

        let request: SFSpeechAudioBufferRecognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = arguments["reportPartialResults"] as? Bool ?? true
        request.requiresOnDeviceRecognition = mode == "onDevice"
        request.taskHint = taskHint(name: arguments["taskHint"] as? String)
        if #available(iOS 16.0, *) {
            request.addsPunctuation = arguments["addsPunctuation"] as? Bool ?? true
        }
        recognitionRequest = request

        do {
            let session: AVAudioSession = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode: AVAudioInputNode = audioEngine.inputNode
            let format: AVAudioFormat = inputNode.outputFormat(forBus: 0)
            guard isValidAudioFormat(format) else {
                throw NativeSessionError.modelUnavailable(
                    code: "speechRecognitionUnavailable",
                    message: "The microphone returned an invalid audio format.",
                    recoverySuggestion: "Disconnect conflicting audio devices and retry microphone transcription."
                )
            }
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            _ = scheduleCaptureCleanup()
            fail(
                token: token,
                code: "speechRecognitionUnavailable",
                message: "Audio capture could not start: \(error.localizedDescription)",
                recoverySuggestion: "Check microphone availability and audio session usage in your app."
            )
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                let text: String = result.bestTranscription.formattedString
                let isFinal: Bool = result.isFinal
                Task { @MainActor [weak self] in
                    self?.emit(
                        token: token,
                        text: text,
                        isFinal: isFinal,
                        mode: mode,
                        localeIdentifier: localeIdentifier,
                        engine: "sfSpeech"
                    )
                }
                return
            }
            if let error {
                let message: String = error.localizedDescription
                Task { @MainActor [weak self] in
                    self?.fail(
                        token: token,
                        code: "speechRecognitionUnavailable",
                        message: message,
                        recoverySuggestion: "Retry live transcription or check speech availability."
                    )
                }
            }
        }
    }

    private func emit(
        token: UUID,
        text: String,
        isFinal: Bool,
        mode: String,
        localeIdentifier: String,
        engine: String
    ) {
        guard activeToken == token, let sink = eventSink else {
            return
        }
        sink([
            "text": text,
            "isFinal": isFinal,
            "metadata": [
                "usedMode": mode,
                "localeIdentifier": localeIdentifier,
                "engine": engine
            ]
        ])
        if isFinal {
            sink(FlutterEndOfEventStream)
            eventSink = nil
            _ = stopCapture()
        }
    }

    private func fail(
        token: UUID,
        code: String,
        message: String,
        recoverySuggestion: String
    ) {
        guard activeToken == token, let sink = eventSink else {
            return
        }
        sink(
            ErrorMapper.flutterError(
                code: code,
                message: message,
                details: ["recoverySuggestion": recoverySuggestion]
            )
        )
        sink(FlutterEndOfEventStream)
        eventSink = nil
        _ = stopCapture()
    }

    @discardableResult
    private func stopCapture() -> Task<Void, Never>? {
        activeToken = nil
        let startingTask: Task<Void, Never>? = startTask
        startingTask?.cancel()
        startTask = nil
        return scheduleCaptureCleanup(startingTask: startingTask)
    }

    private func scheduleCaptureCleanup(startingTask: Task<Void, Never>? = nil) -> Task<Void, Never>? {
        let previousTask: Task<Void, Never>? = cleanupTask
        let cleanup: (() async -> Void)? = takeCaptureCleanup()
        guard previousTask != nil || cleanup != nil || startingTask != nil else {
            return nil
        }
        let token: UUID = UUID()
        cleanupToken = token
        let task: Task<Void, Never> = Task { [weak self] in
            await previousTask?.value
            if let cleanup {
                await cleanup()
            }
            await startingTask?.value
            guard self?.cleanupToken == token else {
                return
            }
            self?.cleanupTask = nil
            self?.cleanupToken = nil
        }
        cleanupTask = task
        return task
    }

    private func cleanupCaptureComponentsNow() async {
        guard let cleanup: (() async -> Void) = takeCaptureCleanup() else {
            return
        }
        await cleanup()
    }

    private func takeCaptureCleanup() -> (() async -> Void)? {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        let sessionToStop: AVCaptureSession? = captureSession
        captureSession = nil
        captureProvider = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        analyzerFinishInput?()
        analyzerFinishInput = nil
        let cancelAnalyzer: (() async -> Void)? = analyzerCancel
        analyzerCancel = nil
        analyzerResultsTask?.cancel()
        analyzerResultsTask = nil
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
        guard sessionToStop != nil || cancelAnalyzer != nil else {
            return nil
        }
        let captureQueue: DispatchQueue = self.captureQueue
        return {
            if let sessionToStop {
                await withCheckedContinuation { continuation in
                    captureQueue.async {
                        if sessionToStop.isRunning {
                            sessionToStop.stopRunning()
                        }
                        continuation.resume()
                    }
                }
            }
            if let cancelAnalyzer {
                await cancelAnalyzer()
            }
        }
    }

    private func startCaptureSession(_ session: AVCaptureSession) async {
        await withCheckedContinuation { continuation in
            captureQueue.async {
                session.startRunning()
                continuation.resume()
            }
        }
    }

    private func isActive(_ token: UUID) -> Bool {
        return activeToken == token && eventSink != nil && !Task.isCancelled
    }

    private func isValidAudioFormat(_ format: AVAudioFormat) -> Bool {
        return format.sampleRate.isFinite && format.sampleRate > 0 && format.channelCount > 0
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        }
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    private func taskHint(name: String?) -> SFSpeechRecognitionTaskHint {
        switch name {
        case "dictation":
            return .dictation
        case "search":
            return .search
        case "confirmation":
            return .confirmation
        default:
            return .unspecified
        }
    }
}
