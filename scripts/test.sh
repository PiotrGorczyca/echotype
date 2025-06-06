#!/bin/bash

# EchoType Test Script
# This script runs basic tests to verify the application is working

set -e

echo "🧪 EchoType Test Suite"
echo "====================="

# Check if we're in the right directory
if [ ! -f "build.zig" ]; then
    echo "❌ Please run this script from the project root directory"
    exit 1
fi

# Test 1: Build test
echo "🔨 Test 1: Building application..."
if zig build; then
    echo "✅ Build successful"
else
    echo "❌ Build failed"
    exit 1
fi

# Test 2: Check if executable exists
echo "📁 Test 2: Checking executable..."
if [ -f "zig-out/bin/echotype" ]; then
    echo "✅ Executable found at zig-out/bin/echotype"
else
    echo "❌ Executable not found"
    exit 1
fi

# Test 3: Check dependencies
echo "📦 Test 3: Checking system dependencies..."
MISSING_DEPS=()

if ! pkg-config --exists x11; then
    MISSING_DEPS+=("libx11-dev")
fi

if ! pkg-config --exists xtst; then
    MISSING_DEPS+=("libxtst-dev")
fi

if ! pkg-config --exists portaudio-2.0; then
    MISSING_DEPS+=("portaudio19-dev")
fi

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo "❌ Missing dependencies: ${MISSING_DEPS[*]}"
    echo "Run ./scripts/setup.sh to install them"
    exit 1
else
    echo "✅ All dependencies are available"
fi

# Test 4: Configuration test
echo "⚙️  Test 4: Testing configuration..."
CONFIG_DIR="$HOME/.config/echotype"
if [ ! -d "$CONFIG_DIR" ]; then
    echo "📁 Creating config directory..."
    mkdir -p "$CONFIG_DIR"
fi

if [ ! -f "$CONFIG_DIR/config.json" ]; then
    echo "📝 Creating test config..."
    cp config/example.json "$CONFIG_DIR/config.json"
    echo "✅ Test configuration created"
else
    echo "✅ Configuration file exists"
fi

# Test 5: Quick functionality test (without API key)
echo "🎯 Test 5: Quick functionality test..."
echo "Note: This test runs the app for 2 seconds to check basic initialization"

# Run the app in background for a short time
timeout 2s ./zig-out/bin/echotype > /tmp/echotype_test.log 2>&1 || true

if grep -q "EchoType - Voice Transcription Application" /tmp/echotype_test.log; then
    echo "✅ Application starts correctly"
else
    echo "❌ Application failed to start properly"
    echo "Log output:"
    cat /tmp/echotype_test.log
    exit 1
fi

# Clean up test log
rm -f /tmp/echotype_test.log

echo ""
echo "🎉 All tests passed!"
echo ""
echo "Next steps:"
echo "1. Set your OpenAI API key in $CONFIG_DIR/config.json"
echo "2. Run the application: ./zig-out/bin/echotype"
echo "3. Test with Ctrl+Shift+S hotkey"
echo ""
echo "For full functionality, make sure you have:"
echo "- A valid OpenAI API key"
echo "- A working microphone"
echo "- X11 environment (not Wayland)" 