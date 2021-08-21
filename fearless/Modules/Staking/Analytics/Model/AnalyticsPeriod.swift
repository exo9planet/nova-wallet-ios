import Foundation

enum AnalyticsPeriod: CaseIterable {
    case weekly
    case monthly
    case yearly
}

extension AnalyticsPeriod {
    static let `default` = AnalyticsPeriod.monthly

    func title(for locale: Locale) -> String {
        switch self {
        case .weekly:
            return R.string.localizable.stakingAnalyticsPeriodWeekly(preferredLanguages: locale.rLanguages).uppercased()
        case .monthly:
            return R.string.localizable.stakingAnalyticsPeriodMonthly(preferredLanguages: locale.rLanguages).uppercased()
        case .yearly:
            return R.string.localizable.stakingAnalyticsPeriodYearly(preferredLanguages: locale.rLanguages).uppercased()
        }
    }

    var chartBarsCount: Int {
        xAxisValues.count
    }

    var xAxisValues: [String] {
        switch self {
        case .weekly:
            return ["M", "T", "W", "T", "F", "S", "S"]
        case .monthly:
            return ["1", "7", "15", "22", "31"]
        case .yearly:
            return (1 ... 12).map { String($0) }
        }
    }
}

extension AnalyticsPeriod {
    func timestampInterval(periodDelta: Int) -> (Int64, Int64) {
        let tillDate: Date = {
            let interval: TimeInterval = {
                switch self {
                case .weekly:
                    return .secondsInDay * 7
                case .monthly:
                    return .secondsInDay * 31
                case .yearly:
                    return .secondsInDay * 31 * 12
                }
            }()
            return Date().addingTimeInterval(interval * Double(periodDelta))
        }()

        let calendar = Calendar(identifier: .iso8601)
        let dateComponent: Calendar.Component = {
            switch self {
            case .weekly:
                return .weekOfYear
            case .monthly:
                return .month
            case .yearly:
                return .year
            }
        }()
        guard let interval = calendar.dateInterval(of: dateComponent, for: tillDate) else { return (0, 0) }
        let startTimestamp = Int64(interval.start.timeIntervalSince1970)
        let endTimestamp = Int64(interval.end.timeIntervalSince1970)
        return (startTimestamp, endTimestamp)
    }
}
