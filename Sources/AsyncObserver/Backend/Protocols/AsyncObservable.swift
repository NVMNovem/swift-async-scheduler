//
//  AsyncObservable.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 02/10/2025.
//

import Foundation

/// An actor protocol for types that support asynchronous observer callbacks for value changes.
///
/// Conforming types can register async observers that are notified whenever the observed value changes.
/// Observers are invoked asynchronously and receive the new value.
///
public protocol AsyncObservable: Actor {
    
    /// The type of value being observed.
    associatedtype Observable: Sendable
    
    /// The list of async observers registered to receive value changes.
    var asyncObservers: [AsyncObserver<Observable>] { get set }
}

public extension AsyncObservable {
    
    /// Registers an async observer callback to be notified of value changes.
    /// - Parameter callback: The async callback to invoke when the value changes.
    /// - Returns: A token (UUID) that can be used to remove the observer later.
    ///
    func addAsyncObserver(_ callback: @Sendable @escaping (Observable) async -> Void) -> UUID {
        let newObserver = AsyncObserver(callback)
        self.asyncObservers.append(newObserver)
        return newObserver.id
    }
    
    /// Removes an async observer by its token (UUID).
    /// - Parameter id: The token returned when the observer was added.
    ///
    func removeAsyncObserver(id: UUID) {
        self.asyncObservers.removeAll { $0.id == id }
    }
}

public extension AsyncObservable {
    
    /// Notifies all registered async observers with the new value.
    /// Each observer callback is invoked asynchronously.
    /// - Parameter value: The new value to send to observers.
    ///
    func notifyAsyncObservers(_ value: Observable) {
        for asyncObserver in asyncObservers {
            Task { await asyncObserver.callback(value) }
        }
    }
}
