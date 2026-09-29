// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "WorldsSimplestTodo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WorldsSimplestTodo", targets: ["WorldsSimplestTodo"])
    ],
    targets: [
        .executableTarget(
            name: "WorldsSimplestTodo",
            linkerSettings: [
                .linkedFramework("Carbon")
            ]
        )
    ]
)
