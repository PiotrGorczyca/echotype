const std = @import("std");
const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xutil.h");
    @cInclude("X11/extensions/Xfixes.h");
    @cInclude("X11/extensions/Xrender.h");
});

pub const VisualizerState = enum {
    hidden,
    recording,
    transcribing,
    finished,
};

pub const Visualizer = struct {
    allocator: std.mem.Allocator,
    display: ?*c.Display,
    window: c.Window,
    gc: c.GC,
    is_visible: bool,
    current_state: VisualizerState,
    window_width: u32,
    window_height: u32,
    follow_cursor: bool,
    last_cursor_x: i32,
    last_cursor_y: i32,
    rotation_angle: f32,
    finished_start_time: ?i64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .display = null,
            .window = 0,
            .gc = undefined,
            .is_visible = false,
            .current_state = .hidden,
            .window_width = 40,
            .window_height = 40,
            .follow_cursor = false,
            .last_cursor_x = 0,
            .last_cursor_y = 0,
            .rotation_angle = 0.0,
            .finished_start_time = null,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.display != null) {
            _ = c.XFreeGC(self.display, self.gc);
            _ = c.XDestroyWindow(self.display, self.window);
            _ = c.XCloseDisplay(self.display);
        }
    }

    fn initX11(self: *Self) !void {
        if (self.display != null) return; // Already initialized

        self.display = c.XOpenDisplay(null);
        if (self.display == null) {
            return error.CannotOpenDisplay;
        }

        const screen = c.XDefaultScreen(self.display);
        const root = c.XRootWindow(self.display, screen);

        // Try to get ARGB visual for transparency
        var visual_info: c.XVisualInfo = undefined;
        var visual: ?*c.Visual = null;
        var depth: c_int = 32;

        // Try to find 32-bit ARGB visual
        var template = c.XVisualInfo{
            .visual = undefined,
            .visualid = 0,
            .screen = screen,
            .depth = 32,
            .class = c.TrueColor,
            .red_mask = 0,
            .green_mask = 0,
            .blue_mask = 0,
            .colormap_size = 0,
            .bits_per_rgb = 0,
        };

        var nitems: c_int = 0;
        const visuals = c.XGetVisualInfo(self.display, c.VisualScreenMask | c.VisualDepthMask | c.VisualClassMask, &template, &nitems);

        if (visuals != null and nitems > 0) {
            visual_info = visuals[0];
            visual = visual_info.visual;
            _ = c.XFree(visuals);
        } else {
            // Fallback to default visual
            visual = c.XDefaultVisual(self.display, screen);
            depth = c.XDefaultDepth(self.display, screen);
        }

        // Create colormap
        const colormap = c.XCreateColormap(self.display, root, visual, c.AllocNone);

        // Create a borderless, transparent window
        var attrs: c.XSetWindowAttributes = undefined;
        attrs.override_redirect = c.True;
        attrs.background_pixel = 0; // Transparent background
        attrs.border_pixel = 0;
        attrs.colormap = colormap;

        self.window = c.XCreateWindow(self.display, root, 0, 0, // x, y (will be set later)
            self.window_width, self.window_height, 0, // border width
            depth, c.InputOutput, visual, c.CWOverrideRedirect | c.CWBackPixel | c.CWBorderPixel | c.CWColormap, &attrs);

        // Create graphics context
        self.gc = c.XCreateGC(self.display, self.window, 0, null);

        // Set window to stay on top
        const atom_net_wm_state = c.XInternAtom(self.display, "_NET_WM_STATE", c.False);
        const atom_net_wm_state_above = c.XInternAtom(self.display, "_NET_WM_STATE_ABOVE", c.False);

        _ = c.XChangeProperty(self.display, self.window, atom_net_wm_state, 4, 32, c.PropModeReplace, @ptrCast(&atom_net_wm_state_above), 1);
    }

    fn getCursorPosition(self: *Self) !struct { x: i32, y: i32 } {
        var root: c.Window = undefined;
        var child: c.Window = undefined;
        var root_x: c_int = undefined;
        var root_y: c_int = undefined;
        var win_x: c_int = undefined;
        var win_y: c_int = undefined;
        var mask: c_uint = undefined;

        const result = c.XQueryPointer(self.display, c.XDefaultRootWindow(self.display), &root, &child, &root_x, &root_y, &win_x, &win_y, &mask);

        if (result == c.False) {
            return error.CannotGetCursorPosition;
        }

        return .{ .x = root_x, .y = root_y };
    }

    fn drawState(self: *Self) !void {
        if (self.display == null) return;

        // Clear the window
        _ = c.XClearWindow(self.display, self.window);

        const screen = c.XDefaultScreen(self.display);

        // Set colors based on state
        var color: c.XColor = undefined;
        const colormap = c.XDefaultColormap(self.display, screen);

        const color_name = switch (self.current_state) {
            .recording => "red",
            .transcribing => "orange",
            .finished => "green",
            .hidden => return,
        };

        if (c.XParseColor(self.display, colormap, color_name, &color) == 0) {
            // Fallback to white if color parsing fails
            color.pixel = c.XWhitePixel(self.display, screen);
        } else {
            _ = c.XAllocColor(self.display, colormap, &color);
        }

        _ = c.XSetForeground(self.display, self.gc, color.pixel);

        const center_x = @as(c_int, @intCast(self.window_width / 2));
        const center_y = @as(c_int, @intCast(self.window_height / 2));

        if (self.current_state == .finished) {
            // Draw checkmark
            _ = c.XSetLineAttributes(self.display, self.gc, 3, c.LineSolid, c.CapRound, c.JoinRound);

            // Checkmark coordinates (relative to center)
            const check_size = 12;
            const x1 = center_x - check_size;
            const y1 = center_y;
            const x2 = center_x - 4;
            const y2 = center_y + 8;
            const x3 = center_x + check_size;
            const y3 = center_y - 8;

            // Draw checkmark as two line segments
            _ = c.XDrawLine(self.display, self.window, self.gc, x1, y1, x2, y2);
            _ = c.XDrawLine(self.display, self.window, self.gc, x2, y2, x3, y3);
        } else {
            // Draw spinning arcs for recording/transcribing states
            _ = c.XSetLineAttributes(self.display, self.gc, 3, c.LineSolid, c.CapRound, c.JoinRound);

            const spinner_radius = 12;
            const arc_length = 90 * 64; // 90 degrees in X11 units (64ths of a degree)

            // Update rotation angle for animation
            self.rotation_angle += 5.0; // Slower rotation speed
            if (self.rotation_angle >= 360.0) {
                self.rotation_angle -= 360.0;
            }

            // Convert angle to X11 format (64ths of a degree)
            const start_angle = @as(c_int, @intFromFloat(self.rotation_angle * 64.0));

            // Draw spinning arc
            _ = c.XDrawArc(self.display, self.window, self.gc, center_x - spinner_radius, center_y - spinner_radius, spinner_radius * 2, spinner_radius * 2, start_angle, arc_length);

            // Draw a second arc for fuller spinner effect
            const second_start = start_angle + (180 * 64);
            _ = c.XDrawArc(self.display, self.window, self.gc, center_x - spinner_radius, center_y - spinner_radius, spinner_radius * 2, spinner_radius * 2, second_start, arc_length);
        }

        _ = c.XFlush(self.display);
    }

    pub fn showNearCursor(self: *Self) !void {
        try self.initX11();

        const pos = try self.getCursorPosition();

        // Position window near cursor (offset to avoid covering it) - moved higher
        const window_x = pos.x + 20;
        const window_y = pos.y - 10;

        _ = c.XMoveWindow(self.display, self.window, window_x, window_y);
        _ = c.XMapWindow(self.display, self.window);

        self.is_visible = true;
        self.current_state = .recording;
        self.follow_cursor = true;
        self.last_cursor_x = pos.x;
        self.last_cursor_y = pos.y;

        try self.drawState();
    }

    pub fn setState(self: *Self, state: VisualizerState) !void {
        if (!self.is_visible and state != .hidden) return;

        self.current_state = state;

        // Start timer for finished state
        if (state == .finished) {
            self.finished_start_time = std.time.milliTimestamp();
        } else {
            self.finished_start_time = null;
        }

        try self.drawState();
    }

    pub fn updatePosition(self: *Self) !void {
        if (!self.is_visible or !self.follow_cursor) return;

        const pos = self.getCursorPosition() catch return;

        // Only move if cursor has moved significantly (reduces flickering)
        const dx = @abs(pos.x - self.last_cursor_x);
        const dy = @abs(pos.y - self.last_cursor_y);

        if (dx > 5 or dy > 5) {
            const window_x = pos.x + 20;
            const window_y = pos.y - 10;

            _ = c.XMoveWindow(self.display, self.window, window_x, window_y);
            _ = c.XFlush(self.display);

            self.last_cursor_x = pos.x;
            self.last_cursor_y = pos.y;
        }
    }

    pub fn animate(self: *Self) !void {
        if (!self.is_visible or self.current_state == .hidden) {
            return;
        }

        // Check if finished state should be auto-hidden
        if (self.current_state == .finished and self.finished_start_time != null) {
            const elapsed = std.time.milliTimestamp() - self.finished_start_time.?;
            if (elapsed >= 3000) { // 3 seconds
                self.hide();
                return;
            }
        }

        // Redraw to update spinner animation (also for finished state to continue following cursor)
        try self.drawState();
    }

    pub fn hide(self: *Self) void {
        if (self.display != null and self.is_visible) {
            _ = c.XUnmapWindow(self.display, self.window);
            _ = c.XFlush(self.display);
        }
        self.is_visible = false;
        self.current_state = .hidden;
        self.follow_cursor = false;
    }
};
