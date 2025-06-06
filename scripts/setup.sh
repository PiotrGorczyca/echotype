#!/bin/bash

# EchoType Setup Script
# This script helps set up the development environment and dependencies

set -e

echo "🎙️  EchoType Setup Script"
echo "========================="

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "❌ This application currently only supports Linux"
    exit 1
fi

# Check for required system dependencies
echo "📦 Checking system dependencies..."

MISSING_DEPS=()

# Check for development libraries
if ! pkg-config --exists x11; then
    MISSING_DEPS+=("libx11-dev")
fi

if ! pkg-config --exists xtst; then
    MISSING_DEPS+=("libxtst-dev")
fi

if ! pkg-config --exists xfixes; then
    MISSING_DEPS+=("libxfixes-dev")
fi

if ! pkg-config --exists portaudio-2.0; then
    MISSING_DEPS+=("libportaudio2 portaudio19-dev")
fi

# Check for xdotool (optional but recommended)
if ! command -v xdotool &> /dev/null; then
    MISSING_DEPS+=("xdotool")
fi

# Check for aplay (for testing audio files)
if ! command -v aplay &> /dev/null; then
    MISSING_DEPS+=("alsa-utils")
fi

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo "❌ Missing dependencies: ${MISSING_DEPS[*]}"
    echo ""
    echo "Please install them using your package manager:"
    echo ""
    
    # Detect package manager and provide appropriate command
    if command -v apt &> /dev/null; then
        echo "sudo apt update && sudo apt install ${MISSING_DEPS[*]}"
    elif command -v pacman &> /dev/null; then
        # Convert package names for Arch Linux
        ARCH_DEPS=()
        for dep in "${MISSING_DEPS[@]}"; do
            case $dep in
                "libx11-dev") ARCH_DEPS+=("libx11") ;;
                "libxtst-dev") ARCH_DEPS+=("libxtst") ;;
                "libxfixes-dev") ARCH_DEPS+=("libxfixes") ;;
                "libportaudio2") ARCH_DEPS+=("portaudio") ;;
                "portaudio19-dev") ;; # Already covered by portaudio
                *) ARCH_DEPS+=("$dep") ;;
            esac
        done
        echo "sudo pacman -S ${ARCH_DEPS[*]}"
    elif command -v dnf &> /dev/null; then
        echo "sudo dnf install ${MISSING_DEPS[*]}"
    else
        echo "Please install the equivalent packages for your distribution."
    fi
    echo ""
    echo "Then run this script again."
    exit 1
fi

echo "✅ All system dependencies are installed!"

# Check for Zig compiler
echo "🔧 Checking Zig compiler..."
if ! command -v zig &> /dev/null; then
    echo "❌ Zig compiler not found!"
    echo "Please install Zig from: https://ziglang.org/download/"
    echo "Or use your package manager:"
    echo "  - Ubuntu/Debian: sudo snap install zig --classic --beta"
    echo "  - Arch Linux: sudo pacman -S zig"
    echo "  - Fedora: sudo dnf install zig"
    exit 1
fi

ZIG_VERSION=$(zig version)
echo "✅ Zig compiler found: $ZIG_VERSION"

# Build the project
echo "🔨 Building EchoType..."
if zig build; then
    echo "✅ Build successful!"
else
    echo "❌ Build failed!"
    exit 1
fi

# Create config directory
echo "📁 Setting up configuration..."
CONFIG_DIR="$HOME/.config/echotype"
mkdir -p "$CONFIG_DIR"

# Copy example config if it doesn't exist
if [ ! -f "$CONFIG_DIR/config.json" ]; then
    cp config/example.json "$CONFIG_DIR/config.json"
    echo "📝 Created example config at: $CONFIG_DIR/config.json"
    echo ""
    echo "⚠️  IMPORTANT: You need to set your OpenAI API key!"
    echo "Edit $CONFIG_DIR/config.json and replace 'sk-your-openai-api-key-here' with your actual API key."
    echo ""
    echo "You can also set it as an environment variable:"
    echo "export OPENAI_API_KEY='your-api-key-here'"
else
    echo "✅ Configuration file already exists"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Set your OpenAI API key in $CONFIG_DIR/config.json"
echo "2. Run the application: ./zig-out/bin/echotype"
echo "3. Use Ctrl+Shift+S to start/stop recording"
echo ""
echo "For more information, see README.md" 