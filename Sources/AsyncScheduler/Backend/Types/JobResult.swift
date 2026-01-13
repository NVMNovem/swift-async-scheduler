//
//  JobResult.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 13/01/2026.
//

public enum JobResult {
    
    case completed
    case cancelled
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
