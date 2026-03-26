const Self = @This();

keys: [16]bool,
prev_keys: [16]bool,

pub fn init() Self {
    return .{
        .keys = [_]bool{false} ** 16,
        .prev_keys = [_]bool{false} ** 16,
    };
}

pub fn tick(self: *Self) void {
    self.prev_keys = self.keys;
}

pub fn pressKey(self: *Self, key: u4) void {
    self.keys[key] = true;
}

pub fn releaseKey(self: *Self, key: u4) void {
    self.keys[key] = false;
}

pub fn isKeyPressed(self: Self, key: u4) bool {
    return self.keys[key];
}

pub fn getAnyReleasedKey(self: Self) ?u4 {
    for (self.keys, self.prev_keys, 0..) |current, previous, i| {
        if (!current and previous) {
            return @intCast(i);
        }
    }
    return null;
}
