//
//  CronField.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 07/01/2026.
//

public struct CronField {

    let values: [Int]
    let isAny: Bool
    private let lookup: [Bool]

    init(
        _ field: Substring,
        min: Int,
        max: Int,
        map: (Substring) -> Int?
    ) throws {
        guard min <= max else { throw CronExpression.Error.invalidField }

        var present = Array(repeating: false, count: max + 1)
        let parts = field.split(separator: ",", omittingEmptySubsequences: true)
        guard !parts.isEmpty else { throw CronExpression.Error.invalidField }

        for part in parts {
            let stepParts = part.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
            let base = stepParts[0]
            let stepValue: Int
            if stepParts.count == 2 {
                guard let step = Int(stepParts[1]), step > 0
                else { throw CronExpression.Error.invalidField }
                stepValue = step
            } else {
                stepValue = 1
            }

            let range: ClosedRange<Int>
            if base == "*" || base == "?" {
                range = min...max
            } else if let dashIndex = base.firstIndex(of: "-") {
                let startToken = base[..<dashIndex]
                let endToken = base[base.index(after: dashIndex)...]
                guard let startValue = map(startToken), let endValue = map(endToken), startValue <= endValue
                else { throw CronExpression.Error.invalidField }
                
                range = startValue...endValue
            } else {
                guard let value = map(base) else { throw CronExpression.Error.invalidField }
                
                range = value...value
            }

            guard range.lowerBound >= min, range.upperBound <= max
            else { throw CronExpression.Error.invalidField }

            var value = range.lowerBound
            while value <= range.upperBound {
                present[value] = true
                value += stepValue
            }
        }

        var collected: [Int] = []
        collected.reserveCapacity(max - min + 1)
        for value in min...max where present[value] {
            collected.append(value)
        }

        guard !collected.isEmpty else { throw CronExpression.Error.invalidField }

        self.values = collected
        self.isAny = collected.count == (max - min + 1)
        self.lookup = present
    }

    func contains(_ value: Int) -> Bool {
        guard value >= 0 && value < lookup.count else { return false }
        
        return lookup[value]
    }
}
