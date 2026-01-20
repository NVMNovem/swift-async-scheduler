// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-async-scheduler",
    platforms: [.macOS(.v13), .iOS(.v16), .watchOS(.v9), .tvOS(.v16)],
    products: [
        .library(name: "AsyncScheduler", targets: ["AsyncScheduler"])
    ],
    dependencies: [
        .package(url: "https://github.com/NVMNovem/swift-async-observer", .upToNextMinor(from: Version(1,0,0)))
    ],
    targets: [
        .target(
            name: "AsyncScheduler",
            dependencies: [
                .product(name: "AsyncObserver", package: "swift-async-observer")
            ]
        ),
        .testTarget(
            name: "AsyncSchedulerTests",
            dependencies: [
                "AsyncScheduler"
            ]
        )
    ]
)
