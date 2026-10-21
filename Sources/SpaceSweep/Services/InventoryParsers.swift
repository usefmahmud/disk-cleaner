import Foundation

// MARK: - Ollama

struct OllamaModel: Equatable, Sendable {
    var name: String
    var size: Int64
    var modified: String?
}

enum OllamaParser {
    private static let regex = try! NSRegularExpression(
        pattern: #"^(\S+)\s+(\S+)\s+([\d.]+)\s+([KMGT]?B)\s*(.*)$"#,
        options: [.caseInsensitive]
    )

    static func parseList(_ output: String) -> [OllamaModel] {
        var models: [OllamaModel] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let text = String(line).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty, !text.lowercased().hasPrefix("name") else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  let nameRange = Range(match.range(at: 1), in: text),
                  let valueRange = Range(match.range(at: 3), in: text),
                  let unitRange = Range(match.range(at: 4), in: text) else {
                continue
            }
            let name = String(text[nameRange])
            let value = Double(text[valueRange]) ?? 0
            let unit = String(text[unitRange]).uppercased()
            let modifiedRange = Range(match.range(at: 5), in: text)
            let modified = modifiedRange.map { String(text[$0]).trimmingCharacters(in: .whitespaces) }

            models.append(OllamaModel(
                name: name,
                size: bytes(value: value, unit: unit),
                modified: modified?.isEmpty == false ? modified : nil
            ))
        }
        return models
    }

    static func bytes(value: Double, unit: String) -> Int64 {
        let multiplier: Double
        switch unit.uppercased() {
        case "KB": multiplier = 1_000
        case "MB": multiplier = 1_000_000
        case "GB": multiplier = 1_000_000_000
        case "TB": multiplier = 1_000_000_000_000
        default: multiplier = 1
        }
        return Int64(value * multiplier)
    }
}

// MARK: - Docker

struct DockerResource: Equatable, Sendable {
    var type: String
    var totalCount: Int
    var activeCount: Int
    var size: Int64
    var reclaimable: Int64
    var reclaimableLabel: String
}

enum DockerParser {
    static func parseSystemDFJSON(_ output: String) -> [DockerResource] {
        var resources: [DockerResource] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let text = line.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty,
                  let data = text.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let type = object["Type"] as? String ?? ""
            guard !type.isEmpty else { continue }
            let total = Int(object["TotalCount"] as? String ?? "") ?? 0
            let active = Int(object["Active"] as? String ?? "") ?? 0
            let sizeText = object["Size"] as? String ?? "0B"
            let reclaimText = object["Reclaimable"] as? String ?? "0B"

            resources.append(DockerResource(
                type: type,
                totalCount: total,
                activeCount: active,
                size: parseHumanBytes(sizeText),
                reclaimable: parseHumanBytes(reclaimText),
                reclaimableLabel: reclaimText
            ))
        }
        return resources
    }

    static func parseHumanBytes(_ text: String) -> Int64 {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        let digits = normalized.prefix { $0.isNumber || $0 == "." }
        let remainder = normalized.dropFirst(digits.count).trimmingCharacters(in: .whitespaces)
        let suffix = String(remainder.prefix { $0.isLetter }).uppercased()
        guard let value = Double(digits) else { return 0 }

        switch suffix {
        case "KB", "KIB": return Int64(value * 1_000)
        case "MB", "MIB": return Int64(value * 1_000_000)
        case "GB", "GIB": return Int64(value * 1_000_000_000)
        case "TB", "TIB": return Int64(value * 1_000_000_000_000)
        default: return Int64(value)
        }
    }
}

// MARK: - Hugging Face

enum HuggingFaceParser {
    static func displayName(for folderName: String) -> (name: String, detail: String) {
        if folderName.hasPrefix("models--") {
            let rest = folderName.dropFirst("models--".count)
            return (repository(rest), "Model cache")
        }
        if folderName.hasPrefix("datasets--") {
            let rest = folderName.dropFirst("datasets--".count)
            return (repository(rest), "Dataset cache")
        }
        if folderName.hasPrefix("spaces--") {
            let rest = folderName.dropFirst("spaces--".count)
            return (repository(rest), "Space cache")
        }
        if folderName == "blobs" {
            return ("Shared blobs", "Hugging Face shared download blobs")
        }
        if folderName == "xet" {
            return ("Xet cache", "Hugging Face Xet transfer cache")
        }
        return (folderName, "Hugging Face cache")
    }

    private static func repository(_ value: Substring) -> String {
        let parts = value.components(separatedBy: "--")
        guard parts.count >= 2 else { return String(value) }
        return parts[0] + "/" + parts.dropFirst().joined(separator: "--")
    }
}

// MARK: - Time Machine snapshots

enum SnapshotParser {
    private static let regex = try! NSRegularExpression(
        pattern: #"com\.apple\.TimeMachine\.(\d{4}-\d{2}-\d{2}-\d{6})\.local"#
    )

    static func parseSnapshots(_ output: String) -> [String] {
        var dates: [String] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let text = String(line)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  let dateRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            dates.append(String(text[dateRange]))
        }
        return dates
    }

    static func displayDate(_ identifier: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        guard let date = formatter.date(from: identifier) else { return identifier }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
