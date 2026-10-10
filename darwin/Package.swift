// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CupertinoFoundationModelsContracts",
    platforms: [.macOS("26.0")],
    targets: [
        .target(
            name: "CupertinoSchemaContracts",
            path: "cupertino_fundations_models/Sources/cupertino_fundations_models",
            exclude: [
                "ApplePlatform.swift", "AvailabilityService.swift",
                "CupertinoFoundationModelsPlugin.swift", "ErrorMapper.swift",
                "FileSelectionService.swift", "LiveTranscriptionService.swift",
                "MessageCodec.swift", "PrivateCloudComputeAccess.swift",
                "PrivacyInfo.xcprivacy", "SessionRegistry.swift",
                "SpeechPermissions.swift", "SpeechTranscriptionService.swift",
                "ToolBridge.swift"
            ],
            sources: ["SchemaMapper.swift", "StructuredSnapshotMapper.swift", "SessionHistoryCodec.swift", "AvailabilityMonitor.swift", "TextModelLanguageMapper.swift", "NativeSessionError.swift"]
        ),
        .testTarget(
            name: "CupertinoSchemaContractsTests",
            dependencies: ["CupertinoSchemaContracts"],
            path: "Tests/CupertinoSchemaContractsTests"
        )
    ]
)
