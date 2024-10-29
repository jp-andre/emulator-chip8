const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});
const core = @import("core");
const DisplayState = core.display.DisplayState;
const Emulator = core.emulator.Emulator;

pub const SdlErrors = error{
    SDL_INITIALIZATION_FAILED,
    SDL_INVALID_STATE,
    SDL_QUIT_EARLY,
};

pub fn sdl_scancode_to_chip8(scancode: c_uint) ?u4 {
    const qwerty: u8 = switch (scancode) {
        sdl.SDL_SCANCODE_0 => '0',
        sdl.SDL_SCANCODE_1 => '1',
        sdl.SDL_SCANCODE_2 => '2',
        sdl.SDL_SCANCODE_3 => '3',
        sdl.SDL_SCANCODE_Q => 'q',
        sdl.SDL_SCANCODE_W => 'w',
        sdl.SDL_SCANCODE_E => 'e',
        sdl.SDL_SCANCODE_R => 'r',
        sdl.SDL_SCANCODE_A => 'a',
        sdl.SDL_SCANCODE_S => 's',
        sdl.SDL_SCANCODE_D => 'd',
        sdl.SDL_SCANCODE_F => 'f',
        sdl.SDL_SCANCODE_Z => 'z',
        sdl.SDL_SCANCODE_X => 'x',
        sdl.SDL_SCANCODE_C => 'c',
        sdl.SDL_SCANCODE_V => 'v',
        else => return null,
    };

    return core.input.qwerty_to_chip(qwerty) catch null;
}

