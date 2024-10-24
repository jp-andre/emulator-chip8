const std = @import("std");

pub const GeneralErrors = error{
    NOT_IMPLEMENTED,
    INVALID_INSTRUCTION,
};

pub const RegisterErrors = error{
    // http://devernay.free.fr/hacks/chip8/C8TECH10.HTM#3.0
    VF_WRITE_FORBIDDEN,
};

pub const Registers = struct {
    Vx: [16]u8,
    I: u16,
    DT: u8, // delay timer
    ST: u8, // sound timer
    PC: u16, // program counter
    SP: u8, // stack pointer

    pub fn set_vx(self: *Registers, x: u4, value: u8) !void {
        if (x == 0xf) {
            return error.VF_WRITE_FORBIDDEN;
        }

        self.Vx[x] = value;
    }

    pub fn init() Registers {
        return Registers{
            .Vx = [_]u8{0} ** 16,
            .I = 0,
            .DT = 0,
            .ST = 0,
            .PC = 0,
            .SP = 0,
        };
    }
};

// http://devernay.free.fr/hacks/chip8/C8TECH10.HTM#3.1
pub const OpCode = enum {
    SYS, // 0nnn - SYS addr.  Jump to a machine code routine at nnn. (IGNORED)
    CLS, // 00E0 - CLS.  Clear the display.
    RET, // 00EE - RET.  Return from a subroutine.
    JP, // 1nnn - JP addr.  Jump to location nnn.
    CALL, // 2nnn - CALL addr.  Call subroutine at nnn.
    SERB, // 3xkk - SE Vx, byte.  Skip next instruction if Vx = kk.
    SNERB, // 4xkk - SNE Vx, byte.  Skip next instruction if Vx != kk.
    SERR, // 5xy0 - SE Vx, Vy.  Skip next instruction if Vx = Vy.
    LDRB, // 6xkk - LD Vx, byte.  Set Vx = kk.
    ADDRB, // 7xkk - ADD Vx, byte.   Set Vx = Vx + kk.
    LDRR, // 8xy0 - LD Vx, Vy.   Set Vx = Vy.
    ORRR, // 8xy1 - OR Vx, Vy.    Set Vx = Vx OR Vy.
    ANDRR, // 8xy2 - AND Vx, Vy.    Set Vx = Vx AND Vy.
    XORRR, // 8xy3 - XOR Vx, Vy.    Set Vx = Vx XOR Vy.
    ADDRR, // 8xy4 - ADD Vx, Vy.   Set Vx = Vx + Vy, set VF = carry.
    SUBRR, // 8xy5 - SUB Vx, Vy.   Set Vx = Vx - Vy, set VF = NOT borrow.
    SHR, // 8xy6 - SHR Vx {, Vy}.   Set Vx = Vx SHR 1.
    SUBN, // 8xy7 - SUBN Vx, Vy.    Set Vx = Vy - Vx, set VF = NOT borrow.
    SHL, // 8xyE - SHL Vx {, Vy}.    Set Vx = Vx SHL 1.
    SNERR, // 9xy0 - SNE Vx, Vy.    Skip next instruction if Vx != Vy.
    LDI, // Annn - LD I, addr.    Set I = nnn.
    JPR, // Bnnn - JP V0, addr.    Jump to location nnn + V0.
    RND, // Cxkk - RND Vx, byte.    Set Vx = random byte AND kk.
    DRW, // Dxyn - DRW Vx, Vy, nibble.    Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision.
    SKP, // Ex9E - SKP Vx.    Skip next instruction if key with the value of Vx is pressed.
    SKNP, // ExA1 - SKNP Vx.    Skip next instruction if key with the value of Vx is not pressed.
    LDDTB, // Fx07 - LD Vx, DT.    Set Vx = delay timer value.
    WAITK, // Fx0A - LD Vx, K.    Wait for a key press, store the value of the key in Vx.
    LDDTR, // Fx15 - LD DT, Vx.    Set delay timer = Vx.
    LDST, // Fx18 - LD ST, Vx.    Set sound timer = Vx.
    ADDI, // Fx1E - ADD I, Vx.    Set I = I + Vx.
    LDF, // Fx29 - LD F, Vx.    Set I = location of sprite for digit Vx.
    LDBCD, // Fx33 - LD B, Vx.   Store BCD representation of Vx in memory locations I, I+1, and I+2.
    STRR, // Fx55 - LD [I], Vx.   Store registers V0 through Vx in memory starting at location I.
    RDR, // Fx65 - LD Vx, [I].    Read registers V0 through Vx from memory starting at location I.
};

