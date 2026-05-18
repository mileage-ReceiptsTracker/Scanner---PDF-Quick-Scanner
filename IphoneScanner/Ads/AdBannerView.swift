import SwiftUI
import GoogleMobileAds

// Replace with your real AdMob banner unit ID before publishing.
// Test ID: ca-app-pub-3940256099942544/2934735716
private let bannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"

struct AdBannerView: UIViewRepresentable {
    func makeUIView(context: Context) -> GADBannerView {
        let width = UIScreen.main.bounds.width
        let adaptiveSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
        let banner = GADBannerView(adSize: adaptiveSize)
        banner.adUnitID = bannerAdUnitID
        banner.rootViewController = context.coordinator.rootVC
        banner.load(GADRequest())
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var rootVC: UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first?.rootViewController
        }
    }
}
