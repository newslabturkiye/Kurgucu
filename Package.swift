// swift-tools-version: 6.0
import PackageDescription
import Foundation

let appResourceNames = ["Logo-Light.png", "Logo-Dark.png", "Scene-Landscape.png", "Scene-Portrait.png", "Scene-Square.png", "Scene-Social.png", "Sticker-Arrow.png", "Sticker-Spark.png", "Sticker-Heart.png", "NOTICE.txt", "OpenCut-LICENSE.txt"]
let resourceDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Sources/NKurguApp/Resources")
let excludedResources = ((try? FileManager.default.contentsOfDirectory(atPath: resourceDirectory.path)) ?? []).filter { !appResourceNames.contains($0) }.map { "Resources/" + $0 }


let package = Package(
    name: "NKurgu",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "NKurgu", targets: ["NKurguApp"]),
        .library(name: "KurguCore", targets: ["KurguCore"]),
        .library(name: "KurguEditing", targets: ["KurguEditing"]),
        .library(name: "KurguPersistence", targets: ["KurguPersistence"]),
        .library(name: "KurguMedia", targets: ["KurguMedia"]),
        .library(name: "KurguPlayback", targets: ["KurguPlayback"]),
        .library(name: "KurguExport", targets: ["KurguExport"])
    ],
    targets: [
        .target(name: "KurguCore"),
        .target(name: "KurguEditing", dependencies: ["KurguCore"]),
        .target(name: "KurguPersistence", dependencies: ["KurguCore"]),
        .target(name: "KurguMedia", dependencies: ["KurguCore"]),
        .target(name: "KurguPlayback", dependencies: ["KurguCore", "KurguMedia"]),
        .target(name: "KurguExport", dependencies: ["KurguCore", "KurguMedia", "KurguPlayback"]),
        .executableTarget(name: "NKurguApp", dependencies: ["KurguCore", "KurguEditing", "KurguPersistence", "KurguMedia", "KurguPlayback", "KurguExport"], exclude: excludedResources, resources: appResourceNames.map { .process("Resources/" + $0) }),
        .testTarget(name: "KurguTests", dependencies: ["KurguCore", "KurguEditing", "KurguPersistence", "KurguMedia", "KurguPlayback", "KurguExport"])
    ]
)
