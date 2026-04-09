const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const desktop_exe_mod = b.createModule(.{
        .root_source_file = b.path("src/desktop/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "Chip8", .module = b.addModule(
                "Chip8",
                .{ .root_source_file = b.path("src/core/Chip8.zig") },
            )},
        },
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

    desktop_exe_mod.addImport("zopengl", zopengl.module("root"));
    desktop_exe_mod.addImport("zglfw", zglfw.module("root"));
    desktop_exe_mod.addImport("zaudio", zaudio.module("root"));

    desktop_exe_mod.linkLibrary(zaudio.artifact("miniaudio"));
    if (target.result.os.tag != .emscripten) {
        desktop_exe_mod.linkLibrary(zglfw.artifact("glfw"));
    }

    desktop_exe_mod.strip = true;
    const exe = b.addExecutable(.{
        .name = "chip_8",
        .root_module = desktop_exe_mod,
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

    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const wasm_exe = b.addExecutable(.{
        .name = "chip_8_web",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/web/wasm.zig"),
            .target = wasm_target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "Chip8", .module = b.addModule(
                    "Chip8",
                    .{ .root_source_file = b.path("src/core/Chip8.zig") },
                )},
            },
        }),
    });

    wasm_exe.entry = .disabled;
    wasm_exe.rdynamic = true;

    const install_wasm = b.addInstallArtifact(wasm_exe, .{});
    const web_step = b.step("web", "Build the WebAssembly module");
    web_step.dependOn(&install_wasm.step);
}
