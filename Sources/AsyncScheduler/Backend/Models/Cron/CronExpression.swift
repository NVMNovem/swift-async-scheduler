//
//  CronExpression.swift
//  swift-async-scheduler
//
//  Created by Damian Van de Kauter on 07/01/2026.
//

import Foundation

public struct CronExpression {
    
    private let expression: String
    
    private let seconds: CronField
    private let minutes: CronField
    private let hours: CronField
    private let daysOfMonth: CronField
    private let months: CronField
    private let daysOfWeek: CronField
    
    private let calendar: Calendar
    
    public init(_ expression: String, calendar: Calendar) throws {
        let parts = expression.split { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" }
        let normalized: [Substring]
        if parts.count == 5 {
            normalized = [Substring("0")] + parts
        } else {
            normalized = parts
        }
        guard normalized.count == 6
        else { throw Error.invalidField }
        
        self.expression = expression
        self.seconds = try CronField(normalized[0], min: 0, max: 59, map: parseNumber)
        self.minutes = try CronField(normalized[1], min: 0, max: 59, map: parseNumber)
        self.hours = try CronField(normalized[2], min: 0, max: 23, map: parseNumber)
        self.daysOfMonth = try CronField(normalized[3], min: 1, max: 31, map: parseNumber)
        self.months = try CronField(normalized[4], min: 1, max: 12, map: parseMonth)
        self.daysOfWeek = try CronField(normalized[5], min: 1, max: 7, map: parseDayOfWeek)
        
        self.calendar = calendar
    }
    
    func nextDate(after date: Date) throws -> Date {
        guard let start = calendar.date(byAdding: .second, value: 1, to: date)
        else { throw Schedule.Kind.Error.invalidDate(date, kind: .cron(expression)) }
        
        let end = calendar.date(byAdding: .year, value: 10, to: start) ?? start.addingTimeInterval(10 * 365 * 24 * 60 * 60)
        var candidate = start
        
        let minSecond = seconds.values[0]
        let minMinute = minutes.values[0]
        let minHour = hours.values[0]
        
        while candidate <= end {
            var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday], from: candidate)
            guard
                let year = comps.year,
                let month = comps.month,
                let day = comps.day,
                let hour = comps.hour,
                let minute = comps.minute,
                let second = comps.second,
                let weekday = comps.weekday
            else { throw Schedule.Kind.Error.invalidDate(candidate, kind: .cron(expression)) }
            
            if !months.contains(month) {
                let nextMonth = nextValue(atOrAfter: month, in: months.values) ?? months.values[0]
                let newYear = nextMonth < month ? year + 1 : year
                comps.year = newYear
                comps.month = nextMonth
                comps.day = 1
                comps.hour = minHour
                comps.minute = minMinute
                comps.second = minSecond
                candidate = calendar.date(from: comps) ?? candidate.addingTimeInterval(60)
                
                continue
            }
            
            if !matchesDay(day: day, weekday: weekday) {
                guard let startOfToday = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: candidate))
                else { throw Schedule.Kind.Error.invalidDate(candidate, kind: .cron(expression)) }
                
                guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: startOfToday)
                else { throw Schedule.Kind.Error.invalidDate(candidate, kind: .cron(expression)) }
                
                var nextComps = calendar.dateComponents([.year, .month, .day], from: nextDayStart)
                nextComps.hour = minHour
                nextComps.minute = minMinute
                nextComps.second = minSecond
                
                candidate = calendar.date(from: nextComps) ?? nextDayStart
                
                continue
            }
            
            if !hours.contains(hour) {
                if let nextHour = nextValue(atOrAfter: hour, in: hours.values) {
                    comps.hour = nextHour
                    comps.minute = minMinute
                    comps.second = minSecond
                    candidate = calendar.date(from: comps) ?? candidate.addingTimeInterval(60)
                } else {
                    guard let startOfToday = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: candidate))
                    else { throw Schedule.Kind.Error.invalidDate(candidate, kind: .cron(expression)) }
                    
                    guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: startOfToday)
                    else { throw Schedule.Kind.Error.invalidDate(candidate, kind: .cron(expression)) }
                    
                    var nextComps = calendar.dateComponents([.year, .month, .day], from: nextDayStart)
                    nextComps.hour = minHour
                    nextComps.minute = minMinute
                    nextComps.second = minSecond
                    
                    candidate = calendar.date(from: nextComps) ?? nextDayStart
                }
                
                continue
            }
            
            if !minutes.contains(minute) {
                if let nextMinute = nextValue(atOrAfter: minute, in: minutes.values) {
                    comps.minute = nextMinute
                    comps.second = minSecond
                    candidate = calendar.date(from: comps) ?? candidate.addingTimeInterval(60)
                } else {
                    guard let nextHourDate = calendar.date(byAdding: .hour, value: 1, to: candidate)
                    else { throw Schedule.Kind.Error.invalidDate(candidate, kind: .cron(expression)) }
                    var nextComps = calendar.dateComponents([.year, .month, .day, .hour], from: nextHourDate)
                    nextComps.minute = minMinute
                    nextComps.second = minSecond
                    candidate = calendar.date(from: nextComps) ?? nextHourDate
                }
                
                continue
            }
            
            if !seconds.contains(second) {
                if let nextSecond = nextValue(atOrAfter: second, in: seconds.values) {
                    comps.second = nextSecond
                    candidate = calendar.date(from: comps) ?? candidate.addingTimeInterval(1)
                } else {
                    guard let nextMinuteDate = calendar.date(byAdding: .minute, value: 1, to: candidate)
                    else { throw Schedule.Kind.Error.invalidDate(candidate, kind: .cron(expression)) }
                    
                    var nextComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextMinuteDate)
                    nextComps.second = minSecond
                    candidate = calendar.date(from: nextComps) ?? nextMinuteDate
                }
                
                continue
            }
            
            return calendar.date(from: comps) ?? candidate
        }
        
        throw Schedule.Kind.Error.invalidDate(date, kind: .cron(expression))
    }
    
    private func matchesDay(day: Int, weekday: Int) -> Bool {
        let domMatch = daysOfMonth.contains(day)
        let dowMatch = daysOfWeek.contains(weekday)
        if daysOfMonth.isAny && daysOfWeek.isAny {
            return true
        }
        if daysOfMonth.isAny {
            return dowMatch
        }
        if daysOfWeek.isAny {
            return domMatch
        }
        return domMatch || dowMatch
    }
}

private func nextValue(atOrAfter current: Int, in values: [Int]) -> Int? {
    for value in values where value >= current {
        return value
    }
    return nil
}

private func parseNumber(_ token: Substring) -> Int? {
    Int(token)
}

private func parseMonth(_ token: Substring) -> Int? {
    let upper = token.uppercased()
    switch upper {
    case "JAN": return 1
    case "FEB": return 2
    case "MAR": return 3
    case "APR": return 4
    case "MAY": return 5
    case "JUN": return 6
    case "JUL": return 7
    case "AUG": return 8
    case "SEP": return 9
    case "OCT": return 10
    case "NOV": return 11
    case "DEC": return 12
    default:
        return Int(token)
    }
}

private func parseDayOfWeek(_ token: Substring) -> Int? {
    let upper = token.uppercased()
    switch upper {
    case "SUN": return 1
    case "MON": return 2
    case "TUE": return 3
    case "WED": return 4
    case "THU": return 5
    case "FRI": return 6
    case "SAT": return 7
    default:
        guard let value = Int(token) else {
            return nil
        }
        if value == 0 || value == 7 {
            return 1
        }
        if (1...6).contains(value) {
            return value + 1
        }
        return nil
    }
}
