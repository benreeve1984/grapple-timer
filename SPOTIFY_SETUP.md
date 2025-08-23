# Spotify Setup Guide for Grapple Timer

## Prerequisites
- Spotify account (Free or Premium)
- Spotify iOS app installed on your device
- Spotify Developer account (free)

## Step 1: Create a Spotify App

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Log in with your Spotify account
3. Click "Create app"
4. Fill in the details:
   - **App name**: Grapple Timer
   - **App description**: BJJ Training Timer with music control
   - **Website**: (optional)
   - **Redirect URI**: `grappletimer://spotify-callback`
   - **Which API/SDKs are you planning to use?**: Select "iOS SDK"
5. Check "I understand and agree" and click "Save"

## Step 2: Get Your Client ID

1. In your app dashboard, you'll see your **Client ID** (looks like: `a1b2c3d4e5f6g7h8i9j0`)
2. Copy this Client ID

## Step 3: Configure the App

1. Open the Xcode project
2. Navigate to `GrappleTimer/Features/Playback/SpotifyControl.swift`
3. Find this line (around line 32):
   ```swift
   static let clientID = "YOUR_SPOTIFY_CLIENT_ID"
   ```
4. Replace `YOUR_SPOTIFY_CLIENT_ID` with your actual Client ID:
   ```swift
   static let clientID = "a1b2c3d4e5f6g7h8i9j0"  // Your actual ID
   ```

## Step 4: Install Spotify iOS SDK

### Option A: Manual Installation (Recommended)
1. Download the [Spotify iOS SDK](https://github.com/spotify/ios-sdk/releases)
2. Download the latest `SpotifyiOS.xcframework.zip`
3. Unzip the file
4. In Xcode, drag `SpotifyiOS.xcframework` into your project navigator
5. When prompted:
   - Check "Copy items if needed"
   - Select your app target
6. Go to your target's settings → General → Frameworks, Libraries, and Embedded Content
7. Make sure `SpotifyiOS.xcframework` is set to "Embed & Sign"

### Option B: Swift Package Manager (if available)
1. In Xcode: File → Add Package Dependencies
2. Enter: `https://github.com/spotify/ios-sdk`
3. Select the latest version
4. Add to your app target

## Step 5: Verify Info.plist Configuration

The following should already be configured in Info.plist:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>spotify</string>
</array>
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>grappletimer</string>
        </array>
    </dict>
</array>
```

## Step 6: Test on Device

1. Connect your iPhone to Xcode
2. Select your device as the build target (not simulator - Spotify SDK doesn't work in simulator)
3. Build and run (Cmd+R)

## Usage Notes

### Music Modes
The app offers three music modes:
1. **No Music** - No Spotify control, just timer sounds
2. **Current Playback** - Resumes whatever you're currently playing
3. **Custom Playlist** - Starts a specific playlist (Premium only)

### Default Playlist
The app comes with a curated BJJ training playlist:
- URI: `spotify:playlist:2P2oppRNcZgcyyhW2dhS9k`
- You can change this in Settings

### Premium vs Free Accounts

**Premium Features:**
- Can start specific playlists
- Full playback control
- Can skip tracks

**Free Account Limitations:**
- Cannot start specific playlists (falls back to current playback)
- Limited control (play/pause only)
- May have ads between songs

### Troubleshooting

**Spotify not connecting:**
- Ensure Spotify app is installed and you're logged in
- Check internet connection
- Try force-quitting both apps and retrying
- Verify Client ID is correct

**Music not playing during rounds:**
- Check Music Mode isn't set to "No Music"
- Ensure Spotify app is open in background
- Verify you have something in your play queue

**"Spotify not installed" error:**
- Install Spotify from the App Store
- The app must be installed even if you use Spotify Web

**Authentication issues:**
- Log out and back into Spotify app
- Revoke access in Spotify account settings and re-authenticate
- Check your Spotify Developer app settings

### Testing Without Premium

To test free account behavior:
1. Create a free Spotify account
2. Log out of your premium account in Spotify app
3. Log in with free account
4. Try using "Custom Playlist" mode - it should fall back to current playback

## Security Notes

- Never commit your Client ID to public repositories
- Consider using environment variables or a config file for the Client ID
- The Client ID alone cannot access user data without authentication

## App Store Submission

Before submitting to App Store:
1. Ensure Client ID is properly configured
2. Test on multiple devices
3. Include Spotify attribution in app description
4. Note that Spotify SDK adds ~15MB to app size

## Support

For Spotify SDK issues: https://github.com/spotify/ios-sdk/issues
For API questions: https://developer.spotify.com/community