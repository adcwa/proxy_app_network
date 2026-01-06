// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProxyAppNetwork",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "ProxyApp", targets: ["ProxyApp"]),
        .library(name: "ProxyExtension", targets: ["ProxyExtension"])
    ],
    dependencies: [
        .package(path: "Packages/ProxyEngine")
    ],
    targets: [
        .executableTarget(
            name: "ProxyApp",
            dependencies: [
                .product(name: "ProxyEngine", package: "ProxyEngine")
            ],
            path: "Sources/App",
            linkerSettings: [
                .linkedFramework("SystemExtensions"),
                .linkedFramework("NetworkExtension")
            ]
        ),
        .target(
            name: "ProxyExtension",
            dependencies: [
                .product(name: "ProxyEngine", package: "ProxyEngine")
            ],
            path: "Sources/Extension",
            linkerSettings: [
                .linkedFramework("NetworkExtension")
            ]
        )
    ]
)
