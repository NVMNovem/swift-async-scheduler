//
//  Scheduler.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

import Foundation
import AsyncObserver

public actor Scheduler: AsyncObservable {
    
    public let id: UUID
    
    public var asyncObservers: [AsyncObserver<[JobEntry]>] = []

    internal private(set) var jobs: [JobEntry] {
        willSet {
            let currentJobs = Set(jobs.map { $0.schedulerJob.job })
            let updatedJobs = Set(newValue.map { $0.schedulerJob.job })
            let removedJobs = currentJobs.subtracting(updatedJobs)
            if !removedJobs.isEmpty {
                if newValue.isEmpty {
                    print("[Scheduler] All jobs removed; scheduler is now idle.")
                } else {
                    print("[Scheduler] Removed jobs: \(removedJobs.map({ $0.description }).joined(separator: ", "))" )
                }
            }
        }
        didSet {
            notifyAsyncObservers(jobs)
        }
    }
    
    // For cron schedules, keep an anchored "next scheduled" date per job.
    // This prevents late wakeups or execution time from shifting the schedule.
    private var cronNextRunDate: [Job : Date]
    
    private var idleContinuation: CheckedContinuation<Void, Never>? = nil

    private func index(of job: Job) -> Int? {
        jobs.firstIndex(where: { $0.schedulerJob.job == job })
    }
    
    public init() {
        self.id = UUID()
        
        self.jobs = []
        self.cronNextRunDate = [:]
    }
    
    @discardableResult
    private func schedule(_ schedulerJob: SchedulerJob) -> Job {
        let task = Task {
            await self.execute(schedulerJob)
        }

        let job = schedulerJob.job
        jobs.append(JobEntry(from: schedulerJob, task: task))

        return job
    }
    
    public func jobState(for job: Job) -> JobState {
        guard let jobIndex = index(of: job) else { return .idle }
        return jobs[jobIndex].state
    }
}

extension Scheduler: Sendable {}

extension Scheduler: Identifiable {}

// MARK: - Scheduling Jobs
public extension Scheduler {

    /// Creates a fresh scheduler instance, builds jobs, schedules them, and suspends until the scheduler is idle.
    ///
    /// This is a *convenience method* for one-off execution without needing to manually instantiate an
    /// `Scheduler`. It is especially useful in tests and short-lived command flows where you want
    /// a clean scheduler instance and to await completion.
    ///
    /// The builder receives the newly created scheduler so you can reference it while constructing jobs.
    ///
    /// - Parameter builder: A closure that receives the newly created scheduler and returns the jobs to schedule.
    /// - Note: This method returns only after all jobs scheduled by the builder have completed and the scheduler
    ///   has become idle.
    static func scheduleAndWait(
        @SchedulerJobBuilder _ builder: @Sendable (Scheduler) -> [SchedulerJob]
    ) async {
        let scheduler = Scheduler()
        await scheduler.scheduleAndWait {
            builder(scheduler)
        }
    }

    /// Executes the scheduler with jobs provided by the given builder and suspends until all jobs have completed.
    ///
    /// This method constructs one or more `SchedulerJob` instances using the provided builder closure,
    /// schedules them for execution, and then suspends until the scheduler becomes fully idle (i.e. all
    /// scheduled jobs have finished and no jobs are currently running).
    ///
    /// Each job is scheduled as a separate asynchronous task. After all jobs have been scheduled, this method
    /// waits for the scheduler to reach a quiescent state before returning.
    ///
    /// - Parameter builder: A closure that returns one or more `SchedulerJob`s.
    /// - Note: This method returns only after all jobs scheduled by the builder have completed and the scheduler
    ///   has become idle.
    func scheduleAndWait(
        @SchedulerJobBuilder _ schedulerJobsBuilder: @Sendable () -> [SchedulerJob]
    ) async {
        let schedulerJobs = schedulerJobsBuilder()

        await withTaskGroup(of: Job.self) { group in
            for schedulerJob in schedulerJobs {
                group.addTask {
                    await self.schedule(schedulerJob)
                }
            }

            // Ensure at least one task is awaited so scheduling begins before we wait for idle.
            _ = await group.next()
        }

        await self.waitUntilIdle()
    }

    /// Executes the scheduler for a variadic list of jobs and suspends until all jobs have completed.
    ///
    /// This is a *convenience method* that forwards to ``scheduleAndWait(_:)`` using a variadic parameter list.
    ///
    /// - Parameter schedulerJobs: One or more jobs to schedule.
    /// - Note: This method returns only after all jobs have completed and the scheduler is idle.
    func scheduleAndWait(_ schedulerJobs: SchedulerJob...) async {
        await scheduleAndWait {
            schedulerJobs
        }
    }

