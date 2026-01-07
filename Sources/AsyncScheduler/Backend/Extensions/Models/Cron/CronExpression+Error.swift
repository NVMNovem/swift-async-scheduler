//
//  CronExpression+Error.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 07/01/2026.
//

import Foundation

public extension CronExpression {
    
    enum Error: Swift.Error, Sendable {
        case invalidField
    }
}

extension CronExpression.Error: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .invalidField:
            return "The cron expression has an invalid field."
        }
    }
}
