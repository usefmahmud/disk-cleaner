import AppKit
import Foundation

enum PermissionChecker {
    static func hasFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let probes = [
            home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db"),
            home.appendingPathComponent("Library/Mail"),
            home.appendingPathComponent("Library/Safari")
        ]

        for probe in probes {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: probe.path, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                if (try? FileManager.default.contentsOfDirectory(atPath: probe.path)) != nil {
                    return true
                }
            } else if let handle = try? FileHandle(forReadingFrom: probe) {
                try? handle.close()
                return true
            }
        }

        return false
    }

    static func openFullDiskAccessSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
        ]
        for string in urls {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    static func revealInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func open(path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
}
