import Foundation

extension Date {
    var startOfDayUTC: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.startOfDay(for: self)
    }

    func isSameDay(as other: Date, timeZone: TimeZone = .current) -> Bool {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar.isDate(self, inSameDayAs: other)
    }
}
