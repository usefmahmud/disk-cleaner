import Foundation
import SwiftUI

// MARK: - Categories

enum CategoryGroup: String, CaseIterable, Identifiable, Sendable {
    case smart
    case storage
    case cleanup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart: return "Smart Cleanup"
        case .storage: return "Your Files"
        case .cleanup: return "System & Apps"
        }
    }
}

enum CleanupCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case overview
    case quickClean
    case largeFiles
    case downloads
    case trash
    case caches
    case developer
    case aiModels
    case appSupport
    case containers
    case logs
    case docker
    case snapshots

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .quickClean: return "One-Click Clean"
        case .largeFiles: return "Large Files"
        case .downloads: return "Downloads"
        case .trash: return "Trash"
        case .caches: return "User Caches"
        case .developer: return "Developer Junk"
        case .aiModels: return "AI Models"
        case .appSupport: return "App Support"
        case .containers: return "App Containers"
        case .logs: return "Logs & Reports"
        case .docker: return "Docker"
        case .snapshots: return "Time Machine"
        }
    }

    var subtitle: String {
        switch self {
        case .overview:
            return "A clear picture of what is using your disk."
        case .quickClean:
            return "Your saved cleanup, ready in one click."
        case .largeFiles:
            return "Individual files over your size threshold."
        case .downloads:
            return "Large items in your Downloads folder."
        case .trash:
            return "Items waiting in the Trash."
        case .caches:
            return "Rebuildable data stored by your apps."
        case .developer:
            return "Build artifacts, package caches, and toolchains."
        case .aiModels:
            return "Hugging Face datasets, Ollama models, and more."
        case .appSupport:
            return "Data kept by apps. Quit the app before removing."
        case .containers:
            return "Sandboxed app data in your Library."
        case .logs:
            return "Diagnostic and crash reports you no longer need."
        case .docker:
            return "Images, containers, volumes, and build cache."
        case .snapshots:
            return "Local Time Machine snapshots held by macOS."
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.50percent"
        case .quickClean: return "wand.and.stars"
        case .largeFiles: return "doc.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .trash: return "trash.fill"
        case .caches: return "shippingbox.fill"
        case .developer: return "hammer.fill"
        case .aiModels: return "brain.head.profile"
        case .appSupport: return "app.badge.fill"
        case .containers: return "square.stack.3d.up.fill"
        case .logs: return "doc.text.magnifyingglass"
        case .docker: return "shippingbox.and.arrow.backward.fill"
        case .snapshots: return "clock.arrow.circlepath"
        }
    }

    var group: CategoryGroup {
        switch self {
        case .overview, .quickClean: return .smart
        case .largeFiles, .downloads, .trash: return .storage
        case .caches, .developer, .aiModels, .appSupport, .containers, .logs, .docker, .snapshots: return .cleanup
        }
    }

    var accent: Color {
        switch self {
        case .overview: return .blue
        case .quickClean: return .mint
        case .largeFiles: return .indigo
        case .downloads: return .blue
        case .trash: return .gray
        case .caches: return .orange
        case .developer: return .purple
        case .aiModels: return .pink
        case .appSupport: return .teal
        case .containers: return .cyan
        case .logs: return .brown
        case .docker: return .blue
        case .snapshots: return .green
        }
    }

    var isDataCategory: Bool {
        self != .overview && self != .quickClean
    }

    static var dataCategories: [CleanupCategory] {
        allCases.filter(\.isDataCategory)
    }
}

// MARK: - Safety

enum SafetyLevel: Int, Codable, CaseIterable, Sendable, Comparable {
    case safe = 0
    case caution = 1
    case risky = 2

    static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .safe: return "Safe"
        case .caution: return "Check first"
        case .risky: return "Risky"
        }
    }

    var symbol: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .risky: return "exclamationmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .safe: return .green
        case .caution: return .orange
        case .risky: return .red
        }
    }
}

// MARK: - Items

enum CleanableKind: String, Codable, Sendable {
    case folder
    case file
    case group
    case command

