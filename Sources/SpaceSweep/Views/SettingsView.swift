import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmClearRules = false

    var body: some View {
        TabView {
            general
                .tabItem { Label("General", systemImage: "gearshape") }

            permissions
                .tabItem { Label("Permissions", systemImage: "lock.shield") }

            about
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 540, height: 440)
        .alert("Clear One-Click Clean?", isPresented: $confirmClearRules) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Saved Items", role: .destructive) {
                model.clearRules()
            }
        } message: {
            Text("This removes your saved preset. No files on disk are touched.")
        }
    }

    private var general: some View {
        Form {
            Section("Scanning") {
                Picker("Large file threshold", selection: $model.settings.largeFileThresholdMB) {
                    Text("100 MB").tag(100)
                    Text("250 MB").tag(250)
                    Text("500 MB").tag(500)
                    Text("1 GB").tag(1000)
                    Text("2 GB").tag(2000)
                }

                Picker("Show folders above", selection: $model.settings.minFolderSizeMB) {
                    Text("5 MB").tag(5)
                    Text("10 MB").tag(10)
                    Text("25 MB").tag(25)
                    Text("50 MB").tag(50)
                }

                Stepper(
                    "Large file results: \(model.settings.maxLargeFiles)",
                    value: $model.settings.maxLargeFiles,
                    in: 25...500,
                    step: 25
                )

                HStack {
                    Text("Changes apply to the next scan.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Scan Now") {
                        model.scan()
                    }
                    .controlSize(.small)
                    .disabled(model.isScanning)
                }
            }

            Section("Removal") {
                Picker("Default method", selection: $model.defaultRemovalMode) {
                    ForEach(RemovalMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text("You still confirm every cleanup. Permanent deletion requires an extra acknowledgement.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("One-Click Clean") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(model.pinnedCount) saved item\(model.pinnedCount == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .medium))
                        Text("Saved locations are rechecked on every scan.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Clear Saved Items", role: .destructive) {
                        confirmClearRules = true
                    }
                    .controlSize(.small)
                    .disabled(model.pinnedCount == 0)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var permissions: some View {
        Form {
            Section("Full Disk Access") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: model.hasFullDiskAccess ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(model.hasFullDiskAccess ? .green : .orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.hasFullDiskAccess ? "Full Disk Access is on" : "Full Disk Access is off")
                            .font(.system(size: 13, weight: .semibold))
                        Text(model.hasFullDiskAccess
                             ? "SpaceSweep can measure caches, containers, logs, and the Trash accurately."
                             : "macOS hides some Library folders from apps without this permission. SpaceSweep still works, but some categories may be incomplete.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)

                Button("Open Full Disk Access Settings") {
                    model.openFullDiskAccessSettings()
                }

                Text("Add SpaceSweep in System Settings → Privacy & Security → Full Disk Access. You may need to quit and reopen the app after granting access.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Files and Folders") {
                Text("The first time SpaceSweep scans Documents, Downloads, or the Desktop, macOS may ask for permission. Approve it so those folders can be measured.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Privacy") {
                Text("SpaceSweep runs entirely on your Mac. File names, paths, and sizes are never uploaded anywhere.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }

    private var about: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.mint, .cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 82, height: 82)
                    .shadow(color: .blue.opacity(0.22), radius: 12, y: 5)
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 3) {
                Text("SpaceSweep")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Version \(appVersion)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Text("A native macOS cleaner for caches, downloads, AI models, developer junk, containers, Docker, and more.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)

            Divider()
                .frame(width: 300)

            VStack(alignment: .leading, spacing: 8) {
                aboutLine(symbol: "lock.shield.fill", text: "Trash-first removal with a guarded permanent option.")
                aboutLine(symbol: "magnifyingglass", text: "Scans locally. No accounts, analytics, or network calls.")
                aboutLine(symbol: "checkmark.seal.fill", text: "Protected paths and command safeguards prevent accidents.")
            }

            Spacer()

            Text("Built for macOS 14 and later.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func aboutLine(symbol: String, text: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(.green)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
