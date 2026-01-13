//
//  AsyncScheduler.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

import Foundation

public actor AsyncScheduler: Sendable, Identifiable {
    
    public let id: UUID
    
    /// A Sendable identifier for a scheduled job.
    /// Used to reference scheduled jobs when cancelling them.
    public typealias Job = SchedulerJob.ID
    
    private var tasks: [Job : Task<Void, Never>]
    private var jobStates: [Job : JobState]
    
    // For cron schedules, keep an anchored "next scheduled" date per job.
    // This prevents late wakeups or execution time from shifting the schedule.
    private var cronNextRunDate: [Job : Date]
    
    private var idleContinuation: CheckedContinuation<Void, Never>? = nil
    
    public init() {
        self.id = UUID()
        
        self.tasks = [:]
        self.jobStates = [:]
        self.cronNextRunDate = [:]
    }
    
    @discardableResult
    internal func schedule(_ schedulerJob: SchedulerJob) -> Job {
        let task = Task {
            await self.execute(schedulerJob)
        }

        let job = schedulerJob.job
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
        cronNextRunDate.removeValue(forKey: job)
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
        cronNextRunDate.removeAll()
        resumeIfIdle()
    }
    
    /// Suspends the current task until all scheduled jobs have completed and the scheduler becomes idle.
    ///
    /// This method returns immediately if there are no running or scheduled jobs.
    /// Otherwise, it suspends the caller using a checked continuation and resumes only when all active jobs
    /// have finished executing and the internal scheduler state is idle.
    ///
    /// Use this to await for complete quiescence of the scheduler, for example when shutting down or testing.
    ///
    /// - Note: If a job is added after calling `waitUntilIdle()`, this method does not wait for newly
    ///         scheduled jobs. It only waits for jobs that were running or scheduled at the time of the call.
    ///
    public func waitUntilIdle() async {
        if tasks.isEmpty { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            idleContinuation = continuation
        }
    }
}

public extension AsyncScheduler {
    
    /// Executes the scheduler with jobs provided by the given builder and suspends until all jobs have completed.
    ///
    /// This method constructs one or more `SchedulerJob` instances using the provided builder closure,
    /// schedules them for execution, and then suspends until the scheduler becomes fully idle, meaning
    /// all scheduled jobs have finished and no jobs are currently running.
    ///
    /// The builder receives the scheduler instance and returns an array of jobs to schedule.
    /// Each job is scheduled as a separate asynchronous task. The method then immediately waits
    /// for all jobs to be scheduled and for the scheduler to reach a quiescent state before returning.
    ///
    /// - Parameter builder: A closure that receives the scheduler and returns one or more `SchedulerJob`s.
    ///
    /// - Note: This method is `async` and will only return after all jobs scheduled by the builder have completed.
    ///         It is typically used in contexts where you want to synchronously await the lifecycle of the scheduled jobs,
    ///         such as in tests or coordinated shutdown flows.
    func execute(@SchedulerJobBuilder _ builder: @Sendable (AsyncScheduler) -> [SchedulerJob]) async {
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
    
    /// Schedules and runs jobs defined by a builder closure as detached asynchronous tasks.
    ///
    /// This method constructs one or more `SchedulerJob` instances using the provided builder closure,
    /// schedules them for execution, and immediately returns without waiting for their completion.
    /// The jobs are scheduled and executed in the background using a detached `Task`, which allows
    /// them to run independently of the caller.
    ///
    /// Use this method when you want to fire off jobs and allow them to run asynchronously,
    /// without blocking the current context or waiting for their results.
    ///
    /// - Parameter builder: A closure that receives the scheduler and returns an array of `SchedulerJob`s to schedule.
    ///                      This closure is executed on a background task.
    ///
    /// - Note: Scheduled jobs will run according to their individual schedules and will not block the caller.
    ///         If you need to wait for all jobs to complete before proceeding, consider using `execute(_:)` instead.
    func run(@SchedulerJobBuilder _ builder: @escaping @Sendable (AsyncScheduler) -> [SchedulerJob]) {
        Task.detached {
            let jobs = builder(self)
            
            await withTaskGroup(of: Job.self) { group in
                
                for job in jobs {
                    group.addTask {
                        return await self.schedule(job)
                    }
                }
                
                _ = await group.next()
            }
        }
    }
}

private extension AsyncScheduler {
    
