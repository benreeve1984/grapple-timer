import SwiftUI
import AppIntents

@main
struct GrappleTimerApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    
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