//
//  AsyncScheduler+Convenience.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

public extension AsyncScheduler {
    
    @discardableResult
    func every(
        _ interval: Duration,
        name: String? = nil,
        errorPolicy: ErrorPolicy = .ignore,
        overrunPolicy: OverrunPolicy = .skip,
        _ action: @escaping @Sendable () async throws -> Void
    ) -> Job.ID {
        var job = Job(name, schedule: .interval(interval), action: action)
        
        job.withErrorPolicy(errorPolicy)
        job.overrunPolicy(overrunPolicy)
        
        return schedule(job)
    }
}

public extension AsyncScheduler {
    
    @discardableResult
    func daily(
        hour: Int, minute: Int,
        name: String? = nil,
        errorPolicy: ErrorPolicy = .ignore,
        overrunPolicy: OverrunPolicy = .skip,
        _ action: @escaping @Sendable () async throws -> Void
    ) -> Job.ID {
        var job = Job(name, schedule: .daily(hour: hour, minute: minute), action: action)
        
        job.withErrorPolicy(errorPolicy)
        job.overrunPolicy(overrunPolicy)
        
        return schedule(job)
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
    ) -> Job.ID {
        var job = Job(name, schedule: .cron(expression), action: action)
        
        job.withErrorPolicy(errorPolicy)
        job.overrunPolicy(overrunPolicy)
        
        return schedule(job)
    }
}
