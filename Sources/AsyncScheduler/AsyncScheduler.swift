//
//  AsyncScheduler.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

import Foundation

public actor AsyncScheduler {
    
    public typealias Job = ScheduledJob
    
    private let clock: any Clock<Duration>
    
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var jobStates: [UUID: JobState] = [:]
    
    public init(clock: any Clock<Duration> = .continuous) {
        self.clock = clock
    }
    
    @discardableResult
    public func schedule(_ job: Job) -> Job.ID {
        let runner: @Sendable () async -> Void = { [unowned self] in
            await self.execute(job)
        }
        
        let task = Task {
            await runner()
        }
        
        tasks[job.id] = task
        return job.id
    }
    
    public func cancel(_ id: UUID) {
        if let task = tasks.removeValue(forKey: id) {
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
    
    func execute(_ job: Job) async {
        while !Task.isCancelled {
            do {
                try await clock.sleep(for: job.schedule.sleep)
                if jobStates[job.id] == .running {
                    switch job.overrunPolicy {
                    case .skip:
                        continue
                    case .wait:
                        while jobStates[job.id] == .running { try await clock.sleep(for: .milliseconds(10)) }
                    case .overlap:
                        break //TODO: allow overlapping runs
                    }
                }
                
                jobStates[job.id] = .running
                
                Task {
                    defer { jobStates.removeValue(forKey: job.id) }
                    try await job.action()
                }
            } catch {
                //TODO: Create a logger to log the error
                switch job.errorPolicy {
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
