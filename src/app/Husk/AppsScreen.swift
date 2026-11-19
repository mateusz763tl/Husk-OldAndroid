// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI

/// The apps installed inside the machines.
///
/// A machine keeps its own /data, so this list is whatever the machine that
/// most recently ran has installed. It is deliberately the only reminder of
/// Android's old "one shared guest" model: the machine manager is the home,
/// and this is the app drawer for it.
struct AppsScreen: View {
    @ObservedObject private var host = AndroidHost.shared
    @ObservedObject private var runner = QemuRunner.shared
    @ObservedObject private var manager = VMManager.shared
    @ObservedObject private var router = Router.shared
    @State private var query = ""

    private var packages: [AndroidHost.Package] {
        host.packages
            .filter { query.isEmpty
                || $0.label.localizedCaseInsensitiveContains(query)
                || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private var machine: VirtualMachine? {
        manager.runningID.flatMap(manager.machine) ?? manager.lastBooted ?? manager.selected
    }

    var body: some View {
        NavigationStack(path: $router.library) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    SearchField(text: $query, prompt: "Search installed apps…")

                    if let busy = host.busy { BusyStrip(text: busy) }

                    if manager.machines.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.stack.badge.plus")
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Create a machine first")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Apps are installed inside an Android machine.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textDim)
                            }
                        }
                        .padding(15)
                        .huskCard()
                    } else if !runner.isRunning {
                        Button { startMachine() } label: {
                            Label(machine == nil ? "Start Android" : "Start \(machine!.name)",
                                  systemImage: "play.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }

                    if packages.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "square.stack.3d.up.slash")
                                .font(.system(size: 28))
                                .foregroundStyle(Theme.textDim)
                            Text(query.isEmpty ? "No apps installed" : "No matches")
                                .font(.system(size: 16, weight: .semibold))
                            Text(query.isEmpty
                                 ? "Add an APK with the + button. It installs into the machine that is running."
                                 : "Try a different name.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textDim)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                        .huskCard()
                    } else {
                        LazyVStack(spacing: 2) {
                            ForEach(packages) { pkg in
                                row(pkg)
                                if pkg.id != packages.last?.id {
                                    Divider().padding(.leading, 66)
                                }
                            }
                        }
                        .huskCard()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .huskHideScrollIndicators()
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Apps")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { router.addSomething() } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add an APK")
                }
            }
            .libraryDestinations()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Apps")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text)
            Text(machine.map { "Installed in \($0.name)" } ?? "Installed inside a machine")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textDim)
        }
    }

    private func row(_ pkg: AndroidHost.Package) -> some View {
        HStack(spacing: 12) {
            HuskLink(value: LibraryRoute.android(pkg)) {
                HStack(spacing: 12) {
                    AppIcon(path: pkg.iconPath, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pkg.label)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Text([pkg.version, pkg.sizeBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }]
                                .compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textDim)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { launch(pkg) } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Theme.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(machine == nil)
            .opacity(machine == nil ? 0.35 : 1)
            .accessibilityLabel("Open \(pkg.label)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func startMachine() {
        guard let m = machine else { return }
        manager.requestStart(m)
    }

    private func launch(_ pkg: AndroidHost.Package) {
        if runner.isRunning, manager.runningID != nil {
            host.launch(pkg.name) { manager.requestOpenGuest() }
            return
        }
        guard let m = machine else { return }
        router.pendingAndroidLaunch = pkg.name
        manager.requestStart(m)
    }
}