    /// Executes the scheduler for an array of jobs and suspends until all jobs have completed.
    ///
    /// This is a *convenience method* that forwards to ``scheduleAndWait(_:)`` using an explicit array.
    ///
    /// - Parameter schedulerJobs: The jobs to schedule.
    /// - Note: This method returns only after all jobs have completed and the scheduler is idle.
    func scheduleAndWait(_ schedulerJobs: [SchedulerJob]) async {
        await scheduleAndWait {
            schedulerJobs
        }
    }

    /// Creates a fresh scheduler instance and executes running jobs built by the given closure without awaiting completion.
    ///
    /// This is a *convenience method* for fire-and-forget usage where you don’t want to manage a scheduler instance.
    /// It starts an asynchronous task that schedules the jobs and returns immediately.
    ///
    /// - Parameter builder: A closure that receives the newly created scheduler and returns the jobs to schedule.
    /// - Important: This method does not wait for job completion.
    ///   If you need to await completion, use ``scheduleAndWait(_:)`` instead.
    static func schedule(
        @SchedulerJobBuilder _ schedulerJobsBuilder: @escaping @Sendable (Scheduler) -> [SchedulerJob]
    ) async {
        let scheduler = Scheduler()
        
        await scheduler.schedule {
            schedulerJobsBuilder(scheduler)
        }
    }

    /// Schedules and runs jobs defined by a builder closure as detached asynchronous tasks.
    ///
    /// This method constructs one or more `SchedulerJob` instances using the provided builder closure,
    /// schedules them for execution, and returns immediately without waiting for their completion.
    ///
    /// Jobs are scheduled from a detached task, allowing them to run independently of the caller.
    ///
    /// - Parameter builder: A closure that returns one or more jobs to schedule.
    /// - Important: This method does not wait for job completion.
    ///   If you need to await completion, use ``scheduleAndWait(_:)`` instead.
    func schedule(
        @SchedulerJobBuilder _ schedulerJobsBuilder: @escaping @Sendable () -> [SchedulerJob]
    ) {
        Task.detached {
            let schedulerJobs = schedulerJobsBuilder()

            await withTaskGroup(of: Job.self) { group in
                for schedulerJob in schedulerJobs {
                    group.addTask {
                        await self.schedule(schedulerJob)
                    }
                }

                // Ensure at least one task is awaited so scheduling begins.
                _ = await group.next()
            }
        }
    }

    /// Schedules and runs a variadic list of jobs without awaiting completion.
    ///
    /// This is a *convenience method* that forwards to ``schedule(_:)`` using a variadic parameter list.
    ///
    /// - Parameter schedulerJobs: One or more jobs to schedule.
    /// - Important: This method does not wait for job completion.
    ///   If you need to await completion, use ``scheduleAndWait(_:)`` instead.
    func schedule(_ schedulerJobs: SchedulerJob...) {
        schedule {
            schedulerJobs
        }
    }

    /// Schedules and runs an array of jobs without awaiting completion.
    ///
    /// This is a *convenience method* that forwards to ``schedule(_:)`` using an explicit array.
    ///
    /// - Parameter schedulerJobs: The jobs to schedule.
    /// - Important: This method does not wait for job completion.
    ///   If you need to await completion, use ``scheduleAndWait(_:)`` instead.
    func schedule(_ schedulerJobs: [SchedulerJob]) {
        schedule {
            schedulerJobs
        }
    }
}

// MARK: - Executing Jobs
public extension Scheduler {
    
    func run(_ schedulerJob: SchedulerJob) {
        let job = schedulerJob.job
        
        self.markJobExecuting(job)
        
        Task.detached { [schedulerJob] in
            try? await schedulerJob.action(job)
            
            await self.markJobFinished(job)
        }
    }
    
    func run(_ job: Job) {
        guard let jobIndex = index(of: job) else { return }
        let schedulerJob = jobs[jobIndex].schedulerJob
        
        run(schedulerJob)
    }
}

// MARK: - Cancelling Jobs
public extension Scheduler {
    
    func cancel(_ schedulerJob: SchedulerJob) async {
        await cancel(schedulerJob.job)
    }
    
