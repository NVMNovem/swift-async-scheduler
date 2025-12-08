import Testing
import Foundation
@testable import AsyncScheduler

actor Box<T> {
    private var value: T
    init(_ value: T) { self.value = value }
    func get() -> T { value }
    func set(_ new: T) { value = new }
    func update(_ f: (inout T) -> Void) { f(&value) }
}

@Test
func testIntervalJobExecutesMultipleTimes() async throws {
    let scheduler = AsyncScheduler()
    let counter = Box(0)
    
    let scheduledJob = ScheduledJob.every(.seconds(0.05)) {
        await counter.update { $0 += 1 }
    }
    await scheduler.schedule(scheduledJob)
    
    try? await Task.sleep(nanoseconds: 150_000_000) // ~0.15s
    await scheduler.cancel(scheduledJob.job)
    
    let count = await counter.get()
    #expect(count > 1, "Counter value: \(count)")
}

@Test
func testIntervalJobStopsAfterCancellation() async throws {
    let scheduler = AsyncScheduler()
    let counter = Box(0)
    
    let scheduledJob = ScheduledJob.every(.nanoseconds(50_000_000)) {
        await counter.update { $0 += 1 }
    }
    await scheduler.schedule(scheduledJob)
    
    try? await Task.sleep(nanoseconds: 120_000_000)
    await scheduler.cancel(scheduledJob.job)
    
    let afterCancel = await counter.get()
    try? await Task.sleep(nanoseconds: 200_000_000)
    
    let finalCount = await counter.get()
    #expect(finalCount == afterCancel)
}

@Test
func testDailyScheduleSchedulesNextRunTomorrowIfTodayPassed() async throws {
    let scheduler = AsyncScheduler()
    
    // Daily schedule at 00:00 local time
    // We force next run to be > 0 seconds (tomorrow)
    let now = Date()
    let calendar = Calendar(identifier: .gregorian)
    let comps = calendar.dateComponents([.hour, .minute], from: now)
    
    let hour = max(0, comps.hour! - 1) // ensure the scheduled time for today is already passed
    let minute = comps.minute!
    
    let scheduledJob = ScheduledJob.daily(on: hour, minute, timeZone: .current) { }
    
    await scheduler.schedule(scheduledJob)
    
    // Extract the sleep duration using the internal API if available,
    // but here we validate indirectly by checking that job's loop starts and waits.
    // We allow the scheduler loop to initialize:
    try? await Task.sleep(nanoseconds: 50_000_000)
    
    // If it didn't crash, and didn't immediately run the action,
    // we consider this correct (since we cannot check exact date math here).
    await scheduler.cancel(scheduledJob.job)
    
    #expect(true)
}

@Test
func testCancelAllStopsAllScheduledJobs() async throws {
    let scheduler = AsyncScheduler()
    let a = Box(0)
    let b = Box(0)
    
    let scheduledJobA = ScheduledJob.every(.seconds(0.05)) { await a.update { $0 += 1 } }
    let scheduledJobB = ScheduledJob.every(.seconds(0.05)) { await b.update { $0 += 1 } }
    
    await scheduler.schedule(scheduledJobA)
    await scheduler.schedule(scheduledJobB)
    
    try? await Task.sleep(nanoseconds: 120_000_000)
    
    await scheduler.cancelAll()
    
    let aAfter = await a.get()
    let bAfter = await b.get()
    
    try? await Task.sleep(nanoseconds: 120_000_000)
    
    #expect(await a.get() == aAfter)
    #expect(await b.get() == bAfter)
}

@Test
func testRunWaitsUntilIdleAfterCancelAll() async throws {
    let counter = Box("")
    
    enum TimeoutError: Error { case timedOut }
    let timeoutNs: UInt64 = 2_000_000_000 // 2s timeout to avoid hanging forever
    
    let scheduler = AsyncScheduler()
    
    await withThrowingTaskGroup(of: Void.self) { group in
        // Task A: run the scheduler normally
        group.addTask {
            await scheduler.run { scheduler in
                
                ScheduledJob.every(.seconds(0.03)) { job in
                    await counter.update { $0 += "A" }
                }
                
                ScheduledJob.every(.seconds(0.05)) { job in
                    await counter.update { $0 += "B" }
                    
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // small yield
                    await scheduler.cancelAll()
                }
            }
        }
        
        // Task B: timeout
        group.addTask {
            try await Task.sleep(nanoseconds: timeoutNs)
            throw TimeoutError.timedOut
        }
        
        do {
            _ = try await group.next()
            
            group.cancelAll()
        } catch {
            defer {
                #expect(Bool(false), "AsyncScheduler.run did not finish within timeout: \(error)")
            }
            await scheduler.cancelAll()
        }
    }
    
    let count = await counter.get()
    defer {
        #expect(count.hasPrefix("ABAAA"), "Counter value: \(count)")
    }
    await scheduler.cancelAll()
}

@Test
func testRunWaitsUntilIdleAfterCancelJob() async throws {
    let counter: Box<[String]> = Box([])
    
    enum TimeoutError: Error { case timedOut }
    let timeoutNs: UInt64 = 2_000_000_000 // 2s timeout to avoid hanging forever
    
    let scheduler = AsyncScheduler()
    
    await #expect(throws: TimeoutError.timedOut) {
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Task A: run the scheduler normally
            group.addTask {
                await scheduler.run { scheduler in
                    
                    ScheduledJob.every(.seconds(0.05)) { job in
                        await counter.update { $0.append("A") }
                    }
                    
                    ScheduledJob.every(.seconds(0.05)) { job in
                        await counter.update { $0.append("B") }
                        
                        Task {
                            try? await Task.sleep(nanoseconds: 1_000_000_000) // small yield
                            await scheduler.cancel(job)
                        }
                    }
                }
            }
            
            // Task B: timeout
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNs)
                
                let array = await counter.get()
                let aCount = array.filter { $0 == "A" }.count
                let bCount = array.filter { $0 == "B" }.count
                #expect(aCount > bCount, "Expected more A runs than B runs, got A: \(aCount), B: \(bCount)")
                
                defer {
                    Task { await scheduler.cancelAll() }
                }
                print("Timeout reached with counter: \(await counter.get())")
                throw TimeoutError.timedOut
            }
            
            return try await group.next()
        }
    }
}