    func execute(_ schedulerJob: SchedulerJob) async {
        let job = schedulerJob.job
        
        // Run the job loop inline in the Task that called `execute(_:)`.
        // This ensures the Task stored in `tasks` is the actual running task
        // and that cancelling it via `cancel(_:)` will stop the loop immediately.
        while !Task.isCancelled {
            // If the job was cancelled via actor state, stop.
            if jobStates[job] == .cancelled { break }
            
            var cronDue: Date?
            var cronExpression: CronExpression?
            if case .cron = schedulerJob.schedule.kind {
                if let (cron, due) = try? cronDueDate(for: schedulerJob) {
                    cronExpression = cron
                    cronDue = due
                    try? await self.sleepUntil(due)
                }
            } else {
                try? await self.sleep(for: nextSleepDuration(for: schedulerJob))
            }
            
            guard !Task.isCancelled else { break }
            
            if jobStates[job] == .cancelled { break }
            
            if await self.isJobRunning(job) {
                switch schedulerJob.overrunPolicy {
                case .skip:
                    if let cron = cronExpression, let due = cronDue {
                        if let next = try? cron.nextDate(after: due) {
                            cronNextRunDate[job] = next
                        }
                    }
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
            
            if let cron = cronExpression, let due = cronDue {
                if let next = try? cron.nextDate(after: due) {
                    cronNextRunDate[job] = next
                }
            }
            await self.markJobRunning(job)
            
            // Execute the job action outside the actor so a long-running or
            // awaiting action doesn't block the scheduler's actor executor and
            // prevent other job loops from making progress.
            // The action will mark the job finished when it completes.
            self.runJobAction(schedulerJob)
            
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
        cronNextRunDate.removeValue(forKey: job)
        resumeIfIdle()
    }
    
    // run job action off the actor so the actor isn't blocked
    private func runJobAction(_ schedulerJob: SchedulerJob) {
        let job = schedulerJob.job
        Task.detached { [schedulerJob] in
            try? await schedulerJob.action(job)
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
    
    func cronDueDate(for schedulerJob: SchedulerJob) throws -> (CronExpression, Date) {
        guard case .cron(let expression, let timeZone) = schedulerJob.schedule.kind else {
            throw NSError(domain: "AsyncScheduler", code: 1)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let cron = try CronExpression(expression, calendar: calendar)

        if let existing = cronNextRunDate[schedulerJob.job] {
            return (cron, existing)
        }

        let due = try cron.nextDate(after: Date())
        cronNextRunDate[schedulerJob.job] = due
        return (cron, due)
    }
    
    func nextSleepDuration(for schedulerJob: SchedulerJob) throws -> Duration {
        switch schedulerJob.schedule.kind {
        case .cron:
            let (_, due) = try cronDueDate(for: schedulerJob)
            let interval = max(0, due.timeIntervalSince(Date()))
            let ns = UInt64((interval * 1_000_000_000).rounded(.up))
            return .nanoseconds(ns)

        default:
            return try schedulerJob.schedule.sleep
        }
    }
}

fileprivate extension AsyncScheduler {
    
    func sleep(for duration: Duration) async throws {
        let ns = duration.nanosecondsApprox
        try await Task.sleep(nanoseconds: ns)
    }

    /// Sleep until a concrete wall-clock deadline using corrective looping.
    func sleepUntil(_ deadline: Date) async throws {
        while true {
            let now = Date()
            if now >= deadline { return }

            let remaining = deadline.timeIntervalSince(now)
            let chunk = min(remaining, 0.25)
            let ns = UInt64((chunk * 1_000_000_000).rounded(.up))
            try await Task.sleep(nanoseconds: ns)
        }
    }
}
