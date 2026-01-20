//
//  SchedulerJob.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

import Foundation

public struct SchedulerJob {
    
    public let id: UUID
    public var job: Job { Job(id: id) }
    
    internal let scheduler: AsyncScheduler
    
    public let schedule: Schedule
    public let action: @Sendable (Job) async throws -> Void
    
    private var _name: String? = nil
    public private(set) var name: String {
        get { _name ?? "Job with ID '\(id.uuidString)'" }
        set { _name = newValue }
    }
    
    public private(set) var errorPolicy: ErrorPolicy
    public private(set) var overrunPolicy: OverrunPolicy
    
    public var state: JobState? {
        get async {
            await scheduler.jobState(for: job)
        }
    }
    
    public init(
        _ scheduler: AsyncScheduler,
        _ schedule: Schedule,
        action: @escaping @Sendable () async throws -> Void
    ) {
        self.id = UUID()
        
        self.scheduler = scheduler
        self.schedule = schedule
        self.action = { _ in try await action() }
        
        self.errorPolicy = .ignore
        self.overrunPolicy = .skip
    }
    
    public init(
        _ scheduler: AsyncScheduler,
        _ schedule: Schedule,
        action: @escaping @Sendable (Job) async throws -> Void
    ) {
        self.id = UUID()
        
        self.scheduler = scheduler
        self.schedule = schedule
        self.action = action
        
        self.errorPolicy = .ignore
        self.overrunPolicy = .skip
    }
}

extension SchedulerJob: Sendable {}

extension SchedulerJob: Identifiable {}

public extension SchedulerJob {
    
    func named(_ name: String) -> Self {
        var copy = self
        copy.name = name
        return copy
    }
    
    func errorPolicy(_ errorPolicy: ErrorPolicy) -> Self {
        var copy = self
        copy.errorPolicy = errorPolicy
        return copy
    }
    
    func overrunPolicy(_ overrunPolicy: OverrunPolicy) -> Self {
        var copy = self
        copy.overrunPolicy = overrunPolicy
        return copy
    }
}

public extension SchedulerJob {
    
    func cancel() async {
        await scheduler.cancel(self)
    }
}
