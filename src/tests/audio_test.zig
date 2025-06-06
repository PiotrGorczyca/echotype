const std = @import("std");
const audio = @import("audio");
const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    print("🎙️  Audio Recording Test\n", .{});
    print("=======================\n\n", .{});

    // Initialize audio recorder
    var recorder = audio.AudioRecorder.init(allocator);
    defer recorder.deinit();

    print("Audio recorder initialized successfully!\n", .{});
    print("Available audio devices:\n", .{});

    // Initialize PortAudio to list devices
    try recorder.initializePortAudio();

    print("\nStarting 5-second recording test...\n", .{});
    print("Please speak into your microphone!\n\n", .{});

    // Start recording
    try recorder.startRecording();

    // Record for 5 seconds
    std.time.sleep(5 * std.time.ns_per_s);

    // Stop recording
    const file_path = try recorder.stopRecording();
    print("\nRecording saved to: {s}\n", .{file_path});

    // Check file exists and get size
    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        print("Error opening recorded file: {}\n", .{err});
        return;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    print("File size: {} bytes\n", .{file_size});

    // Calculate recording duration
    const duration = recorder.getRecordingDuration();
    print("Recording duration: {d:.2} seconds\n", .{duration});

    print("\n✅ Audio recording test completed successfully!\n", .{});
    print("You can play the recorded file with: aplay {s}\n", .{file_path});
    print("NOTE: File is preserved for testing - you can manually delete it later\n", .{});

    // Don't clean up temp file for testing purposes
    // recorder.cleanupTempFile(file_path);
}
