const std = @import("std");
const zaudio = @import("zaudio");

const Self = @This();

device: *zaudio.Device,

const SharedState = struct {
    var is_beeping = std.atomic.Value(bool).init(false);
    var volume_bits = std.atomic.Value(u32).init(@as(u32, @bitCast(@as(f32, 0.15))));
};

const sample_rate = 44100;
const frequency = 440.0;

pub fn init() !Self {
    zaudio.init(std.heap.c_allocator);

    var config = zaudio.Device.Config.init(zaudio.Device.Type.playback);

    config.data_callback = dataCallback;
    config.playback.format = .float32;

    const device = try zaudio.Device.create(null, config);
    try device.start();

    return .{
        .device = device,
    };
}

pub fn deinit(self: Self) void {
    self.device.destroy();
    zaudio.deinit();
}

pub fn setBeep(_: Self, enabled: bool) void {
    SharedState.is_beeping.store(enabled, .release);
}


pub fn getVolume(_: Self) f32 {
    const bits = SharedState.volume_bits.load(.acquire);
    return @as(f32, @bitCast(bits));
}

pub fn adjustVolume(self: Self, delta: f32) void {
    const current = self.getVolume();

    const new_vol = std.math.clamp(current + delta, 0.0, 1.0);
    SharedState.volume_bits.store(@as(u32, @bitCast(new_vol)), .release);
}

fn dataCallback(device: *zaudio.Device, output: ?*anyopaque, _: ?*const anyopaque, frame_count: u32) callconv(.c) void {
    const is_playing = SharedState.is_beeping.load(.acquire);
    const vol_bits = SharedState.volume_bits.load(.acquire);
    const volume = @as(f32, @bitCast(vol_bits));

    const buffer = @as([*]f32, @ptrCast(@alignCast(output.?)));
    const num_channels = device.getPlaybackChannels();
    const State = struct { var phase: f32 = 0.0; };

    if (!is_playing or volume <= 0.001) {
        @memset(buffer[0 .. frame_count * num_channels], 0);
        State.phase = 0;
        return;
    }

    const sine_step = std.math.tau * frequency / @as(f32, @floatFromInt(sample_rate));

    for (0..frame_count) |frame| {
        const sample = std.math.sin(State.phase) * volume;
        State.phase += sine_step;
        if (State.phase > std.math.tau) State.phase -= std.math.tau;

        for (0..num_channels) |ch| {
            buffer[frame * num_channels + ch] = sample;
        }
    }
}
