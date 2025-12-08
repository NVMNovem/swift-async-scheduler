import Foundation

@resultBuilder
public struct ScheduledJobBuilder {
    
    public static func buildBlock(_ components: [ScheduledJob]...) -> [ScheduledJob] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: ScheduledJob) -> [ScheduledJob] {
        [expression]
    }

    public static func buildExpression(_ expression: [ScheduledJob]) -> [ScheduledJob] {
        expression
    }

    public static func buildOptional(_ component: [ScheduledJob]?) -> [ScheduledJob] {
        component ?? []
    }

    public static func buildEither(first component: [ScheduledJob]) -> [ScheduledJob] {
        component
    }

    public static func buildEither(second component: [ScheduledJob]) -> [ScheduledJob] {
        component
    }

    public static func buildArray(_ components: [[ScheduledJob]]) -> [ScheduledJob] {
        components.flatMap { $0 }
    }
}
