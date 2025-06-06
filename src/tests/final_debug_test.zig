const std = @import("std");
const audio = @import("audio");
const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    print("=== FINAL DEBUG TEST ===\n", .{});
    print("This test simulates exactly what the main app does.\n\n", .{});

    var recorder = audio.AudioRecorder.init(allocator);
    defer recorder.deinit();

    // Test sequence
    print("TEST 1: Check initial state\n", .{});
    var is_recording = recorder.isRecording();
    print("  Initial isRecording(): {}\n", .{is_recording});

    print("\nTEST 2: Initialize PortAudio (this may take time...)\n", .{});
    const start_init = std.time.milliTimestamp();
    recorder.initializePortAudio() catch |err| {
        print("  ERROR: PortAudio init failed: {}\n", .{err});
        return;
    };
    const end_init = std.time.milliTimestamp();
    print("  PortAudio initialized in {}ms\n", .{end_init - start_init});

    print("\nTEST 3: Start recording\n", .{});
    const start_recording_time = std.time.milliTimestamp();
    recorder.startRecording() catch |err| {
        print("  ERROR: Start recording failed: {}\n", .{err});
        return;
    };
    const end_recording_time = std.time.milliTimestamp();
    print("  startRecording() completed in {}ms\n", .{end_recording_time - start_recording_time});

    print("\nTEST 4: Wait and check recording state\n", .{});
    std.time.sleep(100_000_000); // 100ms like main app
    is_recording = recorder.isRecording();
    print("  After 100ms delay: isRecording() = {}\n", .{is_recording});

    if (is_recording) {
        print("\n✅ SUCCESS: Recording is active!\n", .{});
        print("Recording for 2 seconds...\n", .{});

        // Monitor for 2 seconds
        var i: u8 = 0;
        while (i < 20) { // 20 * 100ms = 2 seconds
            std.time.sleep(100_000_000); // 100ms
            const samples = recorder.getSamplesRecorded();
            const still_recording = recorder.isRecording();
            print("  [{:2}] Samples: {:6}, Still recording: {}\n", .{ i, samples, still_recording });

            if (!still_recording) {
                print("  Recording stopped automatically!\n", .{});
                break;
            }
            i += 1;
        }

        print("\nStopping recording...\n", .{});
        const file_path = try recorder.stopRecording();
        print("File: {s}\n", .{file_path});
        print("Final duration: {d:.2}s\n", .{recorder.getRecordingDuration()});
        print("Final samples: {}\n", .{recorder.getSamplesRecorded()});
    } else {
        print("\n❌ FAILURE: Recording did not start properly!\n", .{});
        print("This is the bug we need to fix.\n", .{});
    }

    print("\nTest completed.\n", .{});
}
