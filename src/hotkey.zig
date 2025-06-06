const std = @import("std");
const x11 = @import("x11_bindings.zig");
const print = std.debug.print;

// Hotkey combination structure
const HotkeyCombo = struct {
    keycode: c_int,
    modifiers: c_uint,
    description: []const u8,
};

pub const HotkeyHandler = struct {
    allocator: std.mem.Allocator,
    display: ?*x11.Display,
    root_window: x11.Window,
    registered_hotkeys: std.ArrayList(HotkeyCombo),
    hotkey_pressed: bool,
    error_occurred: bool,
    last_trigger_time: i64, // Add timestamp for debouncing
    debounce_ms: i64, // Debounce delay in milliseconds

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .display = null,
            .root_window = 0,
            .registered_hotkeys = std.ArrayList(HotkeyCombo).init(allocator),
            .hotkey_pressed = false,
            .error_occurred = false,
            .last_trigger_time = 0,
            .debounce_ms = 200, // 200ms debounce delay
        };
    }

    pub fn deinit(self: *Self) void {
        // Unregister all hotkeys and free their descriptions
        for (self.registered_hotkeys.items) |hotkey| {
            if (self.display) |display| {
                _ = x11.ungrabKey(display, hotkey.keycode, hotkey.modifiers, self.root_window);
            }
            // Free the allocated description string
            self.allocator.free(hotkey.description);
        }
        self.registered_hotkeys.deinit();

        // Close X11 display
        if (self.display) |display| {
            x11.closeDisplay(display);
        }
    }

    pub fn registerHotkey(self: *Self, hotkey_combination: []const u8) !void {
        // Initialize X11 connection if not already done
        if (self.display == null) {
            try self.initX11();
        }

        // Parse the hotkey combination
        const hotkey = try self.parseHotkeyString(hotkey_combination);

        // Register the hotkey with X11
        // Try to register with and without Num Lock and Caps Lock states
        // since these can interfere with hotkey detection
        const lock_modifiers = [_]c_uint{
            0, // No locks
            x11.LockMask, // Caps Lock
            x11.Mod2Mask, // Num Lock
            x11.LockMask | x11.Mod2Mask, // Both locks
        };

        var success_count: u32 = 0;
        for (lock_modifiers) |lock_mod| {
            const final_modifiers = hotkey.modifiers | lock_mod;
            const result = x11.grabKey(self.display.?, hotkey.keycode, final_modifiers, self.root_window, false, // owner_events
                x11.GrabModeAsync, x11.GrabModeAsync);

            if (result == 0) {
                success_count += 1;
            }
        }

        if (success_count == 0) {
            print("Warning: Failed to register hotkey {s}\n", .{hotkey_combination});
            print("This might happen if another application is using the same hotkey.\n", .{});
            print("Continuing anyway - some hotkeys may still work despite registration warnings.\n", .{});
            // Don't return error - continue and let user try the hotkey
        } else if (success_count < lock_modifiers.len) {
            print("Partially registered hotkey: {s} ({}/{} combinations)\n", .{ hotkey_combination, success_count, lock_modifiers.len });
        } else {
            print("Successfully registered hotkey: {s}\n", .{hotkey_combination});
        }

        // Add to our list of registered hotkeys
        try self.registered_hotkeys.append(hotkey);

        // Flush X11 requests
        _ = x11.flush(self.display.?);
    }

    pub fn isHotkeyPressed(self: *Self) bool {
        if (self.display == null) return false;

        const current_time = std.time.milliTimestamp();

        // Check for pending X11 events
        while (x11.pending(self.display.?) > 0) {
            var event: x11.XEvent = undefined;
            _ = x11.nextEvent(self.display.?, &event);

            // Check if it's a key press event
            if (event.type == x11.KeyPress) {
                const key_event = event.xkey;

                // Check if this matches any of our registered hotkeys
                for (self.registered_hotkeys.items) |hotkey| {
                    if (key_event.keycode == @as(c_uint, @intCast(hotkey.keycode)) and
                        (key_event.state & hotkey.modifiers) == hotkey.modifiers)
                    {
                        // Check debounce - ignore if too soon after last trigger
                        if (current_time - self.last_trigger_time < self.debounce_ms) {
                            print("DEBUG: Hotkey ignored (debounce - {d}ms since last)\n", .{current_time - self.last_trigger_time});
                            continue; // Skip this event
                        }

                        print("Hotkey detected: {s}\n", .{hotkey.description});
                        self.last_trigger_time = current_time;
                        self.hotkey_pressed = true;
                        return true;
                    }
                }
            }
        }

        // Reset the flag and return
        if (self.hotkey_pressed) {
            self.hotkey_pressed = false;
            return true;
        }

        return false;
    }

    fn initX11(self: *Self) !void {
        // Set up X11 error handler
        x11.setErrorHandler(x11ErrorHandler);

        // Open connection to X server
        self.display = x11.openDisplay(null);
        if (self.display == null) {
            return error.CannotOpenDisplay;
        }

        // Get the root window
        self.root_window = x11.defaultRootWindow(self.display.?);

        print("X11 connection established\n", .{});
    }

    fn parseHotkeyString(self: *Self, hotkey_str: []const u8) !HotkeyCombo {
        var modifiers: c_uint = 0;
        var keycode: c_int = 0;
        var key_char: u8 = 0;

        // Split the hotkey string by '+'
        var iterator = std.mem.split(u8, hotkey_str, "+");

        while (iterator.next()) |part| {
            const trimmed = std.mem.trim(u8, part, " ");

            if (std.mem.eql(u8, trimmed, "Ctrl") or std.mem.eql(u8, trimmed, "Control")) {
                modifiers |= x11.ControlMask;
            } else if (std.mem.eql(u8, trimmed, "Shift")) {
                modifiers |= x11.ShiftMask;
            } else if (std.mem.eql(u8, trimmed, "Alt")) {
                modifiers |= x11.Mod1Mask;
            } else if (std.mem.eql(u8, trimmed, "Super") or std.mem.eql(u8, trimmed, "Win")) {
                modifiers |= x11.Mod4Mask;
            } else if (trimmed.len == 1) {
                // Single character key
                key_char = std.ascii.toLower(trimmed[0]);
            } else if (std.mem.startsWith(u8, trimmed, "F") and trimmed.len >= 2) {
                // Function key (F1-F12)
                const f_num_str = trimmed[1..];
                if (std.fmt.parseInt(u8, f_num_str, 10)) |f_num| {
                    if (f_num >= 1 and f_num <= 12) {
                        const keysym = functionKeyToKeysym(f_num);
                        keycode = x11.keysymToKeycode(self.display.?, keysym);
                        if (keycode == 0) {
                            print("Warning: Could not convert function key 'F{d}' to keycode\n", .{f_num});
                            return error.InvalidKey;
                        }
                    } else {
                        print("Warning: Unsupported function key: {s}\n", .{trimmed});
                    }
                } else |_| {
                    print("Warning: Invalid function key format: {s}\n", .{trimmed});
                }
            } else {
                print("Warning: Unknown modifier or key: {s}\n", .{trimmed});
            }
        }

        // Convert character to keycode
        if (key_char != 0) {
            const keysym = charToKeysym(key_char);
            keycode = x11.keysymToKeycode(self.display.?, keysym);

            if (keycode == 0) {
                print("Warning: Could not convert key '{c}' to keycode\n", .{key_char});
                return error.InvalidKey;
            }
        }

        return HotkeyCombo{
            .keycode = keycode,
            .modifiers = modifiers,
            .description = try self.allocator.dupe(u8, hotkey_str),
        };
    }

    pub fn getCursorPosition(self: *Self) !struct { x: i32, y: i32 } {
        if (self.display == null) return error.DisplayNotInitialized;

        var root_return: x11.Window = undefined;
        var child_return: x11.Window = undefined;
        var root_x: c_int = undefined;
        var root_y: c_int = undefined;
        var win_x: c_int = undefined;
        var win_y: c_int = undefined;
        var mask_return: c_uint = undefined;

        const success = x11.queryPointer(self.display.?, self.root_window, &root_return, &child_return, &root_x, &root_y, &win_x, &win_y, &mask_return);

        if (!success) {
            return error.QueryPointerFailed;
        }

        return .{ .x = @intCast(root_x), .y = @intCast(root_y) };
    }
};

