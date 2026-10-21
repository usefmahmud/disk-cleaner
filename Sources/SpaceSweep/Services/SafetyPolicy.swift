import Foundation

enum SafetyPolicy {
    static let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL

    private static let protectedNames: Set<String> = [
        ".Trash", "Desktop", "Documents", "Downloads", "Library", "Movies",
        "Music", "Pictures", "Public", "Applications", "System", "Users",
        ".ssh", ".gnupg", ".config", ".vscode", ".hermes"
    ]

    private static let protectedAbsolutePaths: Set<String> = [
        "/", "/System", "/Users", "/Applications", "/Library", "/private",
        "/private/var", "/private/etc", "/bin", "/sbin", "/usr", "/usr/bin",
        "/usr/local", "/opt"
    ]

    private static let removableTopLevelNames: Set<String> = [
        ".ollama", ".unsloth", ".omlx"
    ]

    enum Validation: Equatable {
        case allowed
        case blocked(String)

        var isAllowed: Bool { self == .allowed }
    }

    static func validateDeletionPath(_ path: String) -> Validation {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let target = url.path

        guard !target.isEmpty else {
            return .blocked("The path is empty.")
        }

        guard target != "/" else {
            return .blocked("The root volume can't be removed.")
        }

        if protectedAbsolutePaths.contains(target) {
            return .blocked("This is a protected system location.")
        }

        let homePath = home.path
        guard target.hasPrefix(homePath + "/") else {
            return .blocked("SpaceSweep only removes items inside your home folder.")
        }

        guard target != homePath else {
            return .blocked("Your home folder can't be removed.")
        }

        let relative = String(target.dropFirst(homePath.count + 1))
        let components = relative.split(separator: "/").map(String.init)

        if components.count == 1 {
            if removableTopLevelNames.contains(components[0]) {
                return .allowed
            }
            return .blocked("This top-level folder is too important to remove.")
        }

        if URL(fileURLWithPath: target).resolvingSymlinksInPath().path == "/" {
            return .blocked("This path resolves to the root volume.")
        }

        if target.hasSuffix("/.Trash") {
            return .blocked("The Trash folder itself can't be removed.")
        }

        return .allowed
    }

    static func validateCommand(_ spec: CommandSpec) -> Validation {
        let executable = spec.executable
        let blockedExecutables: Set<String> = ["rm", "rmdir", "sudo", "sh", "bash", "zsh", "dd", "mkfs", "diskutil"]
        if blockedExecutables.contains(executable) {
            return .blocked("SpaceSweep does not run raw removal commands.")
        }
        if spec.arguments.contains("--no-preserve-root") {
            return .blocked("Unsafe command arguments were rejected.")
        }
        return .allowed
    }
}

extension URL {
    var isInsideHome: Bool {
        standardizedFileURL.path.hasPrefix(SafetyPolicy.home.path + "/")
    }

    var relativeToHome: String {
        let path = standardizedFileURL.path
        let home = SafetyPolicy.home.path
        guard path.hasPrefix(home + "/") else { return path }
        return String(path.dropFirst(home.count + 1))
    }
}
