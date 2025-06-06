const std = @import("std");

// WAV file format structures
const WavHeader = struct {
    // RIFF header
    riff_id: [4]u8 = "RIFF".*,
    file_size: u32,
    wave_id: [4]u8 = "WAVE".*,

    // Format chunk
    fmt_id: [4]u8 = "fmt ".*,
    fmt_size: u32 = 16,
    audio_format: u16 = 1, // PCM
    num_channels: u16,
    sample_rate: u32,
    byte_rate: u32,
    block_align: u16,
    bits_per_sample: u16,

    // Data chunk
    data_id: [4]u8 = "data".*,
    data_size: u32,
};

pub const WavWriter = struct {
    allocator: std.mem.Allocator,
    file: ?std.fs.File,
    header: WavHeader,
    samples_written: u32,
    file_path: []u8,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        file_path: []const u8,
        sample_rate: u32,
        channels: u16,
        bits_per_sample: u16,
    ) !Self {
        const path_copy = try allocator.dupe(u8, file_path);

        const header = WavHeader{
            .file_size = 0, // Will be updated when closing
            .num_channels = channels,
            .sample_rate = sample_rate,
            .byte_rate = sample_rate * channels * (bits_per_sample / 8),
            .block_align = channels * (bits_per_sample / 8),
            .bits_per_sample = bits_per_sample,
            .data_size = 0, // Will be updated when closing
        };

        return Self{
            .allocator = allocator,
            .file = null,
            .header = header,
            .samples_written = 0,
            .file_path = path_copy,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.file) |file| {
            file.close();
        }
        self.allocator.free(self.file_path);
    }

    pub fn open(self: *Self) !void {
        self.file = try std.fs.cwd().createFile(self.file_path, .{});

        // Write initial header (will be updated later)
        try self.writeHeader();
    }

    pub fn writeInt16Samples(self: *Self, samples: []const i16) !void {
        if (self.file == null) return error.FileNotOpen;

        // Convert samples to bytes and write
        const bytes = std.mem.sliceAsBytes(samples);
        try self.file.?.writeAll(bytes);

        self.samples_written += @intCast(samples.len);
    }

    pub fn writeFloat32Samples(self: *Self, samples: []const f32) !void {
        if (self.file == null) return error.FileNotOpen;

        // Convert float32 samples to int16
        var int16_samples = try self.allocator.alloc(i16, samples.len);
        defer self.allocator.free(int16_samples);

        for (samples, 0..) |sample, i| {
            // Clamp and convert to 16-bit integer
            const clamped = std.math.clamp(sample, -1.0, 1.0);
            int16_samples[i] = @intFromFloat(clamped * 32767.0);
        }

        try self.writeInt16Samples(int16_samples);
    }

    pub fn close(self: *Self) !void {
        if (self.file == null) return error.FileNotOpen;

        // Update header with actual sizes
        const bytes_per_sample = self.header.bits_per_sample / 8;
        self.header.data_size = self.samples_written * bytes_per_sample;
        self.header.file_size = @sizeOf(WavHeader) - 8 + self.header.data_size;

        // Seek to beginning and rewrite header
        try self.file.?.seekTo(0);
        try self.writeHeader();

        self.file.?.close();
        self.file = null;

        std.debug.print("WAV file written: {s}\n", .{self.file_path});
        std.debug.print("  Sample rate: {} Hz\n", .{self.header.sample_rate});
        std.debug.print("  Channels: {}\n", .{self.header.num_channels});
        std.debug.print("  Bits per sample: {}\n", .{self.header.bits_per_sample});
        std.debug.print("  Duration: {d:.2} seconds\n", .{@as(f64, @floatFromInt(self.samples_written)) /
            @as(f64, @floatFromInt(self.header.sample_rate * self.header.num_channels))});
    }

    fn writeHeader(self: *Self) !void {
        if (self.file == null) return error.FileNotOpen;

        // Write header fields individually to ensure correct byte order and no padding
        try self.file.?.writeAll(&self.header.riff_id);
        try self.file.?.writeAll(std.mem.asBytes(&std.mem.nativeToLittle(u32, self.header.file_size)));
        try self.file.?.writeAll(&self.header.wave_id);

        try self.file.?.writeAll(&self.header.fmt_id);
        try self.file.?.writeAll(std.mem.asBytes(&std.mem.nativeToLittle(u32, self.header.fmt_size)));
        try self.file.?.writeAll(std.mem.asBytes(&std.mem.nativeToLittle(u16, self.header.audio_format)));
        try self.file.?.writeAll(std.mem.asBytes(&std.mem.nativeToLittle(u16, self.header.num_channels)));
        try self.file.?.writeAll(std.mem.asBytes(&std.mem.nativeToLittle(u32, self.header.sample_rate)));
        try self.file.?.writeAll(std.mem.asBytes(&std.mem.nativeToLittle(u32, self.header.byte_rate)));
        try self.file.?.writeAll(std.mem.asBytes(&std.mem.nativeToLittle(u16, self.header.block_align)));
        try self.file.?.writeAll(std.mem.asBytes(&std.mem.nativeToLittle(u16, self.header.bits_per_sample)));

        try self.file.?.writeAll(&self.header.data_id);
        try self.file.?.writeAll(std.mem.asBytes(&std.mem.nativeToLittle(u32, self.header.data_size)));
    }

    pub fn getDurationSeconds(self: *Self) f64 {
        if (self.samples_written == 0) return 0.0;
        return @as(f64, @floatFromInt(self.samples_written)) /
            @as(f64, @floatFromInt(self.header.sample_rate * self.header.num_channels));
    }

    pub fn getSamplesWritten(self: *Self) u32 {
        return self.samples_written;
    }
};

// Utility functions for WAV format validation
pub fn isValidSampleRate(sample_rate: u32) bool {
    // Common sample rates supported by most systems and APIs
    const valid_rates = [_]u32{ 8000, 11025, 16000, 22050, 44100, 48000, 96000 };
    for (valid_rates) |rate| {
        if (sample_rate == rate) return true;
    }
    return false;
}

pub fn isValidChannelCount(channels: u16) bool {
    return channels >= 1 and channels <= 2; // Mono or stereo
}

pub fn isValidBitsPerSample(bits: u16) bool {
    return bits == 8 or bits == 16 or bits == 24 or bits == 32;
}

// Tests
test "wav header size" {
    // Ensure WAV header is the expected size (44 bytes)
    try std.testing.expect(@sizeOf(WavHeader) == 44);
}

test "wav writer creation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var writer = try WavWriter.init(allocator, "/tmp/test.wav", 44100, 1, 16);
    defer writer.deinit();

    try std.testing.expect(writer.header.sample_rate == 44100);
    try std.testing.expect(writer.header.num_channels == 1);
    try std.testing.expect(writer.header.bits_per_sample == 16);
}
