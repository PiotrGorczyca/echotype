const std = @import("std");

// X11 C library bindings
pub const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/keysym.h");
    @cInclude("X11/extensions/XTest.h");
    @cInclude("X11/Xutil.h");
});

// Type aliases for cleaner code
pub const Display = c.Display;
pub const Window = c.Window;
pub const XEvent = c.XEvent;
pub const KeySym = c.KeySym;
pub const Atom = c.Atom;
pub const XSelectionRequestEvent = c.XSelectionRequestEvent;
pub const XSelectionEvent = c.XSelectionEvent;

// Key modifier masks
pub const ShiftMask = c.ShiftMask;
pub const LockMask = c.LockMask;
pub const ControlMask = c.ControlMask;
pub const Mod1Mask = c.Mod1Mask; // Alt
pub const Mod2Mask = c.Mod2Mask;
pub const Mod3Mask = c.Mod3Mask;
pub const Mod4Mask = c.Mod4Mask; // Super/Windows key
pub const Mod5Mask = c.Mod5Mask;

// Event types
pub const KeyPress = c.KeyPress;
pub const KeyRelease = c.KeyRelease;
pub const SelectionRequest = c.SelectionRequest;
pub const SelectionNotify = c.SelectionNotify;

// Key symbols we care about
pub const XK_Control_L = c.XK_Control_L;
pub const XK_Control_R = c.XK_Control_R;
pub const XK_Shift_L = c.XK_Shift_L;
pub const XK_Shift_R = c.XK_Shift_R;
pub const XK_Alt_L = c.XK_Alt_L;
pub const XK_Alt_R = c.XK_Alt_R;
pub const XK_Super_L = c.XK_Super_L;
pub const XK_Super_R = c.XK_Super_R;

// Letters for hotkey combinations
pub const XK_a = c.XK_a;
pub const XK_s = c.XK_s;
pub const XK_d = c.XK_d;
pub const XK_f = c.XK_f;
pub const XK_g = c.XK_g;
pub const XK_h = c.XK_h;
pub const XK_j = c.XK_j;
pub const XK_k = c.XK_k;
pub const XK_l = c.XK_l;
pub const XK_v = c.XK_v;

// Function keys
pub const XK_F1 = c.XK_F1;
pub const XK_F2 = c.XK_F2;
pub const XK_F3 = c.XK_F3;
pub const XK_F4 = c.XK_F4;
pub const XK_F5 = c.XK_F5;
pub const XK_F6 = c.XK_F6;
pub const XK_F7 = c.XK_F7;
pub const XK_F8 = c.XK_F8;
pub const XK_F9 = c.XK_F9;
pub const XK_F10 = c.XK_F10;
pub const XK_F11 = c.XK_F11;
pub const XK_F12 = c.XK_F12;

// Wrapper functions for X11 API
pub fn openDisplay(display_name: ?[*:0]const u8) ?*Display {
    return c.XOpenDisplay(display_name);
}

pub fn closeDisplay(display: *Display) void {
    _ = c.XCloseDisplay(display);
}

pub fn defaultRootWindow(display: *Display) Window {
    return c.DefaultRootWindow(display);
}

pub fn grabKey(
    display: *Display,
    keycode: c_int,
    modifiers: c_uint,
    grab_window: Window,
    owner_events: bool,
    pointer_mode: c_int,
    keyboard_mode: c_int,
) c_int {
    return c.XGrabKey(
        display,
        keycode,
        modifiers,
        grab_window,
        if (owner_events) c.True else c.False,
        pointer_mode,
        keyboard_mode,
    );
}

pub fn ungrabKey(
    display: *Display,
    keycode: c_int,
    modifiers: c_uint,
    grab_window: Window,
) c_int {
    return c.XUngrabKey(display, keycode, modifiers, grab_window);
}

pub fn keysymToKeycode(display: *Display, keysym: KeySym) c_int {
    return c.XKeysymToKeycode(display, keysym);
}

pub fn pending(display: *Display) c_int {
    return c.XPending(display);
}

pub fn nextEvent(display: *Display, event: *XEvent) c_int {
    return c.XNextEvent(display, event);
}

