const std = @import("std");
const Allocator = std.mem.Allocator;
const ProgramState = @import("program.zig").ProgramState;

const FileErrors = error{
    INVALID_HEX,
    FAILED_TO_READ_FILE,
};

fn read_file(allocator: Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, std.fs.File.OpenFlags{});
    defer file.close();

    const stat = try file.stat();
    const data = try allocator.alloc(u8, stat.size);
    @memset(data, 0);
    const nbytes = try file.readAll(data);
    if (nbytes != stat.size) return error.FAILED_TO_READ_FILE;
    return data;
}

// Takes in OCTO hex string and outputs raw binary
// See https://johnearnest.github.io/Octo
fn convert_binary_data(allocator: Allocator, data: []const u8) ![]u8 {
    var binary_data = try allocator.alloc(u8, data.len); // overallocates
    @memset(binary_data, 0);

    var write_pos: usize = 0;
    var read_pos: usize = 0;
    while (read_pos < data.len) {
        const hexbyte = data[read_pos .. read_pos + 4];
        if (!std.mem.startsWith(u8, hexbyte, "0x")) return error.INVALID_HEX;
        const value = try std.fmt.parseUnsigned(u8, hexbyte[2..], 0x10);
        read_pos += 5;
        binary_data[write_pos] = value;
        write_pos += 1;
    }

    return binary_data;
}

fn load_program(binary_data: []const u8) !ProgramState {
    var prg = ProgramState.init();
    try prg.load_memory(binary_data);
    return prg;
}

var main_allocator: ?Allocator = null;
pub fn get_allocator() Allocator {
    if (main_allocator != null) return main_allocator.?;
    main_allocator = std.heap.page_allocator;
    return main_allocator.?;
}

pub fn run(path: []const u8) !void {
    const allocator = get_allocator();
    const file_data = try read_file(allocator, path);
    defer allocator.free(file_data);
    const binary_data = try convert_binary_data(allocator, file_data);
    defer allocator.free(binary_data);
    var prg = try load_program(binary_data);
    defer prg.close();
    prg.run() catch |e| switch (e) {
        error.INFINITE_LOOP => {
            std.log.info("Program entered an infinite loop, exiting.", .{});
            std.process.exit(0);
        },
        else => return e,
    };
}
