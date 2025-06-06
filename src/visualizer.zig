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

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .display = null,
            .window = 0,
            .gc = undefined,
            .is_visible = false,
            .current_state = .hidden,
            .window_width = 150,
            .window_height = 60,
            .follow_cursor = false,
            .last_cursor_x = 0,
            .last_cursor_y = 0,
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

        // Draw a filled circle
        const circle_size = 30;
        const circle_x = @as(c_int, @intCast((self.window_width - circle_size) / 2));
        const circle_y = 5;

        _ = c.XFillArc(self.display, self.window, self.gc, circle_x, circle_y, circle_size, circle_size, 0, 360 * 64 // X11 uses 64ths of a degree
        );

        // Draw text
        _ = c.XSetForeground(self.display, self.gc, c.XWhitePixel(self.display, screen));

        const text = switch (self.current_state) {
            .recording => "Recording...",
            .transcribing => "Transcribing...",
            .finished => "Ready to paste!",
            .hidden => "",
        };

        if (text.len > 0) {
            _ = c.XDrawString(self.display, self.window, self.gc, 10, 50, text.ptr, @intCast(text.len));
        }

        _ = c.XFlush(self.display);
    }

    pub fn showNearCursor(self: *Self) !void {
        try self.initX11();

        const pos = try self.getCursorPosition();

        // Position window near cursor (offset to avoid covering it)
        const window_x = pos.x + 20;
        const window_y = pos.y - 80;

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
            const window_y = pos.y - 80;

            _ = c.XMoveWindow(self.display, self.window, window_x, window_y);
            _ = c.XFlush(self.display);

            self.last_cursor_x = pos.x;
            self.last_cursor_y = pos.y;
        }
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
