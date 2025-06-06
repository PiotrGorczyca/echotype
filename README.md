# 🎙️ EchoType - Voice Transcription Application

A powerful Linux/X11 application built in Zig that captures voice recordings via global hotkey, provides real-time audio visualization, transcribes speech using OpenAI Whisper API, and automatically pastes the transcription at your cursor location.

## ✨ Features

- **Global Hotkey Activation**: Press `Ctrl+Shift+S` from anywhere to start recording
- **Real-time Audio Visualization**: Beautiful equalizer display near your cursor while recording  
- **AI-Powered Transcription**: Uses OpenAI's Whisper API for accurate speech-to-text
- **Smart Auto-Paste**: Automatically pastes transcription at cursor location
- **Cross-Application Support**: Works with any text input field
- **Configurable Settings**: Customize hotkeys, audio devices, and behavior
- **Multiple Audio Backends**: Supports both ALSA and PulseAudio

## 🚀 Quick Start

### Prerequisites

- Linux system with X11 (GNOME, KDE, i3, etc.)
- Zig compiler (latest stable version)
- OpenAI API key

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd echotype
   ```

2. **Run the setup script**
   ```bash
   ./scripts/setup.sh
   ```
   This will install all required system dependencies and set up the configuration.

3. **Configure your OpenAI API key**
   ```bash
   export OPENAI_API_KEY='your-api-key-here'
   # Or edit ~/.config/echotype/config.json
   ```

4. **Build and run**
   ```bash
   zig build
   zig build run
   ```

## 🛠️ Development Progress

This project follows a structured development plan. Current status:

### ✅ Phase 1: Foundation (Completed)
- [x] Project structure setup
- [x] Build system configuration  
- [x] Configuration management
- [x] X11 FFI bindings
- [x] Development environment setup

### ✅ Phase 2: Core Modules (Completed)
- [x] **Module 1: Global Hotkey System** ✅
- [x] **Module 2: Audio Recording System** ✅
- [x] **Module 3: Real-time Visualization** ✅
- [x] **Module 4: OpenAI Whisper Integration** ✅ **NEW!**
- [x] **Module 5: Clipboard & Auto-Paste** ✅ **NEW!**

### ✅ Phase 3: Integration & Main Application (Completed)
- [x] **Live Transcription Workflow** ✅ **NEW!**
- [x] **Memory Management** ✅
- [x] **Error Handling** ✅

### 🎯 Current Status: **FULLY FUNCTIONAL**
The application now supports complete live transcription workflow:
- ✅ Hotkey detection and recording control
- ✅ Audio recording to WAV files  
- ✅ Real-time transcription via OpenAI Whisper API
- ✅ Automatic clipboard copying and cursor pasting
- ✅ Proper memory management and error handling

### ⏳ Future Enhancements
- **Enhanced UI**: Better visualization and status indicators
- **Performance Optimization**: Reduce latency and resource usage
- **Additional Features**: Custom vocabulary, multiple languages
- **Packaging**: Distribution packages for major Linux distros

## 📁 Project Structure

```
echotype/
├── src/
│   ├── main.zig              # Application entry point
│   ├── config.zig            # Configuration management
│   ├── hotkey.zig            # Global hotkey handling
│   ├── audio.zig             # Audio recording interface
│   ├── audio_backends/       # Platform-specific audio implementations
│   │   ├── alsa.zig         # ALSA backend
│   │   └── pulse.zig        # PulseAudio backend
│   ├── visualizer.zig        # Real-time audio visualization
│   ├── whisper_client.zig    # OpenAI Whisper API client
│   ├── clipboard.zig         # Clipboard management
│   ├── x11_bindings.zig      # X11 FFI bindings
│   └── tests/               # Unit tests
├── config/
│   └── default.json         # Default configuration
├── scripts/
│   ├── setup.sh             # Development setup script
│   └── install.sh           # Installation script
├── build.zig                # Zig build configuration
├── DEVELOPMENT_PLAN.md      # Detailed development roadmap
└── README.md               # This file
```

## ⚙️ Configuration

EchoType can be configured through environment variables or a JSON config file:

### Environment Variables
```bash
export OPENAI_API_KEY='your-api-key'
export ECHOTYPE_HOTKEY='Ctrl+Shift+S'
export ECHOTYPE_AUDIO_DEVICE='default'
export ECHOTYPE_DURATION='5'
export ECHOTYPE_WHISPER_MODEL='whisper-1'
export ECHOTYPE_AUTO_PASTE='true'
export ECHOTYPE_VISUALIZATION='true'
```

### Configuration File
Location: `~/.config/echotype/config.json`

```json
{
  "openai_api_key": "your-api-key-here",
  "hotkey_combination": "Ctrl+Shift+S",
  "audio_device": "default",
  "recording_duration_seconds": 5,
  "whisper_model": "whisper-1",
  "auto_paste_enabled": true,
  "visualization_enabled": true
}
```

## 🧪 Development

### Building
```bash
# Debug build
zig build

