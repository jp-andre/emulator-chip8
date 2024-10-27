const std = @import("std");
const root = @import("root.zig");
const errors = @import("core/errors.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) std.debug.print("detected some memory leaks.\n", .{});

    var args = std.process.args();
    _ = args.next();
    const path = args.next() orelse return error.MISSING_ARGUMENT;
    try root.run(gpa.allocator(), path);
}
