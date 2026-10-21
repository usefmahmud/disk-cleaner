import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(selection: $model.selection) {
            Section {
                sidebarRow(.overview)
                sidebarRow(.quickClean)
            }

            Section("Your Files") {
                sidebarRow(.largeFiles)
                sidebarRow(.downloads)
                sidebarRow(.trash)
            }

            Section("System & Apps") {
                sidebarRow(.caches)
                sidebarRow(.developer)
                sidebarRow(.aiModels)
                sidebarRow(.appSupport)
                sidebarRow(.containers)
                sidebarRow(.docker)
                sidebarRow(.snapshots)
                sidebarRow(.logs)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) {
            brand
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            storageFooter
        }
        .navigationSplitViewColumnWidth(min: 218, ideal: 236, max: 280)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.mint, .cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
            .shadow(color: .blue.opacity(0.18), radius: 5, y: 2)

            VStack(alignment: .leading, spacing: 1) {
                Text("SpaceSweep")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("Mac storage, simplified")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private func sidebarRow(_ category: CleanupCategory) -> some View {
        HStack(spacing: 9) {
            CategoryIcon(category: category, size: 23)
            Text(category.title)
                .font(.system(size: 12.5))
                .lineLimit(1)
            Spacer(minLength: 4)

            if category == .quickClean {
                if model.pinnedCount > 0 {
                    CountBadge(text: "\(model.pinnedCount)", tint: category.accent)
                }
            } else if category.isDataCategory, model.size(for: category) > 0 {
                Text(SizeFormatter.string(model.size(for: category)))
                    .font(.system(size: 10.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .tag(category)
        .accessibilityLabel("\(category.title), \(SizeFormatter.string(model.size(for: category)))")
    }

    private var storageFooter: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Text("Macintosh HD")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open Settings")
            }

            LinearStorageBar(
                fraction: model.volume.total > 0 ? model.volume.usedFraction : 0,
                height: 5,
                tint: .blue
            )

            HStack {
                Text("\(model.freeSpaceText) free")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("of \(model.totalSpaceText)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
