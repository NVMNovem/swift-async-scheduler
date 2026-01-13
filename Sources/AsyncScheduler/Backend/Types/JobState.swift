//
//  JobState.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 13/01/2026.
//

public enum JobState {
    
    case idle
    case running
    case paused
    case finished(JobResult)
}

extension JobState: Sendable {}

extension JobState: Equatable {
    
    public static func == (lhs: JobState, rhs: JobState) -> Bool {
        return switch (lhs, rhs) {
        case (.idle, .idle): true
        case (.running, .running): true
        case (.paused, .paused): true
        case (.finished(let lResult), .finished(let rResult)): lResult == rResult
        default: false
        }
    }
}

public extension JobState {
    
    func isCancelled() -> Bool {
        switch self {
        case .finished(let result): result == .cancelled
        default: false
        }
    }
    
    func isCompleted() -> Bool {
        switch self {
        case .finished(let result): result == .completed
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
