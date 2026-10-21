import AppKit
import SwiftUI

struct CleanupSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var permanentConfirmed = false

    var body: some View {
        VStack(spacing: 0) {
            if let report = model.cleanupReport {
                resultView(report)
            } else if model.isCleaning {
                progressView
            } else {
                confirmView
            }
        }
        .frame(width: 620)
        .frame(minHeight: 430)
        .background(Color(nsColor: .windowBackgroundColor))
        .interactiveDismissDisabled(model.isCleaning)
        .onChange(of: model.cleanupMode) { _, _ in
            permanentConfirmed = false
        }
    }

    // MARK: - Confirmation

    private var confirmView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.10))
                        .frame(width: 46, height: 46)
                    Image(systemName: model.cleanupMode == .permanent ? "trash.slash" : "trash")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("\(model.cleanupItems.count) item\(model.cleanupItems.count == 1 ? "" : "s") · \(SizeFormatter.string(cleanupSize))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    model.dismissCleanup()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.primary.opacity(0.055), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 18)

            itemGroups
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 14) {
                if hasPathActions {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("REMOVAL METHOD")
                            .font(.system(size: 9.5, weight: .bold))
                            .tracking(0.7)
                            .foregroundStyle(.secondary)

                        Picker("Removal method", selection: $model.cleanupMode) {
                            ForEach(RemovalMode.allCases) { mode in
                                Label(mode.title, systemImage: mode.symbol).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }

                if model.cleanupMode == .permanent && hasPathActions {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                            Text("Permanent deletion skips the Trash and cannot be undone. Tool cleanups always run directly.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Toggle("I understand these items cannot be recovered.", isOn: $permanentConfirmed)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.red.opacity(0.16), lineWidth: 1)
                    )
                }

                if commandCount > 0 {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.blue)
                        Text(commandNote)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(11)
                    .background(Color.blue.opacity(0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if trashItemCount > 0 {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "trash.slash.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Text("\(trashItemCount) item\(trashItemCount == 1 ? "" : "s") already in the Trash will be deleted permanently.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer(minLength: 18)

            Divider()

            HStack {
                Text("Nothing is removed until you confirm.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Cancel") {
                    model.dismissCleanup()
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)

                Button(action: {
                    model.runCleanup()
                }) {
                    Label(actionTitle, systemImage: model.cleanupMode == .permanent && hasPathActions ? "trash.slash" : "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .controlSize(.large)
                .disabled(!canConfirm)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.bar)
        }
    }

    private var itemGroups: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(groups) { group in
                    VStack(spacing: 0) {
                        HStack(spacing: 7) {
                            CategoryIcon(category: group.category, size: 20)
                            Text(group.category.title)
                                .font(.system(size: 11, weight: .semibold))
                            Spacer()
                            Text(SizeFormatter.string(group.size))
                                .font(.system(size: 10.5, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)

                        ForEach(group.items) { item in
                            HStack(spacing: 8) {
                                Image(systemName: item.kind.symbol)
                                    .font(.system(size: 9))
                                    .foregroundStyle(group.category.accent)
                                    .frame(width: 13)
                                Text(item.name)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                if item.safety != .safe {
                                    Image(systemName: item.safety.symbol)
                                        .font(.system(size: 9))
                                        .foregroundStyle(item.safety.color)
                                }
                                Spacer()
                                Text(item.size > 0 ? SizeFormatter.string(item.size) : "—")
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                        }
                    }
                    .background(Color.primary.opacity(0.028), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
            .padding(2)
        }
        .frame(maxHeight: 218)
        .overlay(alignment: .bottom) {
            if groups.count > 2 {
                LinearGradient(
                    colors: [Color(nsColor: .windowBackgroundColor).opacity(0), Color(nsColor: .windowBackgroundColor)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 20)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Progress

    private var progressView: some View {
        VStack(spacing: 22) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.09))
                    .frame(width: 86, height: 86)
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 6) {
                Text("Making room…")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                Text("\(model.cleanupItems.count) items · \(SizeFormatter.string(cleanupSize))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 7) {
                ProgressView(value: model.cleanupProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 330)
                Text(model.cleanupProgressLabel.isEmpty ? "Finishing up…" : model.cleanupProgressLabel)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 360)
            }

            Text("Keep SpaceSweep open while this finishes.")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }

    // MARK: - Result

    private func resultView(_ report: CleanupReport) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 26)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill((report.hasFailures ? Color.orange : Color.green).opacity(0.10))
                        .frame(width: 78, height: 78)
                    Image(systemName: report.hasFailures ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(report.hasFailures ? .orange : .green)
                }

                VStack(spacing: 4) {
                    if report.reclaimed > 0 {
                        Text("Freed \(SizeFormatter.string(report.reclaimed))")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                    } else {
                        Text("Cleanup finished")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                    }
                    Text(resultSubtitle(report))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if !report.movedToTrash.isEmpty || !report.deleted.isEmpty || !report.commandsRun.isEmpty {
                    HStack(spacing: 18) {
                        if !report.movedToTrash.isEmpty {
                            resultStat(
                                value: report.movedToTrash.count,
                                label: "moved to Trash",
                                symbol: "trash"
                            )
                        }
                        if !report.deleted.isEmpty {
                            resultStat(
                                value: report.deleted.count,
                                label: "deleted",
                                symbol: "trash.slash"
                            )
                        }
                        if !report.commandsRun.isEmpty {
                            resultStat(
                                value: report.commandsRun.count,
                                label: "tool cleanups",
                                symbol: "terminal"
                            )
                        }
                    }
                    .padding(.top, 4)
                }

                if report.hasFailures {
                    DisclosureGroup("\(report.failures.count) item\(report.failures.count == 1 ? "" : "s") couldn't be cleaned") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(report.failures) { failure in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(failure.itemName)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(failure.message)
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.top, 7)
                    }
                    .frame(width: 420)
                    .padding(12)
                    .background(Color.orange.opacity(0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.horizontal, 26)

            Spacer(minLength: 26)

            Divider()

            HStack {
                if !report.movedToTrash.isEmpty {
                    Button("Open Trash") {
                        NSWorkspace.shared.open(KnownLocations.trash)
                    }
                }
                Spacer()
                Button("Scan Again") {
                    model.dismissCleanup()
                    model.scan()
                }
                .controlSize(.large)

                Button("Done") {
                    model.dismissCleanup()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.bar)
        }
    }

    private func resultStat(value: Int, label: String, symbol: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10))
                Text("\(value)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            Text(label)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func resultSubtitle(_ report: CleanupReport) -> String {
        if report.hasFailures {
            return "\(report.totalSucceeded) succeeded · \(report.failures.count) skipped"
        }
        return "\(report.totalSucceeded) item\(report.totalSucceeded == 1 ? "" : "s") cleaned"
    }

    // MARK: - Derived

    private var cleanupSize: Int64 {
        model.cleanupItems.reduce(0) { $0 + $1.size }
    }

    private var groups: [CleanupGroup] {
        let grouped = Dictionary(grouping: model.cleanupItems, by: \.category)
        return CleanupCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return CleanupGroup(
                category: category,
                items: items.sorted { $0.size > $1.size },
                size: items.reduce(0) { $0 + $1.size }
            )
        }
    }

    private var hasPathActions: Bool {
        model.cleanupItems.contains { !$0.action.isCommand }
    }

    private var commandCount: Int {
        model.cleanupItems.filter(\.action.isCommand).count
    }

    private var commandNote: String {
        if commandCount == model.cleanupItems.count {
            return "This cleanup runs directly through the tool that owns the data. There is no Trash copy."
        }
        return "\(commandCount) item\(commandCount == 1 ? "" : "s") use tool commands (Docker, Ollama, or Time Machine). Those always run directly."
    }

    private var trashItemCount: Int {
        model.cleanupItems.filter { $0.category == .trash }.count
    }

    private var title: String {
        if model.cleanupMode == .permanent && hasPathActions {
            return "Delete \(SizeFormatter.string(cleanupSize))?"
        }
        return "Clean \(SizeFormatter.string(cleanupSize))?"
    }

    private var actionTitle: String {
        if !hasPathActions {
            return "Run Cleanup"
        }
        switch model.cleanupMode {
        case .trash: return "Move to Trash"
        case .permanent: return "Delete Permanently"
        }
    }

    private var canConfirm: Bool {
        guard !model.cleanupItems.isEmpty else { return false }
        if hasPathActions && model.cleanupMode == .permanent {
            return permanentConfirmed
        }
        return true
    }

    private var accent: Color {
        if hasPathActions && model.cleanupMode == .permanent {
            return .red
        }
        return .accentColor
    }
}

private struct CleanupGroup: Identifiable {
    var category: CleanupCategory
    var items: [CleanableItem]
    var size: Int64

    var id: CleanupCategory { category }
}