pub const SdlContext = struct {
    window: ?*sdl.SDL_Window,
    allocator: std.mem.Allocator,
    emulator: *Emulator,
    sdl_perf_counter_freq: u64,

    pub fn init(allocator: std.mem.Allocator, emu: *Emulator) !SdlContext {
        errdefer std.log.err("SDL: init failed with {s}", .{sdl.SDL_GetError()});

        if (sdl.SDL_Init(sdl.SDL_INIT_TIMER |
            sdl.SDL_INIT_AUDIO |
            sdl.SDL_INIT_VIDEO |
            sdl.SDL_INIT_EVENTS) != 0)
            return SdlErrors.SDL_INITIALIZATION_FAILED;

        const window = sdl.SDL_CreateWindow(
            "CHIP-8",
            sdl.SDL_WINDOWPOS_UNDEFINED,
            sdl.SDL_WINDOWPOS_UNDEFINED,
            640,
            320,
            sdl.SDL_WINDOW_SHOWN,
        );
        if (window == null) return SdlErrors.SDL_INITIALIZATION_FAILED;

        const surface = sdl.SDL_GetWindowSurface(window);
        _ = sdl.SDL_FillRect(
            surface,
            null,
            sdl.SDL_MapRGB(surface.*.format, 69, 69, 69),
        );
        _ = sdl.SDL_UpdateWindowSurface(window);

        var ctx = SdlContext{
            .allocator = allocator,
            .window = window,
            .emulator = emu,
            .sdl_perf_counter_freq = sdl.SDL_GetPerformanceFrequency(),
        };
        emu.input.set_wait_key_cb(wait_key_cb, @ptrCast(&ctx));
        return ctx;
    }

    pub fn deinit(self: *SdlContext) void {
        sdl.SDL_DestroyWindow(self.window);
        sdl.SDL_Quit();
    }

    fn wait_key_cb(data: *core.input.WaitKeyDataType) !u4 {
        // FIXME: I don't like the alignemnt cast thingy, it should be part of the type
        const self: *SdlContext = @ptrCast(@alignCast(data));
        _ = self;

        // This is terrible - a loop in the loop :)
        while (true) {
            defer sdl.SDL_Delay(2);

            var event: sdl.SDL_Event = undefined;
            if (sdl.SDL_WaitEvent(&event) != 0) {
                if (event.type == sdl.SDL_QUIT) return core.input.KeyboardErrors.QUIT;
                if (event.type == sdl.SDL_KEYUP) {
                    if (sdl.SDL_SCANCODE_ESCAPE == event.key.keysym.scancode) return core.input.KeyboardErrors.QUIT;
                    if (sdl_scancode_to_chip8(event.key.keysym.scancode)) |key| {
                        return key;
                    }
                }
            }
        }
    }

    pub fn event_loop(self: *SdlContext) !void {
        errdefer std.log.err("SDL: event loop failed with {s}", .{sdl.SDL_GetError()});

        var last_start = sdl.SDL_GetTicks();
        var instructions_since_last: u32 = 0;
        var renders_since_last: u32 = 0;

        var quit = false;
        var done = false;
        var debug = false;

        while (!quit) {
            // FIXME: aim to execute at 500Hz
            // This is not entirely correct, since we should account for time spent here and drawing
            // Proper sync is for another day :)
            defer sdl.SDL_Delay(2);

            var event: sdl.SDL_Event = undefined;
            if (sdl.SDL_PollEvent(&event) != 0) {
                switch (event.type) {
                    sdl.SDL_QUIT => quit = true,
                    sdl.SDL_KEYDOWN => {
                        // std.debug.print("SDL: key down {any}\n", .{event.key});
                        switch (event.key.keysym.scancode) {
                            // sdl.SDL_SCANCODE_ESCAPE => quit = true,
                            else => if (sdl_scancode_to_chip8(event.key.keysym.scancode)) |key| {
                                self.emulator.input.pressed_keys[key] = true;
                            },
                        }
                    },
                    sdl.SDL_KEYUP => {
                        switch (event.key.keysym.scancode) {
                            sdl.SDL_SCANCODE_ESCAPE => quit = true,
                            sdl.SDL_SCANCODE_H => debug = !debug,
                            else => if (sdl_scancode_to_chip8(event.key.keysym.scancode)) |key| {
                                self.emulator.input.pressed_keys[key] = false;
                            },
                        }
                    },
                    else => {},
                }
            }
            if (quit) break;
            if (done) continue;

            const instr = try self.emulator.current_instruction();
            if (debug) {
                std.debug.print("EXEC: {any}\n", .{instr});
            }

            self.emulator.execute_instruction(instr) catch |err| switch (err) {
                core.input.KeyboardErrors.QUIT => return,
                core.errors.ProgramErrors.INFINITE_LOOP => {
                    std.log.info("\nProgram has reached an infinite loop, press Esc to exit.", .{});
                    done = true;
                    continue;
                },
                else => return err,
            };
            if (instr.op == .CLS or instr.op == .DRW) {
                renders_since_last += 1;
                try self.render_display(&self.emulator.display);
            }

            instructions_since_last += 1;
            if (sdl.SDL_GetTicks() - last_start >= 1000) {
                const fps = @as(f64, @floatFromInt(renders_since_last));
                const ips = @as(f64, @floatFromInt(instructions_since_last));
                std.debug.print("IPS: {d}, FPS: {d}\r", .{ ips, fps });
                last_start = sdl.SDL_GetTicks();
                renders_since_last = 0;
                instructions_since_last = 0;
            }
        }
    }

    fn sdl_perf_elapsed_ms(self: *SdlContext, since: u64) f64 {
        const now = sdl.SDL_GetPerformanceCounter();
        const freq: f64 = @as(f64, @floatFromInt(self.sdl_perf_counter_freq));
        const elapsed = (@as(f64, @floatFromInt(now)) - @as(f64, @floatFromInt(since))) / freq;
        return elapsed * 1000.0;
    }

    fn render_display(self: *SdlContext, display: *const DisplayState) !void {
        errdefer std.log.err("SDL: render failed with {s}", .{sdl.SDL_GetError()});

        // const start = sdl.SDL_GetPerformanceCounter();
        // defer std.debug.print("time: {d}ms\n", .{self.sdl_perf_elapsed_ms(start)});

        const window = self.*.window;
        defer _ = sdl.SDL_UpdateWindowSurface(window);

        var window_width: c_int = undefined;
        var window_height: c_int = undefined;
        sdl.SDL_GetWindowSize(self.window, &window_width, &window_height);
        if (window_width <= 0 or window_height <= 0) return SdlErrors.SDL_INVALID_STATE;

        const surface = sdl.SDL_GetWindowSurface(window);

        // solarized
        const rgb_on = sdl.SDL_MapRGB(surface.*.format, 255, 204, 0);
        const rgb_off = sdl.SDL_MapRGB(surface.*.format, 153, 102, 0);
        const palette = [2]u32{ rgb_off, rgb_on };

        for (0..display.height) |y| {
            for (0..display.width) |x| {
                const cell_width = @divFloor(window_width, display.width);
                const cell_height = @divFloor(window_height, display.height);
                const cell_x = @as(c_int, @intCast(x)) * cell_width;
                const cell_y = @as(c_int, @intCast(y)) * cell_height;

                const bit = display.bits[x + y * display.width];
                const color = palette[bit];
                const rect = sdl.SDL_Rect{
                    .x = cell_x,
                    .y = cell_y,
                    .w = cell_width,
                    .h = cell_height,
                };

                _ = sdl.SDL_FillRect(surface, &rect, color);
            }
        }
    }
};
