import Foundation

enum RemovalMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case trash
    case permanent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trash: return "Move to Trash"
        case .permanent: return "Delete Permanently"
        }
    }

    var symbol: String {
        switch self {
        case .trash: return "trash"
        case .permanent: return "trash.slash"
        }
    }
}

struct CleanupService: Sendable {
    typealias Progress = @Sendable (_ completed: Int, _ total: Int, _ name: String) async -> Void

    func clean(
        items: [CleanableItem],
        mode: RemovalMode,
        progress: @escaping Progress
    ) async -> CleanupReport {
        let fileManager = FileManager.default
        var trashed: [CleanableItem] = []
        var deleted: [CleanableItem] = []
        var commands: [CleanableItem] = []
        var failures: [CleanupFailure] = []
        var reclaimed: Int64 = 0

        for (index, item) in items.enumerated() {
            if Task.isCancelled { break }
            await progress(index, items.count, item.name)

            switch item.action {
            case .trash(let path):
                let validation = SafetyPolicy.validateDeletionPath(path)
                guard validation.isAllowed else {
                    if case .blocked(let reason) = validation {
                        failures.append(CleanupFailure(itemName: item.name, message: reason))
                    }
                    continue
                }

                guard fileManager.fileExists(atPath: path) else {
                    failures.append(CleanupFailure(itemName: item.name, message: "The item no longer exists."))
                    continue
                }

                let isTrashItem = URL(fileURLWithPath: path).standardizedFileURL.path.hasPrefix(KnownLocations.trash.path + "/")
                let effectiveMode: RemovalMode = isTrashItem ? .permanent : mode

                do {
                    if effectiveMode == .trash {
                        try fileManager.trashItem(
                            at: URL(fileURLWithPath: path),
                            resultingItemURL: nil
                        )
                        trashed.append(item)
                    } else {
                        try fileManager.removeItem(atPath: path)
                        deleted.append(item)
                    }
                    reclaimed += item.size
                } catch {
                    failures.append(CleanupFailure(
                        itemName: item.name,
                        message: error.localizedDescription
                    ))
                }

            case .command(let spec):
                let validation = SafetyPolicy.validateCommand(spec)
                guard validation.isAllowed else {
                    if case .blocked(let reason) = validation {
                        failures.append(CleanupFailure(itemName: item.name, message: reason))
                    }
                    continue
                }

                do {
                    let result = try await Shell.run(
                        spec.executable,
                        arguments: spec.arguments,
                        requiresAdmin: spec.requiresAdmin,
                        timeout: 180
                    )
                    if result.succeeded {
                        commands.append(item)
                        reclaimed += item.size
                    } else {
                        let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                        failures.append(CleanupFailure(
                            itemName: item.name,
                            message: message.isEmpty ? "The command exited with an error." : message
                        ))
                    }
                } catch {
                    failures.append(CleanupFailure(
                        itemName: item.name,
                        message: error.localizedDescription
                    ))
                }
            }
        }

        await progress(items.count, items.count, "")

        return CleanupReport(
            movedToTrash: trashed,
            deleted: deleted,
            commandsRun: commands,
            failures: failures,
            reclaimed: reclaimed
        )
    }
}
