import Foundation

enum ScanEvent: Sendable {
    case volume(VolumeInfo)
    case progress(label: String, fraction: Double)
    case items(category: CleanupCategory, items: [CleanableItem])
    case warning(String)
    case finished
}

struct DirectoryMeasurement: Sendable {
    var bytes: Int64
    var fileCount: Int
    var modified: Date?
}

struct DiskScanner: Sendable {
    typealias Emitter = @Sendable (ScanEvent) async -> Void

    let home: URL
    let settings: ScanSettings

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser, settings: ScanSettings = .default) {
        self.home = home.standardizedFileURL
        self.settings = settings
    }

    func scan(emit: @escaping Emitter) async {
        let volume = VolumeReader.read(at: home)
        await emit(.volume(volume))

        if Task.isCancelled { await emit(.finished); return }

        await scanLargeFiles(emit: emit)
        if Task.isCancelled { await emit(.finished); return }

        await scanDownloads(emit: emit)
        await scanTrash(emit: emit)
        await scanCaches(emit: emit)
        await scanDeveloper(emit: emit)
        await scanAIModels(emit: emit)
        await scanAppSupport(emit: emit)
        await scanContainers(emit: emit)
        await scanLogs(emit: emit)
        await scanDocker(emit: emit)
        await scanSnapshots(emit: emit)

        if !Task.isCancelled {
            await emit(.finished)
        }
    }

    // MARK: - Large files

    private func scanLargeFiles(emit: @escaping Emitter) async {
        let roots = largeFileRoots()

        var found: [CleanableItem] = []
        let threshold = settings.largeFileThreshold

        for (index, root) in roots.enumerated() {
            if Task.isCancelled { return }
            let progress = 0.02 + (Double(index) / Double(max(roots.count, 1))) * 0.18
            await emit(.progress(label: "Looking for large files in \(root.lastPathComponent)…", fraction: progress))
            found.append(contentsOf: largeFiles(in: root, threshold: threshold))
        }

        found.append(contentsOf: largeFilesAtHomeRoot(threshold: threshold))

        found.sort { $0.size > $1.size }
        if found.count > settings.maxLargeFiles {
            found = Array(found.prefix(settings.maxLargeFiles))
        }
        await emit(.items(category: .largeFiles, items: found))
    }

    private func largeFileRoots() -> [URL] {
        let excluded: Set<String> = [
            "Library", "Downloads", "Applications", "Public",
            ".Trash", ".cache", ".npm", ".bun", ".cargo", ".rustup",
            ".gradle", ".m2", ".ollama", ".unsloth", ".omlx", ".lmstudio",
            ".local", ".TemporaryItems", ".DocumentRevisions-V100"
        ]
        let preferred = ["Documents", "Desktop", "Movies", "Pictures"]

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: home,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let directories = contents.filter { url in
            guard !excluded.contains(url.lastPathComponent) else { return false }
            return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }

        return directories.sorted { lhs, rhs in
            let left = preferred.firstIndex(of: lhs.lastPathComponent) ?? preferred.count
            let right = preferred.firstIndex(of: rhs.lastPathComponent) ?? preferred.count
            if left != right { return left < right }
            return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }
    }

    private func largeFilesAtHomeRoot(threshold: Int64) -> [CleanableItem] {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .totalFileAllocatedSizeKey,
            .contentModificationDateKey
        ]
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: home,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true else {
                return nil
            }
            let size = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            guard size >= threshold else { return nil }
            return CleanableItem(
                name: url.lastPathComponent,
                category: .largeFiles,
                size: size,
                path: url.path,
                detail: "Home folder",
                safety: .caution,
                kind: .file,
                action: .trash(path: url.path),
                modified: values.contentModificationDate
            )
        }
    }

    private func largeFiles(in root: URL, threshold: Int64) -> [CleanableItem] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: root.path) else { return [] }

        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .totalFileAllocatedSizeKey,
            .contentModificationDateKey
        ]

        let skippedComponents: Set<String> = [
            "Library", "node_modules", ".git", ".cache", "Caches", "DerivedData",
            "Pods", ".build", "build", "target", "venv", ".venv", "__pycache__",
            "Photos Library.photoslibrary"
        ]

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        var results: [CleanableItem] = []
        for case let url as URL in enumerator {
            if results.count >= 1_500 { break }

            let components = Set(url.pathComponents)
            if !components.isDisjoint(with: skippedComponents) { continue }

            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true else {
                continue
            }

            let size = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            guard size >= threshold else { continue }

            results.append(CleanableItem(
                name: url.lastPathComponent,
                category: .largeFiles,
                size: size,
                path: url.path,
                detail: "\(url.deletingLastPathComponent().relativeToHome)",
                safety: .caution,
                kind: .file,
                action: .trash(path: url.path),
                modified: values.contentModificationDate
            ))
        }
        return results
    }

    // MARK: - Downloads

    private func scanDownloads(emit: @escaping Emitter) async {
        await emit(.progress(label: "Checking Downloads…", fraction: 0.22))
        let items = await childItems(
            in: KnownLocations.downloads,
            category: .downloads,
            safety: .caution,
            minSize: 20_000_000,
            name: { $0.lastPathComponent },
            detail: { _ in "Check that you still need this download." },
            emit: emit,
            progressBase: 0.22,
            progressSpan: 0.03,
            progressLabel: "Measuring Downloads…"
        )
        await emit(.items(category: .downloads, items: items))
    }

    // MARK: - Trash

    private func scanTrash(emit: @escaping Emitter) async {
        await emit(.progress(label: "Checking the Trash…", fraction: 0.26))
        let items = await childItems(
            in: KnownLocations.trash,
            category: .trash,
            safety: .safe,
            minSize: 1_000_000,
            name: { $0.lastPathComponent },
            detail: { _ in "Emptying the Trash is permanent." },
            emit: emit,
            progressBase: 0.26,
            progressSpan: 0.03,
            progressLabel: "Measuring Trash…"
        )
        await emit(.items(category: .trash, items: items))
    }

    // MARK: - Caches

    private func scanCaches(emit: @escaping Emitter) async {
        await emit(.progress(label: "Measuring app caches…", fraction: 0.30))

        var items: [CleanableItem] = []
        items.append(contentsOf: await childItems(
            in: KnownLocations.caches,
            category: .caches,
            safety: .safe,
            minSize: settings.minFolderSize,
            name: { KnownLocations.friendlyCacheName($0.lastPathComponent) },
            detail: { url in
                KnownLocations.isDeveloperCache(url)
                    ? "Developer cache · rebuilds on demand."
                    : "Rebuilds automatically when the app needs it."
            },
            excluding: { KnownLocations.isDeveloperCache($0) },
            emit: emit,
            progressBase: 0.30,
            progressSpan: 0.06,
            progressLabel: "Measuring Library caches…"
        ))

        items.append(contentsOf: await childItems(
            in: KnownLocations.dotCache,
            category: .caches,
            safety: .safe,
            minSize: settings.minFolderSize,
            name: { KnownLocations.friendlyCacheName($0.lastPathComponent) },
            detail: { _ in "Hidden user cache · rebuilds on demand." },
            excluding: { url in
                let name = url.lastPathComponent
                return name == "huggingface"
                    || name == "lm-studio"
                    || KnownLocations.isDeveloperCache(url)
            },
            emit: emit,
            progressBase: 0.36,
            progressSpan: 0.06,
            progressLabel: "Measuring hidden caches…"
        ))

        await emit(.items(category: .caches, items: items.sorted { $0.size > $1.size }))
    }

    // MARK: - Developer

    private func scanDeveloper(emit: @escaping Emitter) async {
        await emit(.progress(label: "Measuring developer caches…", fraction: 0.44))

        let paths = KnownLocations.developerCachePaths
        var items: [CleanableItem] = []

        for (index, url) in paths.enumerated() {
            if Task.isCancelled { return }
            guard let measurement = measure(url), measurement.bytes >= 1_000_000 else { continue }
            let name = developerName(for: url)
            items.append(CleanableItem(
                name: name,
                category: .developer,
                size: measurement.bytes,
                path: url.path,
                detail: developerDetail(for: url),
                safety: developerSafety(for: url),
                kind: url.hasDirectoryPath ? .folder : .file,
                action: .trash(path: url.path),
                modified: measurement.modified
            ))

            let fraction = 0.44 + (Double(index) / Double(max(paths.count, 1))) * 0.10
            await emit(.progress(label: "Measuring \(name)…", fraction: fraction))
        }

        await emit(.items(category: .developer, items: items.sorted { $0.size > $1.size }))
    }

    private func developerName(for url: URL) -> String {
        switch url.lastPathComponent {
        case "DerivedData": return "Xcode Derived Data"
        case "Archives": return "Xcode Archives"
        case "iOS DeviceSupport": return "iOS Device Support"
        case "Previews": return "Xcode Previews"
        case "Devices": return "Simulator devices"
        case "Caches" where url.path.contains("CoreSimulator"): return "Simulator caches"
        case "Homebrew": return "Homebrew downloads"
        case "ms-playwright": return "Playwright browsers"
        case "pnpm": return "pnpm package cache"
        case "node-gyp": return "node-gyp headers"
        case "typescript": return "TypeScript cache"
        case "yarn": return "Yarn cache"
        case "Cypress": return "Cypress binaries"
        case "puppeteer": return "Puppeteer browsers"
        case "electron": return "Electron downloads"
        case "_cacache": return "npm cache"
        case "install" where url.path.contains(".bun"): return "Bun package cache"
        case "cache" where url.path.contains(".cargo"): return "Cargo registry cache"
        case "src" where url.path.contains(".cargo"): return "Cargo registry sources"
        case "downloads" where url.path.contains(".rustup"): return "Rust toolchain downloads"
        case "m2", "repository": return "Maven repository"
        case "gradle", "caches": return "Gradle cache"
        case "Code", "Cursor":
            return url.lastPathComponent == "Code" ? "VS Code cache" : "Cursor cache"
        case "Cache", "CachedData", "CachedExtensionVSIXs":
            return "Editor cache"
        default:
            if url.path.contains("com.apple.dt.Xcode") { return "Xcode cache" }
            return url.lastPathComponent
        }
    }

    private func developerDetail(for url: URL) -> String {
        if url.path.contains("Xcode/Archives") {
            return "App Store archives. Export anything you want to keep."
        }
        if url.path.contains("CoreSimulator/Devices") {
            return "Deletes simulators and their installed apps. Create them again with Xcode."
        }
        if url.path.contains("iOS DeviceSupport") {
            return "Debug symbols. macOS restores them the next time you connect a device."
        }
        if url.path.contains(".m2") {
            return "Maven downloads. Builds fetch them again."
        }
        return "Rebuilds on demand. Nothing you created is lost."
    }

    private func developerSafety(for url: URL) -> SafetyLevel {
        if url.path.contains("Xcode/Archives") { return .caution }
        if url.path.contains("CoreSimulator/Devices") { return .risky }
        if url.path.contains(".cargo/registry/src") { return .caution }
        if url.path.contains(".m2/repository") { return .caution }
        return .safe
    }

    // MARK: - AI models

    private func scanAIModels(emit: @escaping Emitter) async {
        await emit(.progress(label: "Looking for local AI models…", fraction: 0.54))
        var items: [CleanableItem] = []

        // Hugging Face hub children
        items.append(contentsOf: await childItems(
            in: KnownLocations.huggingFaceHub,
            category: .aiModels,
            safety: .safe,
            minSize: 2_000_000,
            name: { HuggingFaceParser.displayName(for: $0.lastPathComponent).name },
            detail: { url in
                "\(HuggingFaceParser.displayName(for: url.lastPathComponent).detail) · re-downloads on demand."
            },
            emit: emit,
            progressBase: 0.54,
            progressSpan: 0.08,
            progressLabel: "Measuring Hugging Face cache…"
        ))

        // Other Hugging Face folders, such as xet, next to hub
        items.append(contentsOf: await childItems(
            in: KnownLocations.huggingFace,
            category: .aiModels,
            safety: .safe,
            minSize: 5_000_000,
            name: { HuggingFaceParser.displayName(for: $0.lastPathComponent).name },
            detail: { url in HuggingFaceParser.displayName(for: url.lastPathComponent).detail },
            excluding: { $0.lastPathComponent == "hub" },
            emit: emit,
            progressBase: 0.62,
            progressSpan: 0.03,
            progressLabel: "Checking Hugging Face extras…"
        ))

        // Ollama models, preferably through the CLI
        if let ollamaItems = await ollamaItems(), !ollamaItems.isEmpty {
            items.append(contentsOf: ollamaItems)
        } else if let size = measure(KnownLocations.ollama)?.bytes, size > 10_000_000 {
            items.append(CleanableItem(
                name: "Ollama models",
                category: .aiModels,
                size: size,
                path: KnownLocations.ollama.path,
                detail: "Local model store. Remove models with `ollama rm <model>`.",
                safety: .caution,
                kind: .folder,
                action: .trash(path: KnownLocations.ollama.path),
                modified: measure(KnownLocations.ollama)?.modified
            ))
        }

        // LM Studio
        let lmStudioRoot = FileManager.default.fileExists(atPath: KnownLocations.lmStudio.path)
            ? KnownLocations.lmStudio
            : KnownLocations.lmStudioCache
        items.append(contentsOf: await childItems(
            in: lmStudioRoot,
            category: .aiModels,
            safety: .safe,
            minSize: 5_000_000,
            name: { $0.lastPathComponent },
            detail: { _ in "LM Studio model cache." },
            emit: emit,
            progressBase: 0.66,
            progressSpan: 0.03,
            progressLabel: "Measuring LM Studio models…"
        ))

        for root in [KnownLocations.unsloth, KnownLocations.omlx] {
            items.append(contentsOf: await childItems(
                in: root,
                category: .aiModels,
                safety: .caution,
                minSize: 5_000_000,
                name: { $0.lastPathComponent },
                detail: { _ in "Local model or training cache." },
                emit: emit,
                progressBase: 0.69,
                progressSpan: 0.03,
                progressLabel: "Measuring \(root.lastPathComponent)…"
            ))
        }

        await emit(.items(category: .aiModels, items: items.sorted { $0.size > $1.size }))
    }

    private func ollamaItems() async -> [CleanableItem]? {
        guard Shell.findExecutable("ollama") != nil else { return nil }
        guard let result = await Shell.runCapturing("ollama", arguments: ["list"], timeout: 12),
              result.succeeded else {
            return nil
        }

        return OllamaParser.parseList(result.stdout).map { model in
            CleanableItem(
                name: model.name,
                category: .aiModels,
                size: model.size,
                path: nil,
                detail: "Removed with `ollama rm \(model.name)`.",
                safety: .safe,
                kind: .command,
                action: .command(CommandSpec("ollama", ["rm", model.name]))
            )
        }
    }

    // MARK: - App Support

    private func scanAppSupport(emit: @escaping Emitter) async {
        await emit(.progress(label: "Measuring Application Support…", fraction: 0.72))
        let items = await childItems(
            in: KnownLocations.applicationSupport,
            category: .appSupport,
            safety: .caution,
            minSize: settings.minFolderSize,
            name: { KnownLocations.friendlyApplicationName($0.lastPathComponent) },
            detail: { url in
                let name = KnownLocations.friendlyApplicationName(url.lastPathComponent)
                if url.lastPathComponent == "MobileSync" {
                    return "iPhone and iPad backups. These can't be recreated without the device."
                }
                if url.lastPathComponent == "com.docker.install" {
                    return "Docker installer leftovers. Safe to remove."
                }
                return "Quit \(name) first. Contains app settings, data, or caches."
            },
            emit: emit,
            progressBase: 0.72,
            progressSpan: 0.08,
            progressLabel: "Measuring app data…"
        )

        let adjusted = items.map { item -> CleanableItem in
            guard let name = item.path.map({ URL(fileURLWithPath: $0).lastPathComponent }) else {
                return item
            }
            var copy = item
            switch name {
            case "com.docker.install":
                copy.safety = .safe
            case "MobileSync":
                copy.safety = .risky
            case "sklauncher":
                copy.safety = .risky
                copy.detail = "Minecraft launcher data. Back up worlds before removing."
            case "Code", "JetBrains", "discord":
                copy.safety = .caution
            default:
                break
            }
            return copy
        }
        await emit(.items(category: .appSupport, items: adjusted))
    }

    // MARK: - Containers

    private func scanContainers(emit: @escaping Emitter) async {
        await emit(.progress(label: "Checking app containers…", fraction: 0.81))
        let items = await childItems(
            in: KnownLocations.containers,
            category: .containers,
            safety: .caution,
            minSize: settings.minFolderSize,
            name: { $0.lastPathComponent.replacingOccurrences(of: "com.", with: "") },
            detail: { _ in "Sandboxed app data. Quit the app before removing." },
            excluding: { KnownLocations.containerExclusions.contains($0.standardizedFileURL.path) },
            emit: emit,
            progressBase: 0.81,
            progressSpan: 0.05,
            progressLabel: "Measuring containers…"
        )
        await emit(.items(category: .containers, items: items))
    }

    // MARK: - Logs

    private func scanLogs(emit: @escaping Emitter) async {
        await emit(.progress(label: "Checking logs and crash reports…", fraction: 0.87))

        var items: [CleanableItem] = []
        for (index, root) in [KnownLocations.logs, KnownLocations.diagnosticReports].enumerated() {
            items.append(contentsOf: await childItems(
                in: root,
                category: .logs,
                safety: .safe,
                minSize: 1_000_000,
                name: { $0.lastPathComponent },
                detail: { _ in "Diagnostic data. Safe to remove." },
                emit: emit,
                progressBase: 0.87 + Double(index) * 0.015,
                progressSpan: 0.015,
                progressLabel: "Measuring \(root.lastPathComponent)…"
            ))
        }

        await emit(.items(category: .logs, items: items.sorted { $0.size > $1.size }))
    }

    // MARK: - Docker

    private func scanDocker(emit: @escaping Emitter) async {
        await emit(.progress(label: "Asking Docker what it can reclaim…", fraction: 0.91))
        guard Shell.findExecutable("docker") != nil else {
            await emit(.items(category: .docker, items: []))
            return
        }

        guard let result = await Shell.runCapturing(
            "docker",
            arguments: ["system", "df", "--format", "{{json .}}"],
            timeout: 15
        ), result.succeeded else {
            await emit(.items(category: .docker, items: []))
            return
        }

        let resources = DockerParser.parseSystemDFJSON(result.stdout)
        let items = resources.compactMap { resource -> CleanableItem? in
            guard resource.reclaimable > 0 else { return nil }
            let definition = dockerDefinition(for: resource.type)
            return CleanableItem(
                name: definition.name,
                category: .docker,
                size: resource.reclaimable,
                path: nil,
                detail: "\(SizeFormatter.string(resource.size)) total · \(resource.reclaimableLabel) reclaimable · \(definition.detail)",
                safety: definition.safety,
                kind: .command,
                action: .command(CommandSpec("docker", definition.arguments)),
                childCount: resource.totalCount
            )
        }

        await emit(.items(category: .docker, items: items))
    }

    private func dockerDefinition(for type: String) -> (name: String, detail: String, arguments: [String], safety: SafetyLevel) {
        switch type.lowercased() {
        case "images":
            return ("Unused images", "Runs `docker image prune -a -f`.", ["image", "prune", "-a", "-f"], .caution)
        case "containers":
            return ("Stopped containers", "Runs `docker container prune -f`.", ["container", "prune", "-f"], .caution)
        case "local volumes":
            return ("Unused volumes", "Runs `docker volume prune -f`. Volumes can hold database data.", ["volume", "prune", "-f"], .risky)
        case "build cache":
            return ("Build cache", "Runs `docker builder prune -f`.", ["builder", "prune", "-f"], .safe)
        default:
            return (type, "Reclaimed with Docker.", ["system", "prune", "-f"], .caution)
        }
    }

    // MARK: - Time Machine snapshots

    private func scanSnapshots(emit: @escaping Emitter) async {
        await emit(.progress(label: "Checking local Time Machine snapshots…", fraction: 0.94))
        guard Shell.findExecutable("tmutil") != nil,
              let result = await Shell.runCapturing("tmutil", arguments: ["listlocalsnapshots", "/"], timeout: 12),
              result.succeeded else {
            await emit(.items(category: .snapshots, items: []))
            return
        }

        let dates = SnapshotParser.parseSnapshots(result.stdout)
        let items = dates.map { date in
            CleanableItem(
                name: SnapshotParser.displayDate(date),
                category: .snapshots,
                size: 0,
                path: nil,
                detail: "Deleting a local snapshot asks for an administrator password.",
                safety: .safe,
                kind: .command,
                action: .command(CommandSpec("tmutil", ["deletelocalsnapshots", date], requiresAdmin: true))
            )
        }
        await emit(.items(category: .snapshots, items: items))
    }

    // MARK: - Helpers

    private func childItems(
        in directory: URL,
        category: CleanupCategory,
        safety: SafetyLevel,
        minSize: Int64,
        name: @escaping (URL) -> String,
        detail: @escaping (URL) -> String,
        excluding: ((URL) -> Bool)? = nil,
        emit: @escaping Emitter,
        progressBase: Double,
        progressSpan: Double,
        progressLabel: String
    ) async -> [CleanableItem] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else { return [] }

        let children: [URL]
        do {
            children = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: []
            ).filter { url in
                guard excluding?(url) != true else { return false }
                if let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]),
                   values.isSymbolicLink == true {
                    return false
                }
                return true
            }
        } catch {
            await emit(.warning("Couldn't read \(directory.path). Grant Full Disk Access to scan it."))
            return []
        }

        guard !children.isEmpty else { return [] }

        var items: [CleanableItem] = []
        for (index, child) in children.enumerated() {
            if Task.isCancelled { return items }
            guard let measurement = measure(child), measurement.bytes >= minSize else { continue }
            let isDirectory = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            items.append(CleanableItem(
                name: name(child),
                category: category,
                size: measurement.bytes,
                path: child.path,
                detail: detail(child),
                safety: safety,
                kind: isDirectory ? .folder : .file,
                action: .trash(path: child.path),
                modified: measurement.modified,
                childCount: measurement.fileCount
            ))

            if index % 4 == 0 {
                let fraction = progressBase + (Double(index) / Double(children.count)) * progressSpan
                await emit(.progress(label: progressLabel, fraction: fraction))
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    func measure(_ url: URL) -> DirectoryMeasurement? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .contentModificationDateKey
        ]

        guard let rootValues = try? url.resourceValues(forKeys: keys) else { return nil }

        if rootValues.isDirectory != true {
            let bytes = Int64(rootValues.totalFileAllocatedSize ?? rootValues.fileSize ?? 0)
            return DirectoryMeasurement(bytes: bytes, fileCount: 1, modified: rootValues.contentModificationDate)
        }

        var total: Int64 = 0
        var count = 0
        var newest = rootValues.contentModificationDate

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return DirectoryMeasurement(bytes: 0, fileCount: 0, modified: rootValues.contentModificationDate)
        }

        for case let fileURL as URL in enumerator {
            if Task.isCancelled { break }
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isSymbolicLink != true else {
                continue
            }

            if values.isRegularFile == true {
                total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
                count += 1
                if let date = values.contentModificationDate, date > (newest ?? .distantPast) {
                    newest = date
                }
            }
        }

        return DirectoryMeasurement(bytes: total, fileCount: count, modified: newest)
    }
}
