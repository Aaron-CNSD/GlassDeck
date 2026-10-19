// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Lumen",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "GlassDeck", targets: ["GlassDeck"])
    ],
    targets: [
        // Shared model used by both the main app and the widget.
        .target(
            name: "Shared",
            path: "Sources/Shared"
        ),
        .executableTarget(
            name: "GlassDeck",
            dependencies: ["Shared"],
            path: "Sources/GlassDeck",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreServices"),
                .linkedFramework("Vision")
            ]
        ),
        // NOTE: The Widget extension (Widget/) is built via the Xcode project
        // (project.yml → XcodeGen), NOT via SPM. WidgetKit app extensions
        // cannot be built with `swift build` — they require an Xcode app
        // extension target with code signing. See README for build steps.
    ]
)
