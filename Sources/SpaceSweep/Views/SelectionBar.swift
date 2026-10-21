import SwiftUI

struct SelectionBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(model.selectedCount) selected")
                    .font(.system(size: 12.5, weight: .semibold))
                Text(SizeFormatter.string(model.selectedSize))
                    .font(.system(size: 10.5))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Clear") {
                model.clearSelection()
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11.5))

            Button {
                model.pinSelectedItems()
            } label: {
                Label("Save to One-Click Clean", systemImage: "bookmark")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Button {
                model.prepareSelectedCleanup()
            } label: {
                Label("Review & Clean", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 11)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.86), value: model.selectedCount)
    }
}
