// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-async-scheduler",
    platforms: [.macOS(.v13), .iOS(.v16), .watchOS(.v9), .tvOS(.v16)],
    products: [
        .library(name: "AsyncScheduler", targets: ["AsyncScheduler"]),
        .library(name: "AsyncObserver", targets: ["AsyncObserver"]),
    ],
    targets: [
        .target(
            name: "AsyncScheduler",
            dependencies: [
                "AsyncObserver"
            ]
        ),
        .testTarget(
            name: "AsyncSchedulerTests",
            dependencies: [
                "AsyncScheduler"
            ]
        ),
        .target(
            name: "AsyncObserver"
        ),
    ]
)