    var symbol: String {
        switch self {
        case .folder: return "folder.fill"
        case .file: return "doc.fill"
        case .group: return "square.stack.3d.up.fill"
        case .command: return "terminal.fill"
        }
    }
}

struct CommandSpec: Codable, Hashable, Sendable {
    var executable: String
    var arguments: [String]
    var requiresAdmin: Bool

    init(_ executable: String, _ arguments: [String], requiresAdmin: Bool = false) {
        self.executable = executable
        self.arguments = arguments
        self.requiresAdmin = requiresAdmin
    }

    var display: String {
        ([executable] + arguments).joined(separator: " ")
    }
}

enum CleanupAction: Codable, Hashable, Sendable {
    case trash(path: String)
    case command(CommandSpec)

    var identity: String {
        switch self {
        case .trash(let path): return "path:\(path)"
        case .command(let spec): return "cmd:\(spec.display)"
        }
    }

    var isCommand: Bool {
        if case .command = self { return true }
        return false
    }

    var path: String? {
        if case .trash(let path) = self { return path }
        return nil
    }
}

struct CleanableItem: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var category: CleanupCategory
    var size: Int64
    var path: String?
    var detail: String
    var safety: SafetyLevel
    var kind: CleanableKind
    var action: CleanupAction
    var modified: Date?
    var childCount: Int?

    init(
        name: String,
        category: CleanupCategory,
        size: Int64,
        path: String? = nil,
        detail: String = "",
        safety: SafetyLevel,
        kind: CleanableKind,
        action: CleanupAction,
        modified: Date? = nil,
        childCount: Int? = nil
    ) {
        self.name = name
        self.category = category
        self.size = size
        self.path = path
        self.detail = detail
        self.safety = safety
        self.kind = kind
        self.action = action
        self.modified = modified
        self.childCount = childCount
        self.id = "\(category.rawValue)|\(action.identity)"
    }

    var displayPath: String {
        path ?? detail
    }
}

// MARK: - Quick Clean

struct QuickCleanRule: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var category: CleanupCategory
    var action: CleanupAction
    var path: String?
    var sizeAtSave: Int64

    init(item: CleanableItem) {
        self.id = item.id
        self.name = item.name
        self.category = item.category
        self.action = item.action
        self.path = item.path
        self.sizeAtSave = item.size
    }
}

// MARK: - Volume & Scan

struct VolumeInfo: Equatable, Sendable {
    var total: Int64
    var free: Int64
    var used: Int64
    var usedFraction: Double
    var reclaimable: Int64

    static let empty = VolumeInfo(total: 0, free: 0, used: 0, usedFraction: 0, reclaimable: 0)

    var freeFraction: Double {
        guard total > 0 else { return 0 }
        return Double(free) / Double(total)
    }
}

enum ScanPhase: Equatable, Sendable {
    case idle
    case scanning(label: String, fraction: Double)
    case finished(Date)
    case failed(String)

    var isScanning: Bool {
        if case .scanning = self { return true }
        return false
    }
}

struct ScanSettings: Codable, Equatable, Sendable {
    var largeFileThresholdMB: Int = 250
    var maxLargeFiles: Int = 100
    var minFolderSizeMB: Int = 10
    var includeDownloads: Bool = true

    static let `default` = ScanSettings()

    var largeFileThreshold: Int64 {
        Int64(max(10, largeFileThresholdMB)) * 1_000_000
    }

    var minFolderSize: Int64 {
        Int64(max(1, minFolderSizeMB)) * 1_000_000
    }
}

struct CleanupReport: Identifiable, Sendable {
    let id = UUID()
    var movedToTrash: [CleanableItem]
    var deleted: [CleanableItem]
    var commandsRun: [CleanableItem]
    var failures: [CleanupFailure]
    var reclaimed: Int64

    var totalSucceeded: Int {
        movedToTrash.count + deleted.count + commandsRun.count
    }

    var hasFailures: Bool { !failures.isEmpty }
}

struct CleanupFailure: Identifiable, Hashable, Sendable {
    var id = UUID()
    var itemName: String
    var message: String
}
