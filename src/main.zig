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

    try sdl.event_loop();
}
