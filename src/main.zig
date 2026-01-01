const std = @import("std");
const Emulator = @import("emulator/Emulator.zig");

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var emulator = try Emulator.create(allocator, 1280, 640);
    defer emulator.destroy(allocator);

    if (args.len == 2) {
        try emulator.loadRom(args[1]);
        emulator.run();
    } else {
        std.debug.print("No ROM provided", .{});
    }
}
