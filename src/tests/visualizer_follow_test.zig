const std = @import("std");
const visualizer = @import("visualizer");
const VisualizerState = visualizer.VisualizerState;

pub fn main() !void {
    std.debug.print("Cursor Following Test - Move your mouse around!\n", .{});
    std.debug.print("The visualizer should follow your cursor for 10 seconds.\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var vis = visualizer.Visualizer.init(allocator);
    defer vis.deinit();

    // Show the visualizer and enable cursor following
    std.debug.print("Showing visualizer in Recording state - move your mouse!\n", .{});
    try vis.showNearCursor(); // This enables cursor following

    // Update position for 10 seconds
    const start_time = std.time.milliTimestamp();
    while (std.time.milliTimestamp() - start_time < 10000) { // 10 seconds
        try vis.updatePosition();
        std.time.sleep(16_000_000); // ~60 FPS updates
    }

    std.debug.print("Switching to Transcribing state...\n", .{});
    try vis.setState(.transcribing);

    // Continue following for another 5 seconds
    const mid_time = std.time.milliTimestamp();
    while (std.time.milliTimestamp() - mid_time < 5000) { // 5 seconds
        try vis.updatePosition();
        std.time.sleep(16_000_000); // ~60 FPS updates
    }

    std.debug.print("Switching to Finished state...\n", .{});
    try vis.setState(.finished);

    // Continue following for final 3 seconds
    const end_time = std.time.milliTimestamp();
    while (std.time.milliTimestamp() - end_time < 3000) { // 3 seconds
        try vis.updatePosition();
        std.time.sleep(16_000_000); // ~60 FPS updates
    }

    std.debug.print("Hiding visualizer...\n", .{});
    vis.hide();

    std.debug.print("Cursor following test completed!\n", .{});
}
