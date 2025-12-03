//
//  AsyncScheduler.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

import Foundation

public actor AsyncScheduler {
    
    public typealias Job = ScheduledJob.ID
    
    private var tasks: [Job : Task<Void, Never>]
    private var jobStates: [Job : JobState]
    
    private var idleContinuation: CheckedContinuation<Void, Never>? = nil

    public init() {
        self.tasks = [:]
        self.jobStates = [:]
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
        resumeIfIdle()
    }
    
    public func cancelAll() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
        resumeIfIdle()
    }
    
    public func waitUntilIdle() async {
        if tasks.isEmpty { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            idleContinuation = continuation
        }
    }
}

public extension AsyncScheduler {
    
    /// Runs a scheduler with the provided configuration closure and keeps the process alive
    /// as long as any scheduled jobs are still active.
    ///
    /// - Parameter configure: An optional asynchronous closure that receives an `AsyncScheduler`
    ///
    /// - Important: `run()` does not exit until the user cancels all scheduled jobs.
    ///
    static func run(_ configure: ((AsyncScheduler) async -> Void)? = nil) async {
        let scheduler = AsyncScheduler()

        await configure?(scheduler)

        // Suspend until scheduler becomes idle (no active tasks)
        await scheduler.waitUntilIdle()
    }
}

private extension AsyncScheduler {
    func execute(_ scheduledJob: ScheduledJob) async {
        let job = scheduledJob.job

        let task: Task = Task { [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                try? await self.sleep(for: scheduledJob.schedule.sleep)

                guard !Task.isCancelled else { break }

                if await self.isJobRunning(job) {
                    switch scheduledJob.overrunPolicy {
                    case .skip:
                        continue
                    case .wait:
                        while await self.isJobRunning(job) && !Task.isCancelled {
                            try? await self.sleep(for: .milliseconds(10))
                        }
                    case .overlap:
                        break //TODO: Allow overlapping executions
                    }
                }

                await self.markJobRunning(job)

                // Execute the job action inline, not in a detached child Task
                try? await scheduledJob.action()

                guard !Task.isCancelled else { break }

                await self.markJobFinished(job)
            }

            // Final cleanup in case of cancellation
            await self.markJobFinished(job)
        }

        await storeTask(job, task)
    }

    private func storeTask(_ job: Job, _ task: Task<Void, Never>) async {
        tasks[job] = task
    }

    private func isJobRunning(_ job: Job) async -> Bool {
        jobStates[job] == .running
    }

    private func markJobRunning(_ job: Job) async {
        jobStates[job] = .running
    }

    private func markJobFinished(_ job: Job) async {
        tasks.removeValue(forKey: job)
        jobStates.removeValue(forKey: job)
        resumeIfIdle()
    }

    private func runJobAction(_ scheduledJob: ScheduledJob) async {
        let job = scheduledJob.job
        defer { Task { await markJobFinished(job) } }
        try? await scheduledJob.action()
    }

    func resumeIfIdle() {
        if tasks.isEmpty {
            idleContinuation?.resume()
            idleContinuation = nil
        }
    }
}

fileprivate extension AsyncScheduler {
    
    func sleep(for duration: Duration) async throws {
        let ns = duration.nanosecondsApprox
        try await Task.sleep(nanoseconds: ns)
    }
}
