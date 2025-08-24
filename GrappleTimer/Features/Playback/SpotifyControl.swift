import Foundation
import Combine
import UIKit
import SpotifyiOS

enum MusicMode: Codable, Equatable, Hashable {
    case noMusic
    case useCurrentPlayback
    case usePlaylist(uri: String)
    
    var displayName: String {
        switch self {
        case .noMusic:
            return "No Music"
        case .useCurrentPlayback:
            return "Current Playback"
        case .usePlaylist:
            return "Custom Playlist"
        }
    }
}

enum SpotifyError: LocalizedError {
    case notInstalled
    case notLoggedIn
    case connectionFailed
    case authenticationFailed
    case premiumRequired
    case invalidPlaylistURI
    
    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Spotify app is not installed"
        case .notLoggedIn:
            return "Please log in to Spotify"
        case .connectionFailed:
            return "Failed to connect to Spotify"
        case .authenticationFailed:
            return "Spotify authentication failed"
        case .premiumRequired:
            return "Spotify Premium required for playlist selection"
        case .invalidPlaylistURI:
            return "Invalid Spotify playlist URI"
        }
    }
}

@MainActor
protocol SpotifyControlProtocol {
    var isConnected: Bool { get }
    var isPremium: Bool { get }
    var currentError: SpotifyError? { get }
    
    func connect() async throws
    func disconnect()
    func play(mode: MusicMode) async throws
    func pause() async throws
    func resume() async throws
}

@MainActor
final class SpotifyControl: NSObject, ObservableObject, SpotifyControlProtocol, SPTSessionManagerDelegate, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    static let shared = SpotifyControl()
    
    static let clientID = "0450fcbf37fe4d698008fb0e650d2232"
    static let redirectURI = "grappletimer://spotify-callback"
    
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var currentError: SpotifyError?
    @Published private(set) var isPlaying: Bool = false
    
    private var connectionAttempts = 0
    private let maxConnectionAttempts = 3
    
    private var sessionManager: SPTSessionManager?
    private var appRemote: SPTAppRemote?
    private var accessToken: String?
    private var wasConnectedBeforeBackground = false
    
    private override init() {
        super.init()
        setupSpotify()
    }
    
    private func setupSpotify() {
        let configuration = SPTConfiguration(
            clientID: Self.clientID,
            redirectURL: URL(string: Self.redirectURI)!
        )
        configuration.playURI = ""
        
        sessionManager = SPTSessionManager(configuration: configuration, delegate: self)
        
        appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        appRemote?.delegate = self
    }
    
    func connect() async throws {
        currentError = nil
        
        guard isSpotifyInstalled() else {
            currentError = .notInstalled
            throw SpotifyError.notInstalled
        }
        
        connectionAttempts += 1
        
        // If we already have an access token, try to connect the app remote
        if let token = accessToken {
            appRemote?.connectionParameters.accessToken = token
            appRemote?.connect()
        } else {
            // Need to authenticate first
            try await performConnection()
        }
    }
    
    func disconnect() {
        appRemote?.disconnect()
        isConnected = false
        isPlaying = false
        currentError = nil
    }
    
    // MARK: - Lifecycle Management
    func handleAppBecameActive() async {
        // If we were connected before and lost connection, try to reconnect
        if wasConnectedBeforeBackground && !isConnected && accessToken != nil {
            print("App became active - attempting to reconnect to Spotify")
            // Try to reconnect the app remote
            if let token = accessToken {
                appRemote?.connectionParameters.accessToken = token
                appRemote?.connect()
            }
        } else if isConnected {
            print("App became active - Spotify still connected")
        }
    }
    
    func handleAppWentToBackground() async {
        // Remember if we were connected
        wasConnectedBeforeBackground = isConnected
        // Don't disconnect - the connection should persist
        print("App went to background - maintaining Spotify connection (connected: \(isConnected))")
    }
    
    func play(mode: MusicMode) async throws {
        if !isConnected {
            try await connect()
        }
        
        currentError = nil
        
        switch mode {
        case .noMusic:
            // Do nothing for no music mode
            return
            
        case .useCurrentPlayback:
            try await resumeCurrentPlayback()
            
        case .usePlaylist(let uri):
            guard isValidPlaylistURI(uri) else {
                currentError = .invalidPlaylistURI
                throw SpotifyError.invalidPlaylistURI
            }
            
            try await playPlaylist(uri: uri)
        }
        
        isPlaying = true
    }
    
    func pause() async throws {
        guard isConnected else { return }
        
        try await performPause()
        isPlaying = false
    }
    
    func resume() async throws {
        if !isConnected {
            try await connect()
        }
        
        try await performResume()
        isPlaying = true
    }
    
    private func isSpotifyInstalled() -> Bool {
        guard let url = URL(string: "spotify:") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    private func isValidPlaylistURI(_ uri: String) -> Bool {
        let pattern = "^spotify:playlist:[a-zA-Z0-9]{22}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: uri.utf16.count)
        return regex?.firstMatch(in: uri, options: [], range: range) != nil
    }
    
    private func performConnection() async throws {
        guard let sessionManager = sessionManager else { return }
        
        let scope: SPTScope = [.appRemoteControl, .playlistReadPrivate, .userReadPlaybackState, .userModifyPlaybackState]
        
        if #available(iOS 11, *) {
            // This will trigger the OAuth flow
            sessionManager.initiateSession(with: scope, options: .clientOnly, campaign: nil)
        }
    }
    
    private func resumeCurrentPlayback() async throws {
        appRemote?.playerAPI?.resume { _, error in
            if let error = error {
                print("Failed to resume playback: \(error)")
            }
        }
    }
    
    private func playPlaylist(uri: String) async throws {
        appRemote?.playerAPI?.play(uri) { _, error in
            if let error = error {
                print("Failed to play playlist: \(error)")
            }
        }
    }
    
    private func performPause() async throws {
        appRemote?.playerAPI?.pause { _, error in
            if let error = error {
                print("Failed to pause: \(error)")
            }
        }
    }
    
    private func performResume() async throws {
        appRemote?.playerAPI?.resume { _, error in
            if let error = error {
                print("Failed to resume: \(error)")
            }
        }
    }
}

