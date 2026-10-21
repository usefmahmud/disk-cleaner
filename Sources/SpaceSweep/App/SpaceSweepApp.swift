import AppKit
import SwiftUI

@main
struct SpaceSweepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("SpaceSweep") {
            ContentView()
                .environmentObject(model)
        }
        .defaultSize(width: 1180, height: 780)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }

            CommandMenu("Cleanup") {
                Button("Scan Again") {
                    model.scan()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(model.isScanning)

                Button("Open One-Click Clean") {
                    model.selection = .quickClean
                }
                .keyboardShortcut("1", modifiers: [.command, .shift])

                Divider()

                Button("Review Selected Items") {
                    model.prepareSelectedCleanup()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.selectedCount == 0)

                Button("Clear Selection") {
                    model.clearSelection()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(model.selectedCount == 0)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        #if DEBUG
        scheduleDebugSnapshotIfRequested()
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    #if DEBUG
    private func scheduleDebugSnapshotIfRequested() {
        let arguments = CommandLine.arguments
        guard let flag = arguments.firstIndex(of: "--snapshot"),
              arguments.indices.contains(flag + 1) else {
            return
        }
        let path = arguments[flag + 1]
        let delay: TimeInterval = {
            guard let delayFlag = arguments.firstIndex(of: "--snapshot-delay"),
                  arguments.indices.contains(delayFlag + 1) else {
                return 12
            }
            return TimeInterval(arguments[delayFlag + 1]) ?? 12
        }()

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard let window = NSApp.windows.first(where: { $0.isVisible }),
                  let view = window.contentView else {
                fputs("snapshot: no visible window\n", stderr)
                NSApp.terminate(nil)
                return
            }

            view.layoutSubtreeIfNeeded()
            window.displayIfNeeded()

            var data: Data?
            if let image = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                CGWindowID(window.windowNumber),
                [.boundsIgnoreFraming, .bestResolution]
            ) {
                let rep = NSBitmapImageRep(cgImage: image)
                data = rep.representation(using: .png, properties: [:])
            }
            if data == nil, let layer = view.layer {
                let scale = window.backingScaleFactor
                let width = Int(view.bounds.width * scale)
                let height = Int(view.bounds.height * scale)
                if let context = CGContext(
                    data: nil,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) {
                    context.scaleBy(x: scale, y: scale)
                    layer.render(in: context)
                    if let image = context.makeImage() {
                        let rep = NSBitmapImageRep(cgImage: image)
                        data = rep.representation(using: .png, properties: [:])
                    }
                }
            }
            if data == nil, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: rep)
                data = rep.representation(using: .png, properties: [:])
            }
            if data == nil {
                let pdf = view.dataWithPDF(inside: view.bounds)
                if let image = NSImage(data: pdf),
                   let tiff = image.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff) {
                    data = rep.representation(using: .png, properties: [:])
                }
            }

            if let data {
                try? data.write(to: URL(fileURLWithPath: path))
                print("snapshot: wrote \(path)")
            } else {
                fputs("snapshot: could not render window\n", stderr)
            }
            NSApp.terminate(nil)
        }
    }
    #endif
}
