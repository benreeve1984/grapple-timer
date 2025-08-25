import SwiftUI
import AppIntents

@main
struct GrappleTimerApp: App {
    @StateObject private var appCoordinator = AppCoordinator.shared
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        GrappleTimerShortcuts.updateAppShortcutParameters()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appCoordinator)
                .onOpenURL { url in
                    appCoordinator.handleURL(url)
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // App became active
            break
        case .inactive:
            // App is transitioning
            break
        case .background:
            // App went to background
            break
        @unknown default:
            break
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    var body: some View {
        if appCoordinator.showingSession {
            SessionView(timerEngine: appCoordinator.timerEngine)
        } else {
            HomeView()
        }
    }
}