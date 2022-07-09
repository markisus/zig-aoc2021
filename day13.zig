const std = @import("std");
const util = @import("util.zig");

const Grid = util.Grid(u8, ' ');

const Coord = struct {
    const Self = @This();

    x: u32,
    y: u32,

    pub fn flip(self: *const Self, axis: u8, line: u32) Coord {
        switch (axis) {
            'x' => {
                return self.flipX(line);
            },
            'y' => {
                return self.flipY(line);
            },
            else => {
                return self.*;
            },
        }
    }

    pub fn flipX(self: *const Self, xline: u32) Coord {
        // flipping on 1 maps 2 to 0
        // flipping on x maps x+i to x-i
        var new_x: u32 = self.x;
        if (new_x > xline) {
            const delta = new_x - xline;
            new_x = xline - delta;
        }
        return .{ .x = new_x, .y = self.y };
    }

    pub fn flipY(self: *const Self, yline: u32) Coord {
        var new_y: u32 = self.y;
        if (new_y > yline) {
            const delta = new_y - yline;
            new_y = yline - delta;
        }
        return .{ .x = self.x, .y = new_y };
    }
};

pub fn handleInput(filename: []const u8, coord_set: *CoordSet, coord_set_alt: *CoordSet, max_folds: u32) !*CoordSet {
    var file = try std.fs.cwd().openFile(filename, .{});
    var buf: [50]u8 = undefined;
    var saw_empty_line = false;

    var from_coord_set: *const *CoordSet = &coord_set;
    var to_coord_set: *const *CoordSet = &coord_set_alt;
    var num_folds: u32 = 0;

    while (try file.reader().readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        if (line.len == 0) {
            saw_empty_line = true;
            continue;
        }

        if (!saw_empty_line) {
            // coordinate
            var tokens = std.mem.tokenize(u8, line, ",");
            const x_s = tokens.next().?;
            const y_s = tokens.next().?;
            const x = try std.fmt.parseInt(u32, x_s, 10);
            const y = try std.fmt.parseInt(u32, y_s, 10);
            try coord_set.put(Coord{ .x = x, .y = y }, {});
            // std.debug.print("{d} {d}\n", .{ x, y });
        } else {
            // fold instruction
            var tokens = std.mem.tokenize(u8, line, "=");
            const instr = tokens.next().?;
            const xy: u8 = instr[instr.len - 1];
            const number_s = tokens.next().?;
            const number = try std.fmt.parseInt(u32, number_s, 10);

            to_coord_set.*.clearAndFree();
            var it = from_coord_set.*.iterator();
            while (it.next()) |kv| {
                try to_coord_set.*.put(kv.key_ptr.flip(xy, number), {});
            }

            var tmp = to_coord_set;
            to_coord_set = from_coord_set;
            from_coord_set = tmp;

            num_folds += 1;
            if (num_folds >= max_folds) break;
        }
    }
    return from_coord_set.*;
}

const CoordSet = std.AutoHashMap(Coord, void);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) unreachable;

    var coord_set = CoordSet.init(gpa.allocator());
    var coord_set_alt = CoordSet.init(gpa.allocator());
    defer coord_set.deinit();
    defer coord_set_alt.deinit();

    var result_set = try handleInput("day13.txt", &coord_set, &coord_set_alt, 1);
    std.debug.print("num visible = {d}\n", .{result_set.count()});

    coord_set.clearAndFree();
    coord_set_alt.clearAndFree();
    result_set = try handleInput("day13.txt", &coord_set, &coord_set_alt, 10000);

    var max_x: u32 = 0;
    var max_y: u32 = 0;
    {
        var it = result_set.iterator();
        while (it.next()) |kv| {
            const x = kv.key_ptr.x;
            const y = kv.key_ptr.y;
            max_x = @maximum(max_x, x);
            max_y = @maximum(max_y, y);
        }
    }

    var display = try Grid.init(gpa.allocator(), max_y + 1, max_x + 1);
    defer display.deinit();
    {
        var it = result_set.iterator();
        while (it.next()) |kv| {
            display.getPtr(kv.key_ptr.y, kv.key_ptr.x).?.* = '#';
        }
    }
    display.print();
}
