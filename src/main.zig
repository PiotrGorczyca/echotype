const std = @import("std");
const print = std.debug.print;

// Import our modules
const hotkey = @import("hotkey.zig");
const audio = @import("audio.zig");
const visualizer = @import("visualizer.zig");
const whisper_client = @import("whisper_client.zig");
const clipboard = @import("clipboard.zig");
const config = @import("config.zig");

// Import visualizer state
const VisualizerState = visualizer.VisualizerState;

pub fn main() !void {
    print("EchoType - Voice Transcription Application\n", .{});
    print("Press Ctrl+C to quit\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize configuration
    var app_config = config.Config.init(allocator);
    defer app_config.deinit();

    // Initialize modules
    var hotkey_handler = hotkey.HotkeyHandler.init(allocator);
    defer hotkey_handler.deinit();

    var audio_recorder = audio.AudioRecorder.init(allocator);
    defer audio_recorder.deinit();

    var visualizer_window = visualizer.Visualizer.init(allocator);
    defer visualizer_window.deinit();

    var whisper_api = whisper_client.WhisperClient.init(allocator, app_config.openai_api_key);
    defer whisper_api.deinit();

    var clipboard_manager = clipboard.ClipboardManager.init(allocator);
    defer clipboard_manager.deinit();

    // Register hotkey (Ctrl+Shift+S by default)
    try hotkey_handler.registerHotkey(app_config.hotkey_combination);

    print("Application initialized. Listening for hotkey: {s}\n", .{app_config.hotkey_combination});

    var is_processing = false; // Track if we're in transcription/processing mode

    var hotkey_was_pressed = false;

    // Main event loop
    while (true) {
        const hotkey_is_pressed = hotkey_handler.isHotkeyPressed();

        // Only act on the rising edge (transition from not pressed to pressed)
        if (hotkey_is_pressed and !hotkey_was_pressed) {
            if (is_processing) {
                print("DEBUG: Hotkey press ignored (currently processing transcription)\n", .{});
            } else {
                const currently_recording = audio_recorder.isRecording();
                print("DEBUG: Hotkey press detected! Currently recording: {}\n", .{currently_recording});

                if (currently_recording) {
                    print("Hotkey detected! Stopping recording...\n", .{});
                    is_processing = true;

                    finishRecordingWorkflow(allocator, &audio_recorder, &visualizer_window, &whisper_api, &clipboard_manager) catch |err| {
                        print("Error in recording workflow: {}\n", .{err});
                    };

                    is_processing = false;
                    print("Ready for next recording.\n", .{});
                } else {
                    print("Hotkey detected! Starting recording...\n", .{});
                    try startRecordingWorkflow(&audio_recorder, &visualizer_window);

                    // The debug checks below are still useful
                    std.time.sleep(50_000_000); // 50ms is enough for the stream to start
                    if (!audio_recorder.isRecording()) {
                        print("ERROR: Recording failed to start or stopped immediately!\n", .{});
                    }
                }
            }
        }

        // Update visualizer position if following cursor
        visualizer_window.updatePosition() catch {};

        // Animate spinner if visualizer is active
        visualizer_window.animate() catch {};

        // Check if transcription completed
        if (transcription_completed) {
            if (transcription_thread) |thread| {
                thread.join();
                transcription_thread = null;
            }
            handleTranscriptionResult(allocator, &visualizer_window, &clipboard_manager) catch |err| {
                print("Error handling transcription result: {}\n", .{err});
            };
        }

        // Update the previous state for next iteration
        hotkey_was_pressed = hotkey_is_pressed;

        // Small delay to prevent excessive CPU usage
        std.time.sleep(10_000_000); // 10ms
    }
}

fn startRecordingWorkflow(
    audio_recorder: *audio.AudioRecorder,
    visualizer_window: *visualizer.Visualizer,
) !void {
    // 1. Get cursor position and show visualizer
    try visualizer_window.showNearCursor();

    // 2. Start recording
    try audio_recorder.startRecording();

    print("🔴 Recording started! Press hotkey again to stop.\n", .{});
}

// Global state for async transcription
var transcription_thread: ?std.Thread = null;
var transcription_result: ?[]u8 = null;
var transcription_error: bool = false;
var transcription_completed: bool = false;

fn finishRecordingWorkflow(
    allocator: std.mem.Allocator,
    audio_recorder: *audio.AudioRecorder,
    visualizer_window: *visualizer.Visualizer,
    whisper_api: *whisper_client.WhisperClient,
    _: *clipboard.ClipboardManager,
) !void {

    // 1. Stop recording and get audio file
    const audio_file_path = try audio_recorder.stopRecording();
    print("Audio file saved to: {s}\n", .{audio_file_path});

    // 2. Show transcribing state
    try visualizer_window.setState(.transcribing);
    print("Recording completed. Transcribing...\n", .{});

    // 3. Start transcription in background thread
    const TranscriptionContext = struct {
        allocator: std.mem.Allocator,
        audio_file_path: []const u8,
        whisper_api: *whisper_client.WhisperClient,
    };

    const ctx = try allocator.create(TranscriptionContext);
    ctx.* = TranscriptionContext{
        .allocator = allocator,
        .audio_file_path = try allocator.dupe(u8, audio_file_path),
        .whisper_api = whisper_api,
    };

    transcription_thread = try std.Thread.spawn(.{}, transcribeInBackground, .{ctx});
}

fn transcribeInBackground(ctx: anytype) void {
    defer {
        ctx.allocator.free(ctx.audio_file_path);
        ctx.allocator.destroy(ctx);
    }

    const transcription = ctx.whisper_api.transcribe(ctx.audio_file_path) catch |err| {
        print("Error transcribing audio: {}\n", .{err});
        transcription_error = true;
        transcription_completed = true;
        return;
    };

    transcription_result = @constCast(transcription);
    transcription_completed = true;
}

fn handleTranscriptionResult(
    allocator: std.mem.Allocator,
    visualizer_window: *visualizer.Visualizer,
    clipboard_manager: *clipboard.ClipboardManager,
) !void {
    if (transcription_error) {
        print("Transcription failed\n", .{});
        visualizer_window.hide();
        transcription_error = false;
        transcription_completed = false;
        return;
    }

    if (transcription_result) |transcription| {
        defer allocator.free(transcription);
        defer transcription_result = null;
        defer transcription_completed = false;

        print("Transcription: {s}\n", .{transcription});

        // Copy transcription to clipboard
        clipboard_manager.copyText(transcription) catch |err| {
            print("Error copying to clipboard: {}\n", .{err});
            visualizer_window.hide();
            return;
        };

        // Show finished state
        try visualizer_window.setState(.finished);
        print("✅ Transcription copied to clipboard!\n", .{});
        print("📋 You can now paste it anywhere with Ctrl+V\n", .{});
    }
}

// Test function for development
test "basic test" {
    try std.testing.expect(true);
}
