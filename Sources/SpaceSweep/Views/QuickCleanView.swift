import SwiftUI

struct QuickCleanView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if model.quickCleanRules.isEmpty {
                    emptyPreset
                } else {
                    summary
                    if model.quickCleanStaleCount > 0 {
                        staleBanner
                    }
                    rulesList
                    footer
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 26)
            .padding(.bottom, 34)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(DetailBackground())
    }

    private var header: some View {
        ScreenHeader(
            eyebrow: "One-Click Clean",
            title: "Your saved cleanup.",
            subtitle: "Pin the things you remove regularly, then clean them all at once."
        ) {
            Button {
                model.scan()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(model.isScanning)
        }
    }

    private var summary: some View {
        HStack(alignment: .center, spacing: 22) {
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.10))
                    .frame(width: 82, height: 82)
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.teal)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Ready to clean")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    let split = SizeFormatter.split(model.quickCleanSize)
                    Text(split.value)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(split.unit)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Text("\(selectedRuleCount) of \(model.quickCleanRules.count) saved items selected")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 9) {
                Button {
                    model.prepareQuickClean()
                } label: {
                    Label("Clean Now", systemImage: "sparkles")
                        .frame(minWidth: 110)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.hasScanned || model.quickCleanSelectedItems.isEmpty)

                HStack(spacing: 14) {
                    Button("Select All") {
                        model.selectAllQuickCleanRules()
                    }
                    Button("None") {
                        model.deselectAllQuickCleanRules()
                    }
                }
                .buttonStyle(.borderless)
                .font(.system(size: 10.5, weight: .medium))
            }
        }
        .cardSurface(padding: 22)
    }

    private var selectedRuleCount: Int {
        model.quickCleanEntries.filter {
            model.quickCleanSelectedIDs.contains($0.rule.id) && !$0.isStale
        }.count
    }

    private var rulesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Saved items")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if model.isScanning {
                    HStack(spacing: 5) {
                        ProgressView().controlSize(.mini)
                        Text("Updating sizes…")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { index, entry in
                    QuickCleanRow(entry: entry)
                    if index < sortedEntries.count - 1 {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.065), lineWidth: 1)
            )
        }
    }

    private var sortedEntries: [QuickCleanEntry] {
        model.quickCleanEntries.sorted { lhs, rhs in
            if lhs.isStale != rhs.isStale { return !lhs.isStale }
            return lhs.size > rhs.size
        }
    }

    private var staleBanner: some View {
        HStack(spacing: 11) {
            Image(systemName: "questionmark.folder.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(model.quickCleanStaleCount) saved item\(model.quickCleanStaleCount == 1 ? "" : "s") not found in this scan")
                    .font(.system(size: 12, weight: .semibold))
                Text("They may have been removed already. They are skipped when you clean.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Remove Missing") {
                model.removeStaleRules()
            }
            .controlSize(.small)
        }
        .padding(14)
        .background(Color.orange.opacity(0.075), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.17), lineWidth: 1)
        )
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Text("Saved items remember a location, not a fixed size. SpaceSweep rechecks them on every scan.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Clear All Saved Items") {
                model.clearRules()
                model.showToast("Cleared One-Click Clean.", symbol: "trash")
            }
            .buttonStyle(.borderless)
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private var emptyPreset: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.mint.opacity(0.24), .cyan.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.teal)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Build a preset once. Clean in one click.")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Choose the folders and caches you remove every time, and SpaceSweep will remember them for you.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                step(number: 1, text: "Open a category and tick the items you regularly remove.")
                step(number: 2, text: "Click the bookmark on a row to save it here. You can also select several and save them together.")
                step(number: 3, text: "Come back and press Clean Now. You still review everything before it is removed.")
            }

            HStack(spacing: 9) {
                Button {
                    model.selection = .caches
                } label: {
                    Label("Browse User Caches", systemImage: CleanupCategory.caches.symbol)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    model.selection = .aiModels
                } label: {
                    Label("Browse AI Models", systemImage: CleanupCategory.aiModels.symbol)
                }
                .buttonStyle(.bordered)

                Button {
                    model.selection = .largeFiles
                } label: {
                    Label("Browse Large Files", systemImage: CleanupCategory.largeFiles.symbol)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.regular)
        }
        .cardSurface(padding: 24)
    }

    private func step(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text("\(number)")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }
}

private struct QuickCleanRow: View {
    @EnvironmentObject private var model: AppModel
    let entry: QuickCleanEntry
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 11) {
            Button {
                model.toggleQuickClean(entry.rule.id)
            } label: {
                SelectionCheckbox(
                    isSelected: model.quickCleanSelectedIDs.contains(entry.rule.id),
                    accessibilityTitle: "Select \(entry.rule.name)"
                )
            }
            .buttonStyle(.plain)

            CategoryIcon(category: entry.rule.category, size: 29)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.rule.name)
                        .font(.system(size: 12.5, weight: .medium))
                        .lineLimit(1)
                    if entry.isStale {
                        CountBadge(text: "MISSING", tint: .orange)
                    }
                }
                Text(entry.isStale ? "Not found in the latest scan." : entry.rule.category.title)
                    .font(.system(size: 10.5))
                    .foregroundStyle(entry.isStale ? .orange : .secondary)
                if let path = entry.rule.path, !entry.isStale {
                    Text(path.replacingOccurrences(of: SafetyPolicy.home.path + "/", with: "~/"))
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.size > 0 ? SizeFormatter.string(entry.size) : "—")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(entry.isStale ? .tertiary : .primary)
                Text("saved \(SizeFormatter.string(entry.rule.sizeAtSave))")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Button {
                model.removeRule(id: entry.rule.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Color.primary.opacity(0.055), in: Circle())
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0.4)
            .help("Remove from One-Click Clean")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.primary.opacity(isHovering ? 0.025 : 0))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}
