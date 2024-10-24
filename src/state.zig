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
        var state = ProgramState{
            .registers = mem.Registers.init(),
            .stack = [_]u16{0} ** 16,
            .memory = [_]u8{0} ** 4096,
            .display = display.DisplayState.init(),
        };
        state.load_builtin_fonts();
        return state;
    }

    fn load_builtin_fonts(self: *ProgramState) void {
        const start = mem.BUILTIN_FONT_START;
        for (0..display.BuiltinSprites.len) |k| {
            @memcpy(self.memory[start + k * 5 .. start + (k + 1) * 5], &display.BuiltinSprites[k]);
        }
        // @memcpy(
        //     self.memory[start .. start + display.BUILTIN_SPRITES_LEN],
        //     &display.BuiltinSprites,
        // );
    }

    pub fn current_instruction_u8(self: *const ProgramState) !mem.RawInstruction {
        const pc = self.registers.PC;
        if (pc + 1 > self.memory.len) return error.JUMP_OUT_OF_BOUNDS;
        const ri = [2]u8{ self.memory[pc], self.memory[pc + 1] };
        return ri;
    }

    pub fn current_instruction(self: *const ProgramState) !mem.Instruction {
        const ri = try self.current_instruction_u8();
        return mem.Instruction.from_u8(ri);
    }
};

test "can create program state" {
    const st = ProgramState.init();

    const curi = try st.current_instruction();
    try testing.expectEqual(0x0, curi.to_u16());

    const builtin_font_sprite0 = st.memory[mem.BUILTIN_FONT_START .. mem.BUILTIN_FONT_START + 5];
    try testing.expectEqualSlices(u8, &display.BuiltinSprites[0], builtin_font_sprite0);
}
