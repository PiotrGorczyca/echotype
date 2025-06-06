#!/bin/bash

# Test hotkey flow and state management
echo "🎮 Testing EchoType Hotkey Flow"
echo "==============================="

echo "This test verifies that:"
echo "1. First hotkey press starts recording"
echo "2. Second hotkey press stops recording and starts transcription"
echo "3. Additional hotkey presses during transcription are ignored"
echo "4. System is ready for next recording after transcription completes"
echo ""

# Check if application is built
if [ ! -f "zig-out/bin/echotype" ]; then
    echo "❌ Please build the project first: zig build"
    exit 1
fi

echo "📝 Expected Flow:"
echo "1. Start application: ./zig-out/bin/echotype"
echo "2. Press Ctrl+Shift+S → Should see: '🔴 Recording started!'"
echo "3. Speak your message"
echo "4. Press Ctrl+Shift+S → Should see: 'Hotkey detected! Stopping recording...'"
echo "5. During transcription → Additional hotkey presses should show: 'DEBUG: Hotkey ignored (processing transcription)'"
echo "6. After transcription → Should see: 'Ready for next recording.'"
echo "7. Can start new recording cycle"
echo ""

echo "🔍 What to verify:"
echo "✅ NO duplicate 'Recording started!' messages after pressing hotkey to stop"
echo "✅ Clear state transitions and processing indicators"
echo "✅ Hotkey presses ignored during transcription"
echo "✅ Ready message when transcription completes"
echo ""

echo "🚨 Previous Problem (now fixed):"
echo "❌ Second hotkey press would start HTTP request AND start new recording"
echo "❌ No protection against hotkey spam during processing"
echo "❌ Race conditions in state management"
echo ""

echo "✅ Current Solution:"
echo "✅ Added is_processing flag to prevent new recordings during transcription"
echo "✅ Clear state management with debug messages"
echo "✅ Error handling that doesn't break the state machine"
echo "✅ 'Ready for next recording' indicator"
echo ""

echo "To test manually:"
echo "1. Run: ./zig-out/bin/echotype"
echo "2. Try rapid hotkey presses - should be properly debounced"
echo "3. Start recording → stop recording → try pressing hotkey during transcription"
echo "4. Verify only appropriate actions happen at each stage"

if [ "$1" = "--auto" ]; then
    echo ""
    echo "🤖 Running automatic basic test..."
    echo "Starting application for 5 seconds to test initialization..."
    
    timeout 5s ./zig-out/bin/echotype > /tmp/hotkey_flow_test.log 2>&1 || true
    
    if grep -q "Application initialized" /tmp/hotkey_flow_test.log; then
        echo "✅ Application starts correctly"
    else
        echo "❌ Application failed to start"
        cat /tmp/hotkey_flow_test.log
        exit 1
    fi
    
    if grep -q "Listening for hotkey" /tmp/hotkey_flow_test.log; then
        echo "✅ Hotkey system initialized"
    else
        echo "❌ Hotkey system not initialized"
        exit 1
    fi
    
    echo "✅ Basic initialization test passed"
    echo "For full flow testing, run manually with actual hotkey presses"
    
    rm -f /tmp/hotkey_flow_test.log
fi 