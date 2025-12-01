//
//  AsyncScheduler.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

import Foundation

public actor AsyncScheduler {
    
    public typealias Job = ScheduledJob
    
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private let clock: any Clock<Duration>
    
    public init(clock: any Clock<Duration> = .continuous) {
        self.clock = clock
    }
    
    @discardableResult
    public func schedule(_ job: Job) -> Job.ID {
        return job.id
    }
    
    public func cancel(_ id: UUID) {
        
    }
    
    public func cancelAll() {
        
    }
}

private extension AsyncScheduler {
    
    func run(_ job: Job) async {
        while !Task.isCancelled {
            do {
                try await clock.sleep(for: job.schedule.sleep)
                try await job.action()
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
