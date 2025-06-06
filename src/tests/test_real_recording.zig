const std = @import("std");
const audio = @import("audio");
const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    print("🎙️  REAL Microphone Recording Test\n", .{});
    print("==================================\n\n", .{});

    // Initialize audio recorder
    var recorder = audio.AudioRecorder.init(allocator);
    defer recorder.deinit();

    print("Initializing audio system...\n", .{});
    try recorder.initializePortAudio();

    print("\n🔴 Starting REAL-TIME 10-second recording...\n", .{});
    print("👄 SPEAK NOW - Make some noise!\n", .{});
    print("📊 Recording progress:\n", .{});

    // Start recording
    const start_time = std.time.milliTimestamp();
    try recorder.startRecording();

    // Monitor recording in real-time for 10 seconds
    var last_samples: u32 = 0;
    var seconds_elapsed: u32 = 0;

    while (seconds_elapsed < 10) {
        std.time.sleep(1 * std.time.ns_per_s); // Wait 1 second
        seconds_elapsed += 1;

        const current_samples = recorder.getSamplesRecorded();
        const samples_this_second = current_samples - last_samples;

        // Calculate volume level (simple RMS of recent samples)
        var volume_level: f32 = 0.0;
        const recorded_samples = recorder.getRecordedSamples();
        if (recorded_samples.len > 0) {
            const recent_start = if (recorded_samples.len > 1000)
                recorded_samples.len - 1000
            else
                0;

            var sum_squares: f64 = 0.0;
            for (recorded_samples[recent_start..]) |sample| {
                sum_squares += @as(f64, @floatCast(sample * sample));
            }
            volume_level = @floatCast(@sqrt(sum_squares / @as(f64, @floatFromInt(recorded_samples.len - recent_start))));
        }

        // Visual progress bar
        const progress_chars = (seconds_elapsed * 50) / 10;
        var progress_bar: [52]u8 = undefined;
        progress_bar[0] = '[';
        progress_bar[51] = ']';

        for (1..51) |i| {
            if (i <= progress_chars) {
                progress_bar[i] = '#';
            } else {
                progress_bar[i] = '-';
            }
        }

        // Volume indicator
        const volume_bars = @min(10, @as(u32, @intFromFloat(volume_level * 1000)));
        var volume_indicator: [12]u8 = undefined;
        volume_indicator[0] = '|';
        volume_indicator[11] = '|';
        for (1..11) |i| {
            if (i <= volume_bars) {
                volume_indicator[i] = '#';
            } else {
                volume_indicator[i] = '-';
            }
        }

        print("  [{d:2}s] {s} {d:6} samples/sec, Vol: {s} ({d:.4})\n", .{ seconds_elapsed, progress_bar[0..52], samples_this_second, volume_indicator[0..12], volume_level });

        last_samples = current_samples;

        if (!recorder.isRecording()) {
            print("⚠️  Recording stopped unexpectedly!\n", .{});
            break;
        }
    }

    // Stop recording
    const end_time = std.time.milliTimestamp();
    const actual_duration_ms = end_time - start_time;

    print("\n🛑 Stopping recording...\n", .{});
    const file_path = try recorder.stopRecording();

    // Analysis
    print("\n�� RECORDING ANALYSIS:\n", .{});
    print("Wall clock time: {d} ms ({d:.2} seconds)\n", .{ actual_duration_ms, @as(f64, @floatFromInt(actual_duration_ms)) / 1000.0 });
    print("Audio duration: {d:.2} seconds\n", .{recorder.getRecordingDuration()});
    print("Total samples: {d}\n", .{recorder.getSamplesRecorded()});
    print("Expected samples: {d} (16000 Hz * {d:.2}s)\n", .{ @as(u32, @intFromFloat(16000.0 * (@as(f64, @floatFromInt(actual_duration_ms)) / 1000.0))), @as(f64, @floatFromInt(actual_duration_ms)) / 1000.0 });

    // Check file
    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        print("❌ Error opening recorded file: {}\n", .{err});
        return;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    print("📁 File: {s}\n", .{file_path});
    print("💾 File size: {d} bytes\n", .{file_size});

    // Audio quality analysis
    const final_samples = recorder.getRecordedSamples();
    if (final_samples.len > 0) {
        var max_amplitude: f32 = 0.0;
        var total_energy: f64 = 0.0;
        var silent_samples: u32 = 0;

        for (final_samples) |sample| {
            const abs_sample = @abs(sample);
            if (abs_sample > max_amplitude) max_amplitude = abs_sample;
            total_energy += @as(f64, @floatCast(sample * sample));
            if (abs_sample < 0.001) silent_samples += 1;
        }

        const avg_energy = total_energy / @as(f64, @floatFromInt(final_samples.len));
        const silence_percentage = (@as(f64, @floatFromInt(silent_samples)) / @as(f64, @floatFromInt(final_samples.len))) * 100.0;

        print("\nAUDIO QUALITY:\n", .{});
        print("Max amplitude: {d:.4}\n", .{max_amplitude});
        print("Avg energy: {d:.6}\n", .{avg_energy});
        print("Silence: {d:.1}%\n", .{silence_percentage});

        if (max_amplitude < 0.001) {
            print("⚠️  WARNING: Very low audio levels - check microphone!\n", .{});
        } else if (silence_percentage > 95.0) {
            print("⚠️  WARNING: Mostly silence - is microphone working?\n", .{});
        } else {
            print("✅ Audio levels look good!\n", .{});
        }
    }

    print("\n🎧 Play recording: aplay {s}\n", .{file_path});
    print("🔍 Keep file for inspection\n", .{});
}
