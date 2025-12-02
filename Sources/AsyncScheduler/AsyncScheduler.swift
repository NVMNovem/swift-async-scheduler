//
//  AsyncScheduler.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

import Foundation

public actor AsyncScheduler {
    
    public typealias Job = ScheduledJob.ID
    
    private let clock: any Clock<Duration>
    
    private var tasks: [Job : Task<Void, Never>] = [:]
    private var jobStates: [Job : JobState] = [:]
    
    public init(clock: any Clock<Duration> = .continuous) {
        self.clock = clock
    }
    
    @discardableResult
    public func schedule(_ scheduledJob: ScheduledJob) -> Job {
        let runner: @Sendable () async -> Void = { [unowned self] in
            await self.execute(scheduledJob)
        }
        
        let task = Task {
            await runner()
        }
        
        let job = scheduledJob.job
        tasks[job] = task
        
        return job
    }
    
    public func cancel(_ job: Job) {
        if let task = tasks.removeValue(forKey: job) {
            task.cancel()
        }
    }
    
    public func cancelAll() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
    }
}

private extension AsyncScheduler {
    
    func execute(_ scheduledJob: ScheduledJob) async {
        let job = scheduledJob.job
        while !Task.isCancelled {
            do {
                try await clock.sleep(for: scheduledJob.schedule.sleep)
                if jobStates[job] == .running {
                    switch scheduledJob.overrunPolicy {
                    case .skip:
                        continue
                    case .wait:
                        while jobStates[job] == .running { try await clock.sleep(for: .milliseconds(10)) }
                    case .overlap:
                        break //TODO: allow overlapping runs
                    }
                }
                
                jobStates[job] = .running
                
                Task {
                    defer { jobStates.removeValue(forKey: job) }
                    try await scheduledJob.action()
                }
            } catch {
                //TODO: Create a logger to log the error
                switch scheduledJob.errorPolicy {
                case .ignore:
                    continue
                case .stop:
                    return
                case .retry(backoff: let backoff):
                    try? await clock.sleep(for: backoff)
                }
            }
        }
    }
}
