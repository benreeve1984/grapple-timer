import SwiftUI
import Combine

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var showingSession = false
    @Published var timerEngine = TimerEngine()
    
    private let configStore = ConfigStore.shared
    private let spotifyControl = SpotifyControl.shared
    private let audioCue = AudioCue.shared
    private let notificationScheduler = NotificationScheduler.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupTimerCallbacks()
        requestNotificationPermission()
    }
    
    func handleURL(_ url: URL) {
        if url.scheme == "grappletimer" {
            if url.host == "spotify-callback" {
                _ = spotifyControl.handleOpenURL(url)
            } else if url.host == "start-timer" {
                handleStartTimerDeepLink(url)
            }
        }
    }
    
    func startSessionFromSiri(configuration: TimerConfiguration) {
        timerEngine.start(configuration: configuration)
        showingSession = true
    }
    
    private func handleStartTimerDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return }
        
        var roundDuration: TimeInterval = 300
        var restDuration: TimeInterval = 60
        var rounds: Int = 5
        var clapperTime: TimeInterval = 10
        
        for item in queryItems {
            switch item.name {
            case "round":
                if let value = item.value, let seconds = TimeInterval(value) {
                    roundDuration = seconds
                }
            case "rest":
                if let value = item.value, let seconds = TimeInterval(value) {
                    restDuration = seconds
                }
            case "rounds":
                if let value = item.value, let count = Int(value) {
                    rounds = count
                }
            case "clapper":
                if let value = item.value, let seconds = TimeInterval(value) {
                    clapperTime = seconds
                }
            default:
                break
            }
        }
        
        let configuration = TimerConfiguration(
            roundDuration: roundDuration,
            restDuration: restDuration,
            rounds: rounds,
            clapperTime: clapperTime,
            startDelay: configStore.settings.enableStartDelay ? 3 : 0
        )
        
        if configuration.isValid {
            timerEngine.start(configuration: configuration)
            showingSession = true
        }
    }
    
    private func setupTimerCallbacks() {
        timerEngine.onPhaseChange = { [weak self] oldPhase, newPhase in
            Task { @MainActor in
                await self?.handlePhaseChange(from: oldPhase, to: newPhase)
            }
        }
        
        timerEngine.onClapper = { [weak self] in
            self?.audioCue.playClapper()
        }
        
        AudioSessionManager.shared.onInterruptionBegan = { [weak self] in
            if self?.timerEngine.phase.isActive == true && self?.timerEngine.isPaused == false {
                self?.timerEngine.pause()
            }
        }
        
        AudioSessionManager.shared.onInterruptionEnded = { [weak self] shouldResume in
            if shouldResume && self?.timerEngine.isPaused == true {
                self?.timerEngine.resume()
            }
        }
    }
    
    private func handlePhaseChange(from oldPhase: Phase, to newPhase: Phase) async {
        switch newPhase {
        case .work:
            audioCue.playHorn()
            if configStore.settings.musicMode == .useCurrentPlayback {
                try? await spotifyControl.resume()
            } else if case .usePlaylist(let uri) = configStore.settings.musicMode {
                try? await spotifyControl.play(mode: .usePlaylist(uri: uri))
            }
            
        case .rest:
            audioCue.playHorn()
            try? await spotifyControl.pause()
            
        case .done:
            audioCue.playHorn()
            try? await spotifyControl.pause()
            showingSession = false
            
        case .starting:
            audioCue.playStartCountdown()
            
        default:
            break
        }
    }
    
    private func requestNotificationPermission() {
        Task {
            _ = await notificationScheduler.requestAuthorization()
        }
    }
}