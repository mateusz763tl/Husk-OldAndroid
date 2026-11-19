// SPDX-License-Identifier: GPL-2.0-or-later
// husk://game/<package>, from a game's page on the website ("Open in Husk"): its page here when it is added, else the APK importer.
import Foundation

@MainActor enum GameLink {
    static func handle(_ url: URL) -> Bool {
        guard url.scheme == "husk", url.host == "game" || url.host == "app" else { return false }
        let id = url.lastPathComponent
        guard !id.isEmpty, id != "/" else { return true }
        let router = Router.shared
        if let item = Launcher.items(store: TranslationLayerStore.shared, host: AndroidHost.shared).first(where: { $0.accountID == id }) {
            // The Apps tab owns the same stack the old Library did, and it is
            // the one tab that can show a game's page now.
            router.tab = .library
            router.library = [item.route]
        } else {
            // There is no Store tab to send an unknown link to any more. An
            // APK link that is not installed belongs in the importer.
            router.tab = .library
            router.showImport = true
        }
        HuskLog.log("ui", "game link \(id)")
        return true
    }
}
