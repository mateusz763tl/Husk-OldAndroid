// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import UniformTypeIdentifiers

// MARK: - machine list

/// The home screen: one card per Android machine.
///
/// This is the Virtual Master shape. The app is no longer a launcher for APKs
/// that happen to run in one hidden Android; it is a set of little phones, each
/// with its own Android version, storage and saved state, and one of them can be
/// on screen at a time.
struct MachinesView: View {
    @ObservedObject private var manager = VMManager.shared
    @ObservedObject private var runner = QemuRunner.shared
    @ObservedObject private var guest = GuestImage.shared
    @ObservedObject private var host = AndroidHost.shared

    @State private var creating = false
    @State private var editing: VirtualMachine?
    @State private var deleting: VirtualMachine?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    notices
                    if manager.machines.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(manager.machines) { machine in
                                MachineCard(
                                    machine: machine,
                                    status: manager.status(for: machine),
                                    onStart: { start(machine) },
                                    onOpen: { manager.requestOpenGuest() },
                                    onEdit: { editing = machine },
                                    onDuplicate: { duplicate(machine) },
                                    onReset: { reset(machine) },
                                    onDelete: { deleting = machine })
                            }
                        }
                    }
                    howItWorks
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .huskHideScrollIndicators()
            .background(Theme.bg.ignoresSafeArea())
            .huskNavigationBar(hidden: true)
        }
        .sheet(isPresented: $creating) {
            CreateMachineView()
        }
        .sheet(item: $editing) { machine in
            MachineDetailView(machine: machine)
        }
        .confirmationDialog("Delete \(deleting?.name ?? "this machine")?",
                            isPresented: Binding(get: { deleting != nil },
                                                 set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("Delete Machine", role: .destructive) {
                if let machine = deleting { delete(machine) }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("Its apps, accounts and saved state go with it. The Android system image stays.")
        }
        .alert("Machine", isPresented: Binding(get: { errorMessage != nil },
                                               set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: runner.isRunning) { running in
            if !running { manager.runningID = nil }
        }
        .onAppear {
            guest.refresh()
        }
    }

    // MARK: pieces

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Machines")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text("Android versions in their own little phones.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textDim)
            }
            Spacer(minLength: 4)
            Button { creating = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Theme.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Android machine")
        }
    }

    @ViewBuilder
    private var notices: some View {
        if manager.runningID != nil, runner.isRunning {
            HStack(spacing: 10) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.runningMachine?.name ?? "Android")
                        .font(.system(size: 14, weight: .semibold))
                    Text(host.isReady ? "Running · tap Open to switch to it"
                                      : (runner.bootProgress > 0 ? "Starting… \(runner.bootProgress)%"
                                                                 : "Starting…"))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textDim)
                }
                Spacer()
                Button("Open") { manager.requestOpenGuest() }
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(14)
            .huskCard()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            MachineIcon(release: AndroidReleases.builtIn, size: 78, running: false)
            VStack(spacing: 6) {
                Text("No machines yet")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("Pick an Android version, give it RAM and a screen, and Husk boots a separate phone for it.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
            Button("Create a Machine") { creating = true }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .huskCard()
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How these machines run")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text("Each machine is a real Android guest under QEMU with its own data disk. "
               + "Only one can run at a time on iPhone, because iOS allows one in-process VM. "
               + "The built-in LineageOS image is Android 13; older versions use a system image you import.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .huskCard(high: true)
    }

    // MARK: actions

    private func start(_ machine: VirtualMachine) {
        guard machine.hasSystemImage else {
            editing = machine
            return
        }
        if runner.isRunning {
            // The QEMU library can only own one machine per process, so the
            // useful action is to show the one that is already running.
            manager.requestOpenGuest()
            return
        }
        manager.requestStart(machine)
    }

    private func duplicate(_ machine: VirtualMachine) {
        do { _ = try manager.duplicate(machine) }
        catch { errorMessage = error.localizedDescription }
    }

    private func reset(_ machine: VirtualMachine) {
        do {
            try manager.resetData(machine)
            errorMessage = "\(machine.name) will boot with a clean Android data disk next time."
        } catch { errorMessage = error.localizedDescription }
    }

    private func delete(_ machine: VirtualMachine) {
        do { try manager.delete(machine) }
        catch { errorMessage = error.localizedDescription }
    }
}

