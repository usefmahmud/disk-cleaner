import Foundation

enum KnownLocations {
    static let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL

    static func path(_ relative: String) -> URL {
        home.appendingPathComponent(relative, isDirectory: true)
    }

    static let library = path("Library")
    static let caches = path("Library/Caches")
    static let applicationSupport = path("Library/Application Support")
    static let containers = path("Library/Containers")
    static let groupContainers = path("Library/Group Containers")
    static let logs = path("Library/Logs")
    static let diagnosticReports = path("Library/DiagnosticReports")
    static let trash = path(".Trash")
    static let downloads = path("Downloads")
    static let documents = path("Documents")
    static let desktop = path("Desktop")
    static let movies = path("Movies")
    static let pictures = path("Pictures")
    static let dotCache = path(".cache")
    static let huggingFace = path(".cache/huggingface")
    static let huggingFaceHub = path(".cache/huggingface/hub")
    static let ollama = path(".ollama")
    static let lmStudio = path(".lmstudio/models")
    static let lmStudioCache = path(".cache/lm-studio")
    static let unsloth = path(".unsloth")
    static let omlx = path(".omlx")

    static let developerCachePaths: [URL] = [
        path("Library/Developer/Xcode/DerivedData"),
        path("Library/Developer/Xcode/Archives"),
        path("Library/Developer/Xcode/iOS DeviceSupport"),
        path("Library/Developer/Xcode/UserData/Previews"),
        path("Library/Developer/CoreSimulator/Caches"),
        path("Library/Developer/CoreSimulator/Devices"),
        path("Library/Caches/Homebrew"),
        path("Library/Caches/ms-playwright"),
        path("Library/Caches/pnpm"),
        path("Library/Caches/node-gyp"),
        path("Library/Caches/typescript"),
        path("Library/Caches/yarn"),
        path("Library/Caches/Cypress"),
        path("Library/Caches/puppeteer"),
        path("Library/Caches/electron"),
        path("Library/Caches/com.apple.dt.Xcode"),
        path(".npm/_cacache"),
        path(".bun/install/cache"),
        path(".cargo/registry/cache"),
        path(".cargo/registry/src"),
        path(".rustup/downloads"),
        path(".gradle/caches"),
        path(".m2/repository"),
        path("Library/Application Support/Code/Cache"),
        path("Library/Application Support/Code/CachedData"),
        path("Library/Application Support/Code/CachedExtensionVSIXs"),
        path("Library/Application Support/Cursor/Cache"),
        path("Library/Application Support/Cursor/CachedData")
    ]

    static let aiPaths: [URL] = [
        huggingFace,
        huggingFaceHub,
        ollama,
        lmStudio,
        lmStudioCache,
        unsloth,
        omlx
    ]

    static let cacheExclusions: Set<String> = Set(developerCachePaths.map(\.standardizedFileURL.path))

    static let containerExclusions: Set<String> = [
        path("Library/Containers/com.docker.docker").path
    ]

    static let applicationNames: [String: String] = [
        "Code": "Visual Studio Code",
        "discord": "Discord",
        "com.docker.install": "Docker installer leftovers",
        "MobileSync": "iPhone & iPad backups",
        "Open Design": "Open Design",
        "sklauncher": "SKLauncher (Minecraft)",
        "JetBrains": "JetBrains IDEs",
        "Arc": "Arc Browser",
        "Figma": "Figma",
        "Slack": "Slack",
        "Spotify": "Spotify",
        "Steam": "Steam",
        "zoom.us": "Zoom",
        "Notion": "Notion",
        "Postman": "Postman",
        "Adobe": "Adobe apps",
        "Google": "Google apps",
        "Signal": "Signal",
        "BraveSoftware": "Brave Browser",
        "Microsoft": "Microsoft apps",
        "com.apple": "Apple apps"
    ]

    static let cacheNames: [String: String] = [
        "Homebrew": "Homebrew downloads",
        "ms-playwright": "Playwright browsers",
        "pnpm": "pnpm package cache",
        "node-gyp": "node-gyp headers",
        "typescript": "TypeScript cache",
        "yarn": "Yarn cache",
        "Cypress": "Cypress binaries",
        "puppeteer": "Puppeteer browsers",
        "electron": "Electron downloads",
        "pip": "pip cache",
        "com.figma.Desktop": "Figma cache",
        "com.microsoft.VSCode": "Visual Studio Code cache",
        "Docker Desktop": "Docker Desktop cache",
        "Arc": "Arc cache",
        "Adobe": "Adobe cache",
        "Google": "Google cache",
        "Firefox": "Firefox cache",
        "JetBrains": "JetBrains cache",
        "com.apple.Safari": "Safari cache",
        "com.apple.dt.Xcode": "Xcode cache",
        "opencode": "OpenCode cache",
        "uv": "uv package cache",
        "bun": "Bun cache"
    ]

    static func friendlyApplicationName(_ name: String) -> String {
        applicationNames[name] ?? name
    }

    static func friendlyCacheName(_ name: String) -> String {
        cacheNames[name] ?? name
    }

    static func isDeveloperCache(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return developerCachePaths.contains { developer in
            let developerPath = developer.standardizedFileURL.path
            return path == developerPath || path.hasPrefix(developerPath + "/")
        }
    }

    static func isOllamaModelStore(_ url: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(ollama.path + "/")
    }
}
