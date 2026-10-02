import Foundation

enum PrivateCloudComputeAccess {
    static let infoPlistKey: String = "CupertinoFoundationModelsPrivateCloudComputeEnabled"

    static var isEnabled: Bool {
        return Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? Bool ?? false
    }

    static let unavailableReason: String =
        "Private Cloud Compute is not enabled for this host app."

    static let recoverySuggestion: String =
        "After Apple grants the managed Private Cloud Compute entitlement, add "
        + "CupertinoFoundationModelsPrivateCloudComputeEnabled=true to the host Info.plist "
        + "and sign the app with com.apple.developer.private-cloud-compute."
}
