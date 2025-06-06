# Zig Voice Transcription Application - Development Plan

## Project Overview
A Linux/X11 application built in Zig that captures voice recordings via hotkey, provides real-time audio visualization, transcribes speech using OpenAI Whisper API, and automatically pastes results at cursor location.

## Development Phases

### Phase 1: Project Foundation & Environment Setup

#### 1.1 Project Structure Setup
- [x] Initialize Zig project structure
- [x] Create `build.zig` with proper dependencies
- [x] Set up source directory structure
- [x] Create development scripts and utilities

#### 1.2 Development Environment
- [x] Verify Zig compiler installation
- [x] Install system development libraries:
  - [x] `libX11-dev` (X11 window management)
  - [x] `libXtst-dev` (keyboard event simulation) 
  - [x] `libXfixes-dev` (clipboard handling)
  - [x] `libasound2-dev` or `libpulse-dev` (audio recording)
- [x] Set up OpenAI API key configuration
- [x] Create development configuration files

#### 1.3 Core Dependencies & FFI Setup
- [x] Create X11 FFI bindings for Zig
- [x] Create audio library FFI bindings
- [x] Set up HTTP client dependencies
- [x] Create JSON handling utilities

### Phase 2: Core Module Development

#### 2.1 Module 1: Global Hotkey System (Week 1)
**Files to create:**
- `src/hotkey.zig` - Main hotkey handling
- `src/x11_bindings.zig` - X11 FFI bindings

**Development Tasks:**
- [x] Create X11 connection management
- [x] Implement global hotkey registration (`XGrabKey`)
- [x] Create event loop for hotkey detection
- [x] Add hotkey configuration (default: Ctrl+Shift+S)
- [x] Handle multiple hotkey combinations
- [x] Add error handling for hotkey conflicts
- [x] Test hotkey detection across different window managers

**Acceptance Criteria:**
- Application can register and detect global hotkeys
- Hotkey works across all applications
- Graceful handling of hotkey conflicts

#### 2.2 Module 2: Audio Recording System (Week 2)
**Files to create:**
- `src/audio.zig` - Main audio interface
- `src/audio_backends/` - Platform-specific implementations
  - `alsa.zig` - ALSA backend
  - `pulse.zig` - PulseAudio backend

**Development Tasks:**
- [x] Create audio device enumeration
- [x] Implement audio recording interface
- [x] Add support for multiple audio backends (ALSA/PulseAudio)
- [x] Create audio buffer management
- [x] Implement WAV file export
- [x] Add recording start/stop controls
- [ ] Create audio format conversion utilities
- [ ] Add silence detection (optional auto-stop)
- [ ] Implement audio quality settings

**Acceptance Criteria:**
- Can record audio from default microphone
- Saves audio in Whisper-compatible format
- Proper resource cleanup
- Configurable audio quality

#### 2.3 Module 3: Real-time Visualization (Week 3)
**Files to create:**
- `src/visualizer.zig` - Main visualization logic
- `src/graphics.zig` - X11 drawing utilities
- `src/audio_analysis.zig` - Signal processing

**Development Tasks:**
- [ ] Get cursor position via `XQueryPointer`
- [ ] Create borderless overlay window
- [ ] Implement real-time audio signal analysis
- [ ] Create equalizer bar visualization
- [ ] Add smooth animation and transitions
- [ ] Implement window positioning logic
- [ ] Add visualization themes/styles
- [ ] Optimize rendering performance
- [ ] Handle multi-monitor setups

**Acceptance Criteria:**
- Visualization appears near cursor when recording
- Smooth real-time audio visualization
- Low CPU/GPU usage
- Works across multiple monitors

#### 2.4 Module 4: OpenAI Whisper Integration (Week 4)
**Files to create:**
- `src/whisper_client.zig` - API client
- `src/http_client.zig` - HTTP utilities
- `src/config.zig` - Configuration management

**Development Tasks:**
- [ ] Create HTTP client for API calls
- [ ] Implement OpenAI API authentication
- [ ] Create multipart/form-data file upload
- [ ] Add JSON response parsing
- [ ] Implement retry logic with exponential backoff
- [ ] Add comprehensive error handling
- [ ] Create API response caching (optional)
- [ ] Add support for different Whisper models
- [ ] Implement request timeout handling

**Acceptance Criteria:**
- Successfully sends audio files to Whisper API
- Handles various API error responses
- Robust network error handling
- Configurable API settings

#### 2.5 Module 5: Clipboard & Auto-Paste (Week 5)
**Files to create:**
- `src/clipboard.zig` - Clipboard management
- `src/paste.zig` - Auto-paste functionality

**Development Tasks:**
- [ ] Implement X11 clipboard operations
- [ ] Create text-to-clipboard functionality
- [ ] Add clipboard format handling (text/plain, UTF-8)
- [ ] Implement keyboard event simulation via XTest
- [ ] Create smart paste detection (cursor context)
- [ ] Add paste confirmation mechanism
- [ ] Handle special characters and formatting
- [ ] Test across different applications
- [ ] Add paste delay configuration

