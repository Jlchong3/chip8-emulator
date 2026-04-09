const std = @import("std");
const Chip8 = @import("Chip8");
const Input = Chip8.Input;

extern "env" fn consoleLog(ptr: [*]const u8, len: usize) void;

fn log(msg: []const u8) void {
    consoleLog(msg.ptr, msg.len);
}

var emulator: Chip8 = undefined;
var input: Input = undefined;

var rom_transfer_buffer: [Chip8.memory_size - Chip8.rom_start]u8 = undefined;

export fn init() void {
    emulator = Chip8.init();
    input = Input.init();
}

export fn get_rom_buffer_pointer() [*]u8 {
    return &rom_transfer_buffer;
}

export fn load_rom(rom_size: usize) void {
    emulator.reset();

    if (rom_size == 0 or rom_size > rom_transfer_buffer.len) {
        log("Error: Invalid ROM size provided by JavaScript.");
        return;
    }

    emulator.loadRom(rom_transfer_buffer[0..rom_size]) catch |err| {
        log(@errorName(err));
    };

    log("ROM loaded successfully into WASM memory!");
}

export fn press_key(key: u8) void {
    input.pressKey(@truncate(key));
}

export fn release_key(key: u8) void {
    input.pressKey(@truncate(key));
}

export fn cycle() void {
    emulator.cycle(&input);
}

export fn tick_timers() void {
    emulator.decrementTimers();
    input.tick();
}

export fn get_video_buffer_pointer() [*]u8 {
    return &emulator.frame_buffer;
}

export fn is_beeping() bool {
    return emulator.sound_timer > 0;
}
