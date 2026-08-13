import AVFoundation
import Foundation
import Speech

final class SpeechTranscriptionService {
    func transcribeAudio(arguments: [String: Any]) async throws -> [String: Any] {
        let filePath: String = arguments["filePath"] as? String ?? ""
        guard !filePath.isEmpty else {
            throw NativeSessionError.modelUnavailable(
                code: "invalidRequest",
                message: "Audio file path is required.",
                recoverySuggestion: "Pick an audio file before requesting transcription."
            )
        }

        let fileURL: URL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NativeSessionError.modelUnavailable(
                code: "invalidRequest",
                message: "The selected audio file no longer exists.",
                recoverySuggestion: "Pick the audio file again before requesting transcription."
            )
        }

        let status: SFSpeechRecognizerAuthorizationStatus = await requestAuthorization()
        guard status == .authorized else {
            throw NativeSessionError.modelUnavailable(
                code: "speechRecognitionDenied",
                message: "Speech recognition permission is not authorized.",
                recoverySuggestion: "Enable Speech Recognition permission for this app in Settings."
            )
        }

        let localeIdentifier: String = arguments["localeIdentifier"] as? String ?? "en_US"
        let requestedMode: String = arguments["mode"] as? String ?? "onDevice"

        if #available(iOS 26.0, *), requestedMode != "server" {
            do {
                return try await transcribeWithAnalyzer(
                    fileURL: fileURL,
                    localeIdentifier: localeIdentifier,
                    requestedMode: requestedMode
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if requestedMode == "onDevice" {
                    throw error
                }
            }
        }