**Acceptance Criteria:**
- Transcription correctly copied to clipboard
- Auto-paste works in various applications
- Handles special characters properly
- User can disable auto-paste if needed

### Phase 3: Integration & Main Application (Week 6)

#### 3.1 Main Application Logic
**Files to create:**
- `src/main.zig` - Application entry point
- `src/app.zig` - Main application controller
- `src/state.zig` - Application state management

**Development Tasks:**
- [ ] Create main application event loop
- [ ] Integrate all modules into cohesive workflow
- [ ] Implement state machine for recording lifecycle
- [ ] Add application configuration system
- [ ] Create logging and debugging utilities
- [ ] Add graceful shutdown handling
- [ ] Implement error recovery mechanisms
- [ ] Add performance monitoring

#### 3.2 Configuration System
**Files to create:**
- `src/config.zig` - Configuration management
- `config/default.json` - Default configuration

**Development Tasks:**
- [ ] Create configuration file parsing
- [ ] Add environment variable support
- [ ] Implement configuration validation
- [ ] Add runtime configuration updates
- [ ] Create configuration documentation

### Phase 4: Build System & Packaging (Week 7)

#### 4.1 Build System Enhancement
**Files to create/modify:**
- `build.zig` - Enhanced build configuration
- `scripts/setup.sh` - Development setup script
- `scripts/install.sh` - Installation script

**Development Tasks:**
- [ ] Create comprehensive build.zig with all dependencies
- [ ] Add static linking options
- [ ] Create debug/release build configurations
- [ ] Add automated dependency checking
- [ ] Create cross-compilation support
- [ ] Add build optimization flags

#### 4.2 Packaging & Distribution
**Development Tasks:**
- [ ] Create installation scripts
- [ ] Generate desktop entry files
- [ ] Create systemd service files (optional)
- [ ] Add uninstall functionality
- [ ] Create basic package (tar.gz)
- [ ] Test installation on clean systems

### Phase 5: Testing & Quality Assurance (Week 8)

#### 5.1 Unit Testing
**Files to create:**
- `tests/` - Test directory structure
- Various `*_test.zig` files

**Development Tasks:**
- [ ] Create unit tests for each module
- [ ] Add integration tests for module interactions
- [ ] Create mock systems for external dependencies
- [ ] Add performance benchmarks
- [ ] Create test automation scripts

#### 5.2 System Testing
**Development Tasks:**
- [ ] Test across different Linux distributions
- [ ] Test with various window managers
- [ ] Test with different audio systems
- [ ] Test network failure scenarios
- [ ] Test with various text applications
- [ ] Create user acceptance tests

### Phase 6: Documentation & Polish (Week 9)

#### 6.1 Documentation
**Files to create:**
- `README.md` - User documentation
- `INSTALL.md` - Installation guide
- `TROUBLESHOOTING.md` - Common issues
- `API.md` - Internal API documentation

#### 6.2 User Experience Polish
**Development Tasks:**
- [ ] Add user feedback mechanisms (notifications)
- [ ] Create configuration GUI (optional)
- [ ] Add keyboard shortcuts customization
- [ ] Implement user preferences
- [ ] Add accessibility features

## Development Timeline

| Week | Phase | Focus Area | Key Deliverables |
|------|--------|------------|------------------|
| 1 | Phase 1-2.1 | Foundation + Hotkeys | Working hotkey detection |
| 2 | Phase 2.2 | Audio Recording | Audio capture functionality |
| 3 | Phase 2.3 | Visualization | Real-time audio visualization |
| 4 | Phase 2.4 | API Integration | Whisper API communication |
| 5 | Phase 2.5 | Clipboard/Paste | Auto-paste functionality |
| 6 | Phase 3 | Integration | Complete workflow |
| 7 | Phase 4 | Build/Package | Installable application |
| 8 | Phase 5 | Testing | Stable, tested application |
| 9 | Phase 6 | Documentation | Production-ready release |

## Risk Mitigation

### Technical Risks
- **X11 FFI Complexity**: Start with simple bindings, use existing C libraries
- **Audio Recording Issues**: Test on multiple systems early
- **API Rate Limits**: Implement proper rate limiting and retry logic
- **Cross-application Pasting**: Test extensively with different applications

### Development Risks
- **Zig Learning Curve**: Allocate extra time for Zig-specific challenges
- **Library Compatibility**: Have fallback options for audio/graphics libraries
- **Platform Dependencies**: Test on multiple Linux distributions early

## Success Metrics
- [ ] Hotkey response time < 100ms
- [ ] Audio recording latency < 200ms
- [ ] Transcription accuracy > 90% (depends on Whisper)
- [ ] Memory usage < 50MB during operation
- [ ] CPU usage < 5% when idle
- [ ] Works on Ubuntu, Fedora, Arch Linux
- [ ] Compatible with GNOME, KDE, i3 window managers

## Next Steps
1. Set up the initial project structure
2. Begin Phase 1 development
3. Create weekly development checkpoints
4. Set up continuous integration (optional)
5. Plan beta testing with target users 