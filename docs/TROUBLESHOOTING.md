# 🔧 EchoType Troubleshooting Guide

## Common Issues and Solutions

### 🎤 Transcription Problems

#### Issue: `Error transcribing audio: error.NotWriteable`
**Cause**: HTTP client issue when sending request to OpenAI API

**Solution**:
1. Check if you have a valid OpenAI API key set:
   ```bash
   echo $OPENAI_API_KEY
   # OR check config file
   cat ~/.config/echotype/config.json
   ```

2. Verify your internet connection:
   ```bash
   curl -I https://api.openai.com/v1/audio/transcriptions
   ```

3. Check API key validity:
   ```bash
   curl -H "Authorization: Bearer $OPENAI_API_KEY" \
        https://api.openai.com/v1/models
   ```

#### Issue: `Error transcribing audio: error.ApiRequestFailed`
**Cause**: OpenAI API returned an error

**Solutions**:
- Check if you have sufficient API credits
- Verify the audio file format is supported (should be WAV)
- Ensure audio file is not empty or corrupted
- Check OpenAI API status: https://status.openai.com/

#### Issue: Empty or no transcription returned
**Cause**: Audio quality issues or API limitations

**Solutions**:
1. Test your audio file manually:
   ```bash
   aplay /tmp/echotype_recording_*.wav
   ```

2. Check audio file properties:
   ```bash
   file /tmp/echotype_recording_*.wav
   ffprobe /tmp/echotype_recording_*.wav
   ```

3. Ensure you're speaking clearly and the microphone is working
4. Try recording in a quieter environment

### 🎮 Hotkey Issues

#### Issue: Hotkey not working
**Solutions**:
1. Check if another application is using the same hotkey:
   ```bash
   # Try a different hotkey combination in config
   export ECHOTYPE_HOTKEY='Ctrl+Alt+S'
   ```

2. Verify X11 permissions:
   ```bash
   # Make sure you're running in X11, not Wayland
   echo $XDG_SESSION_TYPE
   ```

3. Check for X11 errors in logs:
   ```bash
   ./zig-out/bin/echotype 2>&1 | grep -i error
   ```

### 🔊 Audio Recording Issues

#### Issue: No audio captured or very quiet recording
**Solutions**:
1. Test microphone:
   ```bash
   arecord -d 3 test.wav && aplay test.wav
   ```

2. Check PulseAudio/ALSA settings:
   ```bash
   pavucontrol  # PulseAudio Volume Control
   alsamixer    # ALSA mixer
   ```

3. List available audio devices:
   ```bash
   arecord -l    # ALSA devices
   pactl list sources  # PulseAudio sources
   ```

4. Try different audio device in config:
   ```json
   {
     "audio_device": "pulse",
     // or try specific device number
     "audio_device": "hw:0,0"
   }
   ```

#### Issue: Audio recording fails to start
**Solutions**:
1. Check if another application is using the microphone
2. Verify PortAudio installation:
   ```bash
   pkg-config --modversion portaudio-2.0
   ```

3. Run with debug output:
   ```bash
   RUST_LOG=debug ./zig-out/bin/echotype
   ```

### 📋 Clipboard Issues

#### Issue: Text not copied to clipboard
**Solutions**:
1. Test clipboard manually:
   ```bash
   echo "test" | xclip -selection clipboard
   xclip -selection clipboard -o
   ```

2. Install required tools:
   ```bash
   sudo apt install xclip xdotool  # Ubuntu/Debian
   sudo pacman -S xclip xdotool    # Arch Linux
   ```

#### Issue: Auto-paste not working
**Solutions**:
1. Test xdotool:
   ```bash
   xdotool key ctrl+v
   ```

2. Check X11 Test extension:
   ```bash
   xdpyinfo | grep -i test
   ```

3. Disable auto-paste and use manual paste:
   ```json
   {
     "auto_paste_enabled": false
   }
   ```

### 🏗️ Build Issues

#### Issue: Build fails with missing dependencies
**Solution**: Run the setup script:
```bash
./scripts/setup.sh
```

#### Issue: Zig compilation errors
**Solutions**:
1. Check Zig version:
   ```bash
   zig version
   # Should be 0.11.0 or newer
   ```

2. Clean build cache:
   ```bash
   rm -rf zig-cache zig-out
   zig build
   ```

### 🌐 Network Issues

#### Issue: Cannot reach OpenAI API
**Solutions**:
1. Check firewall settings
2. Verify DNS resolution:
   ```bash
   nslookup api.openai.com
   ```

3. Test with curl:
   ```bash
   curl -v https://api.openai.com/v1/models
   ```

4. Check proxy settings if behind corporate firewall

## Debug Mode

To run with maximum debugging information:

```bash
# Set debug environment
export ECHOTYPE_DEBUG=1

# Run application
./zig-out/bin/echotype
```

This will show:
- Detailed HTTP request/response information
- Audio processing details
- X11 event debugging
- Memory allocation tracking

## Getting Help

If you're still experiencing issues:

1. **Collect debug information**:
   ```bash
   ./scripts/test.sh > debug.log 2>&1
   ./zig-out/bin/echotype > app.log 2>&1 &
   # Reproduce the issue
   pkill echotype
   ```

2. **Check system information**:
   ```bash
   uname -a
   zig version
   echo $XDG_SESSION_TYPE
   ldd ./zig-out/bin/echotype
   ```

3. **Create an issue** with:
   - Your system information
   - Debug logs
   - Steps to reproduce
   - Expected vs actual behavior

## Performance Optimization

### Reduce Memory Usage
```json
{
  "recording_duration_seconds": 10,
  "visualization_enabled": false
}
```

### Reduce Latency
```json
{
  "whisper_model": "whisper-1",
  "audio_device": "pulse"
}
```

### Improve Accuracy
```json
{
  "recording_duration_seconds": 30,
  "whisper_model": "whisper-1"
}
``` 