const std = @import("std");
const testing = std.testing;
const mem = @import("mem.zig");
const display = @import("display.zig");

pub const ProgramState = struct {
    registers: mem.Registers,
    stack: mem.StackBuffer,
    memory: mem.RawMemoryBuffer,
    display: display.DisplayState,

    pub fn init() ProgramState {
        return ProgramState{
            .registers = mem.Registers.init(),
            .stack = [_]u16{0} ** 16,
            .memory = [_]u8{0} ** 4096,
            .display = display.DisplayState.init(),
        };
    }
};

test "can create program state" {
    _ = ProgramState.init();
}
