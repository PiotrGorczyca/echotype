const std = @import("std");
const hotkey = @import("hotkey");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🔥 Hotkey Detection Test\n", .{});
    std.debug.print("========================\n", .{});

    var handler = hotkey.HotkeyHandler.init(allocator);
    defer handler.deinit();

    // Test different hotkey combinations
    const test_hotkeys = [_][]const u8{
        "Ctrl+Shift+S", // Default (might conflict)
        "Ctrl+Alt+F12", // Less common
        "Super+F", // Might work
        "Ctrl+Shift+F11", // Very uncommon
    };

    for (test_hotkeys) |hotkey_combo| {
        std.debug.print("Testing hotkey: {s}\n", .{hotkey_combo});
        handler.registerHotkey(hotkey_combo) catch |err| {
            std.debug.print("  Failed to register: {}\n", .{err});
            continue;
        };
    }

    // Test cursor position
    if (handler.getCursorPosition()) |pos| {
        std.debug.print("Current cursor position: ({}, {})\n", .{ pos.x, pos.y });
    } else |err| {
        std.debug.print("Failed to get cursor position: {}\n", .{err});
    }

    std.debug.print("\nPress any registered hotkey (Ctrl+C to quit)...\n", .{});

    // Main loop - check for hotkeys
    var counter: u32 = 0;
    while (true) {
        if (handler.isHotkeyPressed()) {
            std.debug.print("🎯 Hotkey pressed! (detection #{})\n", .{counter + 1});
            counter += 1;

            // Get cursor position when hotkey is pressed
            if (handler.getCursorPosition()) |pos| {
                std.debug.print("   Cursor at: ({}, {})\n", .{ pos.x, pos.y });
            } else |err| {
                std.debug.print("   Could not get cursor position: {}\n", .{err});
            }
        }

        // Small delay to prevent excessive CPU usage
        std.time.sleep(10_000_000); // 10ms
    }
}
