//
//  AsyncScheduler+Convenience.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

import Foundation

public extension AsyncScheduler {
    
    @discardableResult
    func every(
        _ interval: Duration,
        name: String? = nil,
        errorPolicy: ErrorPolicy = .ignore,
        overrunPolicy: OverrunPolicy = .skip,
        _ action: @escaping @Sendable () async throws -> Void
    ) -> Job {
        var scheduledJob = ScheduledJob(name, schedule: .interval(interval), action: action)
        
        scheduledJob.withErrorPolicy(errorPolicy)
        scheduledJob.overrunPolicy(overrunPolicy)
        
        return schedule(scheduledJob)
    }
}

public extension AsyncScheduler {
    
    @discardableResult
    func daily(
        on hour: Int, _ minute: Int, timeZone: TimeZone = .current,
        name: String? = nil,
        errorPolicy: ErrorPolicy = .ignore,
        overrunPolicy: OverrunPolicy = .skip,
        _ action: @escaping @Sendable () async throws -> Void
    ) -> Job {
        var scheduledJob = ScheduledJob(name, schedule: .daily(hour: hour, minute: minute, timeZone: timeZone), action: action)
        
        scheduledJob.withErrorPolicy(errorPolicy)
        scheduledJob.overrunPolicy(overrunPolicy)
        
        return schedule(scheduledJob)
    }
}

public extension AsyncScheduler {
    
    @discardableResult
    func cron(
        _ expression: String,
        name: String? = nil,
        errorPolicy: ErrorPolicy = .ignore,
        overrunPolicy: OverrunPolicy = .skip,
        _ action: @escaping @Sendable () async throws -> Void
    ) -> Job {
        var scheduledJob = ScheduledJob(name, schedule: .cron(expression), action: action)
        
        scheduledJob.withErrorPolicy(errorPolicy)
        scheduledJob.overrunPolicy(overrunPolicy)
        
        return schedule(scheduledJob)
    }
}
