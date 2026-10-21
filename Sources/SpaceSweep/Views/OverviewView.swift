import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var model: AppModel

    private let columns = [
        GridItem(.adaptive(minimum: 238, maximum: 360), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if !model.hasFullDiskAccess {
                    PermissionBanner()
                }

                hero
                quickCleanCard
                categorySection
                safetyNote
            }
            .padding(.horizontal, 28)
            .padding(.top, 26)
            .padding(.bottom, 34)
            .frame(maxWidth: 1080)
            .frame(maxWidth: .infinity)
        }
        .background(DetailBackground())
    }

    private var header: some View {
        ScreenHeader(
            eyebrow: "Storage overview",
            title: "Make room, keep what matters.",
            subtitle: model.scanStatusText
        ) {
            Button {
                if model.isScanning {
                    model.cancelScan()
                } else {
                    model.scan()
                }
            } label: {
                Label(
                    model.isScanning ? "Cancel Scan" : (model.hasScanned ? "Scan Again" : "Scan Now"),
                    systemImage: model.isScanning ? "xmark" : "arrow.clockwise"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 30) {
            VStack(alignment: .leading, spacing: 14) {
                Text("YOU CAN RECLAIM")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(.secondary)

                let split = SizeFormatter.split(model.totalReclaimable)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(model.isScanning && model.totalReclaimable == 0 ? "—" : split.value)
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(model.isScanning && model.totalReclaimable == 0 ? "" : split.unit)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Text(summaryLine)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 9) {
                    if model.selectedCount > 0 {
                        Button {
                            model.prepareSelectedCleanup()
                        } label: {
                            Label("Review \(model.selectedCount) selected", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else if model.pinnedCount > 0 {
                        Button {
                            model.prepareQuickClean()
                        } label: {
                            Label("Run One-Click Clean", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!model.hasScanned || model.quickCleanSelectedItems.isEmpty)
                    } else {
                        Button {
                            model.scan()
                        } label: {
                            Label(model.hasScanned ? "Scan Again" : "Scan My Mac", systemImage: "magnifyingglass")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(model.isScanning)
                    }

                    Text("\(model.totalItemCount) items found")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 10)

            VStack(spacing: 9) {
                StorageRing(usedFraction: model.volume.usedFraction, size: 156)
                Text("\(model.freeSpaceText) free")
                    .font(.system(size: 12, weight: .semibold))
                Text("of \(model.totalSpaceText)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 6)
        }
        .cardSurface(padding: 24)
    }

    private var summaryLine: String {
        if model.isScanning && model.totalReclaimable == 0 {
            return "Looking through your caches, downloads, models, and app data…"
        }
        if !model.hasScanned && model.totalReclaimable == 0 {
            return "Run a scan to see what is taking up space. Nothing is removed until you confirm."
        }
        let populated = CleanupCategory.dataCategories.filter { model.count(for: $0) > 0 }.count
        return "Across \(populated) categories. Everything is reviewed before it is removed."
    }

    private var quickCleanCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.mint.opacity(0.24), .cyan.opacity(0.13)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.teal)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text("One-Click Clean")
                    .font(.system(size: 15, weight: .semibold))
                if model.pinnedCount == 0 {
                    Text("Pin the folders you delete often, then clear them all with one click.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("\(model.pinnedCount) saved item\(model.pinnedCount == 1 ? "" : "s") · \(SizeFormatter.string(model.quickCleanSize)) ready")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if model.pinnedCount == 0 {
                Button("Build a Preset") {
                    model.selection = .caches
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            } else {
                Button("Review") {
                    model.selection = .quickClean
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button("Clean Now") {
                    model.prepareQuickClean()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!model.hasScanned || model.quickCleanSelectedItems.isEmpty)
            }
        }
        .cardSurface(padding: 16)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Browse by category")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(CleanupCategory.dataCategories.count) categories")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(CleanupCategory.dataCategories) { category in
                    CategoryCard(category: category)
                }
            }
        }
    }

    private var safetyNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 17))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 3) {
                Text("Trash first, permanent only when you choose")
                    .font(.system(size: 12.5, weight: .semibold))
                Text("Every folder is checked against your home folder before removal. Items already in the Trash are always deleted permanently, and tool cleanups such as Docker or Ollama are explained before they run.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.green.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.green.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct CategoryCard: View {
    @EnvironmentObject private var model: AppModel
    let category: CleanupCategory
    @State private var isHovering = false

    var body: some View {
        Button {
            model.selection = category
        } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top) {
                    CategoryIcon(category: category, size: 36)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 5)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(category.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(category.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(model.size(for: category) > 0 ? SizeFormatter.string(model.size(for: category)) : "—")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(model.size(for: category) > 0 ? category.accent : Color.secondary)
                    Text(itemCountLabel)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(category.accent.opacity(isHovering ? 0.045 : 0))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isHovering ? category.accent.opacity(0.25) : Color.primary.opacity(0.065),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(isHovering ? 0.06 : 0.025), radius: isHovering ? 12 : 7, y: 3)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovering = hovering
            }
        }
        .accessibilityLabel("\(category.title), \(SizeFormatter.string(model.size(for: category)))")
    }

    private var itemCountLabel: String {
        let count = model.count(for: category)
        guard count > 0 else { return "nothing found" }
        return "\(count) item\(count == 1 ? "" : "s")"
    }
}

struct DetailBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [Color.blue.opacity(0.018), .clear, Color.mint.opacity(0.014)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}
