const std = @import("std");
const testing = std.testing;
const mem = @import("./mem.zig");

test "parse opcode SYS" {
    const instr = try mem.Instruction.from_split4([4]u4{ 0, 1, 2, 3 });
    try testing.expectEqual(mem.OpCode.SYS, instr.op);
    try testing.expectEqual(1 << 8 | 2 << 4 | 3, instr.addr);
    try testing.expectEqual(null, instr.r0);
    try testing.expectEqual(null, instr.r1);
    try testing.expectEqual(null, instr.nibble);
    try testing.expectEqual(null, instr.byte);
}

test "parse opcode CLS" {
    const instr = try mem.Instruction.from_split4([4]u4{ 0, 0, 0xE, 0 });
    try testing.expectEqual(mem.OpCode.CLS, instr.op);
    try testing.expectEqual(null, instr.r0);
    try testing.expectEqual(null, instr.r1);
    try testing.expectEqual(null, instr.nibble);
    try testing.expectEqual(null, instr.byte);
    try testing.expectEqual(null, instr.addr);
}

test "parse opcode RET" {
    const instr = try mem.Instruction.from_split4([4]u4{ 0, 0, 0xE, 0xE });
    try testing.expectEqual(mem.OpCode.RET, instr.op);
    try testing.expectEqual(null, instr.r0);
    try testing.expectEqual(null, instr.r1);
    try testing.expectEqual(null, instr.nibble);
    try testing.expectEqual(null, instr.byte);
    try testing.expectEqual(null, instr.addr);
}

// todo: all others lol
