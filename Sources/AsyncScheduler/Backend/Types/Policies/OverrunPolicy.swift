//
//  OverrunPolicy.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 01/12/2025.
//

public enum OverrunPolicy {
    
    case skip
    case wait
    case overlap
}

extension OverrunPolicy: Sendable {}
