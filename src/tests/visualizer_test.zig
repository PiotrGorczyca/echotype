const std = @import("std");
const visualizer = @import("visualizer");
const VisualizerState = visualizer.VisualizerState;

pub fn main() !void {
    std.debug.print("Visualizer Test - Testing different states near cursor\n", .{});
    std.debug.print("Move your mouse and watch for the indicator!\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var vis = visualizer.Visualizer.init(allocator);
    defer vis.deinit();

    // Test sequence: Recording -> Transcribing -> Finished -> Hide
    std.debug.print("Showing Recording state...\n", .{});
    try vis.showNearCursor(); // This starts in recording state
    std.time.sleep(2_000_000_000); // 2 seconds

    std.debug.print("Switching to Transcribing state...\n", .{});
    try vis.setState(.transcribing);
    std.time.sleep(2_000_000_000); // 2 seconds

    std.debug.print("Switching to Finished state...\n", .{});
    try vis.setState(.finished);
    std.time.sleep(3_000_000_000); // 3 seconds

    std.debug.print("Hiding visualizer...\n", .{});
    vis.hide();

    std.debug.print("Test completed!\n", .{});
}
