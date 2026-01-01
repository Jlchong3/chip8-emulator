const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zopengl = b.dependency("zopengl", .{});
    const zglfw = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
        .x11 = false,
    });
    const zaudio = b.dependency("zaudio", .{
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("zopengl", zopengl.module("root"));
    exe_mod.addImport("zglfw", zglfw.module("root"));
    exe_mod.addImport("zaudio", zaudio.module("root"));

    exe_mod.linkLibrary(zaudio.artifact("miniaudio"));
    if (target.result.os.tag != .emscripten) {
        exe_mod.linkLibrary(zglfw.artifact("glfw"));
    }

    exe_mod.strip = true;
    const exe = b.addExecutable(.{
        .name = "chip_8",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    // 6. Run Step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the App");
    run_step.dependOn(&run_cmd.step);
}
