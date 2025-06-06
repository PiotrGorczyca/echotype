const std = @import("std");
const audio = @import("audio");
const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    print("=== PORTAUDIO INITIALIZATION TEST ===\n", .{});

    var recorder = audio.AudioRecorder.init(allocator);
    defer recorder.deinit();

    print("Step 1: Creating recorder - DONE\n", .{});

    print("Step 2: Calling initializePortAudio()...\n", .{});
    recorder.initializePortAudio() catch |err| {
        print("ERROR: PortAudio initialization failed: {}\n", .{err});
        return;
    };

    print("Step 3: PortAudio initialized successfully!\n", .{});

    print("Step 4: Testing isRecording() before start...\n", .{});
    const before_recording = recorder.isRecording();
    print("Before start: isRecording() = {}\n", .{before_recording});

    print("Step 5: Calling startRecording()...\n", .{});
    recorder.startRecording() catch |err| {
        print("ERROR: startRecording failed: {}\n", .{err});
        return;
    };

    print("Step 6: Checking isRecording() after start...\n", .{});
    const after_recording = recorder.isRecording();
    print("After start: isRecording() = {}\n", .{after_recording});

    if (after_recording) {
        print("✅ SUCCESS: Recording started properly!\n", .{});
        print("Waiting 1 second...\n", .{});
        std.time.sleep(1 * std.time.ns_per_s);

        print("Stopping recording...\n", .{});
        const file_path = try recorder.stopRecording();
        print("File: {s}\n", .{file_path});
        print("Duration: {d:.2}s\n", .{recorder.getRecordingDuration()});
    } else {
        print("❌ FAILURE: Recording did not start!\n", .{});
    }
}
