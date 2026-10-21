import AppKit
import SwiftUI

struct CategoryDetailView: View {
    @EnvironmentObject private var model: AppModel
    let category: CleanupCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            controls
            content
        }
        .background(DetailBackground())
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 15) {
            CategoryIcon(category: category, size: 50)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(category.title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text(category.subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Text(model.size(for: category) > 0 ? SizeFormatter.string(model.size(for: category)) : "—")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(category.accent)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(itemCountLabel)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    if model.count(for: category) > 0 {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Label("Click a row to select", systemImage: "cursorarrow.click")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 12)

            Button {
                model.scan()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(model.isScanning)
        }
        .padding(.horizontal, 28)
        .padding(.top, 26)
        .padding(.bottom, 16)
    }

    private var itemCountLabel: String {
        let count = model.count(for: category)
        return count == 0 ? "Nothing found yet" : SizeFormatter.fileCount(count)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Filter \(category.title.lowercased())", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear filter")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .frame(width: 240)

            Menu {
                Picker("Sort", selection: $model.sortOrder) {
                    ForEach(ItemSort.allCases) { order in
                        Label(order.title, systemImage: order.symbol).tag(order)
                    }
                }
            } label: {
                Label(model.sortOrder.title, systemImage: "arrow.up.arrow.down")
                    .font(.system(size: 11.5))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            if !model.visibleItems.isEmpty {
                Button(model.visibleItems.allSatisfy { model.isSelected($0) } ? "Deselect All" : "Select All") {
                    if model.visibleItems.allSatisfy({ model.isSelected($0) }) {
                        model.clearSelection()
                    } else {
                        model.selectAllVisible()
                    }
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11.5, weight: .medium))
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var content: some View {
        if model.isScanning && model.visibleItems.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                Text(model.scanStatusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.visibleItems.isEmpty {
            emptyState
        } else {
            itemList
        }
    }

    private var itemList: some View {
        List {
            ForEach(model.visibleItems) { item in
                CleanRow(item: item)
                    .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.065), lineWidth: 1)
        )
        .padding(.horizontal, 28)
        .padding(.bottom, 22)
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        EmptyStateView(
            symbol: emptySymbol,
            title: emptyTitle,
            message: emptyMessage,
            actionTitle: model.hasScanned ? "Scan Again" : "Scan My Mac",
            action: { model.scan() }
        )
        .frame(maxHeight: .infinity)
    }

    private var emptySymbol: String {
        if category == .snapshots { return "checkmark.seal.fill" }
        if category == .trash { return "trash" }
        if category == .docker { return "shippingbox" }
        return category.symbol
    }

    private var emptyTitle: String {
        switch category {
        case .snapshots: return "No local snapshots"
        case .trash: return "The Trash is empty"
        case .docker: return "Docker has nothing to reclaim"
        case .largeFiles: return "No large files found"
        case .logs: return "No logs worth removing"
        case .aiModels: return "No local AI models found"
        default: return "Nothing to clean here"
        }
    }

    private var emptyMessage: String {
        switch category {
        case .snapshots:
            return "macOS is not holding any extra local restore points."
        case .trash:
            return "Everything you deleted has already been cleared."
        case .docker:
            return "Make sure Docker Desktop is running, then scan again. Only reclaimable images, containers, volumes, and build cache are counted."
        case .largeFiles:
            return "No individual files are over \(SizeFormatter.string(model.settings.largeFileThreshold)). You can lower the threshold in Settings."
        case .aiModels:
            return "Hugging Face, Ollama, LM Studio, Unsloth, and OMLX caches were checked."
        case .caches:
            return "No app or hidden caches are over \(SizeFormatter.string(model.settings.minFolderSize))."
        default:
            return "SpaceSweep did not find anything in this category that is worth removing."
        }
    }
}

struct CleanRow: View {
    @EnvironmentObject private var model: AppModel
    let item: CleanableItem
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 11) {
            Button {
                model.toggleSelection(item)
            } label: {
                SelectionCheckbox(
                    isSelected: model.isSelected(item),
                    accessibilityTitle: "Select \(item.name)"
                )
            }
            .buttonStyle(.plain)
            .help(model.isSelected(item) ? "Remove from selection" : "Add to selection")

            ItemIcon(item: item, size: 31)

            Button {
                model.toggleSelection(item)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        SafetyBadge(safety: item.safety)
                        if model.isPinned(item) {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.accentColor)
                                .help("Saved in One-Click Clean")
                        }
                    }

                    Text(item.detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let path = item.path {
                        Text(abbreviated(path))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.size > 0 ? SizeFormatter.string(item.size) : "—")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if let count = item.childCount, count > 0, item.kind != .command {
                    Text(count == 1 ? "1 file" : "\(count.formatted()) files")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                } else if let modified = item.modified {
                    Text(DateText.relative(modified))
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(minWidth: 72, alignment: .trailing)

            Button {
                model.togglePin(item)
            } label: {
                Image(systemName: model.isPinned(item) ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(model.isPinned(item) ? Color.accentColor : Color.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(model.isPinned(item) || isHovering ? 1 : 0.35)
            .help(model.isPinned(item) ? "Remove from One-Click Clean" : "Save to One-Click Clean")

            Menu {
                Button("Reveal in Finder") {
                    model.reveal(item)
                }
                .disabled(item.path == nil)

                Button("Open") {
                    model.open(item)
                }
                .disabled(item.path == nil)

                Divider()

                Button(model.isPinned(item) ? "Remove from One-Click Clean" : "Add to One-Click Clean") {
                    model.togglePin(item)
                }

                if let path = item.path {
                    Divider()
                    Button("Copy Path") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(path, forType: .string)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .opacity(isHovering ? 1 : 0.45)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(background)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button("Select / Deselect") {
                model.toggleSelection(item)
            }
            Button("Save to One-Click Clean") {
                model.togglePin(item)
            }
            if item.path != nil {
                Button("Reveal in Finder") {
                    model.reveal(item)
                }
            }
        }
    }

    private var background: Color {
        if model.isSelected(item) {
            return Color.accentColor.opacity(0.075)
        }
        return isHovering ? Color.primary.opacity(0.035) : .clear
    }

    private func abbreviated(_ path: String) -> String {
        let home = SafetyPolicy.home.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~/" + path.dropFirst(home.count + 1)
        }
        return path
    }
}