// MARK: - URL Handling
extension SpotifyControl {
    func handleOpenURL(_ url: URL) -> Bool {
        guard url.scheme == "grappletimer" else { return false }
        
        // Let the session manager handle the URL
        sessionManager?.application(UIApplication.shared, open: url, options: [:])
        
        return true
    }
}

// MARK: - SPTSessionManagerDelegate
extension SpotifyControl {
    nonisolated func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        Task { @MainActor in
            self.accessToken = session.accessToken
            self.appRemote?.connectionParameters.accessToken = session.accessToken
            self.appRemote?.connect()
        }
    }
    
    nonisolated func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        Task { @MainActor in
            print("Failed to initiate session: \(error)")
            self.currentError = .connectionFailed
        }
    }
    
    nonisolated func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        Task { @MainActor in
            self.accessToken = session.accessToken
        }
    }
}

// MARK: - SPTAppRemoteDelegate
extension SpotifyControl {
    nonisolated func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        Task { @MainActor in
            self.isConnected = true
            self.connectionAttempts = 0
            
            // Subscribe to player state
            appRemote.playerAPI?.delegate = self
            appRemote.playerAPI?.subscribe(toPlayerState: { (result, error) in
                if let error = error {
                    print("Failed to subscribe to player state: \(error)")
                }
            })
            
            // Don't auto-play or change playback state on connection
            // Music should only be controlled during timer sessions
            // If music is playing and we're in no music mode, pause it
            appRemote.playerAPI?.getPlayerState { playerState, error in
                Task { @MainActor in
                    if let state = playerState as? SPTAppRemotePlayerState, !state.isPaused {
                        // Music is playing, pause it since we just connected
                        appRemote.playerAPI?.pause(nil)
                    }
                }
            }
        }
    }
    
    nonisolated func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        Task { @MainActor in
            print("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
            self.isConnected = false
            
            if self.connectionAttempts >= self.maxConnectionAttempts {
                self.currentError = .connectionFailed
                self.connectionAttempts = 0
            }
        }
    }
    
    nonisolated func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        Task { @MainActor in
            print("Disconnected: \(error?.localizedDescription ?? "User disconnected")")
            self.isConnected = false
            self.isPlaying = false
            
            // If we have a token and weren't intentionally disconnected, try to reconnect
            if self.accessToken != nil && error != nil {
                print("Attempting automatic reconnection...")
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                    if let token = self.accessToken {
                        self.appRemote?.connectionParameters.accessToken = token
                        self.appRemote?.connect()
                    }
                }
            }
        }
    }
}

// MARK: - SPTAppRemotePlayerStateDelegate
extension SpotifyControl {
    nonisolated func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        Task { @MainActor in
            self.isPlaying = !playerState.isPaused
            
            // Check if premium based on restrictions
            let restrictions = playerState.playbackRestrictions
            self.isPremium = restrictions.canSkipNext && restrictions.canSkipPrevious
        }
    }
}

extension UIApplication {
    static var spotifyAvailable: Bool {
        guard let url = URL(string: "spotify:") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}