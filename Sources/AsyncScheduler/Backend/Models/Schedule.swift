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
}

extension Schedule: Sendable {}

internal extension Schedule {
    
    var sleep: Duration {
        get throws {
            try kind.sleep
        }
    }
}

extension Schedule {
    
    public static func kind(_ kind: Kind) -> Schedule {
        Schedule(kind)
    }
    
    public static func interval(_ duration: Duration) -> Schedule {
        Schedule(.interval(duration))
    }
    
    public static func daily(hour: Int, minute: Int, timeZone: TimeZone = .current) -> Schedule {
        Schedule(.daily(hour: hour, minute: minute, timeZone: timeZone))
    }
    
    public static func cron(_ expression: String, timeZone: TimeZone = .current) -> Schedule {
        Schedule(.cron(expression, timeZone: timeZone))
    }
}
