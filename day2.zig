const std = @import("std");

pub fn maxUint(comptime u: type) u {
    std.debug.assert(@typeInfo(u).Int.signedness == std.builtin.Signedness.unsigned);
    var b: u = 0;
    return ~b;
}

pub fn main() !void {
    var file = try std.fs.cwd().openFile("day3.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var buf: [10]u8 = undefined;

    var distance: i32 = 0;
    var depth: i32 = 0;

    const use_aim = true;
    var aim: i32 = 0;

    while (try in_stream.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        // read until space
        var space_idx: u16 = 0;
        while (space_idx < line.len) : (space_idx += 1) {
            if (line[space_idx] == ' ') break;
        }

        const first_char = line[0];
        const movement_str = line[space_idx + 1 ..];
        const movement = try std.fmt.parseInt(i32, movement_str, 10);
        // std.debug.print("fchar={c} move={d}\n", .{ first_char, movement });

        if (!use_aim) {
            switch (first_char) {
                'f' => {
                    distance += movement;
                },
                'd' => {
                    depth += movement;
                },
                'u' => {
                    depth -= movement;
                },
                else => {
                    unreachable;
                },
            }
        } else {
            switch (first_char) {
                'f' => {
                    distance += movement;
                    depth += aim * movement;
                },
                'd' => {
                    aim += movement;
                },
                'u' => {
                    aim -= movement;
                },
                else => {
                    unreachable;
                },
            }
            // std.debug.print("depth={d} distance={d}, aim={d}\n", .{ depth, distance, aim });
        }
    }

    std.debug.print("depth={d} distance={d}\n", .{ depth, distance });
    std.debug.print("product={d}\n", .{depth * distance});
}
