import AppKit
import Combine
import Foundation
import SwiftUI

enum ItemSort: String, CaseIterable, Identifiable {
    case largest
    case name
    case newest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .largest: return "Largest First"
        case .name: return "Name"
        case .newest: return "Newest First"
        }
    }

    var symbol: String {
        switch self {
        case .largest: return "arrow.down"
        case .name: return "textformat"
        case .newest: return "clock"
        }
    }
}

struct QuickCleanEntry: Identifiable {
    var rule: QuickCleanRule
    var item: CleanableItem?

    var id: String { rule.id }
    var size: Int64 { item?.size ?? 0 }
    var isStale: Bool { item == nil }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var symbol: String
}

@MainActor
final class AppModel: ObservableObject {
    // Scan output
    @Published private(set) var itemsByCategory: [CleanupCategory: [CleanableItem]] = [:]
    @Published private(set) var scanPhase: ScanPhase = .idle
    @Published private(set) var volume: VolumeInfo = VolumeReader.read()
    @Published private(set) var warnings: [String] = []
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var hasFullDiskAccess = true

    // Navigation and selection
    @Published var selection: CleanupCategory? = .overview {
        didSet {
            #if DEBUG
            if oldValue != selection {
                print("debug: selection \(oldValue?.rawValue ?? "nil") -> \(selection?.rawValue ?? "nil")")
                print(Thread.callStackSymbols.prefix(14).joined(separator: "\n"))
            }
            #endif
        }
    }
    @Published var selectedIDs: Set<String> = []
    @Published var searchText: String = ""
    @Published var sortOrder: ItemSort = .largest

    // Quick clean
    @Published private(set) var quickCleanRules: [QuickCleanRule] = []
    @Published var quickCleanSelectedIDs: Set<String> = []

    // Cleanup flow
    @Published var cleanupItems: [CleanableItem] = []
    @Published var cleanupMode: RemovalMode
    @Published var isCleanupSheetPresented = false
    @Published var isCleaning = false
    @Published var cleanupProgress: Double = 0
    @Published var cleanupProgressLabel: String = ""
    @Published private(set) var cleanupReport: CleanupReport?
    @Published var toast: ToastMessage?
    @Published var errorMessage: String?

    // Settings
    @Published var settings: ScanSettings {
        didSet { settingsStore.saveScanSettings(settings) }
    }
    @Published var defaultRemovalMode: RemovalMode {
        didSet { settingsStore.saveRemovalMode(defaultRemovalMode) }
    }

    private let settingsStore: SettingsStore
    private let presetStore: PresetStore
    private var scanTask: Task<Void, Never>?
    private var scanGeneration = 0
    private var toastTask: Task<Void, Never>?

    #if DEBUG
    private var didApplyDebugScanOptions = false
    #endif

    init(settingsStore: SettingsStore = SettingsStore(), presetStore: PresetStore = PresetStore()) {
        self.settingsStore = settingsStore
        self.presetStore = presetStore
        self.settings = settingsStore.loadScanSettings()
        self.defaultRemovalMode = settingsStore.loadRemovalMode()
        self.cleanupMode = settingsStore.loadRemovalMode()
        self.quickCleanRules = presetStore.load()
        self.quickCleanSelectedIDs = Set(presetStore.load().map(\.id))
        self.hasFullDiskAccess = PermissionChecker.hasFullDiskAccess()

        #if DEBUG
        print("debug: AppModel init \(ObjectIdentifier(self))")
        applyDebugNavigationOptions()
        #endif
    }

    #if DEBUG
    deinit {
        print("debug: AppModel deinit \(ObjectIdentifier(self))")
    }
    #endif

    // MARK: - Derived data

    var allItems: [CleanableItem] {
        CleanupCategory.allCases.flatMap { itemsByCategory[$0] ?? [] }
    }

    var totalReclaimable: Int64 {
        allItems.reduce(0) { $0 + $1.size }
    }

