//
//  ScheduleKind+Error.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 02/12/2025.
//

import Foundation

public extension Schedule.Kind {

    enum Error: Swift.Error, Sendable {
        case invalidDate(Date?, kind: Schedule.Kind)
    }
}

extension Schedule.Kind.Error: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .invalidDate(let date, _):
            if let date {
                return "The date \(date.formatted(date: .numeric, time: .complete)) is invalid."
            } else {
                return "The date is invalid."
            }
        }
    }
}
