//
//  AsyncScheduler.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

import Foundation

public actor AsyncScheduler: Sendable {
    
    /// A Sendable identifier for a scheduled job.
    /// Used to reference scheduled jobs when cancelling them.
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
        let task = Task {
            await self.execute(scheduledJob)
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
    
    /// Run a scheduler with a builder that returns one or more `ScheduledJob`s.
    func run(@ScheduledJobBuilder _ builder: (AsyncScheduler) -> [ScheduledJob]) async {
        let jobs = builder(self)
        
        await withTaskGroup(of: Job.self) { group in
            
            for job in jobs {
                group.addTask {
                    return await self.schedule(job)
                }
            }
            
            _ = await group.next()
        }
        
        await self.waitUntilIdle()
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
            
            // Execute the job action outside the actor so a long-running or
            // awaiting action doesn't block the scheduler's actor executor and
            // prevent other job loops from making progress.
            // The action will mark the job finished when it completes.
            self.runJobAction(scheduledJob)
            
            guard !Task.isCancelled else { break }
            
            if jobStates[job] == .cancelled { break }
            
            // Note: we no longer call `markJobFinished` inline here because
            // the detached task running the action is responsible for calling
            // it when the action completes.
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
    
    // run job action off the actor so the actor isn't blocked
    private func runJobAction(_ scheduledJob: ScheduledJob) {
        let job = scheduledJob.job
        Task.detached { [scheduledJob] in
            try? await scheduledJob.action(job)
            await self.markJobFinished(job)
        }
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
