# Spotify SDK Integration TODO

## Current Status
The app has placeholder Spotify code but needs actual SDK implementation. The client ID is configured: `0450fcbf37fe4d698008fb0e650d2232`

## Required Steps

### 1. Add Spotify SDK to Project
- Download SpotifyiOS.xcframework from https://github.com/spotify/ios-sdk/releases
- Drag into Xcode project
- Set to "Embed & Sign" in Frameworks settings

### 2. Import and Configure SDK
Replace the placeholder code in SpotifyControl.swift with:

```swift
import SpotifyiOS

class SpotifyControl: NSObject, ObservableObject, SPTSessionManagerDelegate, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    
    private var sessionManager: SPTSessionManager?
    private var appRemote: SPTAppRemote?
    
    // Configure in init()
    private func setupSpotify() {
        let configuration = SPTConfiguration(clientID: Self.clientID, redirectURL: URL(string: Self.redirectURI)!)
        configuration.playURI = ""
        configuration.tokenSwapURL = nil // Add if using server-side auth
        configuration.tokenRefreshURL = nil // Add if using server-side auth
        
        sessionManager = SPTSessionManager(configuration: configuration, delegate: self)
        
        appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        appRemote?.delegate = self
    }
}
```

### 3. Implement Connection Methods

Replace placeholder methods with actual SDK calls:

```swift
private func performConnection() async throws {
    // Start auth flow
    guard let sessionManager = sessionManager else { return }
    
    let scope: SPTScope = [.appRemoteControl, .playlistReadPrivate, .userReadPlaybackState]
    
    if #available(iOS 11, *) {
        sessionManager.initiateSession(with: scope, options: .clientOnly)
    }
}

private func resumeCurrentPlayback() async throws {
    appRemote?.playerAPI?.resume(nil)
}

private func playPlaylist(uri: String) async throws {
    appRemote?.playerAPI?.play(uri, callback: nil)
}

private func performPause() async throws {
    appRemote?.playerAPI?.pause(nil)
}
```

### 4. Handle Authentication Callback

In AppCoordinator or SceneDelegate:

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    
    if SpotifyControl.shared.sessionManager?.application(UIApplication.shared, open: url, options: [:]) == true {
        // Handled by Spotify
    }
}
```

### 5. Implement Delegate Methods

```swift
// SPTSessionManagerDelegate
func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
    appRemote?.connectionParameters.accessToken = session.accessToken
    appRemote?.connect()
}

func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
    // Handle error
}

// SPTAppRemoteDelegate  
func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
    self.appRemote?.playerAPI?.delegate = self
    self.appRemote?.playerAPI?.subscribe(toPlayerState: { (result, error) in
        // Handle subscription
    })
}

func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
    // Handle error
}

// SPTAppRemotePlayerStateDelegate
func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
    // Update UI based on player state
}
```

## Testing Without Full Implementation

For now, if you want to test the timer without Spotify:
1. Use "No Music" mode in Settings
2. The timer will still work with audio cues (bell, horn, clapper)

## Alternative: Web API Approach

If SDK integration is too complex, consider using Spotify Web API instead:
- Simpler implementation
- Requires backend server for token management
- Less reliable for real-time playback control
- But easier to get started

## Resources
- SDK Docs: https://spotify.github.io/ios-sdk/
- Sample App: https://github.com/spotify/ios-sdk/tree/master/DemoProjects
- Web API: https://developer.spotify.com/documentation/web-api/