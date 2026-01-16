//
//  JobEntry.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 13/01/2026.
//

import Foundation

public struct JobEntry {
    
    public let schedulerJob: SchedulerJob
    
    internal var task: Task<Void, Never>
    internal private(set) var runningDate: Date
    public internal(set) var state: JobState {
        didSet {
            if case .running(let date) = state {
                runningDate = date
            }
        }
    }
    
    internal init(from schedulerJob: SchedulerJob, task: Task<Void, Never>) {
        self.schedulerJob = schedulerJob
        
        self.task = task
        
        let runDate = Date()
        self.state = .running(since: runDate)
        self.runningDate = runDate
    }
}

extension JobEntry: Sendable {}

internal extension JobEntry {
    
    var runningSince: Date? {
        if state.isCancelled() { return nil }
        if state.isCompleted() { return nil }
        
        return runningDate
    }
}
