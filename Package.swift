// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "WorldsSimplestTodo",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "WorldsSimplestTodo", targets: ["WorldsSimplestTodo"])
    ],
    targets: [
        .executableTarget(
            name: "WorldsSimplestTodo",
            linkerSettings: [
                .linkedFramework("Carbon", .when(platforms: [.macOS])),
                .linkedFramework("UserNotifications")
            ]
        ),
        .testTarget(
            name: "WorldsSimplestTodoTests",
            dependencies: ["WorldsSimplestTodo"]
        )
    ]
)
