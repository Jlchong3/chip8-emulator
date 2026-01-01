const std = @import("std");
const mem = std.mem;
const Input = @import("Input.zig");

pub const fb_width = 64;
pub const fb_height = 32;

const sprite_start = 0x50;
const rom_start = 0x200;
const Self = @This();

memory: [4096]u8,
V: [16]u8,
I: u16,
frame_buffer: [fb_width * fb_height]u8,
delay_timer: u8,
sound_timer: u8,
PC: u16,
stack: [16]u16,
SP: u8,

const Opcode = struct {
    opcode: u16,

    pub fn prefix(self: @This()) u4 {
        return @truncate(self.opcode >> 0xC);
    }

    pub fn nnn(self: @This()) u12 {
        return @truncate(self.opcode & 0x0FFF);
    }
    pub fn n(self: @This()) u4 {
        return @truncate(self.opcode & 0x000F);
    }
    pub fn x(self: @This()) u4 {
        return @truncate((self.opcode & 0x0F00) >> 0x8);
    }
    pub fn y(self: @This()) u4 {
        return @truncate((self.opcode & 0x00F0) >> 0x4);
    }
    pub fn kk(self: @This()) u8 {
        return @truncate(self.opcode & 0x00FF);
    }
};

pub fn init() Self {
    var memory = [_]u8{0} ** 4096;
    loadSprites(&memory);

    return .{
        .memory = memory,
        .V = [_]u8{0} ** 16,
        .I = 0x0,
        .frame_buffer = [_]u8{0} ** (fb_width * fb_height),
        .delay_timer = 0x0,
        .sound_timer = 0x0,
        .PC = rom_start,
        .stack = [_]u16{0} ** 16,
        .SP = 0,
    };
}

pub fn reset(self: *Self) void {
    @memset(self.memory[rom_start..], 0);
    self.V = [_]u8{0} ** 16;
    self.I = 0x0;
    self.frame_buffer = [_]u8{0} ** (fb_width * fb_height);
    self.delay_timer = 0x0;
    self.sound_timer = 0x0;
    self.PC = rom_start;
    self.stack = [_]u16{0} ** 16;
    self.SP = 0;
}

pub fn loadRom(self: *Self, path: []const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = (try file.stat()).size;

    if (file_size == 0) return error.EmptyROM;
    if (file_size > self.memory[rom_start..].len) return error.ROMTooLarge;

    var buf = [_]u8{0} ** 256;
    var reader = file.reader(&buf);
    reader.interface.readSliceAll(self.memory[rom_start..]) catch |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    };

    std.log.debug("ROM loaded successfully!", .{});
}

pub fn decrementTimers(self: *Self) void {
    if (self.delay_timer > 0) self.delay_timer -= 1;
    if (self.sound_timer > 0) self.sound_timer -= 1;
}

fn fetch(self: *Self) Opcode {
    const optcode = mem.readInt(u16, self.memory[self.PC..][0..2], .big);
    self.PC += 2;
    return .{ .opcode = optcode };
}

