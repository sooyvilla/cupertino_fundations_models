import Flutter
import Foundation
import UIKit
import UniformTypeIdentifiers

final class FileSelectionService: NSObject, UIDocumentPickerDelegate {
    private var pendingResult: FlutterResult?
    private var pendingKind: String = "any"

    func pickFile(arguments: [String: Any], result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            guard self.pendingResult == nil else {
                result(ErrorMapper.flutterError(
                    code: "invalidRequest",
                    message: "A file picker request is already active."
                ))
                return
            }

            guard let viewController: UIViewController = self.topViewController() else {
                result(ErrorMapper.flutterError(
                    code: "fileSelectionUnavailable",
                    message: "No active view controller is available to present the file picker."
                ))
                return
            }

            let kind: String = arguments["kind"] as? String ?? "any"
            let picker: UIDocumentPickerViewController = UIDocumentPickerViewController(
                forOpeningContentTypes: self.contentTypes(kind: kind),
                asCopy: true
            )
            picker.delegate = self
            picker.allowsMultipleSelection = false
            self.pendingKind = kind
            self.pendingResult = result
            viewController.present(picker, animated: true)
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let result: FlutterResult = pendingResult else {
            return
        }
        pendingResult = nil

        guard let url: URL = urls.first else {
            result(nil)
            return
        }

        do {
            let copiedURL: URL = try copyToTemporaryDirectory(url: url)
            result([
                "path": copiedURL.path,
                "name": url.lastPathComponent,
                "mimeType": mimeType(for: copiedURL),
                "kind": pendingKind
            ])
        } catch {
            result(ErrorMapper.flutterError(from: error))
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pendingResult?(nil)
        pendingResult = nil
    }

    private func contentTypes(kind: String) -> [UTType] {
        switch kind {
        case "image":
            return [.image]
        case "audio":
            return [.audio]
        case "text":
            return [.plainText, .text, .utf8PlainText, .json, .sourceCode, .pdf]
        default:
            return [.item]
        }
    }

    private func copyToTemporaryDirectory(url: URL) throws -> URL {
        let didStartAccessing: Bool = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cupertino_fundations_models", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let targetURL: URL = directory.appendingPathComponent(
            "\(UUID().uuidString)-\(url.lastPathComponent)"
        )
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.copyItem(at: url, to: targetURL)
        return targetURL
    }

    private func mimeType(for url: URL) -> String? {
        guard let type: UTType = UTType(filenameExtension: url.pathExtension) else {
            return nil
        }
        return type.preferredMIMEType
    }

    private func topViewController() -> UIViewController? {
        let scenes: Set<UIScene> = UIApplication.shared.connectedScenes
        let windowScene: UIWindowScene? = scenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let root: UIViewController? = windowScene?.windows
            .first { $0.isKeyWindow }?
            .rootViewController
        return visibleViewController(from: root)
    }

    private func visibleViewController(from viewController: UIViewController?) -> UIViewController? {
        if let navigationController: UINavigationController = viewController as? UINavigationController {
            return visibleViewController(from: navigationController.visibleViewController)
        }
        if let tabBarController: UITabBarController = viewController as? UITabBarController {
            return visibleViewController(from: tabBarController.selectedViewController)
        }
        if let presented: UIViewController = viewController?.presentedViewController {
            return visibleViewController(from: presented)
        }
        return viewController
    }
}
