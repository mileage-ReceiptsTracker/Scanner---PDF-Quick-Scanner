import GoogleMobileAds
import UIKit

final class AppOpenAdManager: NSObject, GADFullScreenContentDelegate {

    static let shared = AppOpenAdManager()

    private let adUnitID = "ca-app-pub-3286278465510951/5872650107"

    private var appOpenAd: GADAppOpenAd?
    private var isLoadingAd  = false
    private var isShowingAd  = false
    var showWhenReady = false

    private override init() { super.init() }

    // MARK: - Load

    func loadAd() {
        guard !isLoadingAd, appOpenAd == nil else { return }
        isLoadingAd = true
        GADAppOpenAd.load(withAdUnitID: adUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self else { return }
            self.isLoadingAd = false
            if let error {
                print("[AOA] load failed: \(error.localizedDescription)")
                return
            }
            self.appOpenAd = ad
            self.appOpenAd?.fullScreenContentDelegate = self
            if self.showWhenReady {
                self.showWhenReady = false
                self.showAdIfAvailable()
            }
        }
    }

    // MARK: - Show

    func showAdIfAvailable() {
        guard !isShowingAd else { return }
        guard let ad = appOpenAd else {
            showWhenReady = true
            loadAd()
            return
        }
        guard let root = rootViewController() else {
            print("[AOA] no root view controller")
            return
        }
        print("[AOA] presenting ad")
        ad.present(fromRootViewController: root)
    }

    // MARK: - GADFullScreenContentDelegate

    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        isShowingAd = true
        print("[AOA] ad presenting")
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        appOpenAd  = nil
        isShowingAd = false
        print("[AOA] ad dismissed — preloading next")
        loadAd()
    }

    func ad(_ ad: GADFullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error) {
        appOpenAd  = nil
        isShowingAd = false
        print("[AOA] present failed: \(error.localizedDescription)")
        loadAd()
    }

    // MARK: - Helpers

    private func rootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root  = scene.windows.first?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
