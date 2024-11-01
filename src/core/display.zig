const std = @import("std");
const testing = std.testing;
const mem = @import("mem.zig");
const emulator = @import("emulator.zig");
const errors = @import("errors.zig");
const instructions = @import("instructions.zig");

const OpCode = instructions.OpCode;
const Instruction = instructions.Instruction;
const Emulator = emulator.Emulator;

pub const WIDTH = 64;
pub const HEIGHT = 32;
pub const HEIGHT_HIRES = 64;
pub const WIDTH_HIRES = 128;
pub const DUMP_BUFSIZE = (WIDTH_HIRES + 3) * (HEIGHT_HIRES + 2);

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
    bits: [WIDTH_HIRES * HEIGHT_HIRES]u1,
    width: u8,
    height: u8,

    pub fn init() DisplayState {
        return DisplayState{
            .bits = [_]u1{0} ** (WIDTH_HIRES * HEIGHT_HIRES),
            .width = WIDTH,
            .height = HEIGHT,
        };
    }

    pub fn set_hires(self: *DisplayState) void {
        self.height = HEIGHT_HIRES;
        self.width = WIDTH_HIRES;
    }

    // FIXME: poor perf: should be using u8 operations
    // Returns true if the pixel is erased
    pub fn xor1(self: *DisplayState, x: usize, y: usize, v: u1) bool {
        const offset: usize = y * self.width + x;
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
                const draw_x = (@as(u16, x) + @as(u16, xx)) % self.width;
                const draw_y = (@as(u16, y) + @as(u16, yy)) % self.height;
                const value: u1 = @intCast(row >> (7 - xx) & 0x1);
                ret = self.xor1(draw_x, draw_y, value) or ret;
            }
        }

        return ret;
    }

    pub fn execute_draw(self: *DisplayState, emu: *Emulator, instr: Instruction) !void {
        if (instr.op != OpCode.DRW) return error.ASSERTION_ERROR;

        const x = emu.registers.Vx[instr.r0.?];
        const y = emu.registers.Vx[instr.r1.?];
        const n = instr.nibble.?;
        const sprite = emu.memory[emu.registers.I .. emu.registers.I + n];

        const flipped = self.draw_sprite(sprite, x, y);
        emu.registers.Vx[0xF] = if (flipped) 1 else 0;
        emu.registers.PC += 2;
    }

    pub fn execute_clear(self: *DisplayState, emu: *Emulator, instr: Instruction) !void {
        if (instr.op != OpCode.CLS) return error.ASSERTION_ERROR;
        @memset(&self.bits, 0);
        emu.registers.PC += 2;
    }

    pub fn execute_scroll_down(self: *DisplayState, dy: u8) !void {
        if (dy > self.height) return errors.ProgramErrors.INVALID_INSTRUCTION;
        const offset = @as(usize, dy) * @as(usize, self.width);
        std.mem.copyBackwards(u1, self.bits[offset..], self.bits[0 .. self.bits.len - offset]);
        @memset(self.bits[0..offset], 0);
    }

    pub fn dumps(self: *const DisplayState, out: []u8, border: bool) !void {
        if (out.len < DUMP_BUFSIZE) return error.INSUFFICIENT_BUFFER;
        @memset(out, 0);

        var k: u16 = 0;

        if (border) {
            out[k] = '*';
            k += 1;
            for (0..self.width) |_| {
                out[k] = '=';
                k += 1;
            }
            out[k] = '*';
            k += 1;
            out[k] = '\n';
            k += 1;
        }

        for (0..self.height) |y| {
            if (border) {
                out[k] = '|';
                k += 1;
            }
            for (0..self.width) |x| {
                out[k] = if (self.bits[self.width * y + x] == 1) '*' else ' ';
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
            for (0..self.width) |_| {
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

    var emu = Emulator.init();
    var flipped = false;

    for (0..16) |c| {
        const sprite = BuiltinSprites[c];
        const x: u8 = @intCast((c % 8) * 6);
        const y: u8 = @intCast((c / 8) * 6);
        flipped = emu.display.draw_sprite(&sprite, x, y);
    }

    try testing.expectEqual(false, flipped);

    const expected = @embedFile("test/assets/test_display_builtins.txt");
    try emu.display.dumps(&strbuf, true);
    // std.debug.print("DISPLAY:\n{!s}\n", .{strbuf});
    try testing.expectEqualStrings(expected, &strbuf);
}

test "can execute CLS" {
    var strbuf = [_]u8{0} ** (DUMP_BUFSIZE);
    var emu = Emulator.init();

    // draw something
    const sprite = BuiltinSprites[0];
    _ = emu.display.draw_sprite(&sprite, 0, 0);
    try emu.display.dumps(&strbuf, true);

    const instr = try Instruction.from_u16(0x00E0);
    // try emu.display.execute_clear(&emu, instr);
    try emu.execute_instruction(instr);

    const expected = @embedFile("test/assets/test_display_empty.txt");
    try emu.display.dumps(&strbuf, true);
    // std.debug.print("DISPLAY:\n{!s}\n", .{strbuf});
    try testing.expectEqualStrings(expected, &strbuf);
}
