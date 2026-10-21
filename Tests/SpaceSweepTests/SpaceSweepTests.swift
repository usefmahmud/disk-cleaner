import AppKit
import Foundation
import Testing
@testable import SpaceSweep

@Suite("Safety policy")
struct SafetyPolicyTests {
    private let home = SafetyPolicy.home.path

    @Test func blocksRootAndOutsideHome() {
        #expect(!SafetyPolicy.validateDeletionPath("/").isAllowed)
        #expect(!SafetyPolicy.validateDeletionPath("/tmp/something").isAllowed)
        #expect(!SafetyPolicy.validateDeletionPath(home).isAllowed)
    }

    @Test func blocksImportantTopLevelFolders() {
        #expect(!SafetyPolicy.validateDeletionPath(home + "/Documents").isAllowed)
        #expect(!SafetyPolicy.validateDeletionPath(home + "/Library").isAllowed)
        #expect(!SafetyPolicy.validateDeletionPath(home + "/.ssh").isAllowed)
        #expect(!SafetyPolicy.validateDeletionPath(home + "/.Trash").isAllowed)
    }

    @Test func allowsKnownCacheFolders() {
        #expect(SafetyPolicy.validateDeletionPath(home + "/Library/Caches/example.app").isAllowed)
        #expect(SafetyPolicy.validateDeletionPath(home + "/.cache/huggingface/hub/models--org--name").isAllowed)
        #expect(SafetyPolicy.validateDeletionPath(home + "/.Trash/old-file.zip").isAllowed)
    }

    @Test func allowsWholeModelStores() {
        #expect(SafetyPolicy.validateDeletionPath(home + "/.ollama").isAllowed)
        #expect(SafetyPolicy.validateDeletionPath(home + "/.unsloth").isAllowed)
        #expect(SafetyPolicy.validateDeletionPath(home + "/.omlx").isAllowed)
    }

    @Test func commandGuards() {
        #expect(!SafetyPolicy.validateCommand(CommandSpec("rm", ["-rf", "/"])).isAllowed)
        #expect(!SafetyPolicy.validateCommand(CommandSpec("sudo", ["rm", "file"])).isAllowed)
        #expect(SafetyPolicy.validateCommand(CommandSpec("docker", ["image", "prune", "-a", "-f"])).isAllowed)
        #expect(SafetyPolicy.validateCommand(CommandSpec("tmutil", ["deletelocalsnapshots", "2026-01-01-000000"], requiresAdmin: true)).isAllowed)
    }
}

@Suite("Parsers")
struct ParserTests {
    @Test func ollamaListParsing() {
        let output = """
        NAME                                        ID              SIZE      MODIFIED
        llama3.2:latest                             a80c4f17acd5    2.0 GB    2 days ago
        hf.co/org/model:Q4_K_M                      abcdef123456    5.2 GB    3 weeks ago
        tiny:1b                                     123456789abc    120 MB    1 hour ago
        """

        let models = OllamaParser.parseList(output)
        #expect(models.count == 3)
        #expect(models[0].name == "llama3.2:latest")
        #expect(models[0].size == 2_000_000_000)
        #expect(models[1].name == "hf.co/org/model:Q4_K_M")
        #expect(models[1].size == 5_200_000_000)
        #expect(models[2].size == 120_000_000)
    }

    @Test func dockerSystemDFParsing() {
        let output = """
        {"Type":"Images","TotalCount":"9","Active":"2","Size":"12.3GB","Reclaimable":"8.1GB (65%)"}
        {"Type":"Build Cache","TotalCount":"42","Active":"0","Size":"4.4GB","Reclaimable":"4.0GB"}
        """

        let resources = DockerParser.parseSystemDFJSON(output)
        #expect(resources.count == 2)
        #expect(resources[0].type == "Images")
        #expect(resources[0].totalCount == 9)
        #expect(resources[0].reclaimable == 8_100_000_000)
        #expect(resources[1].reclaimable == 4_000_000_000)
    }

    @Test func humanByteParsing() {
        #expect(DockerParser.parseHumanBytes("0B") == 0)
        #expect(DockerParser.parseHumanBytes("512MB") == 512_000_000)
        #expect(DockerParser.parseHumanBytes("1.5 GB (20%)") == 1_500_000_000)
        #expect(DockerParser.parseHumanBytes("1.2GiB") == 1_200_000_000)
    }

