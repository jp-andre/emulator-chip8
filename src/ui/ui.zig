const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const SdlErrors = error{
    SDL_INITIALIZATION_FAILED,
};

fn run_sleep(allocator: std.mem.Allocator, ms: f32) !void {
    const Child = std.process.Child;

    var ms_str: [32]u8 = undefined;
    const argv = [_][]const u8{ "sleep", try std.fmt.bufPrint(&ms_str, "{d}", .{ms / 1000.0}) };
    std.debug.print("Cmd: {s}\n", .{argv});
    var child = Child.init(&argv, allocator);
    try child.spawn();
    std.debug.print("Spawned\n", .{});
    _ = try child.wait();
    std.debug.print("Done\n", .{});
}

pub const SdlContext = struct {
    window: ?*sdl.SDL_Window,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !SdlContext {
        errdefer std.log.err("SDL: init failed with {s}", .{sdl.SDL_GetError()});

        if (sdl.SDL_Init(sdl.SDL_INIT_TIMER |
            sdl.SDL_INIT_AUDIO |
            sdl.SDL_INIT_VIDEO |
            sdl.SDL_INIT_EVENTS) != 0)
            return SdlErrors.SDL_INITIALIZATION_FAILED;

        const w: c_int = 800;
        const h: c_int = 600;
        const window = sdl.SDL_CreateWindow(
            "CHIP-8",
            200, // sdl.SDL_WINDOWPOS_UNDEFINED,
            200, // sdl.SDL_WINDOWPOS_UNDEFINED,
            w,
            h,
            sdl.SDL_WINDOW_SHOWN,
        );
        if (window == null) return SdlErrors.SDL_INITIALIZATION_FAILED;

        const surface = sdl.SDL_GetWindowSurface(window);
        _ = sdl.SDL_FillRect(surface, null, sdl.SDL_MapRGB(surface.*.format, 69, 69, 69));
        _ = sdl.SDL_UpdateWindowSurface(window);
        sdl.SDL_ShowWindow(window);

        return SdlContext{
            .allocator = allocator,
            .window = window,
        };
    }

    pub fn deinit(self: *SdlContext) void {
        sdl.SDL_DestroyWindow(self.window);
        sdl.SDL_Quit();
    }

    pub fn event_loop(self: *SdlContext) !void {
        errdefer std.log.err("SDL: event loop failed with {s}", .{sdl.SDL_GetError()});
        _ = self;

        var quit = false;
        while (!quit) {
            var event: sdl.SDL_Event = undefined;
            if (sdl.SDL_PollEvent(&event) == 0) {
                sdl.SDL_Delay(2);
                continue;
            }

            if (event.type == sdl.SDL_QUIT) {
                quit = true;
            }
            if (event.type == sdl.SDL_KEYDOWN) {
                std.debug.print("SDL: key event {any}\n", .{event.key});
            }
        }
    }
};
