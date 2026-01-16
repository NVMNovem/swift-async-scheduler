//
//  JobEntry.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 13/01/2026.
//

public struct JobEntry {
    
    public let schedulerJob: SchedulerJob
    
    internal var task: Task<Void, Never>
    public internal(set) var state: JobState
    
    internal init(from schedulerJob: SchedulerJob, task: Task<Void, Never>) {
        self.schedulerJob = schedulerJob
        self.task = task
        self.state = .running
    }
}

extension JobEntry: Sendable {}
