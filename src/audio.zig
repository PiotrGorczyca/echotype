const std = @import("std");
const pa = @import("portaudio_bindings.zig");
const wav = @import("wav_writer.zig");
const print = std.debug.print;

// Audio recording configuration
pub const AudioConfig = struct {
    sample_rate: u32 = 16000, // 16kHz for Whisper (saves bandwidth)
    channels: u16 = 1, // Mono recording
    bits_per_sample: u16 = 16, // 16-bit samples
    buffer_frames: u32 = 2048, // Larger buffer size to ensure proper chunking
    max_duration_seconds: u32 = 30, // Maximum recording duration (safety limit)
};

// Recording state and data
const RecordingData = struct {
    samples: std.ArrayList(f32),
    is_recording: bool,
    samples_recorded: u32,
    max_samples: u32,
    start_time_ns: i128,
    last_callback_time_ns: i128,
    end_time_ns: i128,

    fn init(allocator: std.mem.Allocator, max_samples: u32) RecordingData {
        return RecordingData{
            .samples = std.ArrayList(f32).init(allocator),
            .is_recording = false,
            .samples_recorded = 0,
            .max_samples = max_samples,
            .start_time_ns = 0,
            .last_callback_time_ns = 0,
            .end_time_ns = 0,
        };
    }

    fn deinit(self: *RecordingData) void {
        self.samples.deinit();
    }
};

