import SwiftUI

// MARK: - Icon

struct CategoryIcon: View {
    let category: CleanupCategory
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [category.accent.opacity(0.22), category.accent.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: category.symbol)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(category.accent)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct ItemIcon: View {
    let item: CleanableItem
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(item.category.accent.opacity(0.12))
            Image(systemName: item.kind.symbol)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(item.category.accent)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Checkbox

struct SelectionCheckbox: View {
    let isSelected: Bool
    var accessibilityTitle: String = "Select item"

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.65))
            .contentTransition(.symbolEffect(.replace))
            .accessibilityLabel(accessibilityTitle)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Badges

struct SafetyBadge: View {
    let safety: SafetyLevel

    var body: some View {
        if safety != .safe {
            Label(safety.title, systemImage: safety.symbol)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(safety.color)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(safety.color.opacity(0.12), in: Capsule())
                .help(safetyHelp)
        }
    }

    private var safetyHelp: String {
        switch safety {
        case .safe: return "Safe to remove."
        case .caution: return "Check this before removing."
        case .risky: return "This may contain important or irreplaceable data."
        }
    }
}

struct CountBadge: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.11), in: Capsule())
    }
}

// MARK: - Storage ring

struct StorageRing: View {
    let usedFraction: Double
    var size: CGFloat = 150

    private let gradient = AngularGradient(
        colors: [.blue, .cyan, .mint],
        center: .center,
        startAngle: .degrees(-90),
        endAngle: .degrees(270)
    )

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.07), lineWidth: 13)

            Circle()
                .trim(from: 0, to: max(0.003, min(usedFraction, 1)))
                .stroke(
                    gradient,
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.7), value: usedFraction)

            VStack(spacing: 2) {
                Text("\(Int((usedFraction * 100).rounded()))%")
                    .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("used")
                    .font(.system(size: size * 0.09, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Disk is \(Int((usedFraction * 100).rounded())) percent full")
    }
}

struct LinearStorageBar: View {
    let fraction: Double
    var height: CGFloat = 5
    var tint: Color = .accentColor

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.65)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Cards & surfaces

struct CardSurface: ViewModifier {
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.035), radius: 14, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.065), lineWidth: 1)
            )
    }
}

extension View {
    func cardSurface(padding: CGFloat = 20, cornerRadius: CGFloat = 18) -> some View {
        modifier(CardSurface(padding: padding, cornerRadius: cornerRadius))
    }
}

// MARK: - Header

struct ScreenHeader<Trailing: View>: View {
    let eyebrow: String?
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            trailing
        }
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 68, height: 68)
                Image(systemName: symbol)
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.system(size: 17, weight: .semibold))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Scanning strip

struct ScanningStrip: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 9) {
                ProgressView()
                    .controlSize(.small)
                Text(model.scanStatusText)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Button("Cancel") {
                    model.cancelScan()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            }
            if case .scanning(_, let fraction) = model.scanPhase {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 11)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

// MARK: - Permission banner

struct PermissionBanner: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 18))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Some folders are hidden from SpaceSweep")
                    .font(.system(size: 12.5, weight: .semibold))
                Text("Grant Full Disk Access to measure Library, Trash, and other app data accurately.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings") {
                model.openFullDiskAccessSettings()
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Toast

struct ToastView: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: message.symbol)
                .foregroundStyle(.white)
            Text(message.text)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(nsColor: .darkGray).opacity(0.94))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        )
        .accessibilityElement(children: .combine)
    }
}