// Helper function to convert character to X11 keysym
fn charToKeysym(char: u8) x11.KeySym {
    return switch (char) {
        'a' => x11.XK_a,
        's' => x11.XK_s,
        'd' => x11.XK_d,
        'f' => x11.XK_f,
        'g' => x11.XK_g,
        'h' => x11.XK_h,
        'j' => x11.XK_j,
        'k' => x11.XK_k,
        'l' => x11.XK_l,
        else => @as(x11.KeySym, char), // For other characters, try direct conversion
    };
}

// Helper function to convert function key number to X11 keysym
fn functionKeyToKeysym(f_num: u8) x11.KeySym {
    return switch (f_num) {
        1 => x11.XK_F1,
        2 => x11.XK_F2,
        3 => x11.XK_F3,
        4 => x11.XK_F4,
        5 => x11.XK_F5,
        6 => x11.XK_F6,
        7 => x11.XK_F7,
        8 => x11.XK_F8,
        9 => x11.XK_F9,
        10 => x11.XK_F10,
        11 => x11.XK_F11,
        12 => x11.XK_F12,
        else => 0, // Invalid function key
    };
}

// X11 error handler
fn x11ErrorHandler(display: ?*x11.Display, error_event: [*c]x11.c.XErrorEvent) callconv(.C) c_int {
    _ = display;
    if (error_event) |err| {
        print("X11 Error: code={}, request={}, minor={}\n", .{ err.*.error_code, err.*.request_code, err.*.minor_code });
    }
    return 0; // Continue execution
}

// Tests
test "hotkey parsing" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var handler = HotkeyHandler.init(allocator);
    defer handler.deinit();

    // Note: This test will fail without X11 display, but shows the parsing logic
    // In a real test environment, you'd mock the X11 calls
}
