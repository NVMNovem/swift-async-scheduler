//
//  AsyncScheduler.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

import Foundation

public actor AsyncScheduler: Sendable {
    
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
    
    public func cancel(_ job: Job) async {
        // mark cancelled first so the running loop can observe it
        jobStates[job] = .cancelled
        if let task = tasks.removeValue(forKey: job) {
            task.cancel()
            // wait for the task to finish
            _ = await task.value
        }
        resumeIfIdle()
    }
    
    public func cancelAll() async {
        // capture current tasks
        let currentTasks = tasks
        // mark all jobs cancelled first
        for job in currentTasks.keys {
            jobStates[job] = .cancelled
        }
        for task in currentTasks.values {
            task.cancel()
        }
        // await their completion
        for task in currentTasks.values {
            _ = await task.value
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
    static func run(_ configure: (@Sendable (AsyncScheduler) async -> Void)? = nil) async {
        let scheduler = AsyncScheduler()
        
        await configure?(scheduler)
        
        // Suspend until scheduler becomes idle (no active tasks)
        await scheduler.waitUntilIdle()
    }
}

private extension AsyncScheduler {
    
    func execute(_ scheduledJob: ScheduledJob) async {
        let job = scheduledJob.job
        
        // Run the job loop inline in the Task that called `execute(_:)`.
        // This ensures the Task stored in `tasks` is the actual running task
        // and that cancelling it via `cancel(_:)` will stop the loop immediately.
        while !Task.isCancelled {
            // If the job was cancelled via actor state, stop.
            if jobStates[job] == .cancelled { break }
            
            try? await self.sleep(for: scheduledJob.schedule.sleep)
            
            guard !Task.isCancelled else { break }
            
            if jobStates[job] == .cancelled { break }
            
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
            
            if jobStates[job] == .cancelled { break }
            
            await self.markJobRunning(job)
            
            // Execute the job action inline within the actor-executing task. The action is invoked
            // from actor context (we are inside an actor method) so it can safely access actor-local
            // resources if it needs to by making further `await` calls.
            try? await scheduledJob.action(job)
            
            guard !Task.isCancelled else { break }
            
            if jobStates[job] == .cancelled { break }
            
            await self.markJobFinished(job)
        }
        
        // Final cleanup in case of cancellation
        await self.removeTaskAndFinish(job)
    }
    
    private func isJobRunning(_ job: Job) async -> Bool {
        jobStates[job] == .running
    }
    
    private func markJobRunning(_ job: Job) async {
        jobStates[job] = .running
    }
    
    private func markJobFinished(_ job: Job) async {
        // only clear running state; do not remove the stored Task here because
        // the Task may still be looping and scheduling further runs. Removing
        // the Task while it's still running causes cancel/cancelAll to miss it.
        jobStates.removeValue(forKey: job)
    }
    
    private func removeTaskAndFinish(_ job: Job) async {
        tasks.removeValue(forKey: job)
        jobStates.removeValue(forKey: job)
        resumeIfIdle()
    }
    
    private func runJobAction(_ scheduledJob: ScheduledJob) async {
        let job = scheduledJob.job
        defer { Task { await markJobFinished(job) } }
        try? await scheduledJob.action(job)
    }
    
    func resumeIfIdle() {
        if tasks.isEmpty {
            print("AsyncScheduler: Scheduler is now idle; resuming waiters.")
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
