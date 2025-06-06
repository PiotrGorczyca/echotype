#!/bin/bash

# Test OpenAI API configuration and connectivity
set -e

echo "🔍 Testing OpenAI API Configuration"
echo "==================================="

# Check API key from environment
if [ -n "$OPENAI_API_KEY" ]; then
    echo "✅ Found API key in environment variable"
    API_KEY="$OPENAI_API_KEY"
elif [ -f "$HOME/.config/echotype/config.json" ]; then
    echo "📁 Checking config file..."
    API_KEY=$(cat "$HOME/.config/echotype/config.json" | grep -o '"openai_api_key"[^,]*' | cut -d'"' -f4)
    if [ "$API_KEY" != "sk-your-openai-api-key-here" ] && [ -n "$API_KEY" ]; then
        echo "✅ Found API key in config file"
    else
        echo "❌ No valid API key found in config file"
        echo "Edit $HOME/.config/echotype/config.json and set your API key"
        exit 1
    fi
else
    echo "❌ No API key found"
    echo "Set OPENAI_API_KEY environment variable or create config file"
    exit 1
fi

# Test basic connectivity
echo "🌐 Testing internet connectivity..."
if curl -s --connect-timeout 5 https://api.openai.com > /dev/null; then
    echo "✅ Can reach OpenAI API"
else
    echo "❌ Cannot reach OpenAI API - check internet connection"
    exit 1
fi

# Test API key validity
echo "🔑 Testing API key validity..."
RESPONSE=$(curl -s -w "%{http_code}" -H "Authorization: Bearer $API_KEY" \
    https://api.openai.com/v1/models -o /tmp/openai_test.json)

HTTP_CODE="${RESPONSE: -3}"

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ API key is valid"
    MODEL_COUNT=$(cat /tmp/openai_test.json | grep -o '"id"' | wc -l)
    echo "📊 Available models: $MODEL_COUNT"
    
    # Check if whisper-1 is available
    if grep -q "whisper-1" /tmp/openai_test.json; then
        echo "✅ Whisper-1 model is available"
    else
        echo "⚠️  Whisper-1 model not found in available models"
    fi
    
elif [ "$HTTP_CODE" = "401" ]; then
    echo "❌ API key is invalid"
    echo "Response: $(cat /tmp/openai_test.json)"
    exit 1
elif [ "$HTTP_CODE" = "429" ]; then
    echo "⚠️  Rate limited - too many requests"
    echo "Your API key is valid but you're being rate limited"
else
    echo "❌ API request failed with HTTP $HTTP_CODE"
    echo "Response: $(cat /tmp/openai_test.json)"
    exit 1
fi

# Test transcription endpoint specifically
echo "🎙️  Testing transcription endpoint..."

# Create a tiny test audio file (just silence)
if command -v ffmpeg &> /dev/null; then
    echo "📁 Creating test audio file..."
    ffmpeg -f lavfi -i "anullsrc=channel_layout=mono:sample_rate=16000" \
           -t 1 -f wav /tmp/test_audio.wav -y 2>/dev/null
    
    echo "🧪 Testing transcription API..."
    TRANSCRIPTION_RESPONSE=$(curl -s -w "%{http_code}" \
        -H "Authorization: Bearer $API_KEY" \
        -F "file=@/tmp/test_audio.wav" \
        -F "model=whisper-1" \
        https://api.openai.com/v1/audio/transcriptions \
        -o /tmp/transcription_test.json)
    
    TRANSCRIPTION_CODE="${TRANSCRIPTION_RESPONSE: -3}"
    
    if [ "$TRANSCRIPTION_CODE" = "200" ]; then
        echo "✅ Transcription endpoint is working"
        TRANSCRIBED_TEXT=$(cat /tmp/transcription_test.json | grep -o '"text"[^,}]*' | cut -d'"' -f4)
        echo "📝 Transcribed: '$TRANSCRIBED_TEXT'"
    else
        echo "❌ Transcription endpoint failed with HTTP $TRANSCRIPTION_CODE"
        echo "Response: $(cat /tmp/transcription_test.json)"
    fi
    
    # Cleanup
    rm -f /tmp/test_audio.wav /tmp/transcription_test.json
else
    echo "⚠️  ffmpeg not found - skipping transcription endpoint test"
    echo "Install ffmpeg to test the transcription endpoint fully"
fi

# Cleanup
rm -f /tmp/openai_test.json

echo ""
echo "🎉 API configuration test complete!"
echo ""
echo "If all tests passed, your EchoType should work with transcription."
echo "If any tests failed, check the troubleshooting guide: TROUBLESHOOTING.md" 