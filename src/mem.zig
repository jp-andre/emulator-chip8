const std = @import("std");

pub const Registers = struct {
    Vx: [16]u8,
    I: u16,
    DT: u8, // delay timer
    ST: u8, // sound timer
    PC: u16, // program counter
    SP: u8, // stack pointer

    pub fn set_vx(self: *Registers, x: u4, value: u8) !void {
        // This is actually used by programs lol
        // if (x == 0xf) return error.VF_WRITE_FORBIDDEN;
        self.Vx[x] = value;
    }

    pub fn init() Registers {
        return Registers{
            .Vx = [_]u8{0} ** 16,
            .I = 0,
            .DT = 0,
            .ST = 0,
            // FIXME: corresponds to MEMORY_START -- increments by 2... shoudl be the raw value instead
            .PC = 0,
            .SP = 0,
        };
    }
};

// Memory
pub const StackBuffer = [16]u16;
pub const RawMemoryBuffer = [MEMORY_END]u8;

pub const MEMORY_END = 4096;
pub const MEMORY_START = 0x200;
// MEMORY_START_ETI660 = 0x600,
pub const BUILTIN_FONT_START = 0x100;