    @Test func huggingFaceNames() {
        #expect(HuggingFaceParser.displayName(for: "models--org--Qwen").name == "org/Qwen")
        #expect(HuggingFaceParser.displayName(for: "datasets--AuthenticIlm--Shamela4_Full_DB").name == "AuthenticIlm/Shamela4_Full_DB")
        #expect(HuggingFaceParser.displayName(for: "blobs").name == "Shared blobs")
    }

    @Test func snapshotParsing() {
        let output = """
        Snapshots for disk /:
        com.apple.TimeMachine.2026-10-20-142233.local
        com.apple.TimeMachine.2026-10-21-090000.local
        No snapshots found.
        """

        let dates = SnapshotParser.parseSnapshots(output)
        #expect(dates == ["2026-10-20-142233", "2026-10-21-090000"])
    }
}

@Suite("Stores")
struct StoreTests {
    @Test func presetRoundTrip() {
        let suite = "SpaceSweepTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let item = CleanableItem(
            name: "Test Cache",
            category: .caches,
            size: 12_000,
            path: SafetyPolicy.home.path + "/Library/Caches/Test",
            detail: "Test",
            safety: .safe,
            kind: .folder,
            action: .trash(path: SafetyPolicy.home.path + "/Library/Caches/Test")
        )

        let store = PresetStore(defaults: defaults)
        store.save([QuickCleanRule(item: item)])
        let loaded = store.load()

        #expect(loaded.count == 1)
        #expect(loaded[0].name == "Test Cache")
        #expect(loaded[0].action == item.action)
    }

    @Test func settingsRoundTrip() {
        let suite = "SpaceSweepSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = SettingsStore(defaults: defaults)
        var settings = ScanSettings.default
        settings.largeFileThresholdMB = 500
        settings.minFolderSizeMB = 25
        settings.maxLargeFiles = 200
        store.saveScanSettings(settings)

        #expect(store.loadScanSettings() == settings)
        store.saveRemovalMode(.permanent)
        #expect(store.loadRemovalMode() == .permanent)
    }
}

@Suite("Cleanup service")
struct CleanupServiceTests {
    @Test func permanentDeletionInsideHome() async throws {
        let directory = SafetyPolicy.home
            .appendingPathComponent("Library/Caches")
            .appendingPathComponent("SpaceSweepTests-\(UUID().uuidString)", isDirectory: true)
        let file = directory.appendingPathComponent("payload.bin")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(repeating: 0, count: 128_000).write(to: file)
        defer { try? FileManager.default.removeItem(at: directory) }

        let item = CleanableItem(
            name: "Test Cache",
            category: .caches,
            size: 128_000,
            path: directory.path,
            detail: "Test",
            safety: .safe,
            kind: .folder,
            action: .trash(path: directory.path)
        )

        let report = await CleanupService().clean(items: [item], mode: .permanent) { _, _, _ in }

        #expect(report.failures.isEmpty)
        #expect(report.deleted.count == 1)
        #expect(report.reclaimed == 128_000)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func refusesOutsideHome() async {
        let item = CleanableItem(
            name: "Unsafe",
            category: .caches,
            size: 10,
            path: "/tmp/spacesweep-should-not-exist",
            detail: "Test",
            safety: .safe,
            kind: .folder,
            action: .trash(path: "/tmp/spacesweep-should-not-exist")
        )

        let report = await CleanupService().clean(items: [item], mode: .permanent) { _, _, _ in }
        #expect(report.failures.count == 1)
        #expect(report.deleted.isEmpty)
    }
}

@Suite("Scanner")
struct ScannerTests {
    @Test func directoryMeasurement() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceSweepMeasure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try Data(repeating: 1, count: 200_000).write(to: directory.appendingPathComponent("a.bin"))
        try Data(repeating: 2, count: 300_000).write(to: directory.appendingPathComponent("b.bin"))

        let measurement = DiskScanner().measure(directory)
        #expect(measurement != nil)
        #expect((measurement?.bytes ?? 0) >= 500_000)
        #expect(measurement?.fileCount == 2)
    }
}

@Suite("SF Symbols")
struct SymbolTests {
    @Test func categorySymbolsExist() {
        for category in CleanupCategory.allCases {
            #expect(
                NSImage(systemSymbolName: category.symbol, accessibilityDescription: nil) != nil,
                "Missing SF Symbol: \(category.symbol)"
            )
        }
        for level in SafetyLevel.allCases {
            #expect(NSImage(systemSymbolName: level.symbol, accessibilityDescription: nil) != nil)
        }
        for kind in [CleanableKind.folder, .file, .group, .command] {
            #expect(NSImage(systemSymbolName: kind.symbol, accessibilityDescription: nil) != nil)
        }
    }
}
