//
//  AsyncScheduler+Convenience.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

import Foundation

public extension AsyncScheduler {
    
    /// - Important: Do not reference job from inside the closure as the job isn't initialized yet.
    /// Instead use the other overload that provides the job as closure parameter.
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
    
    func every(
        _ interval: Duration,
        name: String? = nil,
        errorPolicy: ErrorPolicy = .ignore,
        overrunPolicy: OverrunPolicy = .skip,
        _ action: @escaping @Sendable (Job) async throws -> Void
    ) {
        var scheduledJob = ScheduledJob(name, schedule: .interval(interval), action: action)
        
        scheduledJob.withErrorPolicy(errorPolicy)
        scheduledJob.overrunPolicy(overrunPolicy)
        
        schedule(scheduledJob)
    }
}

public extension AsyncScheduler {
    
    /// - Important: Do not reference job from inside the closure as the job isn't initialized yet.
    /// Instead use the other overload that provides the job as closure parameter.
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
    
    func daily(
        on hour: Int, _ minute: Int, timeZone: TimeZone = .current,
        name: String? = nil,
        errorPolicy: ErrorPolicy = .ignore,
        overrunPolicy: OverrunPolicy = .skip,
        _ action: @escaping @Sendable (Job) async throws -> Void
    ) {
        var scheduledJob = ScheduledJob(name, schedule: .daily(hour: hour, minute: minute, timeZone: timeZone), action: action)
        
        scheduledJob.withErrorPolicy(errorPolicy)
        scheduledJob.overrunPolicy(overrunPolicy)
        
        schedule(scheduledJob)
    }
}

public extension AsyncScheduler {
    
    /// - Important: Do not reference job from inside the closure as the job isn't initialized yet.
    /// Instead use the other overload that provides the job as closure parameter.
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
    
    func cron(
        _ expression: String,
        name: String? = nil,
        errorPolicy: ErrorPolicy = .ignore,
        overrunPolicy: OverrunPolicy = .skip,
        _ action: @escaping @Sendable (Job) async throws -> Void
    ) {
        var scheduledJob = ScheduledJob(name, schedule: .cron(expression), action: action)
        
        scheduledJob.withErrorPolicy(errorPolicy)
        scheduledJob.overrunPolicy(overrunPolicy)
        
        schedule(scheduledJob)
    }
}
