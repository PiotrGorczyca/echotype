const std = @import("std");
const audio = @import("audio");
const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    print("=== TOGGLE RECORDING TEST ===\n", .{});

    var recorder = audio.AudioRecorder.init(allocator);
    defer recorder.deinit();

    try recorder.initializePortAudio();

    print("\nPress Enter to START recording...\n", .{});
    _ = try std.io.getStdIn().reader().readByte();

    print("🔴 RECORDING - SPEAK NOW!\n", .{});
    try recorder.startRecording();

    print("Press Enter to STOP recording...\n", .{});
    _ = try std.io.getStdIn().reader().readByte();

    const file_path = try recorder.stopRecording();

    print("\n=== RESULTS ===\n", .{});
    print("Duration: {d:.2} seconds\n", .{recorder.getRecordingDuration()});
    print("Samples: {}\n", .{recorder.getSamplesRecorded()});
    print("File: {s}\n", .{file_path});

    // Check file size
    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        print("Error: Cannot open file: {}\n", .{err});
        return;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    print("Size: {} bytes\n", .{file_size});

    print("\n✅ Toggle recording test completed!\n", .{});
    print("Play with: aplay {s}\n", .{file_path});
    print("File preserved for testing.\n", .{});
}
