import SwiftUI
import UIKit

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                if let icon = getAppIcon() {
                    Image(uiImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                } else {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 64))
                        .foregroundStyle(.teal)
                }

                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.teal)
            }
        }
    }

    private func getAppIcon() -> UIImage? {
        if let icon = UIImage(named: "AppIcon") { return icon }
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let last = files.last {
            return UIImage(named: last)
        }
        for name in ["AppIcon-60@2x", "AppIcon-60@3x", "AppIcon@2x", "AppIcon@3x"] {
            if let icon = UIImage(named: name) { return icon }
        }
        return nil
    }
}