pub fn raw_split4(raw: RawInstruction) [4]u4 {
    return [4]u4{
        @intCast(raw[0] >> 4),
        @intCast(raw[0] & 0xf),
        @intCast(raw[1] >> 4),
        @intCast(raw[1] & 0xf),
    };
}

pub const Instruction = struct {
    // FIXME this duplicates info - should not use
    raw: RawInstruction,

    op: OpCode,
    addr: ?u12 = null,
    r0: ?u4 = null,
    r1: ?u4 = null,
    nibble: ?u4 = null,
    byte: ?u8 = null,

    pub fn from_raw(raw: RawInstruction) !Instruction {
        // const r16 = @as(u16, raw[0]) << 8 | raw[1];
        const x = raw_split4(raw);
        const r0 = x[1];
        const r1 = x[2];
        const byte = raw[1];
        const nibble = x[3];
        const addr = @as(u12, x[1]) << 8 | @as(u12, x[2]) << 4 | @as(u12, x[3]) << 0;

        const parsed = switch (x[0]) {
            0x0 => switch (addr) {
                0x0E0 => Instruction{ .raw = raw, .op = OpCode.CLS },
                0x0EE => Instruction{ .raw = raw, .op = OpCode.RET },
                else => Instruction{ .raw = raw, .op = OpCode.SYS, .addr = addr },
            },
            0x1 => Instruction{ .raw = raw, .op = OpCode.JP, .addr = addr },
            0x2 => Instruction{ .raw = raw, .op = OpCode.CALL, .addr = addr },
            0x3 => Instruction{ .raw = raw, .op = OpCode.SERB, .r0 = r0, .byte = byte },
            0x4 => Instruction{ .raw = raw, .op = OpCode.SNERB, .r0 = r0, .byte = byte },
            0x5 => switch (nibble) {
                0x0 => Instruction{ .raw = raw, .op = OpCode.SERR, .r0 = r0, .r1 = r1 },
                else => error.INVALID_INSTRUCTION,
            },
            0x6 => Instruction{ .raw = raw, .op = OpCode.LDRB, .r0 = r0, .byte = byte },
            0x7 => Instruction{ .raw = raw, .op = OpCode.ADDRB, .r0 = r0, .byte = byte },

            0x8 => error.NOT_IMPLEMENTED,

            0x9 => switch (nibble) {
                0x0 => Instruction{ .raw = raw, .op = OpCode.SNERR, .r0 = r0, .r1 = r1 },
                else => error.INVALID_INSTRUCTION,
            },
            0xA => Instruction{ .raw = raw, .op = OpCode.LDI, .addr = addr },
            0xB => Instruction{ .raw = raw, .op = OpCode.JPR, .addr = addr },
            0xC => Instruction{ .raw = raw, .op = OpCode.RND, .r0 = r0, .byte = byte },
            0xD => Instruction{ .raw = raw, .op = OpCode.DRW, .r0 = r0, .r1 = r1, .nibble = nibble },

            0xE => error.NOT_IMPLEMENTED,
            0xF => error.NOT_IMPLEMENTED,
        };

        // std.debug.print("raw: {x} -> parsed: {any}\n", .{ raw, parsed });
        return parsed;
    }

    pub fn from_split4(s4: [4]u4) !Instruction {
        const raw = [2]u8{
            @as(u8, s4[0]) << 4 | @as(u8, s4[1]),
            @as(u8, s4[2]) << 4 | @as(u8, s4[3]),
        };
        // std.debug.print("s4: {x} -> raw: {x}\n", .{ s4, raw });
        return from_raw(raw);
    }

    // pub fn dumps(self: Instruction) []const u8 { // }
};

pub const StackBuffer = [16]u16;
pub const RawMemoryBuffer = [4096]u8;
pub const RawInstruction = [2]u8;

pub const MemoryOffsets = enum(u16) {
    RawMemoryStart = 0x200,
    RawMemoryStartETI660 = 0x600,
};
