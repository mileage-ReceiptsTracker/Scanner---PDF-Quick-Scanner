import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

@main
struct IphoneScannerApp: App {
    @StateObject private var store = DocumentStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    requestTrackingAndStartAds()
                }
        }
    }

    private func requestTrackingAndStartAds() {
        ATTrackingManager.requestTrackingAuthorization { _ in
            GADMobileAds.sharedInstance().start { _ in
                AppOpenAdManager.shared.loadAd()
            }
        }
    }
}
