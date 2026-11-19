// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
import SwiftUI

// MARK: - Android releases

/// One Android version a machine can be built from.
///
/// Virtual Master's whole idea is picking an old Android version and getting a
/// separate little phone for it. Husk ships one bootable image (the LineageOS
/// build the QEMU runner was written around); every other version takes a
/// system image the user supplies. That keeps the catalogue honest: a version
/// is listed because it is a shape we know how to boot, not because a download
/// that does not exist was promised.
struct AndroidRelease: Identifiable, Hashable {
    let id: String
    let version: String
    let codename: String
    let api: Int
    let year: Int
    let builtIn: Bool
    let minRAMMiB: Int
    let defaultRAMMiB: Int
    let defaultWidth: Int
    let defaultHeight: Int
    let defaultDPI: Int

    var title: String { "\(version) \(codename)" }
    var shortTitle: String { "\(version) · \(codename)" }

    /// Virtual Master gives each Android generation its own colour. So do we.
    var accent: Color {
        switch id {
        case "android-4.4":  return Color(red: 0.55, green: 0.38, blue: 0.24)
        case "android-5.1":  return Color(red: 0.86, green: 0.24, blue: 0.22)
        case "android-6.0":  return Color(red: 0.90, green: 0.62, blue: 0.14)
        case "android-7.1":  return Color(red: 0.16, green: 0.60, blue: 0.55)
        case "android-8.1":  return Color(red: 0.20, green: 0.48, blue: 0.80)
        case "android-9":    return Color(red: 0.55, green: 0.29, blue: 0.72)
        case "android-10":   return Color(red: 0.20, green: 0.62, blue: 0.36)
        case "android-11":   return Color(red: 0.16, green: 0.52, blue: 0.72)
        case "android-12":   return Color(red: 0.12, green: 0.62, blue: 0.58)
        case "android-13":   return Color(red: 0.22, green: 0.70, blue: 0.42)
        case "android-14":   return Color(red: 0.48, green: 0.36, blue: 0.78)
        default:             return Theme.accent
        }
    }
}

enum AndroidReleases {
    /// Newest first is how a phone lists its own OS; oldest first is how Virtual
    /// Master lists the history. This is a version picker, so old ones are the
    /// point and the list runs from KitKat forward.
    static let all: [AndroidRelease] = [
        AndroidRelease(id: "android-4.4", version: "Android 4.4", codename: "KitKat",
                       api: 19, year: 2013, builtIn: false,
                       minRAMMiB: 768, defaultRAMMiB: 1024,
                       defaultWidth: 480, defaultHeight: 800, defaultDPI: 240),
        AndroidRelease(id: "android-5.1", version: "Android 5.1", codename: "Lollipop",
                       api: 22, year: 2015, builtIn: false,
                       minRAMMiB: 1024, defaultRAMMiB: 1536,
                       defaultWidth: 540, defaultHeight: 960, defaultDPI: 240),
        AndroidRelease(id: "android-6.0", version: "Android 6.0", codename: "Marshmallow",
                       api: 23, year: 2015, builtIn: false,
                       minRAMMiB: 1024, defaultRAMMiB: 2048,
                       defaultWidth: 720, defaultHeight: 1280, defaultDPI: 320),
        AndroidRelease(id: "android-7.1", version: "Android 7.1", codename: "Nougat",
                       api: 25, year: 2016, builtIn: false,
                       minRAMMiB: 1536, defaultRAMMiB: 2048,
                       defaultWidth: 720, defaultHeight: 1280, defaultDPI: 320),
        AndroidRelease(id: "android-8.1", version: "Android 8.1", codename: "Oreo",
                       api: 27, year: 2017, builtIn: false,
                       minRAMMiB: 1536, defaultRAMMiB: 2048,
                       defaultWidth: 720, defaultHeight: 1280, defaultDPI: 320),
        AndroidRelease(id: "android-9", version: "Android 9", codename: "Pie",
                       api: 28, year: 2018, builtIn: false,
                       minRAMMiB: 2048, defaultRAMMiB: 3072,
                       defaultWidth: 720, defaultHeight: 1280, defaultDPI: 320),
        AndroidRelease(id: "android-10", version: "Android 10", codename: "Quince Tart",
                       api: 29, year: 2019, builtIn: false,
                       minRAMMiB: 2048, defaultRAMMiB: 3072,
                       defaultWidth: 720, defaultHeight: 1280, defaultDPI: 320),
        AndroidRelease(id: "android-11", version: "Android 11", codename: "Red Velvet Cake",
                       api: 30, year: 2020, builtIn: false,
                       minRAMMiB: 2048, defaultRAMMiB: 3072,
                       defaultWidth: 720, defaultHeight: 1280, defaultDPI: 320),
        AndroidRelease(id: "android-12", version: "Android 12", codename: "Snow Cone",
                       api: 31, year: 2021, builtIn: false,
                       minRAMMiB: 3072, defaultRAMMiB: 4096,
                       defaultWidth: 720, defaultHeight: 1280, defaultDPI: 320),
        AndroidRelease(id: "android-13", version: "Android 13", codename: "Tiramisu",
                       api: 33, year: 2022, builtIn: true,
                       minRAMMiB: 3072, defaultRAMMiB: 4096,
                       defaultWidth: 360, defaultHeight: 800, defaultDPI: 320),
        AndroidRelease(id: "android-14", version: "Android 14", codename: "Upside Down Cake",
                       api: 34, year: 2023, builtIn: false,
                       minRAMMiB: 3072, defaultRAMMiB: 4096,
                       defaultWidth: 720, defaultHeight: 1280, defaultDPI: 320),
    ]

