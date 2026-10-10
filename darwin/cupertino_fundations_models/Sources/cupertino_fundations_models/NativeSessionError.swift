import Foundation

enum NativeSessionError: Error {
    case sessionNotFound
    case foundationModelsUnavailable
    case invalidRequest(String)
    case invalidSchema(path: String, reason: String)
    case modelUnavailable(code: String, message: String, recoverySuggestion: String)
}
