//
//  JobState.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 13/01/2026.
//

public enum JobState {
    
    case running
    case paused
    case cancelled
}

extension JobState: Sendable {}
