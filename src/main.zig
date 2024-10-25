const std = @import("std");
const root = @import("root.zig");
const errors = @import("errors.zig");

pub fn main() !void {
    var args = std.process.args();
    _ = args.next();
    const path = args.next() orelse return error.MISSING_ARGUMENT;
    try root.run(path);
}
