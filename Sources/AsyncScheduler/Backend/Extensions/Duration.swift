//
//  Duration.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 02/12/2025.
//

import Foundation

internal extension Duration {
    
    var nanosecondsApprox: UInt64 {
        let comps = self.components
        
        let secondsAsDouble = Double(comps.seconds)
        let attosecondsAsDouble = Double(comps.attoseconds)
        
        let nanos = secondsAsDouble * 1_000_000_000.0 + attosecondsAsDouble * 1e-9
        if !nanos.isFinite || nanos <= 0.0 { return 0 }
        
        let rounded = nanos.rounded()
        if rounded >= Double(UInt64.max) { return UInt64.max }
        
        return UInt64(rounded)
    }
}
