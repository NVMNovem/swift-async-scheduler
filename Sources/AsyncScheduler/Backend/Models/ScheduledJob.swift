//
//  ScheduledJob.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

import Foundation

public struct ScheduledJob {
    
    public let id: UUID
    public let name: String?
    public let schedule: Schedule
    public let action: @Sendable () async throws -> Void
    
    public var errorPolicy: ErrorPolicy
    public var overrunPolicy: OverrunPolicy

    public init(
        _ name: String? = nil,
        schedule: Schedule,
        action: @escaping @Sendable () async throws -> Void
    ) {
        self.id = UUID()
        self.name = name
        self.schedule = schedule
        self.action = action
        
        self.errorPolicy = .ignore
        self.overrunPolicy = .skip
    }
}

extension ScheduledJob: Sendable {}

extension ScheduledJob: Identifiable {}

public extension ScheduledJob {
    
    mutating func withErrorPolicy(_ errorPolicy: ErrorPolicy) {
        self.errorPolicy = errorPolicy
    }
    
    mutating func overrunPolicy(_ overrunPolicy: OverrunPolicy) {
        self.overrunPolicy = overrunPolicy
    }
}
