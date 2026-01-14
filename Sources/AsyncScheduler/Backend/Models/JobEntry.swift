//
//  JobEntry.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 13/01/2026.
//

internal struct JobEntry {
    
    internal let schedulerJob: SchedulerJob
    
    internal var task: Task<Void, Never>
    internal var state: JobState
    
    internal init(from schedulerJob: SchedulerJob, task: Task<Void, Never>) {
        self.schedulerJob = schedulerJob
        self.task = task
        self.state = .idle
    }
}

extension Collection where Element == JobEntry {
    
    internal subscript(job: Scheduler.Job) -> JobEntry? {
        get {
            first { $0.schedulerJob.job == job }
        }
        set {
            var entries = Array(self)
            if let index = entries.firstIndex(where: { $0.schedulerJob.job == job }) {
                if let newValue {
                    entries[index] = newValue
                } else {
                    entries.remove(at: index)
                }
            } else if let newValue {
                entries.append(newValue)
            }
        }
    }
}
