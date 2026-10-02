enum ApplePlatform {
    static var name: String {
        #if os(macOS)
        return "macOS"
        #else
        return "iOS"
        #endif
    }
}
