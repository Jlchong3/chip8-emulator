const glfw = @import("zglfw");

const Self = @This();

keys: [16]bool,
prev_keys: [16]bool,

pub fn init() Self {
    return .{
        .keys = [_]bool{false} ** 16,
        .prev_keys = [_]bool{false} ** 16,
    };
}

pub fn update(self: *Self, window: *glfw.Window) void {
    if (window.getAttribute(.focused) == false) {
        @memset(&self.keys, false);
        return;
    }

    self.prev_keys = self.keys;

    self.keys[0x1] = window.getKey(.one) == .press;
    self.keys[0x2] = window.getKey(.two) == .press;
    self.keys[0x3] = window.getKey(.three) == .press;
    self.keys[0xC] = window.getKey(.four) == .press;

    self.keys[0x4] = window.getKey(.q) == .press;
    self.keys[0x5] = window.getKey(.w) == .press;
    self.keys[0x6] = window.getKey(.e) == .press;
    self.keys[0xD] = window.getKey(.r) == .press;

    self.keys[0x7] = window.getKey(.a) == .press;
    self.keys[0x8] = window.getKey(.s) == .press;
    self.keys[0x9] = window.getKey(.d) == .press;
    self.keys[0xE] = window.getKey(.f) == .press;

    self.keys[0xA] = window.getKey(.z) == .press;
    self.keys[0x0] = window.getKey(.x) == .press;
    self.keys[0xB] = window.getKey(.c) == .press;
    self.keys[0xF] = window.getKey(.v) == .press;
}

pub fn isKeyPressed(self: Self, key: u4) bool {
    return self.keys[key];
}

pub fn getAnyReleasedKey(self: Self) ?u4 {
    for (self.keys, self.prev_keys, 0..) |current, previous, i| {
        if (!current and previous) { // Was pressed, now released
            return @intCast(i);
        }
    }
    return null;
}

pub fn getAnyPressedKey(self: Self) ?u4 {
    for (self.keys, 0..) |pressed, i| {
        if (pressed) return @intCast(i);
    }
    return null;
}
