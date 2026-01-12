//
//  Kind.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 07/01/2026.
//

import Foundation

extension Schedule {
    
    public enum Kind: Codable {
        
        case interval(Duration)
        case daily(hour: Int, minute: Int, timeZone: TimeZone = .current)
        case weekly(dayOfWeek: Int, hour: Int, minute: Int, timeZone: TimeZone = .current)
        case monthly(dayOfMonth: Int, hour: Int, minute: Int, timeZone: TimeZone = .current)
        case cron(String, timeZone: TimeZone = .current)
    }
}

extension Schedule.Kind: Sendable {}

internal extension Schedule.Kind {
    
    var sleep: Duration {
        get throws {
            switch self {
            case .interval(let duration):
                return duration
            case .daily(let hour, let minute, let timeZone):
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = timeZone
                
                let now = Date()
                
                guard let scheduledToday = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now)
                else { throw Error.invalidDate(nil, kind: self) }
                
                let target = scheduledToday > now
                ? scheduledToday
                : calendar.date(byAdding: .day, value: 1, to: scheduledToday) ?? now.addingTimeInterval(60)
                
                let interval = target.timeIntervalSince(now)
                return .seconds(Int(max(0, interval).rounded(.up)))
            case .weekly(_, _, _, _):
                return .seconds(60) // TODO: Implement weekly schedule
            case .monthly(_, _, _, _):
                return .seconds(60) // TODO: Implement monthly schedule
            case .cron(let expression, let timeZone):
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = timeZone
                
                let now = Date()
                let cron = try CronExpression(expression, calendar: calendar)
                let next = try cron.nextDate(after: now)
                let interval = max(0, next.timeIntervalSince(now))
                let nanos = Int64(interval * 1_000_000_000)
                return .nanoseconds(nanos)
            }
        }
    }
}
