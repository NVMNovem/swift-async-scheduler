//
//  Schedule.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

import Foundation

public struct Schedule: Codable {

    public let kind: Kind
    
    public init(_ kind: Kind) {
        self.kind = kind
    }
    
    public enum Kind: Codable {
        
        case interval(Duration)
        case daily(hour: Int, minute: Int, timeZone: TimeZone = .current)
        case cron(String)
    }
}

extension Schedule: Sendable {}
extension Schedule.Kind: Sendable {}


internal extension Schedule {
    
    var sleep: Duration {
        get throws {
            try kind.sleep
        }
    }
}
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
            case .cron(_):
                return .seconds(60) // TODO: Implement cron job
            }
        }
    }
}

extension Schedule {
    
    public static func interval(_ duration: Duration) -> Schedule {
        Schedule(.interval(duration))
    }
    
    public static func daily(hour: Int, minute: Int, timeZone: TimeZone = .current) -> Schedule {
        Schedule(.daily(hour: hour, minute: minute, timeZone: timeZone))
    }
    
    public static func cron(_ expression: String) -> Schedule {
        Schedule(.cron(expression))
    }
}
