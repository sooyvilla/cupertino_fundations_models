import AVFoundation
import Flutter
import Foundation
import Speech

/// Streams live microphone transcription events through a dedicated EventChannel.
///
/// On iOS 26+ it prefers the modern `SpeechAnalyzer`/`SpeechTranscriber`
/// pipeline (fully on-device, volatile partial results). On older systems, or
/// when the locale or the requested mode is unsupported by the analyzer, it
/// falls back to `SFSpeechAudioBufferRecognitionRequest`.
///
/// One live session runs at a time. Cancelling the Dart subscription stops the
/// audio engine and finalizes recognition.
final class LiveTranscriptionService: NSObject, FlutterStreamHandler {
    private let audioEngine: AVAudioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var analyzerFinishInput: (() -> Void)?
    private var analyzerFinalize: (() -> Void)?
    private var analyzerResultsTask: Task<Void, Never>?
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        let payload: [String: Any] = MessageCodec.dictionary(from: arguments)
        eventSink = events
        Task {
            await start(arguments: payload)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopCapture()
        eventSink = nil
        return nil
    }

    private func start(arguments: [String: Any]) async {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await requestSpeechAuthorization()
        guard speechStatus == .authorized else {
            fail(
                code: "speechRecognitionDenied",
                message: "Speech recognition permission is not authorized.",
                recoverySuggestion: "Enable Speech Recognition permission for this app in Settings."
            )
            return
        }

        let microphoneAllowed: Bool = await requestMicrophoneAuthorization()
        guard microphoneAllowed else {
            fail(
                code: "speechRecognitionDenied",
                message: "Microphone permission is not authorized.",
                recoverySuggestion: "Enable Microphone permission for this app in Settings."
            )
            return
        }

        let localeIdentifier: String = arguments["localeIdentifier"] as? String ?? "en_US"
        let requestedMode: String = arguments["mode"] as? String ?? "onDevice"

        // The SpeechAnalyzer pipeline is on-device only; honor explicit server requests with SFSpeech.
        if #available(iOS 26.0, *), requestedMode != "server" {
            let started: Bool = await startAnalyzer(
                arguments: arguments,
                localeIdentifier: localeIdentifier
            )
            if started {
                return
            }
        }

