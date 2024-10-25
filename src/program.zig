const std = @import("std");
const testing = std.testing;
const mem = @import("mem.zig");
const display = @import("display.zig");
const errors = @import("errors.zig");
const instructions = @import("instructions.zig");
const input = @import("input.zig");

const OpCode = instructions.OpCode;
const Instruction = instructions.Instruction;
const RawInstruction = instructions.RawInstruction;

// See 1 & 2 footnotes
// https://github-wiki-see.page/m/mattmikolay/chip-8/wiki/CHIP%E2%80%908-Instruction-Set
const ENABLE_BUG_COMPATIBILITY = true;

pub const ProgramState = struct {
    registers: mem.Registers,
    stack: mem.StackBuffer,
    memory: mem.RawMemoryBuffer,
    display: display.DisplayState,
    randomizer: std.Random.DefaultPrng,
    input: input.InputState,

    pub fn init() ProgramState {
        var prg = ProgramState{
            .registers = mem.Registers.init(),
            .stack = [_]u16{0} ** 16,
            .memory = [_]u8{0} ** 4096,
            .display = display.DisplayState.init(),
            .randomizer = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp())),
            .input = input.InputState.init(),
        };
        prg.load_builtin_fonts();
        return prg;
    }

    pub fn load_memory(self: *ProgramState, binary_data: []const u8) !void {
        if (binary_data.len > mem.MEMORY_END - mem.MEMORY_START) return error.INSUFFICIENT_BUFFER;
        @memcpy(self.memory[mem.MEMORY_START .. mem.MEMORY_START + binary_data.len], binary_data);
    }

    pub fn close(self: *ProgramState) void {
        std.log.info("Bye.", .{});
        _ = self;
    }

    fn load_builtin_fonts(self: *ProgramState) void {
        const offset = mem.BUILTIN_FONT_START;
        for (0..display.BuiltinSprites.len) |k| {
            // FIXME why do I need to iterate here... this is all a single buffer, isn't it?
            @memcpy(self.memory[offset + k * 5 .. offset + (k + 1) * 5], &display.BuiltinSprites[k]);
        }
    }

    pub fn current_instruction_u8(self: *const ProgramState) !RawInstruction {
        const pc = self.registers.PC;
        const offset = pc * 2 + mem.MEMORY_START;
        if (offset + 1 > self.memory.len) return error.JUMP_OUT_OF_BOUNDS;
        const ri = [2]u8{ self.memory[offset], self.memory[offset + 1] };
        return ri;
    }

    pub fn current_instruction(self: *const ProgramState) !Instruction {
        const ri = try self.current_instruction_u8();
        return Instruction.from_u8(ri);
    }

    pub fn execute_instruction(self: *ProgramState, instr: Instruction) !void {
        std.debug.print("0x{X} 0x{X} -> {any}\n", .{ instr.raw[0], instr.raw[1], instr });
        try switch (instr.op) {
            OpCode.SYS => {
                // FIXME: 0x00FF can be used to set 'hires' mode.
                self.registers.PC += 1;
            },
            OpCode.CLS => self.display.execute_clear(self, instr),
            OpCode.RET => self.ret(),
            OpCode.JP => self.jump(instr.addr.?),
            OpCode.CALL => self.call(instr.addr.?),
            OpCode.SERB => self.skipif(self.registers.Vx[instr.r0.?] == instr.byte.?),
            OpCode.SNERB => self.skipif(self.registers.Vx[instr.r0.?] != instr.byte.?),
            OpCode.SERR => self.skipif(self.registers.Vx[instr.r0.?] == self.registers.Vx[instr.r1.?]),
            OpCode.LDRB => self.exec_load(instr.r0.?, instr.byte.?),
            OpCode.ADDRB => self.exec_add(instr.r0.?, instr.byte.?, false),
            OpCode.LDRR => self.exec_load(instr.r0.?, self.registers.Vx[instr.r1.?]),
            OpCode.ORRR => self.exec_or(instr.r0.?, self.registers.Vx[instr.r1.?]),
            OpCode.ANDRR => self.exec_and(instr.r0.?, self.registers.Vx[instr.r1.?]),
            OpCode.XORRR => self.exec_xor(instr.r0.?, self.registers.Vx[instr.r1.?]),
            OpCode.ADDRR => self.exec_add(instr.r0.?, self.registers.Vx[instr.r1.?], true),
            OpCode.SUBRR => self.exec_sub(instr.r0.?, self.registers.Vx[instr.r1.?], true),
            OpCode.SHR => self.exec_shift(instr.r0.?, self.registers.Vx[instr.r1.?], true),
            OpCode.SUBN => self.exec_subn(instr.r0.?, self.registers.Vx[instr.r1.?], true),
            OpCode.SHL => self.exec_shift(instr.r0.?, self.registers.Vx[instr.r1.?], false),
            OpCode.SNERR => self.skipif(self.registers.Vx[instr.r0.?] != self.registers.Vx[instr.r1.?]),
            OpCode.LDI => self.exec_ldi(instr.addr.?),
            OpCode.JPR => self.jump(instr.addr.? + self.registers.Vx[0]),
            OpCode.RND => self.exec_rnd(instr.r0.?, instr.byte.?),
            OpCode.DRW => self.display.execute_draw(self, instr),
            OpCode.SKP => self.skipif(self.input.pressed_keys[self.registers.Vx[instr.r0.?]]),
            OpCode.SKNP => self.skipif(!self.input.pressed_keys[self.registers.Vx[instr.r0.?]]),
            OpCode.RDDT => self.exec_load(instr.r0.?, self.registers.DT),
            OpCode.WAITK => self.exec_waitk(instr.r0.?),
            OpCode.SETDT => self.exec_setdt(self.registers.Vx[instr.r0.?]),
            OpCode.SETST => self.exec_setst(self.registers.Vx[instr.r0.?]),
            OpCode.ADDIR => self.exec_addi(self.registers.Vx[instr.r0.?]),
            OpCode.LDFONT => self.exec_ldi(mem.BUILTIN_FONT_START + @as(u12, self.registers.Vx[instr.r0.?]) * 5),
            OpCode.LDBCD => self.exec_ldbcd(self.registers.Vx[instr.r0.?]),
            OpCode.STRR => self.exec_strr(instr.r0.?),
            OpCode.RDR => self.exec_rdr(instr.r0.?),
        };
        try self.check_pc();
        if (self.registers.DT > 0) {
            // std.time.sleep(std.time.ns_per_ms * 500);
            const key = try self.input.maybe_wait_key();
            std.debug.print("Got key: {?x}\n", .{key});
            self.registers.DT -= 1;
        }
        if (self.registers.ST > 0) {
            std.debug.print("Audio is playing\n", .{});
            self.registers.ST -= 1;
        }
    }

    fn check_pc(self: *const ProgramState) !void {
        const offset = self.registers.PC * 2 + mem.MEMORY_START;
        if (offset < mem.MEMORY_START or offset >= self.memory.len) {
            return error.JUMP_OUT_OF_BOUNDS;
        }
    }

    fn ret(self: *ProgramState) !void {
        if (self.registers.SP == 0) return error.STACK_OVERFLOW;
        const addr = self.stack[self.registers.SP - 1];
        if (addr >= self.memory.len) return error.JUMP_OUT_OF_BOUNDS;
        self.registers.PC = addr + 1;
        self.registers.SP -= 1;
    }

    fn jump(self: *ProgramState, addr: u12) !void {
        if (addr >= self.memory.len) return error.JUMP_OUT_OF_BOUNDS;
        // self.registers.PC = addr;
        const old_pc = self.registers.PC;
        self.registers.PC = (addr - mem.MEMORY_START) / 2;
        if (self.registers.PC == old_pc) {
            return error.INFINITE_LOOP;
        }
    }

    fn call(self: *ProgramState, addr: u12) !void {
        if (addr >= self.memory.len) return error.JUMP_OUT_OF_BOUNDS;
        if (self.registers.SP >= self.stack.len) return error.STACK_OVERFLOW;
        self.registers.SP += 1;
        self.stack[self.registers.SP - 1] = self.registers.PC;
        // self.registers.PC = addr;
        self.registers.PC = (addr - mem.MEMORY_START) / 2;
    }

    fn skipif(self: *ProgramState, cond: bool) !void {
        self.registers.PC += if (cond) 2 else 1;
    }

    fn exec_load(self: *ProgramState, register: u4, value: u8) !void {
        try self.registers.set_vx(register, value);
        self.registers.PC += 1;
    }

    fn exec_add(self: *ProgramState, register: u4, value: u8, set_vf: bool) !void {
        const new_value = @as(u16, self.registers.Vx[register]) + @as(u16, value);
        if (set_vf) {
            self.registers.Vx[0xF] = if (new_value > 0xFF) 1 else 0;
        }
        try self.registers.set_vx(register, @truncate(new_value & 0xFF));
        self.registers.PC += 1;
    }

    fn exec_sub(self: *ProgramState, register: u4, value: u8, set_vf: bool) !void {
        var new_value = @as(i16, self.registers.Vx[register]) - @as(i16, value);
        if (new_value < 0) {
            if (set_vf) self.registers.Vx[0xF] = 0;
            new_value = new_value + 0x100;
        } else {
            if (set_vf) self.registers.Vx[0xF] = 1;
        }
        const value_u8: u8 = @intCast(new_value & 0xFF);
        try self.registers.set_vx(register, value_u8);
        self.registers.PC += 1;
    }

    fn exec_subn(self: *ProgramState, register: u4, value: u8, set_vf: bool) !void {
        var new_value = @as(i16, value) - @as(i16, self.registers.Vx[register]);
        if (new_value > 0xFF) {
            if (set_vf) self.registers.Vx[0xF] = 1;
            new_value = new_value - 0x100;
        } else {
            if (set_vf) self.registers.Vx[0xF] = 0;
        }
        const value_u8: u8 = @intCast(new_value & 0xFF);
        try self.registers.set_vx(register, value_u8);
        self.registers.PC += 1;
    }

    fn exec_or(self: *ProgramState, register: u4, value: u8) !void {
        const new_value = self.registers.Vx[register] | value;
        try self.registers.set_vx(register, new_value);
        self.registers.PC += 1;
    }

    fn exec_xor(self: *ProgramState, register: u4, value: u8) !void {
        const new_value = self.registers.Vx[register] ^ value;
        try self.registers.set_vx(register, new_value);
        self.registers.PC += 1;
    }

    fn exec_and(self: *ProgramState, register: u4, value: u8) !void {
        const new_value = self.registers.Vx[register] & value;
        try self.registers.set_vx(register, new_value);
        self.registers.PC += 1;
    }

    fn exec_shift(self: *ProgramState, register: u4, value: u8, right: bool) !void {
        const val = if (ENABLE_BUG_COMPATIBILITY) self.registers.Vx[register] else value;
        if (right) {
            self.registers.Vx[0xF] = val & 0x1;
            try self.registers.set_vx(register, val >> 1);
        } else {
            self.registers.Vx[0xF] = val >> 7;
            try self.registers.set_vx(register, val << 1);
        }
        self.registers.PC += 1;
    }

    fn exec_ldi(self: *ProgramState, addr: u12) !void {
        self.registers.I = addr;
        self.registers.PC += 1;
    }

    fn exec_rnd(self: *ProgramState, register: u4, byte: u8) !void {
        const value: u8 = @truncate(self.randomizer.next() & 0xFF & byte);
        try self.registers.set_vx(register, value);
        self.registers.PC += 1;
    }

    fn exec_waitk(self: *ProgramState, register: u4) !void {
        const pressed_key = try self.input.wait_key();
        try self.registers.set_vx(register, pressed_key);
        self.registers.PC += 1;
    }

    fn exec_setdt(self: *ProgramState, value: u8) !void {
        self.registers.DT = value;
        self.registers.PC += 1;
    }

    fn exec_setst(self: *ProgramState, value: u8) !void {
        self.registers.ST = value;
        self.registers.PC += 1;
    }

    fn exec_addi(self: *ProgramState, value: u8) !void {
        const new_value = self.registers.I + @as(u16, value);
        self.registers.I = new_value;
        self.registers.PC += 1;
    }

    fn exec_ldbcd(self: *ProgramState, value: u8) !void {
        self.memory[self.registers.I] = value / 100;
        self.memory[self.registers.I + 1] = (value / 10) % 10;
        self.memory[self.registers.I + 2] = value % 10;
        self.registers.PC += 1;
    }

    fn exec_strr(self: *ProgramState, register: u4) !void {
        for (0..register + 1) |r| {
            self.memory[self.registers.I + r] = self.registers.Vx[r];
        }
        self.registers.PC += 1;
    }

    fn exec_rdr(self: *ProgramState, register: u4) !void {
        for (0..register + 1) |r| {
            self.registers.Vx[r] = self.memory[self.registers.I + r];
        }
        self.registers.PC += 1;
    }

    // main loop
    pub fn run(self: *ProgramState) !void {
        var display_buffer = [_]u8{0} ** (display.DUMP_BUFSIZE);

        std.log.info("Starting program", .{});
        std.debug.print("{any}\n", .{self.registers});

        var tick: usize = 0;
        while (true) {
            std.debug.print("TICK: {d}\n", .{tick});

            const instr = try self.current_instruction();
            try self.execute_instruction(instr);

            std.debug.print("{any}\n", .{self.registers});
            std.debug.print("{any}\n", .{self.input});
            if (instr.op == OpCode.DRW or instr.op == OpCode.CLS) {
                try self.display.dumps(&display_buffer, true);
                _ = try std.fmt.bufPrint(&display_buffer, "* TICK: {d} ", .{tick});
                // std.debug.print("TICK: {d}\n", args: anytype)
                std.debug.print("{s}\n", .{display_buffer});
            }

            // break now :)
            if (tick >= 1000) break;

            tick += 1;
        }
    }
};

test "can create program state" {
    const st = ProgramState.init();

    const curi = try st.current_instruction();
    try testing.expectEqual(0x0, curi.to_u16());

    const builtin_font_sprite0 = st.memory[mem.BUILTIN_FONT_START .. mem.BUILTIN_FONT_START + 5];
    try testing.expectEqualSlices(u8, &display.BuiltinSprites[0], builtin_font_sprite0);
}
