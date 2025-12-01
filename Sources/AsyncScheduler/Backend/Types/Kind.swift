//
//  Kind.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

import Foundation

public enum Kind {
    
    case interval(Duration)
    case daily(hour: Int, minute: Int, timeZone: TimeZone = .current)
    case cron(String)
}

extension Kind: Sendable {}

internal extension Kind {
    
    var sleep: Duration {
        switch self {
        case .interval(let duration):
            return duration
        case .daily(let hour, let minute, _):
            return .seconds(hour * 3600 + minute * 60)
        case .cron(_):
            return .seconds(60) //TODO: Implement cron job
        }
    }
}