        startLegacyRecognizer(
            arguments: arguments,
            localeIdentifier: localeIdentifier,
            requestedMode: requestedMode
        )
    }

    // MARK: - SpeechAnalyzer path (iOS 26+)

    @available(iOS 26.0, *)
    private func startAnalyzer(arguments: [String: Any], localeIdentifier: String) async -> Bool {
        let locale: Locale = Locale(identifier: localeIdentifier)
        let supportedLocales: [Locale] = await SpeechTranscriber.supportedLocales
        let requestedTag: String = locale.identifier(.bcp47)
        // Exact BCP-47 match first, then any variant of the same language so
        // regional locales (es_CO, en_AU, ...) still use SpeechAnalyzer instead
        // of silently falling back to the legacy SFSpeech engine.
        var matchedLocale: Locale? = supportedLocales.first { supported in
            supported.identifier(.bcp47) == requestedTag
        }
        if matchedLocale == nil {
            let requestedLanguage: String = requestedTag
                .split(separator: "-").first.map(String.init) ?? requestedTag
            matchedLocale = supportedLocales.first { supported in
                supported.identifier(.bcp47)
                    .split(separator: "-").first.map(String.init) == requestedLanguage
            }
        }
        guard let analyzerLocale: Locale = matchedLocale else {
            return false
        }

        let reportPartials: Bool = arguments["reportPartialResults"] as? Bool ?? true
        let transcriber: SpeechTranscriber = SpeechTranscriber(
            locale: analyzerLocale,
            transcriptionOptions: [],
            reportingOptions: reportPartials ? [.volatileResults] : [],
            attributeOptions: []
        )

        do {
            if let installationRequest = try await AssetInventory.assetInstallationRequest(
                supporting: [transcriber]
            ) {
                try await installationRequest.downloadAndInstall()
            }

            guard let analyzerFormat: AVAudioFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
                compatibleWith: [transcriber]
            ) else {
                return false
            }

            let analyzer: SpeechAnalyzer = SpeechAnalyzer(modules: [transcriber])
            let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

            let session: AVAudioSession = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode: AVAudioInputNode = audioEngine.inputNode
            let tapFormat: AVAudioFormat = inputNode.outputFormat(forBus: 0)
            let converter: AVAudioConverter? = AVAudioConverter(from: tapFormat, to: analyzerFormat)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 2048, format: tapFormat) { buffer, _ in
                guard let converter else {
                    inputBuilder.yield(AnalyzerInput(buffer: buffer))
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

            try await analyzer.start(inputSequence: inputSequence)

            analyzerFinishInput = {
                inputBuilder.finish()
            }
            analyzerFinalize = {
                Task {
                    try? await analyzer.finalizeAndFinishThroughEndOfInput()
                }
            }

            analyzerResultsTask = Task { [weak self] in
                var finalizedText: String = ""
                do {
                    for try await result in transcriber.results {
                        let segmentText: String = String(result.text.characters)
                        if result.isFinal {
                            finalizedText += segmentText
                            self?.emit(
                                text: finalizedText,
                                isFinal: false,
                                mode: "onDevice",
                                localeIdentifier: localeIdentifier,
                                engine: "speechAnalyzer"
                            )
                        } else {
                            self?.emit(
                                text: finalizedText + segmentText,
                                isFinal: false,
                                mode: "onDevice",
                                localeIdentifier: localeIdentifier,
                                engine: "speechAnalyzer"
                            )
                        }
                    }
                    self?.emit(
                        text: finalizedText,
                        isFinal: true,
                        mode: "onDevice",
                        localeIdentifier: localeIdentifier,
                        engine: "speechAnalyzer"
                    )
                } catch {
                    self?.fail(
                        code: "speechRecognitionUnavailable",
                        message: error.localizedDescription,
                        recoverySuggestion: "Retry live transcription or check speech assets."
                    )
                }
            }
            return true
        } catch {
            stopCapture()
            return false
        }
    }

    // MARK: - SFSpeech fallback path

    private func startLegacyRecognizer(
        arguments: [String: Any],
        localeIdentifier: String,
        requestedMode: String
    ) {
        guard let recognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
              recognizer.isAvailable else {
            fail(
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
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            stopCapture()
            fail(
                code: "speechRecognitionUnavailable",
                message: "Audio capture could not start: \(error.localizedDescription)",
                recoverySuggestion: "Check microphone availability and audio session usage in your app."
            )
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else {
                return
            }
            if let result {
                self.emit(
                    text: result.bestTranscription.formattedString,
                    isFinal: result.isFinal,
                    mode: mode,
                    localeIdentifier: localeIdentifier,
                    engine: "sfSpeech"
                )
                if result.isFinal {
                    self.stopCapture()
                }
                return
            }
            if let error {
                self.stopCapture()
                self.fail(
                    code: "speechRecognitionUnavailable",
                    message: error.localizedDescription,
                    recoverySuggestion: "Retry live transcription or check speech availability."
                )
            }
        }
    }

    // MARK: - Shared plumbing

    private func emit(
        text: String,
        isFinal: Bool,
        mode: String,
        localeIdentifier: String,
        engine: String
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?([
                "text": text,
                "isFinal": isFinal,
                "metadata": [
                    "usedMode": mode,
                    "localeIdentifier": localeIdentifier,
                    "engine": engine
                ]
            ])
            if isFinal {
                self?.eventSink?(FlutterEndOfEventStream)
                self?.eventSink = nil
            }
        }
    }

    private func fail(code: String, message: String, recoverySuggestion: String) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(
                ErrorMapper.flutterError(
                    code: code,
                    message: message,
                    details: ["recoverySuggestion": recoverySuggestion]
                )
            )
            self?.eventSink?(FlutterEndOfEventStream)
            self?.eventSink = nil
        }
    }

    private func stopCapture() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        analyzerFinishInput?()
        analyzerFinishInput = nil
        analyzerFinalize?()
        analyzerFinalize = nil
        analyzerResultsTask?.cancel()
        analyzerResultsTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
