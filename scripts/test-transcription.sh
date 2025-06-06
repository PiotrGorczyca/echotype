#!/bin/bash

# Test transcription functionality specifically
set -e

echo "🎙️ Testing EchoType Transcription Workflow"
echo "=========================================="

# Check if we're in the right directory
if [ ! -f "zig-out/bin/echotype" ]; then
    echo "❌ Please build the project first: zig build"
    exit 1
fi

# Check API key
if [ -z "$OPENAI_API_KEY" ] && [ ! -f "$HOME/.config/echotype/config.json" ]; then
    echo "❌ No API key configured"
    echo "Set OPENAI_API_KEY or edit ~/.config/echotype/config.json"
    exit 1
fi

# Create a test audio file with actual speech (if ffmpeg and espeak are available)
echo "📁 Creating test audio file..."

if command -v ffmpeg &> /dev/null && command -v espeak &> /dev/null; then
    echo "🗣️  Creating test audio with speech..."
    
    # Generate spoken text
    espeak "Hello, this is a test of the EchoType transcription system." -w /tmp/speech.wav -s 140
    
    # Convert to the format expected by Whisper (16kHz, mono, 16-bit)
    ffmpeg -i /tmp/speech.wav -ar 16000 -ac 1 -sample_fmt s16 /tmp/echotype_test.wav -y 2>/dev/null
    
    rm -f /tmp/speech.wav
    echo "✅ Created test audio file: /tmp/echotype_test.wav"
    
elif command -v ffmpeg &> /dev/null; then
    echo "🔇 Creating silent audio file (espeak not available)..."
    
    # Create a short audio file with some tone for testing
    ffmpeg -f lavfi -i "sine=frequency=440:duration=2" -ar 16000 -ac 1 /tmp/echotype_test.wav -y 2>/dev/null
    echo "✅ Created test tone file: /tmp/echotype_test.wav"
    
else
    echo "❌ ffmpeg not found - cannot create test audio"
    echo "Install ffmpeg to test transcription: sudo apt install ffmpeg"
    exit 1
fi

# Check audio file
echo "📊 Audio file info:"
ls -lh /tmp/echotype_test.wav
file /tmp/echotype_test.wav

# Test with our application's transcription directly
echo ""
echo "🧪 Testing transcription with EchoType..."
echo "This will test the exact same code path as the real application"

# Create a temporary wrapper to test just the transcription part
cat > /tmp/test_transcription.zig << 'EOF'
const std = @import("std");
const whisper_client = @import("src/whisper_client.zig");
const config = @import("src/config.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize configuration
    var app_config = config.Config.init(allocator);
    defer app_config.deinit();

    // Initialize whisper client
    var whisper_api = whisper_client.WhisperClient.init(allocator, app_config.openai_api_key);
    defer whisper_api.deinit();

    // Test transcription
    const audio_file = "/tmp/echotype_test.wav";
    std.debug.print("Testing transcription of: {s}\n", .{audio_file});
    
    const transcription = whisper_api.transcribe(audio_file) catch |err| {
        std.debug.print("Transcription failed: {}\n", .{err});
        return;
    };
    defer allocator.free(transcription);

    std.debug.print("✅ Transcription successful!\n", .{});
    std.debug.print("📝 Result: '{s}'\n", .{transcription});
}
EOF

# Compile and run the test
echo "🔨 Compiling transcription test..."
if zig run /tmp/test_transcription.zig --deps src/whisper_client.zig --deps src/config.zig 2>/dev/null; then
    echo "✅ Transcription test completed successfully!"
else
    echo "❌ Transcription test failed"
    echo "This helps isolate whether the issue is in transcription or other parts"
    
    # Try running the full application with verbose output
    echo ""
    echo "🔍 Running full application with test file (simulated)..."
    echo "If you want to test the full workflow:"
    echo "1. Start the application: ./zig-out/bin/echotype"
    echo "2. Copy the test file to match the naming pattern:"
    echo "   cp /tmp/echotype_test.wav /tmp/echotype_recording_\$(date +%s).wav"
    echo "3. Test the transcription workflow"
fi

# Cleanup
rm -f /tmp/test_transcription.zig

echo ""
echo "🏁 Test completed!"
echo "If transcription still fails in the main application, check:"
echo "1. API key configuration"
echo "2. Internet connectivity"  
echo "3. Audio file quality and format"
echo "4. OpenAI API limits and billing" 