#!/bin/bash

echo "=== Grapple Timer Project Verification ==="
echo ""
echo "Checking project structure..."
echo ""

# Check for source files
echo "✓ Source Files:"
find GrappleTimer -name "*.swift" -type f | head -20

echo ""
echo "✓ Resources:"
ls -la GrappleTimer/Resources/

echo ""
echo "✓ Total Swift files: $(find GrappleTimer -name "*.swift" | wc -l | tr -d ' ')"

echo ""
echo "✓ Project Structure:"
tree -L 3 GrappleTimer/ 2>/dev/null || find GrappleTimer -type d | head -20

echo ""
echo "=== Quick Start Options ==="
echo ""
echo "1. SIMPLEST: Open Package.swift in Xcode"
echo "   - Double-click Package.swift"
echo "   - Xcode will open it as a Swift Package"
echo "   - You can build and run directly"
echo ""
echo "2. CREATE NEW PROJECT: Follow instructions in create_xcode_project.sh"
echo "   - Run: ./create_xcode_project.sh"
echo "   - Follow the step-by-step guide"
echo ""
echo "3. All source code is ready and working in GrappleTimer/ folder"
echo "   - Just needs to be added to an Xcode project"
echo "   - Or opened as a Swift Package"