pub const AudioRecorder = struct {
    allocator: std.mem.Allocator,
    config: AudioConfig,
    pa_initialized: bool,
    stream: ?*pa.PaStream,
    recording_data: RecordingData,
    temp_file_path: []u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        const config = AudioConfig{};
        const max_samples = config.sample_rate * config.channels * config.max_duration_seconds;

        print("DEBUG: AudioRecorder init:\n", .{});
        print("  Sample rate: {} Hz\n", .{config.sample_rate});
        print("  Channels: {}\n", .{config.channels});
        print("  Buffer frames: {}\n", .{config.buffer_frames});
        print("  Max duration: {} seconds\n", .{config.max_duration_seconds});
        print("  Max samples: {} ({d:.2} seconds max)\n", .{ max_samples, @as(f64, @floatFromInt(max_samples)) / @as(f64, @floatFromInt(config.sample_rate)) });

        return Self{
            .allocator = allocator,
            .config = config,
            .pa_initialized = false,
            .stream = null,
            .recording_data = RecordingData.init(allocator, max_samples),
            .temp_file_path = undefined,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.recording_data.is_recording) {
            _ = self.stopRecording() catch {};
        }

        if (self.stream) |stream| {
            _ = pa.closeStream(stream);
        }

        if (self.pa_initialized) {
            _ = pa.terminate();
        }

        self.recording_data.deinit();

        if (self.temp_file_path.len > 0) {
            self.allocator.free(self.temp_file_path);
        }
    }

    pub fn initializePortAudio(self: *Self) !void {
        if (self.pa_initialized) return;

        const err = pa.initialize();
        if (err != pa.paNoError) {
            print("PortAudio initialization failed: {s}\n", .{pa.getErrorText(err)});
            return error.PortAudioInitFailed;
        }

        self.pa_initialized = true;

        print("PortAudio initialized successfully\n", .{});
        print("PortAudio version: {s}\n", .{pa.getVersionText()});

        // List available input devices
        try listInputDevices();
    }

    pub fn startRecording(self: *Self) !void {
        print("DEBUG: startRecording() called\n", .{});

        if (!self.pa_initialized) {
            print("DEBUG: Initializing PortAudio...\n", .{});
            try self.initializePortAudio();
        }

        if (self.recording_data.is_recording) {
            print("DEBUG: Already recording, returning error\n", .{});
            return error.AlreadyRecording;
        }

        // Generate temp file path
        const timestamp = std.time.timestamp();
        self.temp_file_path = try std.fmt.allocPrint(self.allocator, "/tmp/echotype_recording_{}.wav", .{timestamp});
        print("DEBUG: Generated temp file path: {s}\n", .{self.temp_file_path});

        // Clear previous recording data
        self.recording_data.samples.clearRetainingCapacity();
        self.recording_data.samples_recorded = 0;
        print("DEBUG: Setting is_recording to true\n", .{});
        self.recording_data.is_recording = true;

        // Try to use a better device instead of default
        // Preference order: PulseAudio (8), HD-Audio Generic (5), then default
        var selected_device = pa.getDefaultInputDevice();

        // First try PulseAudio device (usually device 8)
        const device_count = pa.getDeviceCount();
        var pulse_device: ?pa.PaDeviceIndex = null;
        var hw_device: ?pa.PaDeviceIndex = null;

        var i: pa.PaDeviceIndex = 0;
        while (i < device_count) : (i += 1) {
            if (pa.getDeviceInfo(i)) |device_info| {
                if (device_info.maxInputChannels > 0) {
                    const name = std.mem.span(device_info.name);
                    if (std.mem.indexOf(u8, name, "pulse") != null) {
                        pulse_device = i;
                    } else if (std.mem.indexOf(u8, name, "HD-Audio") != null and std.mem.indexOf(u8, name, "hw:") != null) {
                        hw_device = i;
                    }
                }
            }
        }

        // Select device in order of preference
        if (pulse_device) |device| {
            selected_device = device;
            print("DEBUG: Using PulseAudio device: {}\n", .{selected_device});
        } else if (hw_device) |device| {
            selected_device = device;
            print("DEBUG: Using HD-Audio device: {}\n", .{selected_device});
        } else {
            print("DEBUG: Using default input device: {}\n", .{selected_device});
        }

        // Check device info to ensure it supports our channel count
        if (pa.getDeviceInfo(selected_device)) |device_info| {
            print("DEBUG: Device '{}' info:\n", .{selected_device});
            print("  Name: {s}\n", .{device_info.name});
            print("  Max input channels: {}\n", .{device_info.maxInputChannels});
            print("  Max output channels: {}\n", .{device_info.maxOutputChannels});
            print("  Default sample rate: {d:.0} Hz\n", .{device_info.defaultSampleRate});

            if (device_info.maxInputChannels < self.config.channels) {
                print("WARNING: Device only supports {} channels, but config requests {}. Using 1 channel.\n", .{ device_info.maxInputChannels, self.config.channels });
                // Force to mono if device doesn't support our channel count
                self.config.channels = 1;
            }

            // Check if the device supports our sample rate
            if (device_info.defaultSampleRate != @as(f64, @floatFromInt(self.config.sample_rate))) {
                print("WARNING: Device default sample rate is {d:.0} Hz, but we're requesting {} Hz\n", .{ device_info.defaultSampleRate, self.config.sample_rate });
            }
        } else {
            print("WARNING: Could not get device info. Using 1 channel as fallback.\n", .{});
            self.config.channels = 1;
        }

        // Set up stream parameters
        const input_params = pa.PaStreamParameters{
            .device = selected_device,
            .channelCount = @intCast(self.config.channels),
            .sampleFormat = pa.paFloat32,
            .suggestedLatency = 0.0, // Let PortAudio choose the latency
            .hostApiSpecificStreamInfo = null,
        };

        // Check if format is supported
        const format_err = pa.isFormatSupported(&input_params, null, @floatFromInt(self.config.sample_rate));
        if (format_err != pa.paNoError) {
            print("Warning: Audio format may not be supported: {s}\n", .{pa.getErrorText(format_err)});
        }

        // Print debug info about what we're requesting
        print("DEBUG: Requesting PortAudio stream:\n", .{});
        print("  Sample rate: {} Hz\n", .{self.config.sample_rate});
        print("  Channels: {}\n", .{self.config.channels});
        print("  Buffer frames: {}\n", .{self.config.buffer_frames});
        print("  Expected callback interval: {d:.1} ms\n", .{(@as(f64, @floatFromInt(self.config.buffer_frames)) / @as(f64, @floatFromInt(self.config.sample_rate))) * 1000.0});

        // Open audio stream
        print("DEBUG: Opening PortAudio stream...\n", .{});
        // --- AFTER (The fix) ---
        const stream_err = pa.openStream(
            &self.stream,
            &input_params,
            null, // No output
            @floatFromInt(self.config.sample_rate),
            self.config.buffer_frames, // <-- Use your configured buffer size
            pa.paNoFlag,
            audioCallback,
            &self.recording_data,
        );

        if (stream_err != pa.paNoError) {
            print("ERROR: Failed to open audio stream: {s}\n", .{pa.getErrorText(stream_err)});
            self.recording_data.is_recording = false; // Reset flag on failure
            return error.StreamOpenFailed;
        }
        print("DEBUG: Stream opened successfully\n", .{});

        // Check what buffer size we actually got
        if (pa.getStreamInfo(self.stream)) |stream_info| {
            print("DEBUG: Stream configured with:\n", .{});
            print("  Actual sample rate: {d:.0} Hz\n", .{stream_info.sampleRate});
            print("  Actual input latency: {d:.3} ms\n", .{stream_info.inputLatency * 1000.0});
            print("  Actual output latency: {d:.3} ms\n", .{stream_info.outputLatency * 1000.0});

            // Calculate expected callback interval from latency
            const expected_buffer_ms = stream_info.inputLatency * 1000.0;
            print("  Expected callback interval from latency: {d:.1} ms\n", .{expected_buffer_ms});
        }

        // Start the stream
        print("DEBUG: Starting PortAudio stream...\n", .{});
        const start_err = pa.startStream(self.stream);
        if (start_err != pa.paNoError) {
            print("ERROR: Failed to start audio stream: {s}\n", .{pa.getErrorText(start_err)});
            self.recording_data.is_recording = false; // Reset flag on failure
            return error.StreamStartFailed;
        }
        print("DEBUG: Stream started successfully\n", .{});

        print("Audio recording started\n", .{});
        print("  Sample rate: {} Hz\n", .{self.config.sample_rate});
        print("  Channels: {}\n", .{self.config.channels});
        print("  Buffer size: {} frames\n", .{self.config.buffer_frames});

        // Check actual stream properties
        if (pa.getStreamInfo(self.stream)) |stream_info| {
            print("  Actual sample rate: {d:.0} Hz\n", .{stream_info.sampleRate});
            print("  Actual input latency: {d:.3} ms\n", .{stream_info.inputLatency * 1000.0});
            print("  Actual output latency: {d:.3} ms\n", .{stream_info.outputLatency * 1000.0});
        }
    }

    pub fn stopRecording(self: *Self) ![]const u8 {
        if (!self.recording_data.is_recording) {
            // Recording was already stopped (e.g., by reaching the limit)
            // Just save and return the file path
            if (self.recording_data.samples_recorded > 0) {
                try self.saveToWavFile();
                return self.temp_file_path;
            } else {
                return error.NotRecording;
            }
        }

        // Record end time BEFORE setting is_recording to false
        self.recording_data.end_time_ns = std.time.nanoTimestamp();
        self.recording_data.is_recording = false;

        // Stop the stream
        if (self.stream) |stream| {
            _ = pa.stopStream(stream);
            _ = pa.closeStream(stream);
            self.stream = null;
        }

        // Calculate actual elapsed time
        const actual_duration_ms = @divTrunc(self.recording_data.end_time_ns - self.recording_data.start_time_ns, 1_000_000);
        const actual_duration_seconds = @as(f64, @floatFromInt(actual_duration_ms)) / 1000.0;
        const calculated_duration_seconds = @as(f64, @floatFromInt(self.recording_data.samples_recorded)) / @as(f64, @floatFromInt(self.config.sample_rate));

        print("Audio recording stopped\n", .{});
        print("Recorded {} samples\n", .{self.recording_data.samples_recorded});
        print("  Calculated duration: {d:.2} seconds (based on sample count / sample rate)\n", .{calculated_duration_seconds});
        print("  Actual elapsed time: {d:.2} seconds (measured with timestamps)\n", .{actual_duration_seconds});

        // Save to WAV file
        try self.saveToWavFile();

        return self.temp_file_path;
    }

    pub fn cleanupTempFile(self: *Self, file_path: []const u8) void {
        _ = self; // Suppress unused parameter warning
        std.fs.cwd().deleteFile(file_path) catch |err| {
            print("Warning: Failed to delete temp file {s}: {}\n", .{ file_path, err });
        };
        print("Cleaned up temp file: {s}\n", .{file_path});
    }

    pub fn isRecording(self: *Self) bool {
        return self.recording_data.is_recording;
    }

    pub fn getRecordingDuration(self: *Self) f64 {
        if (self.recording_data.samples_recorded == 0) return 0.0;

        // If recording is finished, use actual elapsed time
        if (!self.recording_data.is_recording and self.recording_data.end_time_ns > 0) {
            const actual_duration_ms = @divTrunc(self.recording_data.end_time_ns - self.recording_data.start_time_ns, 1_000_000);
            return @as(f64, @floatFromInt(actual_duration_ms)) / 1000.0;
        }

        // If still recording, use current elapsed time
        if (self.recording_data.is_recording and self.recording_data.start_time_ns > 0) {
            const current_time = std.time.nanoTimestamp();
            const elapsed_ms = @divTrunc(current_time - self.recording_data.start_time_ns, 1_000_000);
            return @as(f64, @floatFromInt(elapsed_ms)) / 1000.0;
        }

        // Fallback to sample-based calculation (may be inaccurate with single-sample callbacks)
        return @as(f64, @floatFromInt(self.recording_data.samples_recorded)) /
            @as(f64, @floatFromInt(self.config.sample_rate));
    }

    pub fn getSamplesRecorded(self: *Self) u32 {
        return self.recording_data.samples_recorded;
    }

    pub fn getRecordedSamples(self: *Self) []const f32 {
        return self.recording_data.samples.items;
    }

    fn saveToWavFile(self: *Self) !void {
        var wav_writer = try wav.WavWriter.init(
            self.allocator,
            self.temp_file_path,
            self.config.sample_rate,
            self.config.channels,
            self.config.bits_per_sample,
        );
        defer wav_writer.deinit();

        try wav_writer.open();
        try wav_writer.writeFloat32Samples(self.recording_data.samples.items);
        try wav_writer.close();

        // Calculate and print correct duration information
        const actual_duration_seconds = self.getRecordingDuration();

        print("WAV file written: {s}\n", .{self.temp_file_path});
        print("  Sample rate: {} Hz\n", .{self.config.sample_rate});
        print("  Channels: {}\n", .{self.config.channels});
        print("  Bits per sample: {}\n", .{self.config.bits_per_sample});
        print("  Duration: {d:.2} seconds\n", .{actual_duration_seconds});
    }
};

