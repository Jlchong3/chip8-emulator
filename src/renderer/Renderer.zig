const std = @import("std");
const Chip8 = @import("../chip8/Chip8.zig");
const zopengl = @import("zopengl");
const glfw = @import("zglfw");
const mem = std.mem;

const gl = zopengl.bindings;

const Self = @This();

const QuadGeometry = struct {
    vao: c_uint,
    ebo: c_uint,
    vbo: c_uint,

    pub fn init() QuadGeometry {
        var vao: c_uint = undefined;
        var vbo: c_uint = undefined;
        var ebo: c_uint = undefined;

        gl.genVertexArrays(1, @ptrCast(&vao));
        gl.genBuffers(1, @ptrCast(&vbo));
        gl.genBuffers(1, @ptrCast(&ebo));
        {
            gl.bindVertexArray(vao);
            {
                gl.bindBuffer(gl.ARRAY_BUFFER, vbo);

                const vertices = [_]f32{
                    1.0,  1.0,  0.0, 1.0, 1.0,
                    -1.0, 1.0,  0.0, 0.0, 1.0,
                    1.0,  -1.0, 0.0, 1.0, 0.0,
                    -1.0, -1.0, 0.0, 0.0, 0.0,
                };

                gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);

                gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(gl.Float), @ptrFromInt(0));
                gl.enableVertexAttribArray(0);

                gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(gl.Float), @ptrFromInt(3 * @sizeOf(gl.Float)));
                gl.enableVertexAttribArray(1);
            }
            const indices = [_]c_uint{
                0, 2, 3,
                0, 1, 3,
            };

            gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
            gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, gl.STATIC_DRAW);
        }

        return .{ .vao = vao, .vbo = vbo, .ebo = ebo };
    }

    pub fn bind(self: @This()) void {
        gl.bindVertexArray(self.vao);
    }
};

const fb_w = Chip8.fb_width;
const fb_h = Chip8.fb_height;

quad: QuadGeometry,
shader_program: c_uint,
display_texture: c_uint,
last_fb: [fb_w * fb_h]u8,

pub fn init(width: u32, height: u32) Self {
    zopengl.loadCoreProfile(glfw.getProcAddress, 3, 3) catch {
        @panic("Error loading proc address");
    };

    gl.viewport(0, 0, @intCast(width), @intCast(height));

    const shader_program = createShader();
    gl.useProgram(shader_program);

    return .{
        .display_texture = createDisplayTexture(),
        .quad = QuadGeometry.init(),
        .shader_program = shader_program,
        .last_fb = [_]u8{0} ** (fb_w * fb_h),
    };
}

pub fn renderFrame(self: *Self, window: *glfw.Window, frame_buffer: []const u8) void {
    var display_buffer: [fb_w * fb_h]u8 = undefined;

    for (0.., self.last_fb, frame_buffer) |i, prev_pixel, curr_pixel| {
        display_buffer[i] = prev_pixel | curr_pixel;
        self.last_fb[i] = curr_pixel;
    }

    gl.clearColor(1.0, 1.0, 1.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    gl.bindTexture(gl.TEXTURE_2D, self.display_texture);
    gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);

    gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, fb_w, fb_h, gl.RED, gl.UNSIGNED_BYTE, &display_buffer);

    self.quad.bind();
    gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);

    window.swapBuffers();
}

pub fn deinit(self: Self) void {
    gl.deleteProgram(self.shader_program);
    gl.deleteVertexArrays(1, @ptrCast(&self.quad.vao));
    gl.deleteBuffers(1, @ptrCast(&self.quad.vbo));
    gl.deleteBuffers(1, @ptrCast(&self.quad.ebo));
    gl.deleteTextures(1, @ptrCast(&self.display_texture));
}

fn createDisplayTexture() c_uint {
    var texture: c_uint = undefined;
    gl.genTextures(1, @ptrCast(&texture));
    {
        gl.bindTexture(gl.TEXTURE_2D, texture);
        defer gl.bindTexture(gl.TEXTURE_2D, 0);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

        const swizzleMask = [_]c_int{ gl.RED, gl.RED, gl.RED, gl.ONE };
        gl.texParameteriv(gl.TEXTURE_2D, gl.TEXTURE_SWIZZLE_RGBA, &swizzleMask);

        gl.texImage2D(gl.TEXTURE_2D, 0, gl.R8, fb_w, fb_h, 0, gl.RED, gl.UNSIGNED_BYTE, null);
    }

    return texture;
}

fn createShader() c_uint {
    const vertexSource = @embedFile("shaders/vertex.glsl");
    const fragmentSource = @embedFile("shaders/fragment.glsl");

    var success: c_int = undefined;
    var infolog: [512:0]u8 = undefined;

    const vertexShader = gl.createShader(gl.VERTEX_SHADER);
    const fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);

    gl.shaderSource(vertexShader, 1, @ptrCast(&vertexSource), null);
    gl.shaderSource(fragmentShader, 1, @ptrCast(&fragmentSource), null);

    gl.compileShader(vertexShader);
    defer gl.deleteShader(vertexShader);

    gl.getShaderiv(vertexShader, gl.COMPILE_STATUS, &success);
    if (success == 0) {
        gl.getShaderInfoLog(vertexShader, 512, null, &infolog);
        _ = std.fs.File.stdout().write(&infolog) catch |err| {
            std.debug.print("Could not write infolog {}", .{err});
        };
    }

    gl.compileShader(fragmentShader);
    defer gl.deleteShader(fragmentShader);

    gl.getShaderiv(fragmentShader, gl.COMPILE_STATUS, &success);
    if (success == 0) {
        gl.getShaderInfoLog(fragmentShader, 512, null, &infolog);
        _ = std.fs.File.stdout().write(&infolog) catch |err| {
            std.debug.print("Could not write infolog {}", .{err});
        };
    }

    const shaderProgram = gl.createProgram();
    gl.attachShader(shaderProgram, vertexShader);
    gl.attachShader(shaderProgram, fragmentShader);
    gl.linkProgram(shaderProgram);

    gl.getProgramiv(shaderProgram, gl.LINK_STATUS, &success);
    if (success == 0) {
        gl.getProgramInfoLog(shaderProgram, 512, null, &infolog);
        _ = std.fs.File.stdout().write(&infolog) catch |err| {
            std.debug.print("Could not write infolog {}", .{err});
        };
    }

    return shaderProgram;
}

pub fn resize(self: *Self, width: c_int, height: c_int) callconv(.c) void {
    _ = self;
    gl.viewport(0, 0, width, height);
}
