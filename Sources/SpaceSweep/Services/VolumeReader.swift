import Foundation

enum VolumeReader {
    static func read(at url: URL = FileManager.default.homeDirectoryForCurrentUser) -> VolumeInfo {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]

        guard let values = try? url.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity else {
            return .empty
        }

        let importantUsage = values.volumeAvailableCapacityForImportantUsage.map { Int64($0) }
        let regularCapacity = Int64(values.volumeAvailableCapacity ?? 0)
        let available = importantUsage ?? regularCapacity
        let free = max(0, available)
        let used = max(0, Int64(total) - free)
        let fraction = total > 0 ? Double(used) / Double(total) : 0

        return VolumeInfo(
            total: Int64(total),
            free: free,
            used: used,
            usedFraction: min(max(fraction, 0), 1),
            reclaimable: 0
        )
    }
}
