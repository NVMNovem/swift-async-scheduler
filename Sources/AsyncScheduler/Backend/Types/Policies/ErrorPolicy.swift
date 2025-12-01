//
//  ErrorPolicy.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

public enum ErrorPolicy {
    
    case ignore
    case stop
    case retry(backoff: Duration)
}

extension ErrorPolicy: Sendable {}
