<picture>
  <source srcset="https://github.com/user-attachments/assets/700311e1-52d0-4c92-bb72-84d8fc7a4c2a" media="(prefers-color-scheme: light)"/>
  <source srcset="https://github.com/user-attachments/assets/91e1a966-a97f-4975-bbb3-bd7682d8d34f"  media="(prefers-color-scheme: dark)"/>
  <img src="https://github.com/user-attachments/assets/700311e1-52d0-4c92-bb72-84d8fc7a4c2a" alt="SwiftAsyncScheduler"/>
</picture>

Swift Async Scheduler is a small, dependency-free Swift package for scheduling and running asynchronous jobs.

This package provides a lightweight API for creating recurring and scheduled async jobs, intended for use in server- and app-side Swift code. It intentionally avoids external dependencies — it's written in plain Swift and integrates with the Swift concurrency model.


## Platform Compatibility
This Swift package is designed to run on:
- ![macOS](https://github.com/NVMNovem/swift-async-scheduler/actions/workflows/buildOnMacOS.yml/badge.svg)
- ![Linux](https://github.com/NVMNovem/swift-async-scheduler/actions/workflows/buildOnLinux.yml/badge.svg)

## Key features
- Dependency-free: no third-party packages required. Works with the Swift standard library and Swift Concurrency.
- Easy scheduling API: convenience helpers to schedule repeating and one-off async jobs.
- Small, focused core: types like `Schedule`, `ScheduledJob`, and policies (e.g. `OverrunPolicy`, `ErrorPolicy`) let you control behavior when jobs overlap or throw.

## Installation

Add `swift-async-scheduler` as a dependency to your `Package.swift`:

```swift
// Package.swift (snippet)
dependencies: [
    .package(url: "https://github.com/NVMNovem/swift-async-scheduler", from: "1.0.0")
]

targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "AsyncScheduler", package: "swift-async-scheduler")
        ]
    )
]
```

Then run `swift build` in your project or open the package in Xcode.

## Basic usage

#### Repeating job every 5 seconds
```swift
import AsyncScheduler

let scheduler = AsyncScheduler()

// Schedule a repeating job every 5 seconds
let scheduledJob = ScheduledJob.every(.seconds(5)) {
    // perform async work here
}

scheduler.schedule(scheduledJob)
```

#### Running process
```swift
import AsyncScheduler

AsyncScheduler.run { scheduler in
    // Schedule a repeating job every 5 seconds
    let scheduledJob = ScheduledJob.every(.seconds(5)) {
        // perform async work here
    }
    if processNeedsToStop {
        await scheduler.cancel(scheduledJob.job)
    }
}

// or
AsyncScheduler.run { scheduler in
    // Schedule a repeating job every 5 seconds
    ScheduledJob.every(.seconds(5)) { scheduledJob in
        if processNeedsToStop {
            await scheduler.cancel(scheduledJob.job)
        }
    }
}
```
