// swift-tools-version: 5.9

import Foundation
import PackageDescription

// Command Line Tools ships Swift Testing outside the default framework search
// path. Xcode installs find it automatically; add the CLT path when needed so
// `swift test` works on both setups.
let cltFrameworks = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let cltInterop = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
let needsCLTTestingPaths = FileManager.default.fileExists(atPath: cltFrameworks + "/Testing.framework")

let testSwiftSettings: [SwiftSetting] = needsCLTTestingPaths
    ? [.unsafeFlags(["-F", cltFrameworks])]
    : []

let testLinkerSettings: [LinkerSetting] = needsCLTTestingPaths
    ? [.unsafeFlags([
        "-F", cltFrameworks,
        "-framework", "Testing",
        "-Xlinker", "-rpath", "-Xlinker", cltFrameworks,
        "-Xlinker", "-rpath", "-Xlinker", cltInterop
    ])]
    : []

let package = Package(
    name: "SpaceSweep",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SpaceSweep", targets: ["SpaceSweep"])
    ],
    targets: [
        .executableTarget(
            name: "SpaceSweep",
            path: "Sources/SpaceSweep"
        ),
        .testTarget(
            name: "SpaceSweepTests",
            dependencies: ["SpaceSweep"],
            path: "Tests/SpaceSweepTests",
            swiftSettings: testSwiftSettings,
            linkerSettings: testLinkerSettings
        )
    ]
)
