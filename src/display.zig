const std = @import("std");
const testing = std.testing;
const mem = @import("mem.zig");
const program = @import("program.zig");
const errors = @import("errors.zig");
const instructions = @import("instructions.zig");

const OpCode = instructions.OpCode;
const Instruction = instructions.Instruction;
const ProgramState = program.ProgramState;

pub const WIDTH = 64;
pub const HEIGHT = 32;
pub const DUMP_BUFSIZE = (WIDTH + 3) * (HEIGHT + 2);

pub const BuiltinSprites = [_][5]u8{
    [5]u8{ 0xF0, 0x90, 0x90, 0x90, 0xF0 },
    [5]u8{ 0x20, 0x60, 0x20, 0x20, 0x70 },
    [5]u8{ 0xF0, 0x10, 0xF0, 0x80, 0xF0 },
    [5]u8{ 0xF0, 0x10, 0xF0, 0x10, 0xF0 },
    [5]u8{ 0x90, 0x90, 0xF0, 0x10, 0x10 },
    [5]u8{ 0xF0, 0x80, 0xF0, 0x10, 0xF0 },
    [5]u8{ 0xF0, 0x80, 0xF0, 0x90, 0xF0 },
    [5]u8{ 0xF0, 0x10, 0x20, 0x40, 0x40 },
    [5]u8{ 0xF0, 0x90, 0xF0, 0x90, 0xF0 },
    [5]u8{ 0xF0, 0x90, 0xF0, 0x10, 0xF0 },
    [5]u8{ 0xF0, 0x90, 0xF0, 0x90, 0x90 },
    [5]u8{ 0xE0, 0x90, 0xE0, 0x90, 0xE0 },
    [5]u8{ 0xF0, 0x80, 0x80, 0x80, 0xF0 },
    [5]u8{ 0xE0, 0x90, 0x90, 0x90, 0xE0 },
    [5]u8{ 0xF0, 0x80, 0xF0, 0x80, 0xF0 },
    [5]u8{ 0xF0, 0x80, 0xF0, 0x80, 0x80 },
};

pub const BUILTIN_SPRITES_LEN = 16 * 5;

pub const DisplayState = struct {
    bits: [WIDTH * HEIGHT]u1,

    pub fn init() DisplayState {
        return DisplayState{
            .bits = [_]u1{0} ** (WIDTH * HEIGHT),
        };
    }

    // FIXME: worst perf possible i guess
    // Returns true if the pixel is erased
    pub fn xor1(self: *DisplayState, x: usize, y: usize, v: u1) bool {
        const offset: usize = y * WIDTH + x;
        const ret = self.bits[offset] & v;
        self.bits[offset] = self.bits[offset] ^ v;
        return ret == 0x1;
    }

    // Returns true if any pixel was erased
    pub fn draw_sprite(self: *DisplayState, sprite: []const u8, x: u8, y: u8) bool {
        var ret = false;

        for (0..sprite.len) |y_iter| {
            const yy: u16 = @intCast(y_iter);
            const row: u8 = sprite[y_iter];
            for (0..8) |x_iter| {
                const xx: u3 = @intCast(x_iter);
                const draw_x = (@as(u16, x) + @as(u16, xx)) % WIDTH;
                const draw_y = (@as(u16, y) + @as(u16, yy)) % HEIGHT;
                const value: u1 = @intCast(row >> (7 - xx) & 0x1);
                ret = self.xor1(draw_x, draw_y, value) or ret;
            }
        }

        return ret;
    }

    pub fn execute_draw(self: *DisplayState, ps: *ProgramState, instr: Instruction) !void {
        if (instr.op != OpCode.DRW) return error.ASSERTION_ERROR;

        const x = ps.registers.Vx[instr.r0.?];
        const y = ps.registers.Vx[instr.r1.?];
        const n = instr.nibble.?;
        const sprite = ps.memory[ps.registers.I .. ps.registers.I + n];

        const flipped = self.draw_sprite(sprite, x, y);
        ps.registers.Vx[0xF] = if (flipped) 1 else 0;
        ps.registers.PC += 2;
    }

    pub fn execute_clear(self: *DisplayState, ps: *ProgramState, instr: Instruction) !void {
        if (instr.op != OpCode.CLS) return error.ASSERTION_ERROR;
        @memset(&self.bits, 0);
        ps.registers.PC += 2;
    }

    pub fn dumps(self: *const DisplayState, out: []u8, border: bool) !void {
        if (out.len < DUMP_BUFSIZE) return error.INSUFFICIENT_BUFFER;
        @memset(out, 0);

        var k: u16 = 0;

        if (border) {
            out[k] = '*';
            k += 1;
            for (0..WIDTH) |_| {
                out[k] = '=';
                k += 1;
            }
            out[k] = '*';
            k += 1;
            out[k] = '\n';
            k += 1;
        }

        for (0..HEIGHT) |y| {
            if (border) {
                out[k] = '|';
                k += 1;
            }
            for (0..WIDTH) |x| {
                out[k] = if (self.bits[WIDTH * y + x] == 1) '*' else ' ';
                k += 1;
            }
            if (border) {
                out[k] = '|';
                k += 1;
            }
            out[k] = '\n';
            k += 1;
        }

        if (border) {
            out[k] = '*';
            k += 1;
            for (0..WIDTH) |_| {
                out[k] = '=';
                k += 1;
            }
            out[k] = '*';
            k += 1;
            out[k] = '\n';
            k += 1;
        }
    }
};

test "can create display state" {
    _ = DisplayState.init();
}

test "can draw basic sprite" {
    var strbuf = [_]u8{0} ** (DUMP_BUFSIZE);

    var ps = ProgramState.init();
    var flipped = false;

    for (0..16) |c| {
        const sprite = BuiltinSprites[c];
        const x: u8 = @intCast((c % 8) * 6);
        const y: u8 = @intCast((c / 8) * 6);
        flipped = ps.display.draw_sprite(&sprite, x, y);
    }

    try testing.expectEqual(false, flipped);

    const expected = @embedFile("test/assets/test_display_builtins.txt");
    try ps.display.dumps(&strbuf, true);
    // std.debug.print("DISPLAY:\n{!s}\n", .{strbuf});
    try testing.expectEqualStrings(expected, &strbuf);
}

test "can execute CLS" {
    var strbuf = [_]u8{0} ** (DUMP_BUFSIZE);
    var ps = ProgramState.init();

    // draw something
    const sprite = BuiltinSprites[0];
    _ = ps.display.draw_sprite(&sprite, 0, 0);
    try ps.display.dumps(&strbuf, true);

    const instr = try Instruction.from_u16(0x00E0);
    // try ps.display.execute_clear(&ps, instr);
    try ps.execute_instruction(instr);

    const expected = @embedFile("test/assets/test_display_empty.txt");
    try ps.display.dumps(&strbuf, true);
    // std.debug.print("DISPLAY:\n{!s}\n", .{strbuf});
    try testing.expectEqualStrings(expected, &strbuf);
}
