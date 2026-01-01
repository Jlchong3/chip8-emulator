const std = @import("std");
const glfw = @import("zglfw");

const KeyState = struct {
    previous: bool = false,
    current: bool = false,

    pub fn isJustPressed(self: *KeyState, window: *glfw.Window, key: glfw.Key) bool {
        self.current = (window.getKey(key) == .press);
        const just_pressed = (self.current and !self.previous);
        self.previous = self.current;
        return just_pressed;
    }
};

pub const Action = union(enum) {
    Quit,
    Reset,
    SpeedUp,
    SpeedDown,
    VolumeUp,
    VolumeDown,
    None,
};

const Self = @This();

speed_up: KeyState = .{},
speed_down: KeyState = .{},
reset: KeyState = .{},

pub fn init() Self {
    return .{};
}

pub fn check(self: *Self, window: *glfw.Window) Action {
    if (window.getKey(.escape) == .press) {
        return .Quit;
    }
    if (self.reset.isJustPressed(window, .p)) {
        return .Reset;
    }
    if (self.speed_up.isJustPressed(window, .period)) {
        return .SpeedUp;
    }
    if (self.speed_down.isJustPressed(window, .comma)) {
        return .SpeedDown;
    }
    if (self.speed_down.isJustPressed(window, .right_bracket)) {
        return .VolumeUp;
    }
    if (self.speed_down.isJustPressed(window, .left_bracket)) {
        return .VolumeDown;
    }
    return .None;
}