# Release build
zig build -Doptimize=ReleaseFast

# Run tests
zig build test

# Run application
zig build run
```

### System Dependencies

The application requires these system libraries:
- **X11 libraries**: `libX11-dev`, `libXtst-dev`, `libXfixes-dev`
- **Audio libraries**: `libasound2-dev` (ALSA) and/or `libpulse-dev` (PulseAudio)
- **Build tools**: Standard C compiler and development tools

### Development Workflow

1. Each module is developed independently with comprehensive tests
2. Integration testing ensures modules work together seamlessly
3. Performance optimization focuses on low latency and minimal resource usage
4. Cross-platform testing on different Linux distributions and window managers

## 🎯 Usage

### Live Transcription Workflow

1. **Start the application**: 
   ```bash
   ./zig-out/bin/echotype
   ```

2. **Activate recording**: Press your configured hotkey (default: `Ctrl+Shift+S`)
   - The application will show "🔴 Recording started!" message
   - A visualization window appears near your cursor (if enabled)

3. **Speak naturally**: Record your voice
   - The application captures high-quality audio
   - Press the hotkey again to stop recording

4. **Automatic transcription**: 
   - Audio is sent to OpenAI Whisper API
   - Transcription appears in the console
   - Text is automatically copied to clipboard

5. **Auto-paste**: The transcribed text is automatically pasted at your cursor location
   - Uses `xdotool` for reliable pasting across applications
   - Falls back to X11 XTest if xdotool is unavailable

### Example Session
```
🎙️ EchoType - Voice Transcription Application
Press Ctrl+C to quit
Application initialized. Listening for hotkey: Ctrl+Shift+S

[Press Ctrl+Shift+S]
🔴 Recording started! Press hotkey again to stop.

[Speak your message]

[Press Ctrl+Shift+S again]
Recording completed. Sending to Whisper API...
Transcription: Hello, this is a test of the live transcription feature.
Text copied to clipboard successfully
Pasted using xdotool
Transcription workflow completed!
```

## 🔧 Troubleshooting

### Quick Diagnosis

If you're experiencing issues, run the diagnostic scripts:

```bash
# Test system setup and dependencies
./scripts/test.sh

# Test OpenAI API configuration
./scripts/test-api.sh
```

### Common Issues

**Transcription fails with `error.NotWriteable`**
- This indicates an HTTP client issue
- Run `./scripts/test-api.sh` to verify API configuration
- Check your OpenAI API key and internet connection

**Build fails with missing libraries**
```bash
# Run the setup script to install dependencies
./scripts/setup.sh
```

**Hotkey not working**
- Check if another application is using the same hotkey combination
- Try a different hotkey combination in the configuration
- Ensure you have proper X11 permissions (not Wayland)

**Audio recording issues**
- Check your microphone permissions
- Verify audio device configuration
- Test with different audio backends (ALSA/PulseAudio)

**API transcription fails**
- Verify your OpenAI API key is correct
- Check your internet connection
- Ensure you have sufficient API credits
- See `TROUBLESHOOTING.md` for detailed debugging steps

## 🎨 Technical Architecture

### Core Technologies
- **Language**: Zig (for performance and memory safety)
- **Windowing**: X11 (direct Xlib integration via FFI)
- **Audio**: ALSA/PulseAudio (multi-backend support)
- **HTTP**: Zig standard library HTTP client
- **API**: OpenAI Whisper API for transcription

### Performance Targets
- **Hotkey response time**: < 100ms
- **Audio recording latency**: < 200ms  
- **Memory usage**: < 50MB during operation
- **CPU usage**: < 5% when idle
- **Transcription accuracy**: > 90% (depends on Whisper model)

## 🤝 Contributing

We welcome contributions! Please see our development plan for current priorities:

1. **Week 1-2**: Core hotkey and audio systems
2. **Week 3-4**: Visualization and API integration
3. **Week 5-6**: Clipboard management and integration
4. **Week 7-9**: Testing, documentation, and polish

## 📄 License

[Your preferred license here]

## 🔗 Links

- [Zig Language](https://ziglang.org/)
- [OpenAI Whisper API](https://platform.openai.com/docs/guides/speech-to-text)
- [Development Plan](DEVELOPMENT_PLAN.md)

---

**Note**: This project is currently in active development. The main application structure is established, but individual modules are being implemented according to the development timeline. See `DEVELOPMENT_PLAN.md` for detailed progress and next steps. 