fn decodeAndExecute(self: *Self, instruction: Opcode, input: *const Input) void {
    switch (instruction.prefix()) {
        0x0 => {
            switch (instruction.opcode) {
                0x00E0 => {
                    @memset(&self.frame_buffer, 0);
                },
                0x00EE => self.PC = self.pop(),
                else => {
                    std.debug.print("Unknown Opcode: {X:0>4}\n", .{instruction.opcode});
                },
            }
        },

        0x1 => self.PC = instruction.nnn(),

        0x2 => {
            self.push(self.PC);
            self.PC = instruction.nnn();
        },

        0x3 => {
            if (self.V[instruction.x()] == instruction.kk())
                self.PC += 2;
        },

        0x4 => {
            if (self.V[instruction.x()] != instruction.kk())
                self.PC += 2;
        },

        0x5 => {
            if (self.V[instruction.x()] == self.V[instruction.y()])
                self.PC += 2;
        },

        0x6 => self.V[instruction.x()] = instruction.kk(),
        0x7 => self.V[instruction.x()] +%= instruction.kk(),

        0x8 => {
            const x = instruction.x();
            const y = instruction.y();

            switch (instruction.n()) {
                0x0 => self.V[x] = self.V[y],
                0x1 => self.V[x] |= self.V[y],
                0x2 => self.V[x] &= self.V[y],
                0x3 => self.V[x] ^= self.V[y],
                0x4 => {
                    self.V[x], self.V[0xF] = @addWithOverflow(self.V[x], self.V[y]);
                },
                0x5 => {
                    self.V[x], const borrow = @subWithOverflow(self.V[x], self.V[y]);
                    self.V[0xF] = if (borrow == 0) 1 else 0;
                },
                0x6 => {
                    self.V[0xF] = self.V[x] & 0x1;
                    self.V[x] >>= 1;
                },
                0x7 => {
                    self.V[x], const borrow = @subWithOverflow(self.V[y], self.V[x]);
                    self.V[0xF] = if (borrow == 0) 1 else 0;
                },
                0xE => {
                    self.V[0xF] = (self.V[x] & 0x80) >> 7;
                    self.V[x] <<= 1;
                },
                else => {},
            }
        },

        0x9 => {
            if (self.V[instruction.x()] != self.V[instruction.y()])
                self.PC += 2;
        },

        0xA => self.I = instruction.nnn(),

        0xB => self.PC = instruction.nnn() + self.V[0],

        0xC => self.V[instruction.x()] = std.crypto.random.int(u8) & instruction.kk(),

        0xD => {
            const start_x = self.V[instruction.x()];
            const start_y = self.V[instruction.y()];

            const sprite = self.memory[self.I..][0..instruction.n()];

            self.V[0xF] = 0;

            for (sprite, 0..) |byte, row| {
                const y = (start_y + row) % fb_height;

                for (0..8) |offset| {
                    const x = (start_x + offset) % fb_width;

                    const sprite_pixel = (byte >> @intCast(7 - offset)) & 1;

                    const pixel_index = y * fb_width + x;

                    self.V[0xF] |= sprite_pixel & self.frame_buffer[pixel_index];
                    self.frame_buffer[pixel_index] ^= sprite_pixel;
                }
            }
        },

        0xE => {
            const x = instruction.x();
            switch (instruction.kk()) {
                0x9E => {
                    const key = self.V[x];
                    if (key <= 0xF and input.isKeyPressed(@intCast(key)))
                        self.PC += 2;
                },
                0xA1 => {
                    const key = self.V[x];
                    if (key > 0xF or !input.isKeyPressed(@intCast(key)))
                        self.PC += 2;
                },
                else => {},
            }
        },

        0xF => {
            const x = instruction.x();
            switch (instruction.kk()) {
                0x07 => self.V[x] = self.delay_timer,
                0x0A => {
                    if (input.getAnyReleasedKey()) |key| {
                        self.V[x] = key;
                    } else {
                        self.PC -= 2;
                    }
                },
                0x15 => self.delay_timer = self.V[x],
                0x18 => self.sound_timer = self.V[x],
                0x1E => self.I +%= self.V[x],
                0x29 => self.I = sprite_start + self.V[x] * 5,
                0x33 => {
                    const value = self.V[x];
                    self.memory[self.I] = value / 100;
                    self.memory[self.I + 1] = (value / 10) % 10;
                    self.memory[self.I + 2] = value % 10;
                },
                0x55 => {
                    for (0..instruction.x() + 1) |reg| {
                        self.memory[self.I + reg] = self.V[reg];
                    }
                },
                0x65 => {
                    for (0..instruction.x() + 1) |reg| {
                        self.V[reg] = self.memory[self.I + reg];
                    }
                },
                else => {
                    std.debug.print("Unknown Opcode: {X:0>4}\n", .{instruction.opcode});
                },
            }
        },
    }
}

pub fn cycle(self: *Self, input: *const Input) void {
    const instruction = self.fetch();
    self.decodeAndExecute(instruction, input);
}

fn loadSprites(memory: []u8) void {
    const sprites = [_]u8{
        0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
        0x20, 0x60, 0x20, 0x20, 0x70, // 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
        0x90, 0x90, 0xF0, 0x10, 0x10, // 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
        0xF0, 0x10, 0x20, 0x40, 0x40, // 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, // A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
        0xF0, 0x80, 0x80, 0x80, 0xF0, // C
        0xE0, 0x90, 0x90, 0x90, 0xE0, // D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
        0xF0, 0x80, 0xF0, 0x80, 0x80, // F
    };
    @memcpy(memory[sprite_start..][0..sprites.len], &sprites);
}

fn push(self: *Self, value: u16) void {
    if (self.SP >= self.stack.len) {
        @panic("Stack overflow! Maximum 16 levels of nesting exceeded.");
    }

    self.stack[self.SP] = value;
    self.SP += 1;
}

fn pop(self: *Self) u16 {
    if (self.SP == 0) {
        @panic("Stack underflow! Attempted to return with empty call stack.");
    }

    self.SP -= 1;
    return self.stack[self.SP];
}
