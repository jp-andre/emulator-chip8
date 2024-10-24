const std = @import("std");
const testing = std.testing;
const mem = @import("./mem.zig");

pub const ProgramState = struct {
    registers: mem.Registers,
    stack: mem.StackBuffer,
    memory: mem.RawMemoryBuffer,

    pub fn init() ProgramState {
        return ProgramState{
            .registers = mem.Registers.init(),
            .stack = [_]u16{0} ** 16,
            .memory = [_]u8{0} ** 4096,
        };
    }
};

test "can create program state" {
    _ = ProgramState.init();
}
