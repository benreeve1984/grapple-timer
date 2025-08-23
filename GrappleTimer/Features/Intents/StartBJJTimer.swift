import AppIntents
import SwiftUI

enum PlaylistSelection: String, AppEnum {
    case useCurrentPlayback = "current"
    case usePlaylistURI = "playlist"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Playlist Selection"
    
    static var caseDisplayRepresentations: [PlaylistSelection: DisplayRepresentation] = [
        .useCurrentPlayback: "Use current Spotify playback",
        .usePlaylistURI: "Use specific playlist"
    ]
}

struct StartBJJTimer: AppIntent {
    static var title: LocalizedStringResource = "Start BJJ Timer"
    
    static var description = IntentDescription(
        "Start a Brazilian Jiu-Jitsu training timer with customizable rounds, rest periods, and clapper alerts"
    )
    
    static var openAppWhenRun: Bool = true
    
    @Parameter(
        title: "Round Duration",
        description: "Duration of each work round in seconds",
        default: 300
    )
    var roundSeconds: Int
    
    @Parameter(
        title: "Rest Duration",
        description: "Duration of rest between rounds in seconds",
        default: 60
    )
    var restSeconds: Int
    
    @Parameter(
        title: "Number of Rounds",
        description: "Total number of rounds",
        default: 5
    )
    var rounds: Int
    
    @Parameter(
        title: "Clapper Time",
        description: "Seconds before round end to play clapper sound",
        default: 10
    )
    var clapperSeconds: Int
    
    @Parameter(
        title: "Music Selection",
        description: "Choose music playback mode",
        default: .useCurrentPlayback
    )
    var playlistSelection: PlaylistSelection
    
    @Parameter(
        title: "Playlist URI",
        description: "Spotify playlist URI (if using specific playlist)"
    )
    var playlistURI: String?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Start timer with \(\.$roundSeconds) second rounds, \(\.$restSeconds) second rest, \(\.$rounds) rounds, clapper at \(\.$clapperSeconds) seconds") {
            \.$playlistSelection
            \.$playlistURI
        }
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & OpensIntent {
        let configStore = ConfigStore.shared
        let appCoordinator = AppCoordinator.shared
        
        guard roundSeconds > 0, restSeconds > 0, rounds > 0 else {
            throw IntentError.invalidInput
        }
        
        guard clapperSeconds < roundSeconds else {
            throw IntentError.clapperTooLong
        }
        
        configStore.updateFromSiri(
            roundSeconds: roundSeconds,
            restSeconds: restSeconds,
            rounds: rounds,
            clapperSeconds: clapperSeconds
        )
        
        if playlistSelection == .usePlaylistURI, let uri = playlistURI {
            configStore.settings.musicMode = .usePlaylist(uri: uri)
        } else {
            configStore.settings.musicMode = .useCurrentPlayback
        }
        
        let configuration = TimerConfiguration(
            roundDuration: TimeInterval(roundSeconds),
            restDuration: TimeInterval(restSeconds),
            rounds: rounds,
            clapperTime: TimeInterval(clapperSeconds),
            startDelay: configStore.settings.enableStartDelay ? 3 : 0
        )
        
        // Actually start the timer through the app coordinator
        appCoordinator.startSessionFromSiri(configuration: configuration)
        
        let roundMinutes = roundSeconds / 60
        let roundSecondsRemainder = roundSeconds % 60
        let restMinutes = restSeconds / 60
        let restSecondsRemainder = restSeconds % 60
        
        let roundDisplay = roundSecondsRemainder > 0 ? 
            "\(roundMinutes):\(String(format: "%02d", roundSecondsRemainder))" : 
            "\(roundMinutes) minute\(roundMinutes != 1 ? "s" : "")"
        
        let restDisplay = restSecondsRemainder > 0 ? 
            "\(restMinutes):\(String(format: "%02d", restSecondsRemainder))" : 
            "\(restMinutes) minute\(restMinutes != 1 ? "s" : "")"
        
        return .result(
            opensIntent: OpenIntent(),
            dialog: "Starting timer: \(rounds) rounds of \(roundDisplay) with \(restDisplay) rest"
        )
    }
}

enum IntentError: LocalizedError {
    case invalidInput
    case clapperTooLong
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Invalid timer settings. Please check your values."
        case .clapperTooLong:
            return "Clapper time cannot be longer than round duration."
        }
    }
}

struct OpenIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Grapple Timer"
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct GrappleTimerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartBJJTimer(),
            phrases: [
                "Start BJJ timer in \(.applicationName)",
                "Start grappling timer in \(.applicationName)",
                "Start Brazilian Jiu-Jitsu timer in \(.applicationName)",
                "Begin BJJ session in \(.applicationName)",
                "Start rolling timer in \(.applicationName)"
            ],
            shortTitle: "Start BJJ Timer",
            systemImageName: "timer"
        )
    }
    
    static var shortcutTileColor: ShortcutTileColor = .blue
}