    static func release(_ id: String) -> AndroidRelease {
        all.first { $0.id == id } ?? all.first { $0.builtIn }!
    }

    static var builtIn: AndroidRelease {
        all.first { $0.builtIn }!
    }
}

// MARK: - a machine

/// One virtual Android phone.
///
/// Everything QEMU needs to boot this instance and nothing else lives under
/// `supportDirectory`: its userdata disk, its UEFI variables, its saved machine
/// and its guest RAM scratch file. The system image is shared because it is
/// read-only from Android's point of view and costs a gigabyte per copy.
struct VirtualMachine: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var releaseID: String
    var systemImagePath: String
    var userdataPath: String
    var varsPath: String
    var supportDirectory: String
    var ramMiB: Int
    var cpuCount: Int
    var width: Int
    var height: Int
    var dpi: Int
    var rootEnabled: Bool
    /// The machine that came from Husk's own pre-booted LineageOS install.
    /// It uses the guest's global disks and shipped snapshot, so starting it is
    /// seconds rather than the cold boot a fresh machine pays once.
    var legacyGuest: Bool
    var createdAt: Date
    var lastBootedAt: Date?

    var release: AndroidRelease { AndroidReleases.release(releaseID) }

    var directory: URL { URL(fileURLWithPath: supportDirectory, isDirectory: true) }

    /// "qcow2" or "raw", from the file the machine boots from.
    var systemImageFormat: String {
        systemImagePath.lowercased().hasSuffix(".img") ? "raw" : "qcow2"
    }

    var hasSystemImage: Bool {
        FileManager.default.fileExists(atPath: systemImagePath)
    }

    var displaySpec: String { "\(width)×\(height)" }
    var memorySpec: String {
        ramMiB >= 1024
            ? String(format: "%.1f GB", Double(ramMiB) / 1024).replacingOccurrences(of: ".0", with: "")
            : "\(ramMiB) MB"
    }
    var cpuSpec: String { "\(cpuCount) core\(cpuCount == 1 ? "" : "s")" }

    var storageBytes: Int64 {
        let fm = FileManager.default
        if legacyGuest {
            // The global Documents folder holds every machine's files, so only
            // the userdata disk is this machine's own.
            return ((try? fm.attributesOfItem(atPath: userdataPath))?[.size] as? NSNumber)?.int64Value ?? 0
        }
        guard let files = fm.enumerator(at: directory, includingPropertiesForKeys: [.totalFileAllocatedSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let url as URL in files {
            total += Int64((try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
                .totalFileAllocatedSize) ?? 0)
        }
        return total
    }
}

enum VirtualMachineError: LocalizedError {
    case missingImage(AndroidRelease)
    case missingSeed(String)
    case notQcow2(String)
    case legacyCannotBeDeleted
    case running
    var errorDescription: String? {
        switch self {
        case .missingImage(let r):
            return "\(r.version) needs a system image before it can start."
        case .missingSeed(let name):
            return "\(name) is missing from the app bundle. Rebuild the app with scripts/package_ipa.sh."
        case .notQcow2(let why):
            return "That file is not a usable Android disk image: \(why)"
        case .legacyCannotBeDeleted:
            return "The built-in machine can be reset, but not deleted."
        case .running:
            return "A machine is running. Close Husk before changing another one."
        }
    }
}

// MARK: - the manager

/// The machine list, its settings, and the folders each one owns.
@MainActor
final class VMManager: ObservableObject {
    static let shared = VMManager()

    @Published private(set) var machines: [VirtualMachine] = []
    @Published var selectedID: UUID?
    /// Set while a machine is booting or running, so the list can show which.
    @Published var runningID: UUID?

    /// Set by ContentView. A view cannot start QEMU itself without dragging the
    /// whole root view's state along, so the root lends it these two actions.
    var requestStart: (VirtualMachine) -> Void = { _ in }
    var requestOpenGuest: () -> Void = {}

    private let defaults = UserDefaults.standard
    private let selectedKey = "husk.vm.selected"
    private let migratedKey = "husk.vm.migrated"
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        load()
        if let saved = defaults.string(forKey: selectedKey).flatMap(UUID.init(uuidString:)),
           machines.contains(where: { $0.id == saved }) {
            selectedID = saved
        } else {
            selectedID = machines.first?.id
        }
        ensureLegacyMachine()
    }

    // MARK: persistence

    var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    var machinesDirectory: URL { documents.appendingPathComponent("Machines", isDirectory: true) }
    var imagesDirectory: URL { documents.appendingPathComponent("AndroidImages", isDirectory: true) }
    private var listURL: URL { documents.appendingPathComponent("husk-machines.json") }

    private func load() {
        guard let data = FileManager.default.contents(atPath: listURL.path),
              let list = try? decoder.decode([VirtualMachine].self, from: data) else { return }
        machines = list
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
            try encoder.encode(machines).write(to: listURL, options: .atomic)
        } catch {
            HuskLog.log("vm", "could not save the machine list: \(error.localizedDescription)")
        }
        if let id = selectedID { defaults.set(id.uuidString, forKey: selectedKey) }
    }

    /// An install that already has the QEMU guest gets a machine for it, once.
    /// Without this, updating Husk would look like all of Android had been
    /// deleted and replaced by an empty machine manager.
    private func ensureLegacyMachine() {
        guard !defaults.bool(forKey: migratedKey) else { return }
        guard machines.isEmpty else {
            // Someone made a machine before the built-in image existed. From
            // here on the manager is theirs, and adopting the global guest
            // later would add a second machine they never asked for.
            defaults.set(true, forKey: migratedKey)
            return
        }
        // Leave the migration open while the guest has not been downloaded:
        // whoever downloads it later still deserves the pre-booted machine.
        guard FileManager.default.fileExists(atPath: GuestImage.shared.diskPath) else { return }
        defaults.set(true, forKey: migratedKey)

        let release = AndroidReleases.builtIn
        let machine = VirtualMachine(
            id: UUID(),
            name: "LineageOS 20",
            releaseID: release.id,
            systemImagePath: GuestImage.shared.diskPath,
            userdataPath: GuestImage.shared.userdataPath,
            varsPath: GuestImage.shared.varsPath,
            supportDirectory: documents.path,
            ramMiB: GuestImage.snapshotGuestMiB,
            cpuCount: GuestImage.defaultSmp,
            width: GuestImage.snapshotXres,
            height: GuestImage.snapshotYres,
            dpi: 320,
            rootEnabled: false,
            legacyGuest: true,
            createdAt: Date(),
            lastBootedAt: nil)
        machines = [machine]
        selectedID = machine.id
        save()
        HuskLog.log("vm", "adopted the installed LineageOS guest as a machine")
    }

    // MARK: reading

    func machine(_ id: UUID) -> VirtualMachine? { machines.first { $0.id == id } }

    var selected: VirtualMachine? { selectedID.flatMap(machine) ?? machines.first }

    var lastBooted: VirtualMachine? {
        machines.filter { $0.lastBootedAt != nil }
            .max { ($0.lastBootedAt ?? .distantPast) < ($1.lastBootedAt ?? .distantPast) }
    }

    /// The system image this release can use, if one is installed.
    ///
    /// An imported disk keeps whichever extension it arrived with: QEMU needs
    /// `format=raw` for a `.img` and `format=qcow2` for anything else, and the
    /// machine derives that from the path. Looking only for the qcow2 name made
    /// a perfectly good raw import invisible to the very machine that needed it.
    func imagePath(for release: AndroidRelease) -> String? {
        if release.builtIn {
            let path = GuestImage.shared.diskPath
            return FileManager.default.fileExists(atPath: path) ? path : nil
        }
        let dir = imagesDirectory.appendingPathComponent(release.id, isDirectory: true)
        for name in ["system.qcow2", "system.img"] {
            let path = dir.appendingPathComponent(name).path
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return nil
    }

    func canCreate(_ release: AndroidRelease) -> Bool { imagePath(for: release) != nil }

    var runningMachine: VirtualMachine? { runningID.flatMap(machine) }

    func isRunning(_ machine: VirtualMachine) -> Bool {
        // activeMachine is the path QEMU actually opened, so it catches the
        // moment between markBooted and the first published isRunning update.
        QemuRunner.shared.isRunning
            && (runningID == machine.id || QemuRunner.activeMachine?.id == machine.id)
    }

    // MARK: creating

    func suggestedName(for release: AndroidRelease) -> String {
        let base = release.version
        guard machines.contains(where: { $0.name == base }) else { return base }
        var n = 2
        while machines.contains(where: { $0.name == "\(base) \(n)" }) { n += 1 }
        return "\(base) \(n)"
    }

    @discardableResult
    func create(name: String,
                release: AndroidRelease,
                ramMiB: Int,
                cpuCount: Int,
                width: Int,
                height: Int,
                dpi: Int,
                rootEnabled: Bool) throws -> VirtualMachine {
        guard let image = imagePath(for: release) else {
            throw VirtualMachineError.missingImage(release)
        }

        let fm = FileManager.default
        let id = UUID()
        let dir = machinesDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let userdata = dir.appendingPathComponent("userdata.qcow2")
        let vars = dir.appendingPathComponent("efi-vars.fd")
        try copyUserdataSeed(to: userdata)
        try copyVarsSeed(to: vars)

        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let machine = VirtualMachine(
            id: id,
            name: clean.isEmpty ? suggestedName(for: release) : uniqueName(clean),
            releaseID: release.id,
            systemImagePath: image,
            userdataPath: userdata.path,
            varsPath: vars.path,
            supportDirectory: dir.path,
            ramMiB: max(release.minRAMMiB, ramMiB),
            cpuCount: min(8, max(1, cpuCount)),
            width: width,
            height: height,
            dpi: dpi,
            rootEnabled: rootEnabled,
            legacyGuest: false,
            createdAt: Date(),
            lastBootedAt: nil)

        machines.append(machine)
        selectedID = machine.id
        save()
        HuskLog.log("vm", "created \(machine.name) (\(release.shortTitle)) in \(dir.path)")
        return machine
    }

    private func uniqueName(_ base: String) -> String {
        guard machines.contains(where: { $0.name == base }) else { return base }
        var n = 2
        while machines.contains(where: { $0.name == "\(base) \(n)" }) { n += 1 }
        return "\(base) \(n)"
    }

    private func copyUserdataSeed(to url: URL) throws {
        guard let seed = Bundle.main.path(forResource: "lineage-vdb-seed", ofType: "qcow2") else {
            throw VirtualMachineError.missingSeed("lineage-vdb-seed.qcow2")
        }
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.copyItem(atPath: seed, toPath: url.path)
    }

    private func copyVarsSeed(to url: URL) throws {
        guard let seed = Bundle.main.path(forResource: "lineage-efi-vars-seed", ofType: "fd") else {
            throw VirtualMachineError.missingSeed("lineage-efi-vars-seed.fd")
        }
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.copyItem(atPath: seed, toPath: url.path)
    }

    // MARK: editing

    func update(_ machine: VirtualMachine) {
        guard let i = machines.firstIndex(where: { $0.id == machine.id }) else { return }
        machines[i] = machine
        save()
    }

    func markBooted(_ machine: VirtualMachine) {
        guard let i = machines.firstIndex(where: { $0.id == machine.id }) else { return }
        machines[i].lastBootedAt = Date()
        selectedID = machine.id
        runningID = machine.id
        save()
    }

    func select(_ machine: VirtualMachine) {
        selectedID = machine.id
        save()
    }

    /// Boot the machine again from a clean /data. The system image is untouched:
    /// this is a factory reset, not a reinstall.
    func resetData(_ machine: VirtualMachine) throws {
        guard !isRunning(machine) else { throw VirtualMachineError.running }
        let fm = FileManager.default

        if machine.legacyGuest {
            // The shipped snapshot lives in userdata. Drop both, then let the
            // normal guest preparation stage a fresh one.
            for path in [machine.userdataPath,
                         GuestImage.shared.snapshotStampPath,
                         GuestImage.shared.snapshotDigestPath,
                         GuestImage.shared.snapshotPinsPath,
                         QemuRunner.shared.guestRamPath,
                         QemuRunner.shared.memoryStrategyPath,
                         QemuRunner.shared.ramAttemptPath,
                         QemuRunner.shared.ramProvenPath,
                         QemuRunner.shared.ramFailedPath] {
                try? fm.removeItem(atPath: path)
            }
            try GuestImage.shared.prepareFirmware()
            HuskLog.log("vm", "reset \(machine.name)'s data; the shipped snapshot was discarded")
            return
        }

        let userdata = URL(fileURLWithPath: machine.userdataPath)
        let vars = URL(fileURLWithPath: machine.varsPath)
        try copyUserdataSeed(to: userdata)
        try copyVarsSeed(to: vars)
        for name in ["husk-snapshot.mib", "husk-snapshot.display", "husk-memory-strategy",
                     "guest-ram.bin", "husk-ram-attempt", "husk-ram-proven", "husk-ram-failed"] {
            try? fm.removeItem(atPath: machine.directory.appendingPathComponent(name).path)
        }
        for sub in ["snapshots"] {
            try? fm.removeItem(atPath: machine.directory.appendingPathComponent(sub).path)
        }
        HuskLog.log("vm", "reset \(machine.name)'s data")
    }

    func duplicate(_ machine: VirtualMachine) throws -> VirtualMachine {
        guard !isRunning(machine) else { throw VirtualMachineError.running }
        let fm = FileManager.default
        let id = UUID()
        let dir = machinesDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let userdata = dir.appendingPathComponent("userdata.qcow2")
        let vars = dir.appendingPathComponent("efi-vars.fd")
        if machine.legacyGuest {
            // Copying several gigabytes of shipped snapshot to make a copy is a
            // poor trade, and a fresh /data is what a new machine is.
            try copyUserdataSeed(to: userdata)
        } else if fm.fileExists(atPath: machine.userdataPath) {
            try fm.copyItem(atPath: machine.userdataPath, toPath: userdata.path)
        } else {
            try copyUserdataSeed(to: userdata)
        }
        if fm.fileExists(atPath: machine.varsPath) {
            try fm.copyItem(atPath: machine.varsPath, toPath: vars.path)
        } else {
            try copyVarsSeed(to: vars)
        }

        var copy = machine
        copy.id = id
        copy.name = uniqueName(machine.name + " Copy")
        copy.userdataPath = userdata.path
        copy.varsPath = vars.path
        copy.supportDirectory = dir.path
        copy.legacyGuest = false
        copy.createdAt = Date()
        copy.lastBootedAt = nil
        machines.append(copy)
        selectedID = id
        save()
        return copy
    }

    func delete(_ machine: VirtualMachine) throws {
        guard !isRunning(machine) else { throw VirtualMachineError.running }
        guard !machine.legacyGuest else { throw VirtualMachineError.legacyCannotBeDeleted }
        machines.removeAll { $0.id == machine.id }
        try? FileManager.default.removeItem(at: machine.directory)
        if selectedID == machine.id { selectedID = machines.first?.id }
        save()
    }

    // MARK: importing a system image

    /// Copy a user-supplied Android disk into this release's image slot.
    ///
    /// Only the disk is the user's; the machine still gets Husk's own UEFI
    /// variables and a fresh userdata, so an image from another project cannot
    /// bring a stale boot entry or somebody else's /data with it.
    @discardableResult
    func importImage(_ url: URL, for release: AndroidRelease) async throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.lowercased()
        guard ext == "qcow2" || ext == "img" else {
            throw VirtualMachineError.notQcow2("use a .qcow2 or .img system disk")
        }

        if ext == "qcow2" {
            if let why = GuestImage.validate(path: url.path).problem {
                throw VirtualMachineError.notQcow2(why)
            }
        } else {
            let size = ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.int64Value ?? 0
            guard size >= 64 * 1024 * 1024 else {
                throw VirtualMachineError.notQcow2("only \(size) bytes; expected at least 64 MB")
            }
        }

        let dir = imagesDirectory.appendingPathComponent(release.id, isDirectory: true)
        // Keep the extension truthful for QEMU's format= argument. Copy first,
        // then replace: a failed copy of a multi-gigabyte disk must not leave
        // the user with neither the old image nor the new one.
        let dest = dir.appendingPathComponent(ext == "img" ? "system.img" : "system.qcow2")
        let temp = dir.appendingPathComponent("import-\(UUID().uuidString).\(ext)")

        // A system disk is routinely a gigabyte or more. Copying it on the main
        // actor freezes the create sheet for the whole copy, which on a slow
        // device is long enough for the watchdog to end the app.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let fm = FileManager.default
                do {
                    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                    try fm.copyItem(at: url, to: temp)
                    for old in ["system.qcow2", "system.img"] {
                        let oldPath = dir.appendingPathComponent(old).path
                        if oldPath != dest.path { try? fm.removeItem(atPath: oldPath) }
                    }
                    if fm.fileExists(atPath: dest.path) {
                        _ = try fm.replaceItemAt(dest, withItemAt: temp)
                    } else {
                        try fm.moveItem(at: temp, to: dest)
                    }
                    continuation.resume()
                } catch {
                    try? fm.removeItem(at: temp)
                    continuation.resume(throwing: error)
                }
            }
        }
        HuskLog.log("vm", "imported \(release.shortTitle) image (\(dest.lastPathComponent))")
        return dest.path
    }

    func removeImage(for release: AndroidRelease) {
        let dir = imagesDirectory.appendingPathComponent(release.id, isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: labels

    func status(for machine: VirtualMachine) -> MachineStatus {
        if isRunning(machine) { return .running }
        if QemuRunner.shared.isRunning { return .busy }
        if !machine.hasSystemImage { return .needsImage }
        if machine.legacyGuest && GuestImage.shared.hasShippedSnapshot { return .ready }
        return .stopped
    }

    enum MachineStatus: Equatable {
        case running, ready, stopped, needsImage, busy
        var title: String {
            switch self {
            case .running: return "Running"
            case .ready: return "Ready"
            case .stopped: return "Stopped"
            case .needsImage: return "Image needed"
            case .busy: return "Another machine is running"
            }
        }
        var color: Color {
            switch self {
            case .running, .ready: return .green
            case .needsImage: return .orange
            case .busy: return .secondary
            case .stopped: return .secondary
            }
        }
    }
}

extension Int64 {
    /// "1.2 GB" for storage readouts.
    var huskByteText: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
