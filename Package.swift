// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-async-scheduler",
    products: [
        .library(
            name: "AsyncScheduler",
            targets: ["AsyncScheduler"]
        ),
    ],
    targets: [
        .target(
            name: "AsyncScheduler"
        ),
        .testTarget(
            name: "AsyncSchedulerTests",
            dependencies: ["AsyncScheduler"]
        ),
    ]
)
