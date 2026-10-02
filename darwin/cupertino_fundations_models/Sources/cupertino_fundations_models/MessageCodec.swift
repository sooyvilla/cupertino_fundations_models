import Foundation

enum MessageCodec {
    static func dictionary(from value: Any?) -> [String: Any] {
        return value as? [String: Any] ?? [:]
    }
}

struct FlutterChannelValue<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
