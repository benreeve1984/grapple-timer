import Foundation
import Combine
import UIKit

enum MusicMode: Codable, Equatable, Hashable {
    case useCurrentPlayback
    case usePlaylist(uri: String)
    
    var displayName: String {
        switch self {
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
final class SpotifyControl: ObservableObject, SpotifyControlProtocol {
    static let shared = SpotifyControl()
    
    static let clientID = "YOUR_SPOTIFY_CLIENT_ID"
    static let redirectURI = "grappletimer://spotify-callback"
    
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var currentError: SpotifyError?
    @Published private(set) var isPlaying: Bool = false
    
    private var connectionAttempts = 0
    private let maxConnectionAttempts = 3
    
    private var mockConnection: Bool = false
    
    private init() {
        #if DEBUG
        mockConnection = true
        #endif
    }
    
    func connect() async throws {
        currentError = nil
        
        if mockConnection {
            try await Task.sleep(nanoseconds: 500_000_000)
            isConnected = true
            isPremium = true
            return
        }
        
        guard isSpotifyInstalled() else {
            currentError = .notInstalled
            throw SpotifyError.notInstalled
        }
        
        connectionAttempts += 1
        
        do {
            try await performConnection()
            isConnected = true
            isPremium = await checkPremiumStatus()
            connectionAttempts = 0
        } catch {
            isConnected = false
            if connectionAttempts >= maxConnectionAttempts {
                currentError = .connectionFailed
                connectionAttempts = 0
                throw SpotifyError.connectionFailed
            }
            throw error
        }
    }
    
    func disconnect() {
        isConnected = false
        isPlaying = false
        currentError = nil
    }
    
    func play(mode: MusicMode) async throws {
        if !isConnected {
            try await connect()
        }
        
        currentError = nil
        
        if mockConnection {
            isPlaying = true
            return
        }
        
        switch mode {
        case .useCurrentPlayback:
            try await resumeCurrentPlayback()
            
        case .usePlaylist(let uri):
            guard isPremium else {
                currentError = .premiumRequired
                try await resumeCurrentPlayback()
                return
            }
            
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
        
        if mockConnection {
            isPlaying = false
            return
        }
        
        try await performPause()
        isPlaying = false
    }
    
    func resume() async throws {
        if !isConnected {
            try await connect()
        }
        
        if mockConnection {
            isPlaying = true
            return
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
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    private func checkPremiumStatus() async -> Bool {
        try? await Task.sleep(nanoseconds: 500_000_000)
        return true
    }
    
    private func resumeCurrentPlayback() async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
    }
    
    private func playPlaylist(uri: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }
    
    private func performPause() async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
    }
    
    private func performResume() async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
    }
}

extension SpotifyControl {
    func handleOpenURL(_ url: URL) -> Bool {
        guard url.scheme == "grappletimer" else { return false }
        
        return true
    }
}

extension UIApplication {
    static var spotifyAvailable: Bool {
        guard let url = URL(string: "spotify:") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}