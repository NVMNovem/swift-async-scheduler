//
//  JobResult.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 13/01/2026.
//

/// A terminal result describing how a job ended.
public enum JobResult {
    
    /// The job completed successfully.
    case completed
    
    /// The job was cancelled.
    case cancelled
    
    /// The job failed with an error.
    case failed(Error)
}

extension JobResult: Sendable {}

extension JobResult: Equatable {
    
    public static func == (lhs: JobResult, rhs: JobResult) -> Bool {
        return switch (lhs, rhs) {
        case (.completed, .completed): true
        case (.cancelled, .cancelled): true
        case (.failed, .failed): true
        default: false
        }
    }
}
