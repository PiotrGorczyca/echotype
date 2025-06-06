const std = @import("std");
const print = std.debug.print;

pub const Config = struct {
    allocator: std.mem.Allocator,
    openai_api_key: []const u8,
    hotkey_combination: []const u8,
    audio_device: []const u8,
    recording_duration_seconds: u32,
    whisper_model: []const u8,
    auto_paste_enabled: bool,
    visualization_enabled: bool,

    // Track what needs to be freed
    _allocated_api_key: bool = false,
    _allocated_hotkey: bool = false,
    _allocated_device: bool = false,
    _allocated_model: bool = false,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        var config = Self{
            .allocator = allocator,
            .openai_api_key = "",
            .hotkey_combination = "Ctrl+Shift+S",
            .audio_device = "default",
            .recording_duration_seconds = 5,
            .whisper_model = "whisper-1",
            .auto_paste_enabled = true,
            .visualization_enabled = true,
        };

        // Load configuration from environment variables and config files
        config.loadConfiguration() catch |err| {
            print("Warning: Failed to load configuration: {}\n", .{err});
            print("Using default configuration\n", .{});
        };

        return config;
    }

    pub fn deinit(self: *Self) void {
        // Free allocated strings based on tracking flags
        if (self._allocated_api_key) {
            self.allocator.free(self.openai_api_key);
        }
        if (self._allocated_hotkey) {
            self.allocator.free(self.hotkey_combination);
        }
        if (self._allocated_device) {
            self.allocator.free(self.audio_device);
        }
        if (self._allocated_model) {
            self.allocator.free(self.whisper_model);
        }
    }

    fn loadConfiguration(self: *Self) !void {
        // 1. Try to load from environment variables
        if (std.process.getEnvVarOwned(self.allocator, "OPENAI_API_KEY")) |api_key| {
            self.openai_api_key = api_key;
            self._allocated_api_key = true;
        } else |_| {
            // 2. Try to load from config file
            self.loadFromConfigFile() catch |err| {
                print("No OpenAI API key found in environment or config file\n", .{});
                print("Please set OPENAI_API_KEY environment variable\n", .{});
                return err;
            };
        }

        // Load other configuration from environment variables
        if (std.process.getEnvVarOwned(self.allocator, "ECHOTYPE_HOTKEY")) |hotkey| {
            self.hotkey_combination = hotkey;
            self._allocated_hotkey = true;
        } else |_| {}

        if (std.process.getEnvVarOwned(self.allocator, "ECHOTYPE_AUDIO_DEVICE")) |device| {
            self.audio_device = device;
            self._allocated_device = true;
        } else |_| {}

        if (std.process.getEnvVarOwned(self.allocator, "ECHOTYPE_DURATION")) |duration_str| {
            self.recording_duration_seconds = std.fmt.parseInt(u32, duration_str, 10) catch 5;
            self.allocator.free(duration_str);
        } else |_| {}

        if (std.process.getEnvVarOwned(self.allocator, "ECHOTYPE_WHISPER_MODEL")) |model| {
            self.whisper_model = model;
            self._allocated_model = true;
        } else |_| {}

        if (std.process.getEnvVarOwned(self.allocator, "ECHOTYPE_AUTO_PASTE")) |paste_str| {
            self.auto_paste_enabled = std.mem.eql(u8, paste_str, "true");
            self.allocator.free(paste_str);
        } else |_| {}

        if (std.process.getEnvVarOwned(self.allocator, "ECHOTYPE_VISUALIZATION")) |viz_str| {
            self.visualization_enabled = std.mem.eql(u8, viz_str, "true");
            self.allocator.free(viz_str);
        } else |_| {}
    }

    fn loadFromConfigFile(self: *Self) !void {
        // Try to load from ~/.config/echotype/config.json
        const home_dir = std.process.getEnvVarOwned(self.allocator, "HOME") catch {
            return error.NoHomeDirectory;
        };
        defer self.allocator.free(home_dir);

        const config_path = try std.fmt.allocPrint(self.allocator, "{s}/.config/echotype/config.json", .{home_dir});
        defer self.allocator.free(config_path);

        const config_file = std.fs.openFileAbsolute(config_path, .{}) catch {
            return error.ConfigFileNotFound;
        };
        defer config_file.close();

        const config_content = try config_file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(config_content);

        // Parse JSON configuration
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, config_content, .{}) catch {
            return error.InvalidConfigFile;
        };
        defer parsed.deinit();

        const root = parsed.value;

        // Extract configuration values
        if (root.object.get("openai_api_key")) |api_key_value| {
            if (api_key_value == .string) {
                self.openai_api_key = try self.allocator.dupe(u8, api_key_value.string);
                self._allocated_api_key = true;
            }
        }

        if (root.object.get("hotkey_combination")) |hotkey_value| {
            if (hotkey_value == .string) {
                self.hotkey_combination = try self.allocator.dupe(u8, hotkey_value.string);
                self._allocated_hotkey = true;
            }
        }

        if (root.object.get("audio_device")) |device_value| {
            if (device_value == .string) {
                self.audio_device = try self.allocator.dupe(u8, device_value.string);
                self._allocated_device = true;
            }
        }

        if (root.object.get("recording_duration_seconds")) |duration_value| {
            if (duration_value == .integer) {
                self.recording_duration_seconds = @intCast(duration_value.integer);
            }
        }

        if (root.object.get("whisper_model")) |model_value| {
            if (model_value == .string) {
                self.whisper_model = try self.allocator.dupe(u8, model_value.string);
                self._allocated_model = true;
            }
        }

        if (root.object.get("auto_paste_enabled")) |paste_value| {
            if (paste_value == .bool) {
                self.auto_paste_enabled = paste_value.bool;
            }
        }

        if (root.object.get("visualization_enabled")) |viz_value| {
            if (viz_value == .bool) {
                self.visualization_enabled = viz_value.bool;
            }
        }
    }

    pub fn saveToConfigFile(self: *Self) !void {
        // Create config directory if it doesn't exist
        const home_dir = std.process.getEnvVarOwned(self.allocator, "HOME") catch {
            return error.NoHomeDirectory;
        };
        defer self.allocator.free(home_dir);

        const config_dir = try std.fmt.allocPrint(self.allocator, "{s}/.config/echotype", .{home_dir});
        defer self.allocator.free(config_dir);

        std.fs.makeDirAbsolute(config_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

        const config_path = try std.fmt.allocPrint(self.allocator, "{s}/config.json", .{config_dir});
        defer self.allocator.free(config_path);

        // Create JSON configuration
        const config_json = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\  "openai_api_key": "{s}",
            \\  "hotkey_combination": "{s}",
            \\  "audio_device": "{s}",
            \\  "recording_duration_seconds": {d},
            \\  "whisper_model": "{s}",
            \\  "auto_paste_enabled": {s},
            \\  "visualization_enabled": {s}
            \\}}
        , .{
            self.openai_api_key,
            self.hotkey_combination,
            self.audio_device,
            self.recording_duration_seconds,
            self.whisper_model,
            if (self.auto_paste_enabled) "true" else "false",
            if (self.visualization_enabled) "true" else "false",
        });
        defer self.allocator.free(config_json);

        // Write to file
        const config_file = try std.fs.createFileAbsolute(config_path, .{});
        defer config_file.close();

        try config_file.writeAll(config_json);
    }

    pub fn validateConfiguration(self: *Self) !void {
        if (self.openai_api_key.len == 0) {
            return error.MissingAPIKey;
        }

        if (self.recording_duration_seconds == 0 or self.recording_duration_seconds > 60) {
            return error.InvalidRecordingDuration;
        }
    }

    pub fn printConfiguration(self: *Self) void {
        print("Configuration:\n", .{});
        print("  Hotkey: {s}\n", .{self.hotkey_combination});
        print("  Audio Device: {s}\n", .{self.audio_device});
        print("  Recording Duration: {d} seconds\n", .{self.recording_duration_seconds});
        print("  Whisper Model: {s}\n", .{self.whisper_model});
        print("  Auto-paste: {s}\n", .{if (self.auto_paste_enabled) "enabled" else "disabled"});
        print("  Visualization: {s}\n", .{if (self.visualization_enabled) "enabled" else "disabled"});
        print("  API Key: {s}\n", .{if (self.openai_api_key.len > 0) "configured" else "missing"});
    }
};

// Tests
test "config creation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var config = Config.init(allocator);
    defer config.deinit();

    try std.testing.expect(std.mem.eql(u8, config.hotkey_combination, "Ctrl+Shift+S"));
    try std.testing.expect(config.recording_duration_seconds == 5);
    try std.testing.expect(config.auto_paste_enabled == true);
}
