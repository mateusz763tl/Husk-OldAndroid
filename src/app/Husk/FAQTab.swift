// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI

/// Help: common problems and what to do about them, so a user stuck on JIT or on an app that will not open has an answer
/// without leaving Husk. A page in Settings (it was a tab of its own; four tabs read simpler than five).
struct FAQTab: View {
    @State private var query = ""

    private var sections: [FAQ.Section] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return FAQ.sections }
        return FAQ.sections.compactMap { s in
            let items = s.items.filter { $0.question.localizedCaseInsensitiveContains(q) || $0.answer.localizedCaseInsensitiveContains(q) }
            return items.isEmpty ? nil : FAQ.Section(title: s.title, symbol: s.symbol, items: items)
        }
    }

    var body: some View {
            HuskPageList {
                ForEach(sections) { s in
                    Section {
                        ForEach(s.items) { item in FAQRow(item: item, expanded: !query.isEmpty) }
                    } header: {
                        Label(s.title, systemImage: s.symbol)
                    }
                }
                if sections.isEmpty {
                    Text("Nothing matches “\(query)”. Open Settings › About › Open Console to see what Husk is doing.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Help")
            .searchable(text: $query, prompt: "Search problems")
    }
}

private struct FAQRow: View {
    let item: FAQ.Item
    var expanded: Bool
    @State private var open = false

    var body: some View {
        DisclosureGroup(isExpanded: Binding(get: { open || expanded }, set: { open = $0 })) {
            Text(.init(item.answer))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 4)
        } label: {
            Text(item.question).font(.body.weight(.medium))
        }
    }
}

enum FAQ {
    struct Item: Identifiable { let question: String; let answer: String; var id: String { question } }
    struct Section: Identifiable { let title: String; let symbol: String; let items: [Item]; var id: String { title } }

