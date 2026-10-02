#if os(macOS)
@preconcurrency import FlutterMacOS
#else
@preconcurrency import Flutter
#endif
import Foundation
#if os(macOS)
@preconcurrency import AppKit
#else
import UIKit
#endif
import UniformTypeIdentifiers

@MainActor
final class FileSelectionService: NSObject {
    private var pendingResult: FlutterResult?
    private var pendingKind: String = "any"
    #if os(macOS)
    private var activePanel: NSOpenPanel?
    #endif

    func pickFile(arguments: [String: Any], result: @escaping FlutterResult) {
        guard pendingResult == nil else {
            result(ErrorMapper.flutterError(
                code: "invalidRequest",
                message: "A file picker request is already active."
            ))
            return
        }

        let kind: String = arguments["kind"] as? String ?? "any"
        #if os(macOS)
        let panel: NSOpenPanel = NSOpenPanel()
        panel.allowedContentTypes = contentTypes(kind: kind)
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        pendingKind = kind
        pendingResult = result
        activePanel = panel
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            self?.finishSelection(url: response == .OK ? panel.url : nil)
        }
        if let window: NSWindow = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
        #else
        guard let viewController: UIViewController = topViewController() else {
            result(ErrorMapper.flutterError(
                code: "fileSelectionUnavailable",
                message: "No active view controller is available to present the file picker."
            ))
            return
        }

        let picker: UIDocumentPickerViewController = UIDocumentPickerViewController(
            forOpeningContentTypes: contentTypes(kind: kind),
            asCopy: true
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        pendingKind = kind
        pendingResult = result
        viewController.present(picker, animated: true)
        #endif
    }

    private func finishSelection(url: URL?) {
        guard let result: FlutterResult = pendingResult else {
            return
        }
        pendingResult = nil
        #if os(macOS)
        activePanel = nil
        #endif

        guard let url else {
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

    #if os(iOS)
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
    #endif
}

#if os(iOS)
extension FileSelectionService: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        finishSelection(url: urls.first)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finishSelection(url: nil)
    }
}
#endif
