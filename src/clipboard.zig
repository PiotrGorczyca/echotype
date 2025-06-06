const std = @import("std");
const x11 = @import("x11_bindings.zig");

pub const ClipboardManager = struct {
    allocator: std.mem.Allocator,
    display: ?*x11.Display,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .display = null,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.display) |display| {
            _ = x11.XCloseDisplay(display);
        }
    }

    fn ensureDisplay(self: *Self) !void {
        if (self.display == null) {
            self.display = x11.XOpenDisplay(null);
            if (self.display == null) {
                return error.CannotOpenDisplay;
            }
        }
    }

    pub fn copyText(self: *Self, text: []const u8) !void {
        std.debug.print("Copying text to clipboard: {s}\n", .{text});

        // Use xclip for reliable clipboard operations
        var child = std.process.Child.init(&[_][]const u8{ "xclip", "-selection", "clipboard" }, self.allocator);
        child.stdin_behavior = .Pipe;
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;

        try child.spawn();

        // Write the text to xclip's stdin
        if (child.stdin) |stdin| {
            try stdin.writeAll(text);
            stdin.close();
            child.stdin = null;
        }

        // Wait for the process to complete
        const term = try child.wait();
        switch (term) {
            .Exited => |code| {
                if (code == 0) {
                    std.debug.print("Text copied to clipboard successfully\n", .{});
                } else {
                    std.debug.print("xclip exited with code: {}\n", .{code});
                    return error.ClipboardCopyFailed;
                }
            },
            else => {
                std.debug.print("xclip terminated unexpectedly\n", .{});
                return error.ClipboardCopyFailed;
            },
        }
    }

    pub fn pasteAtCursor(self: *Self) !void {
        std.debug.print("Pasting at cursor location\n", .{});

        try self.ensureDisplay();
        const display = self.display.?;

        // Use xdotool approach - simulate Ctrl+V
        // This is more reliable than XTest in many cases
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "xdotool", "key", "ctrl+v" },
        }) catch |err| {
            std.debug.print("Failed to execute xdotool: {}\n", .{err});

            // Fallback to XTest if xdotool is not available
            return self.pasteWithXTest(display);
        };

        if (result.term.Exited == 0) {
            std.debug.print("Pasted using xdotool\n", .{});
        } else {
            std.debug.print("xdotool failed, trying XTest fallback\n", .{});
            return self.pasteWithXTest(display);
        }
    }

    fn pasteWithXTest(self: *Self, display: *x11.Display) !void {
        _ = self;

        // Get the Control and V keycodes
        const ctrl_keycode = x11.XKeysymToKeycode(display, x11.XK_Control_L);
        const v_keycode = x11.XKeysymToKeycode(display, x11.XK_v);

        if (ctrl_keycode == 0 or v_keycode == 0) {
            return error.CannotGetKeycodes;
        }

        // Simulate Ctrl+V key press
        _ = x11.XTestFakeKeyEvent(display, ctrl_keycode, x11.True, 0); // Ctrl down
        _ = x11.XTestFakeKeyEvent(display, v_keycode, x11.True, 0); // V down
        _ = x11.XTestFakeKeyEvent(display, v_keycode, x11.False, 0); // V up
        _ = x11.XTestFakeKeyEvent(display, ctrl_keycode, x11.False, 0); // Ctrl up

        _ = x11.XFlush(display);
        std.debug.print("Pasted using XTest\n", .{});
    }
};
