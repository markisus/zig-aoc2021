const std = @import("std");

pub fn maxUint(comptime u: type) u {
    std.debug.assert(@typeInfo(u).Int.signedness == std.builtin.Signedness.unsigned);
    var b: u = 0;
    return ~b;
}

pub fn main() !void {
    var file = try std.fs.cwd().openFile("day1.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var buf: [10]u8 = undefined;

    var increments: u16 = 0;
    var last = maxUint(u16);
    while (try in_stream.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        var result = try std.fmt.parseInt(u16, line, 10);
        if (result > last) {
            increments += 1;
        }
        last = result;
    }
    std.debug.print("increments {d}\n", .{increments});
}
