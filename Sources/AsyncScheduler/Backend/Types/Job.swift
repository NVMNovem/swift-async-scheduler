//
//  Job.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 14/01/2026.
//

import Foundation

public struct Job: ExpressibleByStringLiteral {
    
    public let id: SchedulerJob.ID
    
    public init(stringLiteral value: String) {
        self.id = UUID(uuidString: value) ?? UUID()
    }
    
    public init(id: SchedulerJob.ID) {
        self.id = id
    }
    
    public init?(name: String, scheduler: Scheduler) async {
        guard let jobEntry = await scheduler.jobs.first(where: { $0.schedulerJob.name == name })
        else { return nil }
        
        self.id = jobEntry.schedulerJob.id
    }
}

extension Job: Sendable {}

extension Job: Equatable, Hashable, Identifiable {}

extension Job: CustomStringConvertible {
    
    public var description: String {
        id.uuidString
    }
}
