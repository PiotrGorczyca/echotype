const std = @import("std");
const audio = @import("audio");
const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    print("=== SIMPLE RECORDING TIMING TEST ===\n\n", .{});

    var recorder = audio.AudioRecorder.init(allocator);
    defer recorder.deinit();

    print("Initializing PortAudio...\n", .{});
    try recorder.initializePortAudio();

    print("\nSetting target duration to 5 seconds...\n", .{});
    recorder.setTargetDuration(5);

    print("Starting 5-second recording...\n", .{});
    print("SPEAK INTO YOUR MICROPHONE!\n\n", .{});

    // Record wall clock time
    const start_time = std.time.milliTimestamp();

    try recorder.startRecording();

    print("Recording started, sleeping for 5 seconds...\n", .{});
    std.time.sleep(5 * std.time.ns_per_s);

    const file_path = try recorder.stopRecording();
    const end_time = std.time.milliTimestamp();

    const wall_time_ms = end_time - start_time;

    print("\n=== RESULTS ===\n", .{});
    print("Wall clock time: {} ms ({d:.2} seconds)\n", .{ wall_time_ms, @as(f64, @floatFromInt(wall_time_ms)) / 1000.0 });
    print("Audio duration: {d:.2} seconds\n", .{recorder.getRecordingDuration()});
    print("Samples recorded: {}\n", .{recorder.getSamplesRecorded()});
    print("Expected samples for {}ms: {}\n", .{ wall_time_ms, (wall_time_ms * 16) }); // 16 samples per ms at 16kHz

    // Check if file exists
    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        print("ERROR: Cannot open file: {}\n", .{err});
        return;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    print("File size: {} bytes\n", .{file_size});
    print("File path: {s}\n", .{file_path});

    // Analyze first few samples to see if we're getting real data
    const samples = recorder.getRecordedSamples();
    if (samples.len > 10) {
        print("\nFirst 10 samples: ", .{});
        for (samples[0..10]) |sample| {
            print("{d:.4} ", .{sample});
        }
        print("\n", .{});

        // Check if all samples are zero (indicating no input)
        var non_zero_count: u32 = 0;
        for (samples) |sample| {
            if (@abs(sample) > 0.0001) non_zero_count += 1;
        }

        print("Non-zero samples: {} out of {} ({d:.1}%)\n", .{ non_zero_count, samples.len, (@as(f64, @floatFromInt(non_zero_count)) / @as(f64, @floatFromInt(samples.len))) * 100.0 });

        if (non_zero_count == 0) {
            print("WARNING: All samples are zero - microphone not working!\n", .{});
        } else if (non_zero_count < samples.len / 100) {
            print("WARNING: Very few non-zero samples - check microphone levels!\n", .{});
        } else {
            print("SUCCESS: Audio data detected!\n", .{});
        }
    }

    print("\nTest recording with: aplay {s}\n", .{file_path});
    print("File preserved for analysis.\n", .{});
}
