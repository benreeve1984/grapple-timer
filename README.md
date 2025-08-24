# Grapple Timer

A minimalist iPhone BJJ (Brazilian Jiu-Jitsu) round timer with Siri integration and Spotify control. Features a huge, orientation-adaptive timer UI optimized for training sessions.

## Features

- **Big-Screen Timer**: Massive countdown display that scales to fill the screen, especially in landscape mode
- **Siri Integration**: Start timers hands-free with natural language commands
- **Spotify Control**: Automatically play music during rounds, pause during rest (defaults to curated BJJ playlist)
- **Smart Audio Cues**: Bell sound at round start, horn at round end, clapper warning before time
- **Background Notifications**: Get alerts even when the app is backgrounded
- **Training Presets**: Three optimized configurations for different training styles
- **Landscape Mode**: Near full-screen timer display with opaque control buttons
- **Orientation-Aware UI**: Presets hidden in landscape for maximum timer visibility

## Setup Instructions

### 1. Open the Project

1. Open `GrappleTimer.xcodeproj` in Xcode 15 or later
2. Select your development team in the project settings (Signing & Capabilities)
3. Update the bundle identifier if needed (default: `com.yourcompany.GrappleTimer`)
4. If project files are missing, run `xcodegen generate` to regenerate from `project.yml`

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
2. Choose from three presets:
   - **10×5:00/1:00**: 10 rounds, 5 min work, 1 min rest (default)
   - **15×3:00/1:00**: 15 rounds, 3 min work, 1 min rest
   - **5×10:00/2:00**: 5 rounds, 10 min work, 2 min rest
3. Or adjust custom round/rest times
4. Tap "START SESSION"
5. Bell rings at round start, horn at round end

### During Session
- **Portrait**: Large countdown with progress ring, phase indicator, round counter
- **Landscape**: Near full-screen timer (85-90% of screen), opaque control buttons
- **Audio Cues**: 
  - Bell sound at start of each round
  - Horn sound at end of each round (start of rest)
  - Clapper warning before round ends
- **Controls**: Pause/Resume and Stop buttons always accessible
- **Exit**: X button stops timer and returns to home
- **Background**: Local notifications fire at phase transitions

### Settings
- **Keep Screen Awake**: Prevents auto-lock during sessions
- **Show Tenths**: Display fractional seconds when under 1 minute
- **Start Delay**: Optional 3-second countdown before first round
- **Music Mode**: Defaults to "No Music", optional Spotify integration
  - Default playlist when enabled: https://open.spotify.com/playlist/4f9dMrkjEdxAWD4amTEVhm

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
   - Launch app → Shows 3 presets, default timer (10×5:00/1:00)
   - Start button enabled

2. **Presets**
   - Tap preset → Timer configuration updates
   - Three presets available:
     - 10×5:00/1:00 (default)
     - 15×3:00/1:00
     - 5×10:00/2:00

3. **Orientation**
   - Portrait → Shows presets + controls
   - Landscape → Hides presets, maximizes timer space
   - During session landscape → Opaque button backgrounds, no bleed-through

4. **Audio Cues**
   - Round start → Bell sound
   - Round end → Horn sound
   - Near round end → Clapper sound
   - All cues include haptic feedback

5. **Session Controls**
   - Pause/Resume → Works correctly
   - Stop → Ends session
   - X button → Stops timer and exits

6. **Spotify Integration**
   - Default playlist loads automatically
   - Music plays during WORK, pauses during REST
   - Premium: Uses BJJ playlist
   - Free: Falls back to current playback

7. **Background**
   - Lock during session → Notifications at phase changes
   - Unlock → Shows correct remaining time

8. **Siri Test**
   - Say "Start BJJ timer in Grapple Timer"
   - App launches and starts timer with current config

9. **Edge Cases**
   - Zero/negative time intervals → Handled gracefully
   - Rapid start/pause/resume → No crashes
   - Clapper > round duration → Shows error

## Support

For issues or feature requests, please contact the development team or check the app's support documentation.

## License

Proprietary - All rights reserved