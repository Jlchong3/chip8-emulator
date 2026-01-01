const std = @import("std");
const mem = std.mem;
const glfw = @import("zglfw");
const Renderer = @import("../renderer/Renderer.zig");
const Chip8 = @import("../chip8/Chip8.zig");
const Chip8Input = @import("../chip8/Input.zig");
const EmulatorInput = @import("Input.zig");
const Audio = @import("Audio.zig");

const Self = @This();

window: *glfw.Window,
renderer: Renderer,
chip8: Chip8,
chip8_input: Chip8Input,
emulator_input: EmulatorInput,
audio: Audio,
cpu_hz: u32,
rom_path: ?[]const u8,

const timer_hz = 60;

fn glfwErrorCallback(_: glfw.ErrorCode, description: ?[*:0]const u8) callconv(.c) void  {
    std.debug.print("GLFW Error: {s}\n", .{description orelse "no description"});
}

pub fn create(allocator: mem.Allocator, width: u32, height: u32) !*Self {
    _ = glfw.setErrorCallback(glfwErrorCallback);
    glfw.init() catch @panic("Error initializing glfw");

    const window = createWindow(width, height);
    const self = try allocator.create(Self);

    self.* = .{
        .window = window,
        .renderer = Renderer.init(width, height),
        .chip8 = Chip8.init(),
        .chip8_input = Chip8Input.init(),
        .emulator_input = EmulatorInput.init(),
        .audio = Audio.init() catch @panic("Failedl to init audio"),
        .cpu_hz = 700,
        .rom_path = null,
    };

    window.setUserPointer(self);
    _ = window.setFramebufferSizeCallback(onResize);

    return self;
}

pub fn loadRom(self: *Self, path: []const u8) !void {
    try self.chip8.loadRom(path);
    self.rom_path = path;
}

pub fn run(self: *Self) void {
    const target_fps = 60;
    const ns_per_frame = std.time.ns_per_s / target_fps;

    while (!self.window.shouldClose()) {
        const frame_start = std.time.nanoTimestamp();
        const cycles_per_frame = self.cpu_hz / target_fps;

        std.debug.print("cycles per frame: {}\n", .{cycles_per_frame});
        std.debug.print("cpu hz: {}\n", .{self.cpu_hz});

        self.audio.setBeep(self.chip8.sound_timer > 0);

        self.handleSystemInput();
        self.chip8_input.update(self.window);

        for (0..cycles_per_frame) |_| {
            self.chip8.cycle(&self.chip8_input);
        }

        self.chip8.decrementTimers();

        self.renderer.renderFrame(self.window, &self.chip8.frame_buffer);

        glfw.pollEvents();

        const frame_time = std.time.nanoTimestamp() - frame_start;
        if (frame_time < ns_per_frame) {
            std.Thread.sleep(@intCast(ns_per_frame - frame_time));
        }
    }
}

fn createWindow(width: u32, height: u32) *glfw.Window {
    glfw.windowHint(.client_api, .opengl_api);
    glfw.windowHint(.context_version_major, 3);
    glfw.windowHint(.context_version_minor, 3);
    glfw.windowHint(.opengl_profile, .opengl_core_profile);
    glfw.windowHint(.doublebuffer, true);

    const window = glfw.Window.create(@intCast(width), @intCast(height), "Chip-8", null) catch {
        @panic("Error creating window");
    };
    glfw.makeContextCurrent(window);

    return window;
}

pub fn destroy(self: *Self, allocator: mem.Allocator) void {
    self.audio.deinit();
    self.renderer.deinit();
    glfw.makeContextCurrent(null);
    self.window.destroy();
    glfw.terminate();

    allocator.destroy(self);
}

fn handleSystemInput(self: *Self) void {
    const action = self.emulator_input.check(self.window);

    switch (action) {
        .Quit => self.window.setShouldClose(true),

        .Reset => {
            self.chip8.reset();
            if (self.rom_path) |path| {
                self.chip8.loadRom(path) catch {
                    std.debug.print("Could not reload ROM!", .{});
                    std.process.exit(1);
                };
            }
        },

        .SpeedUp => self.cpu_hz +|= 50,

        .SpeedDown => self.cpu_hz -|= 50,

        .VolumeUp => self.audio.adjustVolume(0.05),

        .VolumeDown => self.audio.adjustVolume(-0.05),

        .None => {},
    }
}

fn onResize(window: *glfw.Window, width: c_int, height: c_int) callconv(.c) void {
    if (window.getUserPointer(Self)) |self| {
        self.renderer.resize(width, height);
    }
}
