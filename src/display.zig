const std = @import("std");
const testing = std.testing;
const mem = @import("mem.zig");
const state = @import("state.zig");
const errors = @import("errors.zig");

pub const WIDTH = 64;
pub const HEIGHT = 32;
const DUMP_BUFSIZE = (WIDTH + 3) * (HEIGHT + 2);

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

    // pub fn set1(self: *DisplayState, x: usize, y: usize, v: u1) void {
    //     const offset: usize = y * WIDTH + x;
    //     self.bits[offset] = v;
    // }

    pub fn dumps(self: *const DisplayState, out: []u8, border: bool) ![]u8 {
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

        return out;
    }
};

// Returns true if any pixel was erased
pub fn draw_sprite(display: *DisplayState, sprite: []const u8, x: u8, y: u8) bool {
    var ret = false;

    for (0..sprite.len) |yy| {
        const row: u8 = sprite[yy];
        for (0..8) |x_iter| {
            const xx: u3 = @intCast(x_iter);
            const draw_x = (x + xx) % WIDTH;
            const draw_y = (y + yy) % HEIGHT;
            const value: u1 = @intCast(row >> (7 - xx) & 0x1);
            ret = display.xor1(draw_x, draw_y, value) or ret;
        }
    }

    return ret;
}

// pub fn draw_execute(st: *state.ProgramState) !u8 {
//     const
// }

test "can create display state" {
    _ = DisplayState.init();
}

test "can draw basic sprite" {
    var strbuf = [_]u8{0} ** (DUMP_BUFSIZE);

    var st = state.ProgramState.init();
    var flipped = false;

    for (0..16) |c| {
        const sprite = BuiltinSprites[c];
        const x: u8 = @intCast((c % 8) * 6);
        const y: u8 = @intCast((c / 8) * 6);
        flipped = draw_sprite(&st.display, &sprite, x, y);
    }

    try testing.expectEqual(false, flipped);

    const expected = @embedFile("test_display_builtins.txt");
    // std.debug.print("DISPLAY:\n{!s}\n", .{st.display.dumps(&strbuf, true)});
    try testing.expectEqualStrings(expected, try st.display.dumps(&strbuf, true));
}
