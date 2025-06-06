const std = @import("std");
const audio = @import("audio");
const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    print("🎙️  Recording Debug Test\n", .{});
    print("========================\n\n", .{});

    // Initialize audio recorder
    var recorder = audio.AudioRecorder.init(allocator);
    defer recorder.deinit();

    print("Starting 5-second recording test...\n", .{});
    print("Speak into your microphone!\n\n", .{});

    // Start recording
    try recorder.startRecording();

    // Record for 5 seconds (same as main app)
    print("Recording for 5 seconds...\n", .{});
    std.time.sleep(5 * std.time.ns_per_s);

    // Stop recording
    const file_path = try recorder.stopRecording();
    print("Audio file saved to: {s}\n", .{file_path});

    // Check file exists and get size
    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        print("❌ Error opening recorded file: {}\n", .{err});
        return;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    print("✅ File size: {} bytes\n", .{file_size});

    // Calculate recording duration
    const duration = recorder.getRecordingDuration();
    print("✅ Recording duration: {d:.2} seconds\n", .{duration});

    print("\n🎯 SUCCESS: Recording workflow complete!\n", .{});
    print("📁 Audio file location: {s}\n", .{file_path});
    print("🔊 You can play it with: aplay {s}\n", .{file_path});
    print("📝 File will be preserved for inspection\n", .{});

    // DON'T clean up the file so user can inspect it
    print("\n✨ Recording preserved for debugging!\n", .{});
}