    func cancel(_ job: Job) async {
        guard let jobIndex = index(of: job) else {
            // Ensure cron state is cleaned up even if the task entry is missing.
            cronNextRunDate.removeValue(forKey: job)
            resumeIfIdle()
            return
        }

        // Mark cancelled first so the running loop can observe it.
        jobs[jobIndex].state = .finished(.cancelled)

        // Snapshot the entry before we remove it from `jobs`.
        let entry = jobs[jobIndex]

        await cancelAndAwait(
            entries: [entry],
            removeJobs: { self.jobs.remove(at: jobIndex) },
            cleanupCron: { self.cronNextRunDate.removeValue(forKey: job) }
        )
    }
    
    func cancelAll() async {
        let entries = jobs

        // Mark all jobs cancelled first so the running loops can observe it.
        for jobIndex in jobs.indices {
            jobs[jobIndex].state = .finished(.cancelled)
        }

        await cancelAndAwait(
            entries: entries,
            removeJobs: { self.jobs.removeAll() },
            cleanupCron: { self.cronNextRunDate.removeAll() }
        )
    }
}

private extension Scheduler {
    
    func execute(_ schedulerJob: SchedulerJob) async {
        let job = schedulerJob.job
        
        // Run the job loop inline in the Task that called `execute(_:)`.
        // This ensures the Task stored in `jobs` is the actual running task
        // and that cancelling it via `cancel(_:)` will stop the loop immediately.
        while !Task.isCancelled {
            // If the job was cancelled via actor state, stop.
            if jobState(for: job).isCancelled() { break }
            
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
            
            if jobState(for: job).isCancelled() { break }
            
            if self.isJobRunning(job) {
                switch schedulerJob.overrunPolicy {
                case .skip:
                    if let cron = cronExpression, let due = cronDue {
                        if let next = try? cron.nextDate(after: due) {
                            cronNextRunDate[job] = next
                        }
                    }
                    continue
                case .wait:
                    while self.isJobRunning(job) && !Task.isCancelled {
                        try? await self.sleep(for: .milliseconds(10))
                    }
                case .overlap:
                    break //TODO: Allow overlapping executions
                }
            }
            
            if jobState(for: job).isCancelled() { break }
            
            if let cron = cronExpression, let due = cronDue {
                if let next = try? cron.nextDate(after: due) {
                    cronNextRunDate[job] = next
                }
            }
            
            self.run(schedulerJob)
            
            guard !Task.isCancelled else { break }
            
            if jobState(for: job) == .finished(.cancelled) { break }
        }
        
        // Final cleanup in case of cancellation
        self.removeTaskAndFinish(job)
    }
    
    func cancelAndAwait(
        entries: [JobEntry],
        removeJobs: () -> Void,
        cleanupCron: () -> Void
    ) async {
        // Cancel the underlying tasks.
        for entry in entries {
            entry.task.cancel()
        }

        // Remove entries from our list so `waitUntilIdle()` can complete.
        removeJobs()

        // Await task completion.
        for entry in entries {
            _ = await entry.task.value
        }

        cleanupCron()
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
    func waitUntilIdle() async {
        if jobs.isEmpty { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            idleContinuation = continuation
        }
    }
    
    func isJobRunning(_ job: Job) -> Bool {
        guard let idx = index(of: job) else { return false }
        return jobs[idx].state == .executing
    }

    func markJobRunning(_ job: Job) {
        guard let idx = index(of: job) else { return }
        jobs[idx].state = .running
    }

    func markJobExecuting(_ job: Job) {
        guard let idx = index(of: job) else { return }
        jobs[idx].state = .executing
    }

    func markJobFinished(_ job: Job) {
        guard let idx = index(of: job) else { return }
        if case .finished = jobs[idx].state { return }
        jobs[idx].state = .running
    }

    func removeTaskAndFinish(_ job: Job) {
        if let idx = index(of: job) {
            jobs[idx].state = .finished(.cancelled)
            jobs.remove(at: idx)
        }

        cronNextRunDate.removeValue(forKey: job)
        resumeIfIdle()
    }
    
    func resumeIfIdle() {
        if jobs.isEmpty {
            print("Scheduler: Scheduler is now idle; resuming waiters.")
            idleContinuation?.resume()
            idleContinuation = nil
        }
    }
    
    func cronDueDate(for schedulerJob: SchedulerJob) throws -> (CronExpression, Date) {
        guard case .cron(let expression, let timeZone) = schedulerJob.schedule.kind else {
            throw NSError(domain: "Scheduler", code: 1)
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

fileprivate extension Scheduler {
    
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
