// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Retypo",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Retypo", targets: ["Retypo"])
    ],
    targets: [
        .executableTarget(
            name: "Retypo",
            path: "Sources/Retypo"
        ),
        .testTarget(
            name: "RetypoTests",
            dependencies: ["Retypo"],
            path: "Tests/RetypoTests"
        )
    ]
)
