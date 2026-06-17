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

        let status: SFSpeechRecognizerAuthorizationStatus = await requestAuthorization()
        guard status == .authorized else {
            throw NativeSessionError.modelUnavailable(
                code: "speechRecognitionDenied",
                message: "Speech recognition permission is not authorized.",
                recoverySuggestion: "Enable Speech Recognition permission for this app in Settings."
            )
        }

        let localeIdentifier: String = arguments["localeIdentifier"] as? String ?? "en_US"
        guard let recognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) else {
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

        let requestedMode: String = arguments["mode"] as? String ?? "onDevice"
        let mode: String = requestedMode == "automatic"
            ? (recognizer.supportsOnDeviceRecognition ? "onDevice" : "server")
            : requestedMode
        let request: SFSpeechURLRecognitionRequest = SFSpeechURLRecognitionRequest(
            url: URL(fileURLWithPath: filePath)
        )
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
        try await withCheckedThrowingContinuation { continuation in
            var didResume: Bool = false
            var recognitionTask: SFSpeechRecognitionTask?
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if didResume {
                    return
                }
                if let error {
                    didResume = true
                    recognitionTask?.cancel()
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    return
                }
                if result.isFinal {
                    didResume = true
                    continuation.resume(returning: result)
                }
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

    private func segmentPayload(segment: SFTranscriptionSegment) -> [String: Any] {
        return [
            "text": segment.substring,
            "timestamp": segment.timestamp,
            "duration": segment.duration,
            "confidence": segment.confidence
        ]
    }
}
