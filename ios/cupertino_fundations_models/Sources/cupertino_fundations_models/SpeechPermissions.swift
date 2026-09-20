import Foundation

enum SpeechPermissions {
    static func validate(requiresMicrophone: Bool) throws {
        let keys: [String] = requiresMicrophone
            ? ["NSSpeechRecognitionUsageDescription", "NSMicrophoneUsageDescription"]
            : ["NSSpeechRecognitionUsageDescription"]
        for key in keys {
            guard let description: String = Bundle.main.object(forInfoDictionaryKey: key) as? String,
                  !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NativeSessionError.invalidRequest("Add a non-empty \(key) to the host Info.plist before requesting speech access.")
            }
        }
    }
}
