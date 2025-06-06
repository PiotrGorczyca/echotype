const std = @import("std");
const audio = @import("audio");
const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    print("=== DEBUGGING MAIN APP BEHAVIOR ===\n", .{});

    var recorder = audio.AudioRecorder.init(allocator);
    defer recorder.deinit();

    print("Simulating hotkey press (start recording)...\n", .{});

    // Simulate what happens in main app
    const currently_recording = recorder.isRecording();
    print("DEBUG: Currently recording: {}\n", .{currently_recording});

    if (!currently_recording) {
        print("Starting recording...\n", .{});

        // This is exactly what startRecordingWorkflow does
        recorder.startRecording() catch |err| {
            print("ERROR: startRecording failed: {}\n", .{err});
            return;
        };

        // Check if recording actually started
        const started_successfully = recorder.isRecording();
        print("DEBUG: Recording started successfully: {}\n", .{started_successfully});

        if (started_successfully) {
            print("🔴 Recording! Waiting 2 seconds before stopping...\n", .{});
            std.time.sleep(2 * std.time.ns_per_s);

            print("Stopping recording...\n", .{});
            const file_path = try recorder.stopRecording();
            print("Recording saved to: {s}\n", .{file_path});

            print("Duration: {d:.2} seconds\n", .{recorder.getRecordingDuration()});
            print("Samples: {}\n", .{recorder.getSamplesRecorded()});
        } else {
            print("ERROR: Recording failed to start properly!\n", .{});
        }
    }

    print("Test completed.\n", .{});
}
