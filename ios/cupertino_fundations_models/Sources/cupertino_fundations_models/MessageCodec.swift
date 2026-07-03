import Foundation

enum MessageCodec {
    static func dictionary(from value: Any?) -> [String: Any] {
        return value as? [String: Any] ?? [:]
    }
}