        return try await transcribeWithLegacyRecognizer(
            fileURL: fileURL,
            localeIdentifier: localeIdentifier,
            requestedMode: requestedMode,
            arguments: arguments
        )
    }

    @available(iOS 26.0, *)
    private func transcribeWithAnalyzer(
        fileURL: URL,
        localeIdentifier: String,
        requestedMode: String
    ) async throws -> [String: Any] {
        guard SpeechTranscriber.isAvailable,
              let locale: Locale = await SpeechTranscriber.supportedLocale(
                  equivalentTo: Locale(identifier: localeIdentifier)
              ) else {
            throw NativeSessionError.modelUnavailable(
                code: "speechRecognitionUnavailable",
                message: "SpeechAnalyzer does not support \(localeIdentifier) on this device.",
                recoverySuggestion: "Use automatic or server mode, or choose a supported locale."
            )
        }

        let transcriber: SpeechTranscriber = SpeechTranscriber(
            locale: locale,
            preset: .transcription
        )
        let modules: [any SpeechModule] = [transcriber]
        let initialAssetStatus: AssetInventory.Status = await AssetInventory.status(
            forModules: modules
        )
        if let installationRequest: AssetInstallationRequest = try await AssetInventory
            .assetInstallationRequest(supporting: modules) {
            try await installationRequest.downloadAndInstall()
        }

        let analyzer: SpeechAnalyzer = SpeechAnalyzer(modules: modules)
        async let collectedResult: AnalyzerResult = collectResults(from: transcriber)

        do {
            let lastSampleTime: CMTime?
            #if compiler(>=6.4)
            if #available(iOS 27.0, *) {
                let provider: AssetInputSequenceProvider = try await AssetInputSequenceProvider
                    .provider(from: AVURLAsset(url: fileURL), compatibleWith: modules)
                lastSampleTime = try await analyzer.analyzeSequence(provider.analyzerInputs)
            } else {
                let audioFile: AVAudioFile = try AVAudioFile(forReading: fileURL)
                lastSampleTime = try await analyzer.analyzeSequence(from: audioFile)
            }
            #else
            let audioFile: AVAudioFile = try AVAudioFile(forReading: fileURL)
            lastSampleTime = try await analyzer.analyzeSequence(from: audioFile)
            #endif

            if let lastSampleTime {
                try await analyzer.finalizeAndFinish(through: lastSampleTime)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } catch {
            await analyzer.cancelAndFinishNow()
            throw error
        }

        let result: AnalyzerResult = try await collectedResult
        return [
            "text": result.text,
            "isFinal": true,
            "usedMode": "onDevice",
            "localeIdentifier": locale.identifier,
            "segments": result.segments.map { $0.payload },
            "metadata": [
                "engine": "speechAnalyzer",
                "requestedMode": requestedMode,
                "initialAssetStatus": String(describing: initialAssetStatus)
            ]
        ]
    }

    @available(iOS 26.0, *)
    private func collectResults(from transcriber: SpeechTranscriber) async throws -> AnalyzerResult {
        var text: String = ""
        var segments: [AnalyzerSegment] = []
        for try await result in transcriber.results {
            let segmentText: String = String(result.text.characters)
            text += segmentText
            segments.append(
                AnalyzerSegment(
                    text: segmentText,
                    timestamp: finiteSeconds(result.range.start),
                    duration: finiteSeconds(result.range.duration),
                    confidence: 0
                )
            )
        }
        return AnalyzerResult(text: text, segments: segments)
    }

    private func transcribeWithLegacyRecognizer(
        fileURL: URL,
        localeIdentifier: String,
        requestedMode: String,
        arguments: [String: Any]
    ) async throws -> [String: Any] {
        guard let recognizer: SFSpeechRecognizer = SFSpeechRecognizer(
            locale: Locale(identifier: localeIdentifier)
        ) else {
            throw NativeSessionError.modelUnavailable(
                code: "speechRecognitionUnavailable",
                message: "Speech recognition is not available for \(localeIdentifier).",
                recoverySuggestion: "Use a supported speech recognition locale."
            )
        }

        guard recognizer.isAvailable else {
            throw NativeSessionError.modelUnavailable(
                code: "speechRecognitionUnavailable",
                message: "Speech recognition is temporarily unavailable.",
                recoverySuggestion: "Check network, on-device speech assets, and system availability."
            )
        }

        let mode: String = requestedMode == "automatic"
            ? (recognizer.supportsOnDeviceRecognition ? "onDevice" : "server")
            : requestedMode
        let request: SFSpeechURLRecognitionRequest = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = mode == "onDevice"
        if #available(iOS 16.0, *) {
            request.addsPunctuation = arguments["addsPunctuation"] as? Bool ?? true
        }
        request.taskHint = taskHint(name: arguments["taskHint"] as? String)
        request.shouldReportPartialResults = false

        if request.requiresOnDeviceRecognition && !recognizer.supportsOnDeviceRecognition {
            throw NativeSessionError.modelUnavailable(
                code: "speechRecognitionUnavailable",
                message: "On-device speech recognition is not supported for \(localeIdentifier).",
                recoverySuggestion: "Use server transcription mode or another supported locale."
            )
        }

        let result: SFSpeechRecognitionResult = try await recognize(
            recognizer: recognizer,
            request: request
        )
        let transcription: SFTranscription = result.bestTranscription
        return [
            "text": transcription.formattedString,
            "isFinal": result.isFinal,
            "usedMode": mode,
            "localeIdentifier": localeIdentifier,
            "segments": transcription.segments.map(segmentPayload),
            "metadata": [
                "engine": "sfSpeech",
                "supportsOnDeviceRecognition": recognizer.supportsOnDeviceRecognition,
                "requestedMode": requestedMode
            ]
        ]
    }

    private func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func recognize(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechURLRecognitionRequest
    ) async throws -> SFSpeechRecognitionResult {
        let state: SpeechRecognitionContinuationState = SpeechRecognitionContinuationState()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                state.install(continuation: continuation)
                let recognitionTask: SFSpeechRecognitionTask = recognizer.recognitionTask(
                    with: request
                ) { result, error in
                    if let error {
                        state.finish(with: .failure(error))
                        return
                    }
                    guard let result, result.isFinal else {
                        return
                    }
                    state.finish(with: .success(result))
                }
                state.install(task: recognitionTask)
            }
        } onCancel: {
            state.cancel()
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

    private func segmentPayload(segment: SFTranscriptionSegment) -> [String: Any] {
        return [
            "text": segment.substring,
            "timestamp": segment.timestamp,
            "duration": segment.duration,
            "confidence": segment.confidence
        ]
    }

    private func finiteSeconds(_ time: CMTime) -> Double {
        let seconds: Double = time.seconds
        return seconds.isFinite ? seconds : 0
    }
}

private struct AnalyzerResult: Sendable {
    let text: String
    let segments: [AnalyzerSegment]
}

private struct AnalyzerSegment: Sendable {
    let text: String
    let timestamp: Double
    let duration: Double
    let confidence: Double

    var payload: [String: Any] {
        return [
            "text": text,
            "timestamp": timestamp,
            "duration": duration,
            "confidence": confidence
        ]
    }
}

private final class SpeechRecognitionContinuationState: @unchecked Sendable {
    private let lock: NSLock = NSLock()
    private var continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var completed: Bool = false

    func install(continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) {
        lock.lock()
        if completed {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    func install(task: SFSpeechRecognitionTask) {
        lock.lock()
        if completed {
            lock.unlock()
            task.cancel()
            return
        }
        recognitionTask = task
        lock.unlock()
    }

    func finish(with result: Result<SFSpeechRecognitionResult, Error>) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        let continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>? = continuation
        self.continuation = nil
        recognitionTask = nil
        lock.unlock()

        continuation?.resume(with: result)
    }

    func cancel() {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        let continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>? = continuation
        let recognitionTask: SFSpeechRecognitionTask? = recognitionTask
        self.continuation = nil
        self.recognitionTask = nil
        lock.unlock()

        recognitionTask?.cancel()
        continuation?.resume(throwing: CancellationError())
    }
}
