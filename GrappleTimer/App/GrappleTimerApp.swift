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
            // App became active - try to reconnect Spotify if it was connected
            Task {
                await SpotifyControl.shared.handleAppBecameActive()
            }
        case .inactive:
            // App is transitioning - don't disconnect yet
            break
        case .background:
            // App went to background - maintain connection if possible
            Task {
                await SpotifyControl.shared.handleAppWentToBackground()
            }
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