# Grapple Timer

A minimalist iPhone BJJ (Brazilian Jiu-Jitsu) round timer with Siri integration and Spotify control. Features a huge, orientation-adaptive timer UI optimized for training sessions.

## Features

- **Big-Screen Timer**: Massive countdown display that scales to fill the screen, especially in landscape mode
- **Siri Integration**: Start timers hands-free with natural language commands
- **Spotify Control**: Automatically play music during rounds, pause during rest
- **Smart Clapper**: Audio and haptic alerts before round ends
- **Background Notifications**: Get alerts even when the app is backgrounded
- **Presets**: Quick access to common training configurations
- **Landscape Mode**: Near full-screen timer display with minimal controls

## Setup Instructions

### 1. Open the Project

1. Open `GrappleTimer.xcodeproj` in Xcode 15 or later
2. Select your development team in the project settings
3. Update the bundle identifier if needed (default: `com.yourcompany.GrappleTimer`)

### 2. Configure Spotify Integration

#### Create a Spotify App
1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Create a new app with these settings:
   - App name: Grapple Timer
   - App description: BJJ Training Timer
   - Redirect URI: `grappletimer://spotify-callback`
3. Note your Client ID

#### Update the App
1. Open `GrappleTimer/Features/Playback/SpotifyControl.swift`
2. Replace `YOUR_SPOTIFY_CLIENT_ID` with your actual Client ID:
   ```swift
   static let clientID = "your-actual-client-id-here"
   ```

3. The Info.plist is already configured with:
   - URL scheme: `grappletimer`
   - LSApplicationQueriesSchemes: `spotify`

#### Install Spotify iOS SDK (Manual)
Since Spotify SDK isn't available via SPM:
1. Download the [Spotify iOS SDK](https://github.com/spotify/ios-sdk)
2. Drag `SpotifyiOS.xcframework` into your project
3. In project settings, under "Frameworks, Libraries, and Embedded Content", set it to "Embed & Sign"

### 3. Build and Run

1. Connect your iPhone (iOS 17+ required)
2. Select your device as the build target
3. Press Cmd+R to build and run
4. Grant notification permissions when prompted

## Siri Usage

After installation, you can immediately use these phrases without any setup:

- "Start BJJ timer in Grapple Timer"
- "Start grappling timer in Grapple Timer with 5-minute rounds, 1-minute rest, 6 rounds"
- "Start Brazilian Jiu-Jitsu timer in Grapple Timer"
- "Begin BJJ session in Grapple Timer with 3-minute rounds"
- "Start rolling timer in Grapple Timer"

### Siri Parameters
- Round duration (seconds)
- Rest duration (seconds) 
- Number of rounds
- Clapper time (seconds before round end)

Example: "Start BJJ timer in Grapple Timer — 5-minute rounds, 1-minute rest, 6 rounds, clapper at 10 seconds"

## Testing Premium vs Free Spotify

### Premium Account
- Can start specific playlists at beginning of session
- Full control over playback
- Paste any Spotify playlist URI in settings

### Free Account  
- Falls back to resuming current playback
- Cannot start specific playlists
- Music control limited to play/pause of current track

To test both behaviors:
1. Log out of Spotify app
2. Log in with test account (Premium or Free)
3. Try selecting "Custom Playlist" in app settings

## Usage Guide

### Quick Start
1. Launch the app
2. Select a preset or adjust round/rest times
3. Tap "START SESSION"
4. Music plays during rounds, pauses during rest

### During Session
- **Portrait**: Large countdown with progress ring, phase indicator, round counter
- **Landscape**: Near full-screen timer (85-90% of screen), minimal controls
- **Clapper**: Haptic + sound alert X seconds before round ends
- **Background**: Local notifications fire at phase transitions

### Settings
- **Keep Screen Awake**: Prevents auto-lock during sessions
- **Show Tenths**: Display fractional seconds when under 1 minute
- **Start Delay**: Optional 3-second countdown before first round
- **Music Mode**: Choose current playback or specific playlist

## Architecture

### Timing Engine
- Deterministic state machine using absolute timestamps
- Recovers correct time after backgrounding
- Accuracy within 50ms over 10 minutes
- Phases: idle → starting → work → rest → done

### Spotify Integration
- Foreground-first reliability
- Connects when app becomes active
- Disconnects when resigning active
- Graceful degradation for Free accounts

### Background Behavior
- Local notifications scheduled at phase boundaries
- Audio session interruption handling
- Time reconciliation on foreground return

## Known Limitations

1. **Background Music Control**: Spotify control requires foreground. Use notifications for background cues.
2. **Spotify SDK**: Must be manually integrated (not available via SPM)
3. **Free Spotify**: Cannot start specific playlists, only resume current playback
4. **Audio Interruptions**: Phone calls/alarms will pause the session

## Troubleshooting

### Spotify Not Connecting
- Ensure Spotify app is installed
- Check you're logged into Spotify
- Verify internet connection
- Try force-quitting both apps and retrying

### Siri Not Working
- Ensure Siri is enabled in Settings
- Speak clearly including "in Grapple Timer"
- Check app is installed and has been opened at least once
- Try shorter commands first

### Timer Inaccuracy
- Keep app in foreground for best accuracy
- Disable Low Power Mode
- Close other intensive apps

### No Sound/Haptics
- Check phone isn't in Silent Mode
- Ensure volume is up
- Check notification permissions
- Verify haptics enabled in Settings

## Manual Test Script

1. **Fresh Install**
   - Launch app → Defaults shown (5:00/1:00, 5 rounds, 10s clapper)
   - Start button enabled

2. **Orientation**
   - Rotate to landscape before starting → Timer scales to ~90% of screen
   - Rotate back to portrait → Clean layout maintained

3. **Spotify Integration**
   - With Spotify installed/logged in → Music plays during WORK, pauses during REST

4. **Playlist Selection**
   - Premium: Paste playlist URI → Starts playlist on WORK
   - Free: Shows friendly message, resumes current playback

5. **Clapper Test**
   - Set 30s round, 10s clapper → Clapper at T=20s, transition at T=30s

6. **Background**
   - Lock during session → Unlock shows correct remaining time
   - Notifications fire at phase boundaries while locked

7. **Siri Test**
   - Say "Start BJJ timer in Grapple Timer — 5-minute rounds, 1-minute rest, 6 rounds, clapper at 10 seconds"
   - App launches into active session with those parameters

8. **Edge Cases**
   - Clapper > round duration → Rejected with guidance
   - Rapid start/pause/resume → No crashes

9. **Accessibility**
   - Dynamic Type → Labels scale appropriately
   - VoiceOver → Reads phase and time
   - Contrast → Passes WCAG AA

## Support

For issues or feature requests, please contact the development team or check the app's support documentation.

## License

Proprietary - All rights reserved