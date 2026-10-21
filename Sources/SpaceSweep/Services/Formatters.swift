import Foundation

enum SizeFormatter {
    private static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    static func string(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 KB" }
        return formatter.string(fromByteCount: bytes)
    }

    static func split(_ bytes: Int64) -> (value: String, unit: String) {
        let text = string(bytes)
        let pieces = text.split(separator: " ", maxSplits: 1).map(String.init)
        if pieces.count == 2 {
            return (pieces[0], pieces[1])
        }
        return (text, "")
    }

    static func fileCount(_ count: Int) -> String {
        count == 1 ? "1 item" : "\(count.formatted()) items"
    }
}

enum DateText {
    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    static func relative(_ date: Date?) -> String {
        guard let date else { return "" }
        return relative.localizedString(for: date, relativeTo: Date())
    }

    static func short(_ date: Date?) -> String {
        guard let date else { return "" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
