const std = @import("std");
const ui = @import("ui/ui.zig");
const core = @import("core");
const root = @import("root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) std.debug.print("detected some memory leaks.\n", .{});

    var args = std.process.args();
    _ = args.next();
    const path = args.next() orelse return error.MISSING_ARGUMENT;

    var emu = try root.create(gpa.allocator(), path);
    var sdl = try ui.SdlContext.init(gpa.allocator(), &emu);
    defer sdl.deinit();

    while (args.next()) |arg| {
        if (std.mem.eql(u8, "--debug", arg)) {
            sdl.enable_debug();
        } else if (std.mem.eql(u8, "--hires", arg)) {
            sdl.enable_hires();
        } else if (std.mem.eql(u8, "--nosleep", arg)) {
            sdl.set_nosleep();
        }
    }

    try sdl.event_loop();
}
