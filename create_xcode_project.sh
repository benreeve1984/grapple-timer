#!/bin/bash

# Create Xcode Project Script for Grapple Timer
# This script creates a new Xcode project and adds all the existing source files

echo "Creating Grapple Timer Xcode Project..."

# Create a new iOS app project using xcodegen or xcodeproj would be ideal,
# but we'll create the structure that can be easily imported

# Create Package.swift for SPM compatibility
cat > Package.swift << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GrappleTimer",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "GrappleTimer",
            targets: ["GrappleTimer"]),
    ],
    targets: [
        .target(
            name: "GrappleTimer",
            dependencies: [],
            path: "GrappleTimer",
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "GrappleTimerTests",
            dependencies: ["GrappleTimer"],
            path: "GrappleTimer/Tests"),
    ]
)
EOF

echo "Package.swift created."
echo ""
echo "=== INSTRUCTIONS TO CREATE XCODE PROJECT ==="
echo ""
echo "Option 1: Create from Xcode GUI (Recommended)"
echo "---------------------------------------------"
echo "1. Open Xcode"
echo "2. File → New → Project"
echo "3. Choose 'iOS' → 'App'"
echo "4. Configure:"
echo "   - Product Name: GrappleTimer"
echo "   - Team: Your Team"
echo "   - Organization Identifier: com.yourcompany"
echo "   - Interface: SwiftUI"
echo "   - Language: Swift"
echo "   - Use Core Data: NO"
echo "   - Include Tests: YES"
echo "5. Save in the grapple-timer directory"
echo "6. Delete the default ContentView.swift and GrappleTimerApp.swift"
echo "7. Drag all files from GrappleTimer/ folder into Xcode project navigator"
echo "8. Make sure to:"
echo "   - Add files to target 'GrappleTimer'"
echo "   - Create folder references for Resources"
echo ""
echo "Option 2: Open as Swift Package"
echo "--------------------------------"
echo "1. Open Xcode"
echo "2. File → Open"
echo "3. Select Package.swift"
echo "4. Xcode will open it as a Swift Package"
echo "5. You can run on device/simulator from there"
echo ""
echo "Required Info.plist entries (add after creating project):"
echo "----------------------------------------------------------"
cat GrappleTimer/Info.plist
echo ""
echo "Spotify Setup:"
echo "--------------"
echo "1. Replace YOUR_SPOTIFY_CLIENT_ID in SpotifyControl.swift"
echo "2. Download Spotify iOS SDK"
echo "3. Add SpotifyiOS.xcframework to project"
echo ""
echo "All source files are ready in the GrappleTimer/ directory!"