fn listInputDevices() !void {
    const device_count = pa.getDeviceCount();
    const default_input = pa.getDefaultInputDevice();

    print("Available input devices:\n", .{});

    var i: pa.PaDeviceIndex = 0;
    while (i < device_count) : (i += 1) {
        if (pa.getDeviceInfo(i)) |device_info| {
            if (device_info.maxInputChannels > 0) {
                const is_default = if (i == default_input) " (default)" else "";
                print("  [{}] {s}{s}\n", .{ i, device_info.name, is_default });
                print("      Max input channels: {}\n", .{device_info.maxInputChannels});
                print("      Default sample rate: {d:.0} Hz\n", .{device_info.defaultSampleRate});
            }
        }
    }
}

// PortAudio callback function for recording
fn audioCallback(
    input_buffer: ?*const anyopaque,
    output_buffer: ?*anyopaque,
    frames_per_buffer: c_ulong,
    time_info: ?*const pa.c.PaStreamCallbackTimeInfo,
    status_flags: pa.c.PaStreamCallbackFlags,
    user_data: ?*anyopaque,
) callconv(.C) c_int {
    _ = output_buffer;
    _ = time_info;
    _ = status_flags;

    if (input_buffer == null or user_data == null) {
        return pa.paAbort;
    }

    const recording_data: *RecordingData = @ptrCast(@alignCast(user_data.?));

    if (!recording_data.is_recording) {
        return pa.paComplete;
    }

    // Cast input buffer to float32 samples
    const samples: [*]const f32 = @ptrCast(@alignCast(input_buffer.?));
    const num_samples = @as(u32, @intCast(frames_per_buffer));

    // Initialize timing on first callback
    if (recording_data.samples_recorded == 0) {
        recording_data.start_time_ns = std.time.nanoTimestamp();
        recording_data.last_callback_time_ns = recording_data.start_time_ns;
        print("🎤 Recording started (frames={})\n", .{frames_per_buffer});

        // CRITICAL: Check if we're getting single-sample callbacks
        if (frames_per_buffer < 64) { // Or some other reasonable minimum
            print("⚠️ WARNING: PortAudio is providing very small buffers ({} frames). This may impact performance.\n", .{frames_per_buffer});
        } else {
            print("✓ Callback initiated with {} frames per buffer.\n", .{frames_per_buffer});
        }
    } else {
        recording_data.last_callback_time_ns = std.time.nanoTimestamp();
    }

    // Safety check: don't exceed maximum samples (30-second limit)
    if (recording_data.samples_recorded + num_samples > recording_data.max_samples) {
        const duration_so_far = @as(f64, @floatFromInt(recording_data.samples_recorded)) / 16000.0;
        print("Maximum recording limit reached, stopping...\n", .{});
        print("  Final: samples_recorded={}, max_samples={}, frames_per_buffer={}\n", .{ recording_data.samples_recorded, recording_data.max_samples, frames_per_buffer });
        print("  Duration so far: {d:.2} seconds\n", .{duration_so_far});
        recording_data.is_recording = false;
        return pa.paComplete;
    }

    // Validate audio input - check if we're getting real data
    var has_signal = false;
    var max_amplitude: f32 = 0.0;
    for (0..num_samples) |i| {
        const sample = samples[i];
        const abs_sample = if (sample < 0) -sample else sample;
        if (abs_sample > max_amplitude) max_amplitude = abs_sample;
        if (abs_sample > 0.001) has_signal = true; // Detect non-silence
    }

    // Log audio signal info occasionally for the first second of recording
    if (recording_data.samples_recorded < 16000) { // First second of recording
        if (recording_data.samples_recorded % 8192 == 0) { // Every 8192 samples
            print("📊 Audio: max={d:.3}, signal={}, samples[0]={d:.6}\n", .{ max_amplitude, has_signal, samples[0] });
        }
    }

    // Append samples to our buffer
    const samples_before = recording_data.samples_recorded;
    for (0..num_samples) |i| {
        recording_data.samples.append(samples[i]) catch {
            print("Failed to append audio sample at index {}\n", .{i});
            print("  Samples before: {}, trying to add: {}\n", .{ samples_before, num_samples });
            recording_data.is_recording = false;
            return pa.paAbort;
        };
    }

    recording_data.samples_recorded += num_samples;

    // Debug: Print callback info for first few callbacks to see frequency
    if (recording_data.samples_recorded <= 65536) { // First ~4 seconds
        if (recording_data.samples_recorded % 4096 == 0) { // More frequent logging
            const time_since_start_ms = @divTrunc(recording_data.last_callback_time_ns - recording_data.start_time_ns, 1_000_000);
            const expected_time_ms = @divTrunc(recording_data.samples_recorded * 1000, 16000);
            print("DEBUG: Callback #{} samples={}, real_time={}ms, expected_time={}ms, frames={}\n", .{ recording_data.samples_recorded / frames_per_buffer + 1, recording_data.samples_recorded, time_since_start_ms, expected_time_ms, frames_per_buffer });
        }
    }

    return pa.paContinue;
}

// Tests
test "audio config validation" {
    const config = AudioConfig{};
    try std.testing.expect(wav.isValidSampleRate(config.sample_rate));
    try std.testing.expect(wav.isValidChannelCount(config.channels));
    try std.testing.expect(wav.isValidBitsPerSample(config.bits_per_sample));
}
