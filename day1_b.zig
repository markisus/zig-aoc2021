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
    var rolling: [3]u16 = .{maxUint(u16)} ** 3;
    var idx: u8 = 0;
    var last_sum = maxUint(u16);

    while (try in_stream.readUntilDelimiterOrEof(buf[0..], '\n')) |line| : (idx = (idx + 1) % 3) {
        var result = try std.fmt.parseInt(u16, line, 10);
        rolling[idx] = result;

        var sum: u16 = 0;
        for (rolling) |value| {
            if (value == maxUint(u16)) {
                sum = maxUint(u16);
                break;
            } else {
                sum += value;
            }
        }

        if (sum > last_sum) {
            increments += 1;
        }
        last_sum = sum;
    }
    std.debug.print("increments {d}\n", .{increments});
}
