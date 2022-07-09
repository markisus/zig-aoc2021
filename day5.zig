const std = @import("std");

const Coordinate = struct {
    x: i32,
    y: i32,

    pub fn minus(self: *const Coordinate, other: Coordinate) Coordinate {
        var result = self.*;
        result.x -= other.x;
        result.y -= other.y;
        return result;
    }

    pub fn plus(self: *const Coordinate, other: Coordinate) Coordinate {
        var result = self.*;
        result.x += other.x;
        result.y += other.y;
        return result;
    }

    pub fn dot(self: *const Coordinate, other: Coordinate) i32 {
        return self.x * other.x + self.y * other.y;
    }

    pub fn l1Normalized(self: *const Coordinate) Coordinate {
        const absx: i32 = std.math.absInt(self.x) catch unreachable;
        const absy: i32 = std.math.absInt(self.y) catch unreachable;
        const delta_norm: i32 = std.math.max(absx, absy);
        var result = self.*;
        result.x = @divExact(result.x, delta_norm);
        result.y = @divExact(result.y, delta_norm);
        return result;
    }
};

const LineSegment = struct {
    base: Coordinate,
    delta: Coordinate,
    delta_l2: i32,
    end: i32,

    pub fn containsPoint(self: *const LineSegment, c: *const Coordinate) bool {
        const dist = c.*.minus(self.base).dot(self.delta);
        return (0 <= dist) and (dist <= self.end);
    }

    pub fn init(ln: [2]Coordinate) LineSegment {
        var result: LineSegment = undefined;
        result.base = ln[0];

        const delta_unnormalized = ln[1].minus(ln[0]);
        result.delta = delta_unnormalized.l1Normalized();
        result.end = result.delta.dot(delta_unnormalized);
        result.delta_l2 = result.delta.dot(result.delta);
        return result;
    }
};

const HomogPoint = struct {
    a: i32,
    b: i32,
    c: i32,

    pub fn cross(self: *const HomogPoint, other: *const HomogPoint) HomogPoint {
        var result: HomogPoint = undefined;
        result.a = self.b * other.*.c - self.c * other.*.b;
        result.b = self.c * other.*.a - self.a * other.*.c;
        result.c = self.a * other.*.b - self.b * other.*.a;
        return result;
    }

    pub fn dotCoordinate(self: *const HomogPoint, coordinate: *const Coordinate) i32 {
        return self.a * coordinate.*.x + self.b * coordinate.*.y + self.c;
    }

    pub fn isZero(self: *const HomogPoint) bool {
        return self.a == 0 and self.b == 0 and self.c == 0;
    }
};

pub fn lineToHomog(ln: [2]Coordinate) HomogPoint {
    var self: HomogPoint = undefined;
    const delta: Coordinate = ln[1].minus(ln[0]).l1Normalized();
    const deltaPerp: Coordinate = .{ .x = -delta.y, .y = delta.x };

    std.debug.assert(delta.dot(deltaPerp) == 0);

    self.a = deltaPerp.x;
    self.b = deltaPerp.y;
    self.c = -(ln[0].dot(deltaPerp));
    std.debug.assert(self.a * ln[1].x + self.b * ln[1].y + self.c == 0);
    std.debug.assert(self.a * ln[0].x + self.b * ln[0].y + self.c == 0);

    return self;
}

pub fn homogToCoordinate(pt: *const HomogPoint) ?Coordinate {
    if (pt.*.c == 0) {
        return null;
    }
    var result: Coordinate = undefined;
    result.x = @divTrunc(pt.*.a, pt.*.c);
    result.y = @divTrunc(pt.*.b, pt.*.c);

    if (result.x * pt.*.c == pt.*.a and
        result.y * pt.*.c == pt.*.b)
    {
        return result;
    } else {
        // non-integral solution
        return null;
    }
}

pub fn getIntersectionHomog(ln0: Coordinate[2], ln1: Coordinate[2]) HomogPoint {
    const ln0_homog: HomogPoint = lineToHomog(ln0);
    const ln1_homog: HomogPoint = lineToHomog(ln1);
    return ln0_homog.cross(&ln1_homog);
}

const CollisionMap = std.HashMap(Coordinate, u16, std.hash_map.AutoContext(Coordinate), 80);

pub fn addCollision(collisions: *CollisionMap, coordinate: Coordinate) !void {
    var gop = try collisions.getOrPut(coordinate);
    if (gop.found_existing) {
        gop.value_ptr.* += 1;
    } else {
        gop.value_ptr.* = 2;
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const leaks = gpa.deinit();
        if (leaks) {
            std.debug.print("Leaks!", .{});
        }
    }

    const test_mode: bool = false;
    const data_file = if (test_mode) "day5_test.txt" else "day5.txt";
    const num_lines = if (test_mode) 10 else 500;

    var file = try std.fs.cwd().openFile(data_file, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var buf: [1024]u8 = undefined;

    // const num_lines = 10;
    var lines: [num_lines][2]Coordinate = undefined;
    var line_no: u16 = 0;
    while (try in_stream.readUntilDelimiterOrEof(buf[0..], '\n')) |line| : (line_no += 1) {
        var tokens = std.mem.tokenize(u8, line, ", ->");
        var i: u8 = 0;
        while (i < 2) : (i += 1) {
            const xt = tokens.next().?;
            const yt = tokens.next().?;
            const x = try std.fmt.parseInt(i16, xt, 10);
            const y = try std.fmt.parseInt(i16, yt, 10);
            lines[line_no][i].x = x;
            lines[line_no][i].y = y;
        }
    }

    // make sure we read exactly 500 lines
    std.debug.assert(line_no == num_lines);

    var collisions = CollisionMap.init(allocator);
    defer collisions.deinit();

    var line_a: u16 = 0;
    while (line_a < num_lines) : (line_a += 1) {
        const line_seg_a = LineSegment.init(lines[line_a]);
        const line_seg_a_homog = lineToHomog(lines[line_a]);
        var line_b: u16 = line_a + 1;
        while (line_b < num_lines) : (line_b += 1) {
            const line_seg_b = LineSegment.init(lines[line_b]);
            const line_seg_b_homog = lineToHomog(lines[line_b]);
            const intersection_homog = line_seg_a_homog.cross(&line_seg_b_homog);
            if (intersection_homog.isZero()) {
                // overlapping lines - do a line walk
                var current = line_seg_a.base;
                var travel: i32 = 0;
                var intersection_started = false;
                while (travel <= line_seg_a.end) {
                    // std.debug.print("line walk top, travel {d} / {d}\n", .{ travel, line_seg_a.end });
                    if (line_seg_b.containsPoint(&current)) {
                        intersection_started = true;
                        try addCollision(&collisions, current);
                    } else {
                        if (intersection_started) break;
                    }
                    current = current.plus(line_seg_a.delta);
                    travel += line_seg_a.delta_l2;
                }
            } else if (homogToCoordinate(&intersection_homog)) |coordinate| {
                if (line_seg_a.containsPoint(&coordinate) and line_seg_b.containsPoint(&coordinate)) {
                    try addCollision(&collisions, coordinate);
                }
            } else {
                // parallel lines, non-overlapping
                // std.debug.print("\tno integral intersection\n", .{});
            }
        }
    }

    // count the number of points at where two points overlap
    var num_dangerous: i32 = 0;
    var collisions_it = collisions.iterator();
    while (collisions_it.next()) |entry| {
        if (entry.value_ptr.* >= 2) {
            num_dangerous += 1;
        }
    }

    // count the number of point to line intersections
    std.debug.print("num dangerous {d}\n", .{num_dangerous});
}