pub fn queryPointer(
    display: *Display,
    w: Window,
    root_return: *Window,
    child_return: *Window,
    root_x_return: *c_int,
    root_y_return: *c_int,
    win_x_return: *c_int,
    win_y_return: *c_int,
    mask_return: *c_uint,
) bool {
    return c.XQueryPointer(
        display,
        w,
        root_return,
        child_return,
        root_x_return,
        root_y_return,
        win_x_return,
        win_y_return,
        mask_return,
    ) == c.True;
}

pub fn flush(display: *Display) c_int {
    return c.XFlush(display);
}

pub fn sync(display: *Display, discard: bool) c_int {
    return c.XSync(display, if (discard) c.True else c.False);
}

// Constants for grab modes
pub const GrabModeSync = c.GrabModeSync;
pub const GrabModeAsync = c.GrabModeAsync;

// X11 error handling
pub fn setErrorHandler(handler: ?*const fn (?*Display, [*c]c.XErrorEvent) callconv(.C) c_int) void {
    _ = c.XSetErrorHandler(handler);
}

// Constants
pub const None = c.None;
pub const True = c.True;
pub const False = c.False;
pub const CurrentTime = c.CurrentTime;
pub const PropModeReplace = c.PropModeReplace;
pub const SelectionRequestMask = @as(c_long, 1) << 30;
pub const XA_STRING = @as(c_ulong, 31);

// Additional X11 functions for clipboard and window management
pub fn XOpenDisplay(display_name: ?[*:0]const u8) ?*Display {
    return c.XOpenDisplay(display_name);
}

pub fn XCloseDisplay(display: *Display) c_int {
    return c.XCloseDisplay(display);
}

pub fn XDefaultScreen(display: *Display) c_int {
    return c.XDefaultScreen(display);
}

pub fn XRootWindow(display: *Display, screen_number: c_int) Window {
    return c.XRootWindow(display, screen_number);
}

pub fn XBlackPixel(display: *Display, screen_number: c_int) c_ulong {
    return c.XBlackPixel(display, screen_number);
}

pub fn XWhitePixel(display: *Display, screen_number: c_int) c_ulong {
    return c.XWhitePixel(display, screen_number);
}

pub fn XCreateSimpleWindow(
    display: *Display,
    parent: Window,
    x: c_int,
    y: c_int,
    width: c_uint,
    height: c_uint,
    border_width: c_uint,
    border: c_ulong,
    background: c_ulong,
) Window {
    return c.XCreateSimpleWindow(display, parent, x, y, width, height, border_width, border, background);
}

pub fn XDestroyWindow(display: *Display, w: Window) c_int {
    return c.XDestroyWindow(display, w);
}

pub fn XInternAtom(display: *Display, atom_name: [*:0]const u8, only_if_exists: c_int) Atom {
    return c.XInternAtom(display, atom_name, only_if_exists);
}

pub fn XChangeProperty(
    display: *Display,
    w: Window,
    property: Atom,
    type_: Atom,
    format: c_int,
    mode: c_int,
    data: [*]const u8,
    nelements: c_int,
) c_int {
    return c.XChangeProperty(display, w, property, type_, format, mode, data, nelements);
}

pub fn XSetSelectionOwner(display: *Display, selection: Atom, owner: Window, time: c_ulong) c_int {
    return c.XSetSelectionOwner(display, selection, owner, time);
}

pub fn XGetSelectionOwner(display: *Display, selection: Atom) Window {
    return c.XGetSelectionOwner(display, selection);
}

pub fn XCheckWindowEvent(display: *Display, w: Window, event_mask: c_long, event_return: *XEvent) c_int {
    return c.XCheckWindowEvent(display, w, event_mask, event_return);
}

pub fn XSendEvent(display: *Display, w: Window, propagate: c_int, event_mask: c_long, event_send: *XEvent) c_int {
    return c.XSendEvent(display, w, propagate, event_mask, event_send);
}

pub fn XFlush(display: *Display) c_int {
    return c.XFlush(display);
}

pub fn XKeysymToKeycode(display: *Display, keysym: KeySym) u8 {
    return c.XKeysymToKeycode(display, keysym);
}

pub fn XTestFakeKeyEvent(display: *Display, keycode: c_uint, is_press: c_int, delay: c_ulong) c_int {
    return c.XTestFakeKeyEvent(display, keycode, is_press, delay);
}