    var totalItemCount: Int {
        allItems.count
    }

    var isScanning: Bool {
        scanPhase.isScanning
    }

    var hasScanned: Bool {
        lastScanDate != nil
    }

    func items(for category: CleanupCategory) -> [CleanableItem] {
        (itemsByCategory[category] ?? []).sorted { $0.size > $1.size }
    }

    func size(for category: CleanupCategory) -> Int64 {
        (itemsByCategory[category] ?? []).reduce(0) { $0 + $1.size }
    }

    func count(for category: CleanupCategory) -> Int {
        (itemsByCategory[category] ?? []).count
    }

    var visibleItems: [CleanableItem] {
        guard let selection, selection.isDataCategory else { return [] }
        var items = items(for: selection)

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            items = items.filter { item in
                item.name.localizedCaseInsensitiveContains(query)
                    || item.detail.localizedCaseInsensitiveContains(query)
                    || (item.path?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }

        switch sortOrder {
        case .largest:
            items.sort { $0.size > $1.size }
        case .name:
            items.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .newest:
            items.sort { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
        }
        return items
    }

    var selectedItems: [CleanableItem] {
        allItems.filter { selectedIDs.contains($0.id) }
    }

    var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    var selectedCount: Int {
        selectedItems.count
    }

    var selectedLargeFileCount: Int {
        selectedItems.filter { $0.kind == .file }.count
    }

    var quickCleanEntries: [QuickCleanEntry] {
        quickCleanRules.map { rule in
            let match = allItems.first { $0.action == rule.action }
            return QuickCleanEntry(rule: rule, item: match)
        }
    }

    var quickCleanSelectedItems: [CleanableItem] {
        quickCleanEntries
            .filter { quickCleanSelectedIDs.contains($0.rule.id) }
            .compactMap(\.item)
    }

    var quickCleanSize: Int64 {
        quickCleanSelectedItems.reduce(0) { $0 + $1.size }
    }

    var quickCleanStaleCount: Int {
        quickCleanEntries.filter(\.isStale).count
    }

    var pinnedCount: Int {
        quickCleanRules.count
    }

    func isPinned(_ item: CleanableItem) -> Bool {
        quickCleanRules.contains { $0.action == item.action }
    }

    var scanStatusText: String {
        switch scanPhase {
        case .idle:
            return "Ready to scan"
        case .scanning(let label, _):
            return label
        case .finished:
            if let lastScanDate {
                return "Scanned \(DateText.relative(lastScanDate))"
            }
            return "Scan complete"
        case .failed(let message):
            return message
        }
    }

    var freeSpaceText: String {
        SizeFormatter.string(volume.free)
    }

    var usedSpaceText: String {
        SizeFormatter.string(volume.used)
    }

    var totalSpaceText: String {
        SizeFormatter.string(volume.total)
    }

    // MARK: - Scanning

    func scan() {
        scanGeneration += 1
        let generation = scanGeneration
        scanTask?.cancel()

        selectedIDs = []
        warnings = []
        itemsByCategory = [:]
        volume = VolumeReader.read()
        hasFullDiskAccess = PermissionChecker.hasFullDiskAccess()
        scanPhase = .scanning(label: "Finding things you can safely remove…", fraction: 0.01)

        let scanner = DiskScanner(settings: settings)
        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await scanner.scan { event in
                await self.receive(event, generation: generation)
            }
        }
    }

    private func receive(_ event: ScanEvent, generation: Int) {
        guard generation == scanGeneration else { return }

        switch event {
        case .volume(let info):
            volume = info

        case .progress(let label, let fraction):
            scanPhase = .scanning(label: label, fraction: min(max(fraction, 0), 1))

        case .items(let category, let items):
            itemsByCategory[category] = items
            selectedIDs = selectedIDs.intersection(Set(allItems.map(\.id)))

        case .warning(let message):
            if !warnings.contains(message) {
                warnings.append(message)
            }

        case .finished:
            let date = Date()
            lastScanDate = date
            scanPhase = .finished(date)
            hasFullDiskAccess = PermissionChecker.hasFullDiskAccess()
            refreshVolume()
            if allItems.isEmpty {
                showToast("Nothing big enough to clean was found.", symbol: "checkmark.circle")
            } else {
                showToast("Found \(SizeFormatter.string(totalReclaimable)) you can reclaim.", symbol: "sparkles")
            }

            #if DEBUG
            applyDebugScanOptions()
            #endif
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        scanGeneration += 1
        scanPhase = .idle
    }

    private func refreshVolume() {
        var info = VolumeReader.read()
        info.reclaimable = totalReclaimable
        volume = info
    }

    // MARK: - Selection

    func toggleSelection(_ item: CleanableItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    func selectAllVisible() {
        selectedIDs.formUnion(visibleItems.map(\.id))
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }

    func isSelected(_ item: CleanableItem) -> Bool {
        selectedIDs.contains(item.id)
    }

    // MARK: - Quick Clean

    func togglePin(_ item: CleanableItem) {
        if let existing = quickCleanRules.first(where: { $0.action == item.action }) {
            removeRule(id: existing.id)
            showToast("Removed from One-Click Clean.", symbol: "bookmark.slash")
        } else {
            let rule = QuickCleanRule(item: item)
            quickCleanRules.append(rule)
            quickCleanSelectedIDs.insert(rule.id)
            persistRules()
            showToast("Added to One-Click Clean.", symbol: "bookmark.fill")
        }
    }

    func pinSelectedItems() {
        let newItems = selectedItems.filter { item in
            !quickCleanRules.contains { $0.action == item.action }
        }
        guard !newItems.isEmpty else {
            showToast("Those items are already in One-Click Clean.", symbol: "bookmark.fill")
            return
        }
        for item in newItems {
            let rule = QuickCleanRule(item: item)
            quickCleanRules.append(rule)
            quickCleanSelectedIDs.insert(rule.id)
        }
        persistRules()
        showToast("Saved \(newItems.count) item\(newItems.count == 1 ? "" : "s") to One-Click Clean.", symbol: "bookmark.fill")
    }

    func removeRule(id: String) {
        quickCleanRules.removeAll { $0.id == id }
        quickCleanSelectedIDs.remove(id)
        persistRules()
    }

    func removeStaleRules() {
        let stale = quickCleanEntries.filter(\.isStale).map(\.rule.id)
        guard !stale.isEmpty else { return }
        quickCleanRules.removeAll { stale.contains($0.id) }
        quickCleanSelectedIDs.subtract(stale)
        persistRules()
        showToast("Removed \(stale.count) stale rule\(stale.count == 1 ? "" : "s").", symbol: "checkmark.circle")
    }

    func clearRules() {
        quickCleanRules = []
        quickCleanSelectedIDs = []
        persistRules()
    }

    func toggleQuickClean(_ ruleID: String) {
        if quickCleanSelectedIDs.contains(ruleID) {
            quickCleanSelectedIDs.remove(ruleID)
        } else {
            quickCleanSelectedIDs.insert(ruleID)
        }
    }

    func selectAllQuickCleanRules() {
        quickCleanSelectedIDs = Set(quickCleanRules.map(\.id))
    }

    func deselectAllQuickCleanRules() {
        quickCleanSelectedIDs = []
    }

    private func persistRules() {
        presetStore.save(quickCleanRules)
    }

    // MARK: - Cleanup

    func prepareSelectedCleanup() {
        let items = deduplicated(selectedItems)
        guard !items.isEmpty else { return }
        beginCleanup(items: items)
    }

    func prepareQuickClean() {
        let items = deduplicated(quickCleanSelectedItems)
        guard !items.isEmpty else {
            showToast("Nothing selected to clean.", symbol: "exclamationmark.circle")
            return
        }
        beginCleanup(items: items)
    }

    func beginCleanup(items: [CleanableItem]) {
        cleanupReport = nil
        cleanupProgress = 0
        cleanupProgressLabel = ""
        cleanupItems = items
        cleanupMode = defaultRemovalMode
        isCleanupSheetPresented = true
    }

    func dismissCleanup() {
        guard !isCleaning else { return }
        isCleanupSheetPresented = false
        cleanupItems = []
        cleanupReport = nil
    }

    func runCleanup() {
        guard !isCleaning, !cleanupItems.isEmpty else { return }
        let items = cleanupItems
        let mode = cleanupMode
        isCleaning = true
        cleanupReport = nil
        cleanupProgress = 0
        cleanupProgressLabel = "Preparing…"

        Task {
            let report = await CleanupService().clean(items: items, mode: mode) { completed, total, name in
                await MainActor.run {
                    self.cleanupProgress = total > 0 ? Double(completed) / Double(total) : 0
                    self.cleanupProgressLabel = name
                }
            }

            self.isCleaning = false
            self.cleanupProgress = 1
            self.cleanupReport = report
            self.defaultRemovalMode = mode
            self.apply(report: report)
        }
    }

    private func apply(report: CleanupReport) {
        let removedIDs = Set(
            (report.movedToTrash + report.deleted + report.commandsRun).map(\.id)
        )
        guard !removedIDs.isEmpty else {
            refreshVolume()
            return
        }

        for category in CleanupCategory.allCases {
            guard var items = itemsByCategory[category] else { continue }
            items.removeAll { removedIDs.contains($0.id) }
            itemsByCategory[category] = items
        }
        selectedIDs.subtract(removedIDs)
        refreshVolume()

        if report.reclaimed > 0 {
            showToast("Freed \(SizeFormatter.string(report.reclaimed)).", symbol: "checkmark.seal.fill")
        }
    }

    private func deduplicated(_ items: [CleanableItem]) -> [CleanableItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.action.identity).inserted }
    }

    // MARK: - Finder helpers

    func reveal(_ item: CleanableItem) {
        guard let path = item.path else { return }
        PermissionChecker.revealInFinder(path: path)
    }

    func open(_ item: CleanableItem) {
        guard let path = item.path else { return }
        PermissionChecker.open(path: path)
    }

    func openFullDiskAccessSettings() {
        PermissionChecker.openFullDiskAccessSettings()
    }

    // MARK: - Toast & errors

    func showToast(_ text: String, symbol: String) {
        toastTask?.cancel()
        let message = ToastMessage(text: text, symbol: symbol)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            toast = message
        }
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self?.toast?.id == message.id else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    self?.toast = nil
                }
            }
        }
    }

    func presentError(_ message: String) {
        errorMessage = message
    }

    #if DEBUG
    // Launch options used only for capturing screens during development.
    private func applyDebugNavigationOptions() {
        let arguments = CommandLine.arguments
        guard let flag = arguments.firstIndex(of: "--screen"),
              arguments.indices.contains(flag + 1),
              let category = CleanupCategory(rawValue: arguments[flag + 1]) else {
            return
        }
        selection = category
        print("debug screen: \(category.rawValue), arguments: \(arguments)")
    }

    private func applyDebugScanOptions() {
        guard !didApplyDebugScanOptions, !allItems.isEmpty else { return }
        didApplyDebugScanOptions = true
        let arguments = CommandLine.arguments

        if arguments.contains("--seed-quick-clean") {
            for item in allItems.prefix(4) {
                let rule = QuickCleanRule(item: item)
                quickCleanRules.append(rule)
                quickCleanSelectedIDs.insert(rule.id)
            }
            selection = .quickClean
        }

        if arguments.contains("--show-cleanup") {
            let items = Array(allItems.prefix(4))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.beginCleanup(items: items)
            }
        }
    }
    #endif
}
