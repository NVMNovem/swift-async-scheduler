//
//  JobState.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 13/01/2026.
//

import Foundation

/// Represents the lifecycle state of a scheduled job.
public enum JobState {
    
    /// The job action is currently executing.
    case executing(since: Date = Date())
    
    /// The job is scheduled and waiting for its next run.
    case running(since: Date)
    
    /// The job is paused and will not execute until resumed.
    case paused(on: Date = Date())
    
    /// The job is not scheduled or tracked by the scheduler.
    case idle(since: Date = Date())
    
    /// The job has finished with a terminal result.
    case finished(JobResult, on: Date = Date())
}

extension JobState: Sendable {}

extension JobState: Equatable {
    
    public static func == (lhs: JobState, rhs: JobState) -> Bool {
        return switch (lhs, rhs) {
        case (.idle, .idle): true
        case (.running, .running): true
        case (.executing, .executing): true
        case (.paused, .paused): true
        case (.finished(let lResult, _), .finished(let rResult, _)): lResult == rResult
        default: false
        }
    }
}

public extension JobState {
    
    func isCancelled() -> Bool {
        switch self {
        case .finished(let result, _): result == .cancelled
        default: false
        }
    }
    
    func isCompleted() -> Bool {
        switch self {
        case .finished(let result, _): result == .completed
        default: false
        }
    }
}

public extension Optional where Wrapped == JobState {
    
    func isCancelled() -> Bool {
        guard let self else { return false }
        return self.isCancelled()
    }
    
    func isCompleted() -> Bool {
        guard let self else { return false }
        return self.isCompleted()
    }
}
