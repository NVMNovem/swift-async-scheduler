// TestClock.swift — from swift-clocks (https://github.com/pointfreeco/swift-clocks)
// MIT License
// Copyright (c) 2025 Point-Free, LLC and contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the “Software”), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.

import Foundation

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public final class TestClock<Duration: DurationProtocol & Hashable>: Clock, @unchecked Sendable {
    public struct Instant: InstantProtocol, Comparable {
        fileprivate let offset: Duration
        
        public init(offset: Duration = .zero) {
            self.offset = offset
        }
        
        public func advanced(by duration: Duration) -> Self {
            .init(offset: self.offset + duration)
        }
        
        public func duration(to other: Self) -> Duration {
            other.offset - self.offset
        }
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.offset < rhs.offset
        }
    }
    
    public var minimumResolution: Duration = .zero
    public private(set) var now: Instant
    
    private let lock = NSRecursiveLock()
    private var suspensions:
    [(
        id: UUID,
        deadline: Instant,
        continuation: AsyncThrowingStream<Never, Error>.Continuation
    )] = []
    
    public init(now: Instant = .init()) {
        self.now = now
    }
    
    private func megaYield() async {
        for _ in 0..<10 {
            await Task.yield()
        }
    }
    
    public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        try Task.checkCancellation()
        let id = UUID()
        do {
            let stream: AsyncThrowingStream<Never, Error>? = self.lock.sync {
                guard deadline >= self.now else { return nil }
                return AsyncThrowingStream<Never, Error> { continuation in
                    self.suspensions.append((id: id, deadline: deadline, continuation: continuation))
                }
            }
            guard let stream = stream else { return }
            for try await _ in stream {}
            try Task.checkCancellation()
        } catch is CancellationError {
            self.lock.sync { self.suspensions.removeAll(where: { $0.id == id }) }
            throw CancellationError()
        }
    }
    
    public func advance(by duration: Duration = .zero) async {
        await self.advance(to: self.lock.sync { self.now.advanced(by: duration) })
    }
    
    public func advance(to deadline: Instant) async {
        while self.lock.sync(operation: { self.now <= deadline }) {
            await megaYield()
            let shouldReturn = self.lock.sync {
                self.suspensions.sort { $0.deadline < $1.deadline }
                guard let next = self.suspensions.first, deadline >= next.deadline else {
                    self.now = deadline
                    return true
                }
                self.now = next.deadline
                self.suspensions.removeFirst()
                next.continuation.finish()
                return false
            }
            if shouldReturn {
                await megaYield()
                return
            }
        }
        await megaYield()
    }
    
    public func run(timeout duration: Swift.Duration = .milliseconds(500)) async {
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await Task.sleep(for: duration)
                    self.lock.sync {
                        for suspension in self.suspensions {
                            suspension.continuation.finish(throwing: CancellationError())
                        }
                    }
                    throw CancellationError()
                }
                group.addTask {
                    await self.megaYield()
                    while let deadline = self.lock.sync(operation: { self.suspensions.first?.deadline }) {
                        try Task.checkCancellation()
                        await self.advance(by: self.lock.sync { self.now.duration(to: deadline) })
                    }
                }
                try await group.next()
                group.cancelAll()
            }
        } catch {
            // In a minimal implementation we do not report issues.
        }
    }
}

public struct SuspensionError: Error {}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension TestClock where Duration == Swift.Duration {
    public convenience init() {
        self.init(now: .init())
    }
}

private extension NSRecursiveLock {
    func sync<T>(operation: () throws -> T) rethrows -> T {
        self.lock()
        defer { self.unlock() }
        return try operation()
    }
}
