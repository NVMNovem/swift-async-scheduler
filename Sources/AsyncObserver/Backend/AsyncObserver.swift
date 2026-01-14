//
//  AsyncObserver.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 02/10/2025.
//

import Foundation

/// Represents an asynchronous observer for a value of type `Observable`.
///
/// Each observer has a unique identifier and an async callback that is invoked when the observed value changes.
/// Used in conjunction with `AsyncObservable` to implement the async observer pattern.
///
public struct AsyncObserver<Observable> {
    
    /// Unique identifier for the observer instance.
    public let id: UUID
    
    /// The async callback to invoke when the observed value changes.
    internal let callback: @Sendable (Observable) async -> Void
    
    /// Creates a new async observer with the provided callback.
    /// - Parameter callback: The async callback to invoke when the value changes.
    ///
    public init(_ callback: @Sendable @escaping (Observable) async -> Void) {
        self.id = UUID()
        self.callback = callback
    }
}

extension AsyncObserver: Sendable
