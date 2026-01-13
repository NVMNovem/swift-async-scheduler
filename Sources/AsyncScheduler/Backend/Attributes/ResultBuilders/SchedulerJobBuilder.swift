import Foundation

@resultBuilder
public struct SchedulerJobBuilder {
    
    public static func buildBlock(_ components: [SchedulerJob]...) -> [SchedulerJob] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: SchedulerJob) -> [SchedulerJob] {
        [expression]
    }

    public static func buildExpression(_ expression: [SchedulerJob]) -> [SchedulerJob] {
        expression
    }

    public static func buildOptional(_ component: [SchedulerJob]?) -> [SchedulerJob] {
        component ?? []
    }

    public static func buildEither(first component: [SchedulerJob]) -> [SchedulerJob] {
        component
    }

    public static func buildEither(second component: [SchedulerJob]) -> [SchedulerJob] {
        component
    }

    public static func buildArray(_ components: [[SchedulerJob]]) -> [SchedulerJob] {
        components.flatMap { $0 }
    }
}