    static let sections: [Section] = [
        Section(title: "JIT", symbol: "bolt.fill", items: [
            Item(question: "What is JIT, and why does Husk need it?",
                 answer: "Android is emulated, and its code has to be translated while the machine runs. That needs memory that can be written and then run. "
                       + "iOS only allows that while a debugger is attached to the app. Turning on JIT attaches one for a moment. "
                       + "Without it, Husk can show your machines but cannot start one."),
            Item(question: "Which way of turning on JIT should I use?",
                 answer: "• **iOS 27 or later:** Settings › JIT › Pair on this iPhone. No computer needed.\n"
                       + "• **iOS 26:** StikJIT (built in) with a pairing file made on a computer, plus LocalDevVPN.\n"
                       + "• **Older iOS, or Husk inside LiveContainer:** the StikDebug app.\n"
                       + "• **Installed with TrollStore:** TrollStore, with its URL Scheme setting on.\n"
                       + "• **Jailbroken with Dopamine:** turn on JIT for apps in the jailbreak's settings."),
            Item(question: "StikJIT says it cannot connect, or Enable JIT fails",
                 answer: "1. Make sure **LocalDevVPN** is installed and connected. The VPN icon should be in the status bar.\n"
                       + "2. Wi-Fi must be on, even though nothing leaves your iPhone.\n"
                       + "3. **Developer Mode** must be on (Settings › Privacy & Security › Developer Mode).\n"
                       + "4. The first time, Husk downloads Apple's Developer Disk Image, which can take a minute. Let it finish.\n"
                       + "5. Still failing? Toggle LocalDevVPN off and on, then pair again."),
            Item(question: "“Pair with Husk” does not appear in Developer Mode",
                 answer: "Tap **Start pairing** in Husk first and allow **Local Network** access when asked. If you said no earlier, "
                       + "turn it on in Settings › Privacy & Security › Local Network › Husk. Wi-Fi has to be on. "
                       + "Developer Mode must already be enabled, which restarts the iPhone the first time."),
            Item(question: "My pairing file stopped working",
                 answer: "Pairing files stop working when the iPhone's trust settings are reset, and sometimes after an iOS update. "
                       + "Make a new one, or pair on the iPhone itself if you are on iOS 27, then import it again in Settings › JIT."),
            Item(question: "Why do I have to turn JIT on again?",
                 answer: "JIT lasts as long as Husk is running. When iOS closes Husk in the background, or you swipe it away, "
                       + "the next launch needs JIT again. With Pair on this iPhone or a pairing file it is one tap."),
            Item(question: "Can I use Husk without JIT?",
                 answer: "You can browse and import machines, but none of them can start. Android always needs JIT."),
        ]),
        Section(title: "Machines", symbol: "desktopcomputer", items: [
            Item(question: "How do I make a machine?",
                 answer: "Open **Machines** and tap +. Pick an Android version, a name, how much memory and how many CPU cores it gets, "
                       + "and its screen size. Each machine keeps its own storage, so what you install in one does not appear in another."),
            Item(question: "Why can only one machine run at a time?",
                 answer: "Husk runs Android with QEMU, and iOS grants one emulator its JIT memory. Starting a second machine would need "
                       + "the first one to stop. Save or stop the running machine before starting another."),
            Item(question: "Why is Android 4.4–14 listed but not downloadable?",
                 answer: "Husk ships one ready-to-boot image: Android 13 (LineageOS 20). The older versions are shapes QEMU can boot, "
                       + "but their system images are not Husk's to redistribute. A machine for one of them needs a system disk you supply."),
            Item(question: "What image can I import?",
                 answer: "A **.qcow2** or **.img** system disk, at least 64 MB, from the machine's page. Husk copies it into its own folder, "
                       + "gives the machine fresh UEFI variables and a new data disk, and starts from cold."),
            Item(question: "What does Reset do?",
                 answer: "Reset throws away the machine's data disk and saved state, then sets up a clean /data. The Android system image is "
                       + "not touched, so it is a factory reset rather than a reinstall. **Duplicate** copies the machine instead, including its data."),
            Item(question: "Why can't I delete one machine?",
                 answer: "An install upgraded from an older Husk gets a machine for the Android guest it already had. That one is marked as "
                       + "the built-in machine: it can be reset, but not deleted, so an upgrade never silently throws away your data."),
        ]),
        Section(title: "Apps", symbol: "square.grid.2x2.fill", items: [
            Item(question: "How do I install an app?",
                 answer: "Start a machine, open **Apps**, and tap + to pick an APK, or share the file to Husk from Files. The app installs "
                       + "into the machine that is running, and stays in that machine."),
            Item(question: "Which files can I install?",
                 answer: ".apk, and split bundles as .apks, .xapk or .apkm. Split sets — a base APK plus its config pieces — must be picked "
                       + "together; installing the base alone fails on missing native libraries."),
            Item(question: "An app will not open",
                 answer: "Some apps check that they are on a real Android phone, need Google Play services, or only ship x86 code. "
                       + "Husk does not get around those. Try an ARM (arm64-v8a or armeabi-v7a) build, or a version that works offline."),
            Item(question: "Sign-in with Google does not work",
                 answer: "The built-in image has no Google Play services, so “Sign in with Google” buttons can fail. Use email or another sign-in if the app offers one."),
            Item(question: "A machine runs slowly or the phone gets hot",
                 answer: "Every instruction is emulated, so a big app is much slower than on a real phone. Close other apps, let the phone cool, "
                       + "and give the machine fewer cores or less memory if it is fighting the rest of iOS. Low Power Mode slows Husk down too."),
        ]),
        Section(title: "Storage", symbol: "externaldrive.fill", items: [
            Item(question: "Husk is using a lot of storage",
                 answer: "Each machine has its own data disk, and a saved machine adds more. Delete machines you no longer use, or reset one "
                       + "to reclaim its data. The built-in Android image is shared by every machine built from it."),
            Item(question: "Where did my machine's files go?",
                 answer: "Each machine's disks, UEFI variables and saved state live in its own folder in Husk's Documents directory. "
                       + "Deleting the machine deletes that folder; the shared system image stays."),
        ]),
        Section(title: "Husk Itself", symbol: "app.badge", items: [
            Item(question: "Husk will not open at all",
                 answer: "• **Opens and closes instantly:** the signing certificate has probably expired. Free Apple accounts last 7 days. "
                       + "Re-sign or reinstall Husk with your sideloader; your machines and saves stay.\n"
                       + "• **“Untrusted Developer”:** go to Settings › General › VPN & Device Management and trust your certificate.\n"
                       + "• **Asks for Developer Mode:** turn it on in Settings › Privacy & Security."),
            Item(question: "Husk closed while a machine was running",
                 answer: "When Husk opens again it shows what happened, with a report you can share. Emulation can run out of memory or hit "
                       + "something QEMU does not support yet. Give the machine less memory, close other apps, and share the report if it keeps happening."),
            Item(question: "How do I get logs to report a problem?",
                 answer: "Go to Settings › About › **Open Console** for Husk's own log. Turning on **Developer Info** there adds more detail."),
            Item(question: "How do I update Husk?",
                 answer: "Husk tells you when a new version is out. Install the new IPA over the old one with the same sideloader. "
                       + "Your machines, apps and saves are kept."),
        ]),
    ]
}