// MARK: - one card

private struct MachineCard: View {
    let machine: VirtualMachine
    let status: VMManager.MachineStatus
    let onStart: () -> Void
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onReset: () -> Void
    let onDelete: () -> Void

    private var running: Bool { status == .running }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                MachineIcon(release: machine.release, size: 62, running: running)
                VStack(alignment: .leading, spacing: 3) {
                    Text(machine.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(machine.release.shortTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(machine.release.accent)
                    Text("\(machine.memorySpec) · \(machine.cpuSpec) · \(machine.displaySpec)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textDim)
                    MachineStatusPill(status: status)
                        .padding(.top, 3)
                }
                Spacer(minLength: 6)
                Menu {
                    Button { onEdit() } label: { Label("Settings", systemImage: "slider.horizontal.3") }
                    Button { onDuplicate() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                    Divider()
                    Button { onReset() } label: { Label("Reset Android Data", systemImage: "arrow.counterclockwise") }
                    Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                        .disabled(machine.legacyGuest)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("More for \(machine.name)")
            }

            HStack(spacing: 10) {
                if running {
                    Button(action: onOpen) {
                        Label("Open", systemImage: "arrow.up.forward.app.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onStart) {
                        Label(status == .needsImage ? "Add Image" : "Start",
                              systemImage: status == .needsImage ? "square.and.arrow.down" : "play.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(status == .busy ? Theme.textDim : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(status == .busy ? Theme.surfaceHigh : Theme.accent,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(status == .busy)
                }
            }
        }
        .padding(15)
        .huskCard()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                .strokeBorder(running ? Theme.accent.opacity(0.55) : Color.clear, lineWidth: 1)
        )
    }
}

private struct MachineStatusPill: View {
    let status: VMManager.MachineStatus
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(status.color).frame(width: 6, height: 6)
            Text(status.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textDim)
        }
        .padding(.horizontal, 8)
        .frame(height: 21)
        .background(Theme.surfaceHigh, in: Capsule())
    }
}

struct MachineIcon: View {
    let release: AndroidRelease
    var size: CGFloat = 62
    var running = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(LinearGradient(colors: [release.accent.opacity(0.98),
                                              release.accent.opacity(0.62)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "apps.iphone")
                .font(.system(size: size * 0.43, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            Text("\(release.api)")
                .font(.system(size: size * 0.15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, size * 0.08)
                .frame(height: size * 0.22)
                .background(.black.opacity(0.28), in: Capsule())
                .padding(size * 0.07)
        }
        .overlay(alignment: .topTrailing) {
            if running {
                Circle().fill(.green)
                    .frame(width: size * 0.17, height: size * 0.17)
                    .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
                    .padding(size * 0.07)
            }
        }
        .shadow(color: release.accent.opacity(0.25), radius: 8, y: 4)
    }
}

// MARK: - create

struct CreateMachineView: View {
    @ObservedObject private var manager = VMManager.shared
    @ObservedObject private var guest = GuestImage.shared
    @Environment(\.dismiss) private var dismiss

    @State private var releaseID = AndroidReleases.builtIn.id
    @State private var name = ""
    @State private var ramMiB = AndroidReleases.builtIn.defaultRAMMiB
    @State private var cpuCount = 4
    @State private var resolution = 2
    @State private var importing = false
    @State private var errorMessage: String?
    @State private var pickerOpen = false

    private var release: AndroidRelease { AndroidReleases.release(releaseID) }
    private var imagePath: String? { manager.imagePath(for: release) }

    private let resolutions: [(String, Int, Int, Int)] = [
        ("Small · 480×800", 480, 800, 240),
        ("Medium · 540×960", 540, 960, 240),
        ("Phone · 720×1280", 720, 1280, 320),
        ("Sharp · 1080×1920", 1080, 1920, 420),
        ("Tall · 360×800", 360, 800, 320),
    ]

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("Android version") {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(AndroidReleases.all) { r in
                                ReleaseCard(release: r,
                                            selected: releaseID == r.id,
                                            available: manager.canCreate(r)) {
                                    choose(r)
                                }
                            }
                        }
                    }

                    section("System image") {
                        imageSection
                    }

                    section("Name") {
                        TextField("Android 13", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .padding(13)
                            .background(Theme.surfaceHigh, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .textInputAutocapitalization(.words)
                        Text("Defaults to the Android version if left empty.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textDim)
                    }

                    section("Performance") {
                        settingRow("Memory", detail: ramMiB >= 1024
                                   ? String(format: "%.1f GB", Double(ramMiB) / 1024)
                                   : "\(ramMiB) MB") {
                            Picker("Memory", selection: $ramMiB) {
                                ForEach([1024, 1536, 2048, 3072, 4096, 5120], id: \.self) { mib in
                                    Text(mib >= 1024
                                         ? String(format: "%.1f GB", Double(mib) / 1024).replacingOccurrences(of: ".0", with: "")
                                         : "\(mib) MB").tag(mib)
                                }
                            }
                            .labelsHidden()
                        }
                        settingRow("CPU cores", detail: "\(cpuCount)") {
                            Picker("CPU cores", selection: $cpuCount) {
                                ForEach([2, 4, 6, 8], id: \.self) { Text("\($0)").tag($0) }
                            }
                            .labelsHidden()
                        }
                        settingRow("Screen", detail: resolutions[resolution].0) {
                            Picker("Screen", selection: $resolution) {
                                ForEach(resolutions.indices, id: \.self) { i in
                                    Text(resolutions[i].0).tag(i)
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    if let imagePath {
                        Text("System disk: \((imagePath as NSString).lastPathComponent)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.textDim)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Button("Create Machine") { create() }
                        .buttonStyle(PrimaryButtonStyle(enabled: imagePath != nil))
                        .disabled(imagePath == nil)

                    if release.builtIn {
                        Text("The built-in image is the LineageOS build Husk already knows how to boot. "
                           + "It is the one that starts quickly, and the one a new install downloads.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textDim)
                    } else {
                        Text("Older Android is not bundled. Import a QEMU-ready qcow2 or raw system disk for "
                           + "\(release.shortTitle); the machine supplies its own userdata and UEFI variables.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textDim)
                    }
                }
                .padding(20)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("New Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Machine", isPresented: Binding(get: { errorMessage != nil },
                                                   set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: releaseID) { _ in applyDefaults() }
            .onAppear { applyDefaults() }
            .huskFilePicker(isPresented: $pickerOpen, types: [.item], multiple: false) { urls in
                guard let url = urls.first else { return }
                importImage(url)
            }
        }
    }

    @ViewBuilder
    private var imageSection: some View {
        if let path = imagePath {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(release.builtIn ? "Built-in image ready" : "Image ready")
                        .font(.system(size: 14, weight: .semibold))
                    Text((path as NSString).lastPathComponent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textDim)
                        .lineLimit(1)
                }
                Spacer()
                if !release.builtIn {
                    Button("Replace") { pickerOpen = true }
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .padding(14)
            .huskCard(high: true)
        } else if release.builtIn {
            VStack(alignment: .leading, spacing: 12) {
                Text("The LineageOS image is not on this iPhone yet.")
                    .font(.system(size: 14, weight: .semibold))
                if case let .downloading(progress, received, total) = guest.state {
                    ProgressView(value: progress, total: 1)
                    Text("\(ByteCountFormatter.string(fromByteCount: received, countStyle: .file))"
                       + (total > 0 ? " of \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))" : ""))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textDim)
                } else if case let .failed(why) = guest.state {
                    Text(why).font(.system(size: 12)).foregroundStyle(.red)
                    Button("Try Again") { guest.download() }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Text("About a gigabyte. It lives in Documents and is reused by every machine built on it.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textDim)
                    Button("Download Image") { guest.download() }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(14)
            .huskCard(high: true)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("No \(release.version) image installed.")
                    .font(.system(size: 14, weight: .semibold))
                Text("Choose a qcow2 or .img system disk. Husk gives the machine its own empty userdata and "
                   + "UEFI variable store, so the image only has to be a bootable Android system partition.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textDim)
                Button {
                    pickerOpen = true
                } label: {
                    Label(importing ? "Importing…" : "Choose System Image",
                          systemImage: "square.and.arrow.down")
                }
                .buttonStyle(PrimaryButtonStyle(enabled: !importing))
                .disabled(importing)
            }
            .padding(14)
            .huskCard(high: true)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textDim)
                .textCase(.uppercase)
            content()
        }
    }

    private func settingRow<Content: View>(_ title: String, detail: String,
                                           @ViewBuilder control: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 15))
            Spacer(minLength: 8)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textDim)
                .lineLimit(1)
            control()
                .font(.system(size: 13))
        }
        .padding(.vertical, 2)
    }

    private func choose(_ r: AndroidRelease) {
        releaseID = r.id
        applyDefaults()
    }

    private func applyDefaults() {
        let r = release
        ramMiB = max(r.minRAMMiB, min(r.defaultRAMMiB, 4096))
        cpuCount = 4
        if let i = resolutions.firstIndex(where: { $0.1 == r.defaultWidth && $0.2 == r.defaultHeight }) {
            resolution = i
        } else {
            resolution = 4
        }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = manager.suggestedName(for: r)
        }
    }

    private func importImage(_ url: URL) {
        let target = release
        Task { @MainActor in
            importing = true
            defer { importing = false }
            do {
                try await manager.importImage(url, for: target)
                HuskLog.log("vm", "\(target.shortTitle) image imported from \(url.lastPathComponent)")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func create() {
        let r = release
        let res = resolutions[resolution]
        do {
            _ = try manager.create(name: name,
                                   release: r,
                                   ramMiB: ramMiB,
                                   cpuCount: cpuCount,
                                   width: res.1,
                                   height: res.2,
                                   dpi: res.3,
                                   rootEnabled: false)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ReleaseCard: View {
    let release: AndroidRelease
    let selected: Bool
    let available: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                MachineIcon(release: release, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(release.version)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(release.codename)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textDim)
                        .lineLimit(1)
                    Text(available ? "Image ready" : "Need image")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(available ? .green : .orange)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? release.accent.opacity(0.13) : Theme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(selected ? release.accent : Theme.hairline, lineWidth: selected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - settings

struct MachineDetailView: View {
    @ObservedObject private var manager = VMManager.shared
    @ObservedObject private var runner = QemuRunner.shared
    @ObservedObject private var guest = GuestImage.shared
    @Environment(\.dismiss) private var dismiss

    @State private var machine: VirtualMachine
    @State private var confirmingReset = false
    @State private var confirmingDelete = false
    @State private var pickerOpen = false
    @State private var errorMessage: String?

    init(machine: VirtualMachine) {
        _machine = State(initialValue: machine)
    }

    private var isRunning: Bool { manager.isRunning(machine) }
    private var imagePath: String? { manager.imagePath(for: machine.release) }
    private let resolutions: [(String, Int, Int, Int)] = [
        ("480×800", 480, 800, 240),
        ("540×960", 540, 960, 240),
        ("720×1280", 720, 1280, 320),
        ("1080×1920", 1080, 1920, 420),
        ("360×800", 360, 800, 320),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        MachineIcon(release: machine.release, size: 64, running: isRunning)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(machine.name)
                                .font(.system(size: 19, weight: .bold))
                            Text(machine.release.shortTitle)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(machine.release.accent)
                            Text(manager.status(for: machine).title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(manager.status(for: machine).color)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Name") {
                    TextField("Machine name", text: $machine.name)
                        .disabled(machine.legacyGuest)
                }

                Section {
                    LabeledContent("Memory", value: machine.memorySpec)
                    LabeledContent("CPU", value: machine.cpuSpec)
                    LabeledContent("Screen", value: "\(machine.displaySpec) · \(machine.dpi) dpi")
                } header: {
                    Text("Hardware")
                } footer: {
                    if machine.legacyGuest {
                        Text("The built-in machine is pinned to the shape of its pre-booted snapshot. Create a new machine to choose different hardware.")
                    } else if isRunning {
                        Text("Hardware changes apply the next time this machine starts.")
                    }
                }
                .disabled(machine.legacyGuest)

                if !machine.legacyGuest {
                    Section("Hardware") {
                        Picker("Memory", selection: $machine.ramMiB) {
                            ForEach([1024, 1536, 2048, 3072, 4096, 5120], id: \.self) { mib in
                                Text(mib >= 1024
                                     ? String(format: "%.1f GB", Double(mib) / 1024).replacingOccurrences(of: ".0", with: "")
                                     : "\(mib) MB").tag(mib)
                            }
                        }
                        Picker("CPU cores", selection: $machine.cpuCount) {
                            ForEach([2, 4, 6, 8], id: \.self) { Text("\($0)").tag($0) }
                        }
                        Picker("Screen", selection: resolutionBinding) {
                            ForEach(resolutions.indices, id: \.self) { i in
                                Text(resolutions[i].0).tag(i)
                            }
                        }
                    }
                    .disabled(isRunning)
                }

                Section {
                    if let path = imagePath {
                        LabeledContent("System image", value: (path as NSString).lastPathComponent)
                    } else {
                        LabeledContent("System image", value: "Not installed")
                    }
                    LabeledContent("Data size", value: machine.storageBytes.huskByteText)
                    if let booted = machine.lastBootedAt {
                        LabeledContent("Last started", value: booted.formatted(date: .abbreviated, time: .shortened))
                    }
                    if !machine.release.builtIn {
                        Button("Choose System Image") { pickerOpen = true }
                            .disabled(isRunning)
                    }
                } header: {
                    Text("Storage")
                } footer: {
                    Text("System images are shared between machines of the same Android version. Apps, accounts and files stay in this machine's own data disk.")
                }

                Section {
                    Button { confirmingReset = true } label: {
                        Label("Reset Android Data", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(isRunning)
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Label("Delete Machine", systemImage: "trash")
                    }
                    .disabled(isRunning || machine.legacyGuest)
                } footer: {
                    if machine.legacyGuest {
                        Text("The built-in machine can be reset but not deleted, because its image is the app's own Android system.")
                    } else {
                        Text("Resetting erases Android's data and boots it fresh. The system image is kept.")
                    }
                }

                Section {
                    Button {
                        if isRunning { manager.requestOpenGuest() }
                        else { manager.requestStart(machine) }
                    } label: {
                        Label(isRunning ? "Open Machine" : "Start Machine",
                              systemImage: isRunning ? "arrow.up.forward.app" : "play.fill")
                    }
                    .disabled(!isRunning && !machine.hasSystemImage)
                }
            }
            .navigationTitle("Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveAndDismiss() }
                }
            }
            .onChange(of: machine) { updated in
                manager.update(updated)
            }
            .confirmationDialog("Reset \(machine.name)?", isPresented: $confirmingReset,
                                titleVisibility: .visible) {
                Button("Reset Android Data", role: .destructive) {
                    do { try manager.resetData(machine) }
                    catch { errorMessage = error.localizedDescription }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("All apps, accounts and files inside Android are erased.")
            }
            .confirmationDialog("Delete \(machine.name)?", isPresented: $confirmingDelete,
                                titleVisibility: .visible) {
                Button("Delete Machine", role: .destructive) {
                    do {
                        try manager.delete(machine)
                        dismiss()
                    } catch { errorMessage = error.localizedDescription }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Its data disk and saved state are removed. The Android system image is kept.")
            }
            .alert("Machine", isPresented: Binding(get: { errorMessage != nil },
                                                   set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .huskFilePicker(isPresented: $pickerOpen, types: [.item], multiple: false) { urls in
                guard let url = urls.first else { return }
                let target = machine.release
                Task { @MainActor in
                    do {
                        try await manager.importImage(url, for: target)
                        machine.systemImagePath = manager.imagePath(for: target) ?? machine.systemImagePath
                        manager.update(machine)
                    } catch { errorMessage = error.localizedDescription }
                }
            }
        }
    }

    private var resolutionBinding: Binding<Int> {
        Binding(
            get: {
                resolutions.firstIndex { $0.1 == machine.width && $0.2 == machine.height } ?? 0
            },
            set: { i in
                machine.width = resolutions[i].1
                machine.height = resolutions[i].2
                machine.dpi = resolutions[i].3
            })
    }

    private func saveAndDismiss() {
        manager.update(machine)
        dismiss()
    }
}
