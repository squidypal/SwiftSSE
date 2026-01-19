// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftSSE",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
    ],
    products: [
        .library(name: "SwiftSSECore", targets: ["SwiftSSECore"]),
        .library(name: "SwiftSSEServer", targets: ["SwiftSSEServer"]),
        //.library(name: "SwiftSSEClient", targets: ["SwiftSSEClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.19.0"),
    ],
    targets: [
        .target(
            name: "SwiftSSECore"
        ),
        .target(
            name: "SwiftSSEServer",
            dependencies: [
                "SwiftSSECore",
                .product(name: "Vapor", package: "vapor")
            ]
        ),
        .target(
            name: "SwiftSSEClient",
            dependencies: [
                "SwiftSSECore",
                .product(name: "AsyncHTTPClient", package: "async-http-client", condition: .when(platforms: [.linux]))
            ]
        ),
        .testTarget(
            name: "SwiftSSECoreTests",
            dependencies: ["SwiftSSECore"]
        ),
        .testTarget(
            name: "SwiftSSEServerTests",
            dependencies: ["SwiftSSEServer"]
        ),
        .testTarget(
            name: "SwiftSSEClientTests",
            dependencies: ["SwiftSSEClient"]
        ),
    ]
)
