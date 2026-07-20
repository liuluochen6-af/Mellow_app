import Foundation

enum DateParsing {
    private static let isoWithTimezone: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let isoWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoNoTimezone: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func parse(_ string: String) -> Date? {
        isoWithFractional.date(from: string)
            ?? isoWithTimezone.date(from: string)
            ?? isoNoTimezone.date(from: string)
    }
}
