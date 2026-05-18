import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: DocumentStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showScanner = false
    @State private var showSplash  = true

    var body: some View {
        ZStack {
            NavigationStack {
                ZStack(alignment: .bottom) {
                    GalleryView(showScanner: $showScanner)
                        .safeAreaInset(edge: .bottom) {
                            Color.clear.frame(height: 80)
                        }

                    ScanTabBar(onScan: { showScanner = true })
                }
                .navigationTitle("My Scans")
                .navigationBarTitleDisplayMode(.large)
                .ignoresSafeArea(edges: .bottom)
            }
            .sheet(isPresented: $showScanner) {
                ScannerFlowView()
                    .environmentObject(store)
                    .ignoresSafeArea()
            }
            // Show AOA when coming back from background (not during splash)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, !showSplash {
                    AppOpenAdManager.shared.showAdIfAvailable()
                }
            }

            if showSplash {
                SplashView()
                    .zIndex(1)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                showSplash = false
                            }
                            AppOpenAdManager.shared.showAdIfAvailable()
                        }
                    }
            }
        }
    }
}

// MARK: - Scan tab bar

struct ScanTabBar: View {
    let onScan: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                Button(action: onScan) {
                    ZStack {
                        Circle()
                            .fill(Color.teal)
                            .frame(width: 62, height: 62)
                            .shadow(color: .teal.opacity(0.35), radius: 8, y: 3)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .offset(y: -8)
                Spacer()
            }
            .frame(height: 72)
            .background(.regularMaterial)
        }
    }
}
