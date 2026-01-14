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

extension Array where Element == JobEntry {

    /// Convenience accessor for reading/updating/removing a `JobEntry` by `Job`.
    ///
    /// - Setting a non-nil value updates an existing entry (if present) or appends a new one.
    /// - Setting `nil` removes the entry (if present).
    internal subscript(job: Job) -> JobEntry? {
        get {
            first { $0.schedulerJob.job == job }
        }
        set {
            if let index = firstIndex(where: { $0.schedulerJob.job == job }) {
                if let newValue {
                    self[index] = newValue
                } else {
                    self.remove(at: index)
                }
            } else if let newValue {
                self.append(newValue)
            }
        }
    }
}
