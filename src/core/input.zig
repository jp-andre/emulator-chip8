const std = @import("std");
const errors = @import("errors.zig");

// Keyboard layout (mapped to qwerty 1234-ZXCV)
// 1	2	3	C
// 4	5	6	D
// 7	8	9	E
// A	0	B	F

pub const KeyboardErrors = error{
    INVALID_KEY,
    QUIT,
};

pub fn qwerty_to_chip(char: u8) !u4 {
    return switch (std.ascii.toUpper(char)) {
        '1' => 0x1,
        '2' => 0x2,
        '3' => 0x3,
        '4' => 0xC,
        'Q' => 0x4,
        'W' => 0x5,
        'E' => 0x6,
        'R' => 0xD,
        'A' => 0x7,
        'S' => 0x8,
        'D' => 0x9,
        'F' => 0xE,
        'Z' => 0xA,
        'X' => 0x0,
        'C' => 0xB,
        'V' => 0xF,
        else => error.INVALID_KEY,
    };
}

// FIXME: this is not a good use of opaque (since no C interaction here)
pub const WaitKeyDataType = opaque {};

pub const InputState = struct {
    pressed_keys: [16]bool,
    wait_key_cb: ?*const fn (data: *WaitKeyDataType) KeyboardErrors!u4,
    wait_key_data: ?*WaitKeyDataType,

    pub fn init() InputState {
        return InputState{
            .pressed_keys = [_]bool{false} ** 16,
            .wait_key_cb = null,
            .wait_key_data = null,
        };
    }

    pub fn set_wait_key_cb(self: *InputState, cb: fn (data: *WaitKeyDataType) KeyboardErrors!u4, data: *WaitKeyDataType) void {
        self.wait_key_cb = cb;
        self.wait_key_data = data;
    }

    pub fn wait_key(self: *InputState) !u4 {
        if (self.wait_key_cb != null) {
            return self.wait_key_cb.?(self.wait_key_data.?);
        }

        // FIXME obviouly this cant work
        const stdin = std.io.getStdIn();

        while (true) {
            var buffer = [1]u8{0};
            const nbytes = try stdin.read(&buffer);
            if (nbytes < 1) {
                std.log.debug("Weird: read 0 bytes from stdin", .{});
                continue;
            }

            // failsafe?
            if (buffer[0] == 'p') std.process.abort();

            const key = qwerty_to_chip(buffer[0]) catch continue;
            @memset(&self.pressed_keys, false);
            self.pressed_keys[key] = true;
            return key;
        }

        return error.ASSERTION_ERROR;
    }

    pub fn maybe_wait_key(self: *InputState) !?u4 {
        // FIXME obviouly this cant work
        const stdin = std.io.getStdIn();

        @memset(&self.pressed_keys, false);

        var buffer = [1]u8{0};
        const nbytes = try stdin.read(&buffer);
        if (nbytes < 1) {
            std.log.debug("read: read 0 bytes from stdin", .{});
            return null;
        }

        const key = qwerty_to_chip(buffer[0]) catch return null;
        self.pressed_keys[key] = true;
        return key;
    }
};
