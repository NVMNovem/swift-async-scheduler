import Testing
@testable import AsyncScheduler

@Test
func testIntervalJobRunsMultipleTimes() async throws {
    let clock = TestClock()
    let scheduler = AsyncScheduler(clock: clock)
    
    let counter = Counter()
    
    await scheduler.every(.seconds(5)) {
        await counter.increment()
    }
    
    #expect(await counter.value == 0)
    
    await clock.advance(by: .seconds(5))
    #expect(await counter.value == 1)
    
    await clock.advance(by: .seconds(5))
    #expect(await counter.value == 2)
    
    await clock.advance(by: .seconds(10))
    #expect(await counter.value == 4)
}


fileprivate actor Counter {
    private(set) var value = 0
    
    func increment() {
        value += 1
    }
}
