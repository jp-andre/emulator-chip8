const std = @import("std");

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
    ORRR, // 8xy1 - OR Vx, Vy.    Set Vx = Vx OR Vy.6
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
    RDDT, // Fx07 - LD Vx, DT.    Set Vx = delay timer value.
    WAITK, // Fx0A - LD Vx, K.    Wait for a key press, store the value of the key in Vx.
    SETDT, // Fx15 - LD DT, Vx.    Set delay timer = Vx.
    SETST, // Fx18 - LD ST, Vx.    Set sound timer = Vx.
    ADDIR, // Fx1E - ADD I, Vx.    Set I = I + Vx.
    LDFONT, // Fx29 - LD F, Vx.    Set I = location of sprite for digit Vx.
    LDBCD, // Fx33 - LD B, Vx.   Store BCD representation of Vx in memory locations I, I+1, and I+2.
    STRR, // Fx55 - LD [I], Vx.   Store registers V0 through Vx in memory starting at location I.
    RDR, // Fx65 - LD Vx, [I].    Read registers V0 through Vx from memory starting at location I.
};

pub const Instruction = struct {
    // FIXME this duplicates info - should use some kind of union
    raw: RawInstruction,

    op: OpCode,
    addr: ?u12 = null,
    r0: ?u4 = null,
    r1: ?u4 = null,
    nibble: ?u4 = null,
    byte: ?u8 = null,

    pub fn from_u8(ri: RawInstruction) !Instruction {
        const x = instr_u4(ri);
        const r0 = x[1];
        const r1 = x[2];
        const nibble = x[3];
        const byte = ri[1];
        const addr = @as(u12, x[1]) << 8 | @as(u12, x[2]) << 4 | @as(u12, x[3]) << 0;

        errdefer std.debug.print("Encountered invalid instruction: 0x{X}\n", .{instr_u16(ri)});

        const parsed = switch (x[0]) {
            0x0 => switch (addr) {
                0x0E0 => Instruction{ .raw = ri, .op = OpCode.CLS },
                0x0EE => Instruction{ .raw = ri, .op = OpCode.RET },
                else => Instruction{ .raw = ri, .op = OpCode.SYS, .addr = addr },
            },
            0x1 => Instruction{ .raw = ri, .op = OpCode.JP, .addr = addr },
            0x2 => Instruction{ .raw = ri, .op = OpCode.CALL, .addr = addr },
            0x3 => Instruction{ .raw = ri, .op = OpCode.SERB, .r0 = r0, .byte = byte },
            0x4 => Instruction{ .raw = ri, .op = OpCode.SNERB, .r0 = r0, .byte = byte },
            0x5 => switch (nibble) {
                0x0 => Instruction{ .raw = ri, .op = OpCode.SERR, .r0 = r0, .r1 = r1 },
                else => error.INVALID_INSTRUCTION,
            },
            0x6 => Instruction{ .raw = ri, .op = OpCode.LDRB, .r0 = r0, .byte = byte },
            0x7 => Instruction{ .raw = ri, .op = OpCode.ADDRB, .r0 = r0, .byte = byte },
            0x8 => switch (nibble) {
                0x0 => Instruction{ .raw = ri, .op = OpCode.LDRR, .r0 = r0, .r1 = r1 },
                0x1 => Instruction{ .raw = ri, .op = OpCode.ORRR, .r0 = r0, .r1 = r1 },
                0x2 => Instruction{ .raw = ri, .op = OpCode.ANDRR, .r0 = r0, .r1 = r1 },
                0x3 => Instruction{ .raw = ri, .op = OpCode.XORRR, .r0 = r0, .r1 = r1 },
                0x4 => Instruction{ .raw = ri, .op = OpCode.ADDRR, .r0 = r0, .r1 = r1 },
                0x5 => Instruction{ .raw = ri, .op = OpCode.SUBRR, .r0 = r0, .r1 = r1 },
                0x6 => Instruction{ .raw = ri, .op = OpCode.SHR, .r0 = r0, .r1 = r1 },
                0x7 => Instruction{ .raw = ri, .op = OpCode.SUBN, .r0 = r0, .r1 = r1 },
                0xE => Instruction{ .raw = ri, .op = OpCode.SHL, .r0 = r0, .r1 = r1 },
                else => error.INVALID_INSTRUCTION,
            },
            0x9 => switch (nibble) {
                0x0 => Instruction{ .raw = ri, .op = OpCode.SNERR, .r0 = r0, .r1 = r1 },
                else => error.INVALID_INSTRUCTION,
            },
            0xA => Instruction{ .raw = ri, .op = OpCode.LDI, .addr = addr },
            0xB => Instruction{ .raw = ri, .op = OpCode.JPR, .addr = addr },
            0xC => Instruction{ .raw = ri, .op = OpCode.RND, .r0 = r0, .byte = byte },
            0xD => Instruction{ .raw = ri, .op = OpCode.DRW, .r0 = r0, .r1 = r1, .nibble = nibble },
            0xE => switch (byte) {
                0x9E => Instruction{ .raw = ri, .op = OpCode.SKP, .r0 = r0 },
                0xA1 => Instruction{ .raw = ri, .op = OpCode.SKNP, .r0 = r0 },
                else => error.INVALID_INSTRUCTION,
            },
            0xF => switch (byte) {
                0x07 => Instruction{ .raw = ri, .op = OpCode.RDDT, .r0 = r0 },
                0x0A => Instruction{ .raw = ri, .op = OpCode.WAITK, .r0 = r0 },
                0x15 => Instruction{ .raw = ri, .op = OpCode.SETDT, .r0 = r0 },
                0x18 => Instruction{ .raw = ri, .op = OpCode.SETST, .r0 = r0 },
                0x1E => Instruction{ .raw = ri, .op = OpCode.ADDIR, .r0 = r0 },
                0x29 => Instruction{ .raw = ri, .op = OpCode.LDFONT, .r0 = r0 },
                0x33 => Instruction{ .raw = ri, .op = OpCode.LDBCD, .r0 = r0 },
                0x55 => Instruction{ .raw = ri, .op = OpCode.STRR, .r0 = r0 },
                0x65 => Instruction{ .raw = ri, .op = OpCode.RDR, .r0 = r0 },
                else => error.INVALID_INSTRUCTION,
            },
        };

        // std.debug.print("raw: {x} -> parsed: {any}\n", .{ ri, parsed });
        return parsed;
    }

    pub fn from_u4(s4: [4]u4) !Instruction {
        const raw = [2]u8{
            @as(u8, s4[0]) << 4 | @as(u8, s4[1]),
            @as(u8, s4[2]) << 4 | @as(u8, s4[3]),
        };
        return from_u8(raw);
    }

    pub fn from_u16(instr: u16) !Instruction {
        const raw = [2]u8{ @intCast(instr >> 8), @intCast(instr & 0xff) };
        return from_u8(raw);
    }

    pub fn to_u4(self: Instruction) [4]u4 {
        return instr_u4(self.raw);
    }

    pub fn to_u8(self: Instruction) [2]u8 {
        return self.raw;
    }

    pub fn to_u16(self: Instruction) u16 {
        return instr_u16(self.raw);
    }
};

// FIXME: this is a poorly defined union type.
// Can't use union or packed union due to Zig semantics.
pub const RawInstruction = [2]u8;

pub fn instr_u4(ri: RawInstruction) [4]u4 {
    return [4]u4{
        @intCast(ri[0] >> 4),
        @intCast(ri[0] & 0xf),
        @intCast(ri[1] >> 4),
        @intCast(ri[1] & 0xf),
    };
}

pub fn instr_u16(ri: RawInstruction) u16 {
    return @as(u16, ri[0]) << 8 | @as(u16, ri[1]);
}
