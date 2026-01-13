//
//  SchedulerJob+Convenience.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

import Foundation

public extension SchedulerJob {
    
    /// - Important: Do not reference job from inside the closure as the job isn't initialized yet.
    /// Instead use the other overload that provides the job as closure parameter.
    @discardableResult
    static func every(
        _ interval: Duration,
        name: String? = nil,
        errorPolicy: ErrorPolicy = .ignore,
        overrunPolicy: OverrunPolicy = .skip,
        _ action: @escaping @Sendable () async throws -> Void
    ) -> SchedulerJob {
        var schedulerJob = SchedulerJob(name, schedule: .interval(interval), action: action)
        
        schedulerJob.withErrorPolicy(errorPolicy)
        schedulerJob.overrunPolicy(overrunPolicy)
        
        return schedulerJob
    }
    
    static func every(
        _ interval: Duration,
        name: String? = nil,
        errorPolicy: ErrorPolicy = .ignore,
        overrunPolicy: OverrunPolicy = .skip,
        _ action: @escaping @Sendable (AsyncScheduler.Job) async throws -> Void
    ) -> SchedulerJob {
        var schedulerJob = SchedulerJob(name, schedule: .interval(interval), action: action)
        
        schedulerJob.withErrorPolicy(errorPolicy)
        schedulerJob.overrunPolicy(overrunPolicy)
        
        return schedulerJob
    }
}

public extension SchedulerJob {
    
    /// - Important: Do not reference job from inside the closure as the job isn't initialized yet.
    /// Instead use the other overload that provides the job as closure parameter.
    @discardableResult
    static func daily(
        on hour: Int, _ minute: Int, timeZone: TimeZone = .current,
        name: String? = nil,
        errorPolicy: ErrorPolicy = .ignore,
        overrunPolicy: OverrunPolicy = .skip,
        _ action: @escaping @Sendable () async throws -> Void
    ) -> SchedulerJob {
        var schedulerJob = SchedulerJob(name, schedule: .daily(hour: hour, minute: minute, timeZone: timeZone), action: action)
        
        schedulerJob.withErrorPolicy(errorPolicy)
        schedulerJob.overrunPolicy(overrunPolicy)
        
        return schedulerJob
    }
    
    static func daily(
        on hour: Int, _ minute: Int, timeZone: TimeZone = .current,
        name: String? = nil,
        errorPolicy: ErrorPolicy = .ignore,
        overrunPolicy: OverrunPolicy = .skip,
        _ action: @escaping @Sendable (AsyncScheduler.Job) async throws -> Void
    ) -> SchedulerJob {
        var schedulerJob = SchedulerJob(name, schedule: .daily(hour: hour, minute: minute, timeZone: timeZone), action: action)
        
        schedulerJob.withErrorPolicy(errorPolicy)
        schedulerJob.overrunPolicy(overrunPolicy)
        
        return schedulerJob
    }
}

public extension SchedulerJob {
    
    /// - Important: Do not reference job from inside the closure as the job isn't initialized yet.
    /// Instead use the other overload that provides the job as closure parameter.
    @discardableResult
    static func cron(
        _ expression: String,
        name: String? = nil,
        errorPolicy: ErrorPolicy = .ignore,
        overrunPolicy: OverrunPolicy = .skip,
        _ action: @escaping @Sendable () async throws -> Void
    ) -> SchedulerJob {
        var schedulerJob = SchedulerJob(name, schedule: .cron(expression), action: action)
        
        schedulerJob.withErrorPolicy(errorPolicy)
        schedulerJob.overrunPolicy(overrunPolicy)
        
        return schedulerJob
    }
    
    static func cron(
        _ expression: String,
        name: String? = nil,
        errorPolicy: ErrorPolicy = .ignore,
        overrunPolicy: OverrunPolicy = .skip,
        _ action: @escaping @Sendable (AsyncScheduler.Job) async throws -> Void
    ) -> SchedulerJob {
        var schedulerJob = SchedulerJob(name, schedule: .cron(expression), action: action)
        
        schedulerJob.withErrorPolicy(errorPolicy)
        schedulerJob.overrunPolicy(overrunPolicy)
        
        return schedulerJob
    }
}
