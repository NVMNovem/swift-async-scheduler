//
//  SchedulerJob.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

import Foundation

public struct SchedulerJob {
    
    public let id: UUID
    private let scheduler: AsyncScheduler
    
    public var job: AsyncScheduler.Job { id }
    
    public let name: String?
    public let schedule: Schedule
    public let action: @Sendable (AsyncScheduler.Job) async throws -> Void
    
    public var errorPolicy: ErrorPolicy
    public var overrunPolicy: OverrunPolicy
    
    internal init(
        _ name: String? = nil,
        schedule: Schedule,
        scheduler: AsyncScheduler,
        action: @escaping @Sendable () async throws -> Void
    ) {
        self.id = UUID()
        self.name = name
        self.schedule = schedule
        self.scheduler = scheduler
        self.action = { _ in try await action() }
        self.errorPolicy = .ignore
        self.overrunPolicy = .skip
    }
    
    internal init(
        _ name: String? = nil,
        schedule: Schedule,
        scheduler: AsyncScheduler,
        action: @escaping @Sendable (AsyncScheduler.Job) async throws -> Void
    ) {
        self.id = UUID()
        self.name = name
        self.schedule = schedule
        self.scheduler = scheduler
        self.action = action
        self.errorPolicy = .ignore
        self.overrunPolicy = .skip
    }
}

extension SchedulerJob: Sendable {}

extension SchedulerJob: Identifiable {}

public extension SchedulerJob {
    
    mutating func errorPolicy(_ errorPolicy: ErrorPolicy) {
        self.errorPolicy = errorPolicy
    }
    
    mutating func overrunPolicy(_ overrunPolicy: OverrunPolicy) {
        self.overrunPolicy = overrunPolicy
    }
}

