const std = @import("std");

const Coord = struct { row: i64, col: i64 };
const CoordSet = std.AutoHashMap(Coord, void);
const Image = struct {
    const Self = @This();

    algo: [512]u8,
    allocator: std.mem.Allocator,
    max_coord: Coord,
    min_coord: Coord,
    data: CoordSet,
    alt_data: CoordSet,
    oob_on: bool,

    pub fn init(allocator: std.mem.Allocator) Self {
        var self: Self = undefined;
        self.allocator = allocator;
        self.data = CoordSet.init(allocator);
        self.resetBounds();
        self.oob_on = false;
        return self;
    }

    pub fn resetBounds(self: *Self) void {
        self.max_coord = Coord{ .row = std.math.minInt(i64), .col = std.math.minInt(i64) };
        self.min_coord = Coord{ .row = std.math.maxInt(i64), .col = std.math.maxInt(i64) };
    }

    pub fn add(self: *Self, coord: Coord) !void {
        try self.data.put(coord, {});
        self.min_coord.row = @minimum(coord.row, self.min_coord.row);
        self.min_coord.col = @minimum(coord.col, self.min_coord.col);
        self.max_coord.row = @maximum(coord.row, self.max_coord.row);
        self.max_coord.col = @maximum(coord.col, self.max_coord.col);
    }

    pub fn get(self: *Self, coord: Coord) bool {
        const in_bounds = ((self.min_coord.row <= coord.row and coord.row <= self.max_coord.row) and
            (self.min_coord.col <= coord.col and coord.col <= self.max_coord.col));
        if (!in_bounds) {
            return self.oob_on;
        } else {
            return self.data.contains(coord);
        }
    }

    pub fn deinit(self: *Self) void {
        self.data.deinit();
    }

    pub fn readNeighborhood(self: *Self, r0: i64, c0: i64) u9 {
        var result: u9 = 0;
        var dr: i64 = -1;
        while (dr <= 1) : (dr += 1) {
            var dc: i64 = -1;
            while (dc <= 1) : (dc += 1) {
                result = result << 1;
                const r = r0 + dr;
                const c = c0 + dc;
                if (self.get(Coord{ .row = r, .col = c })) {
                    result += 1;
                }
            }
        }
        return result;
    }

    pub fn enhanceInto(self: *Self, other: *Self) !void {
        other.resetBounds();
        other.data.clearRetainingCapacity();

        var row = self.min_coord.row - 1;
        while (row <= self.max_coord.row + 1) : (row += 1) {
            var col = self.min_coord.col - 1;
            while (col <= self.max_coord.col + 1) : (col += 1) {
                const coord = Coord{ .row = row, .col = col };
                const algo_idx = self.readNeighborhood(row, col);
                if (self.algo[algo_idx] == '#') {
                    try other.add(coord);
                }
            }
        }

        // other is now correct, at least for in-bounds data
        // but we have to fix the oob data
        if (self.algo[0] == '#' and !self.oob_on) {
            other.oob_on = true;
        }
        if (self.algo[511] == '.' and self.oob_on) {
            other.oob_on = false;
        }
    }

    pub fn print(self: *Self) void {
        var row = self.min_coord.row;
        while (row <= self.max_coord.row) : (row += 1) {
            var col = self.min_coord.col;
            while (col <= self.max_coord.col) : (col += 1) {
                const coord = Coord{ .row = row, .col = col };
                if (self.data.contains(coord)) {
                    std.debug.print("#", .{});
                } else {
                    std.debug.print(".", .{});
                }
            }
            std.debug.print("\n", .{});
        }
    }
};

pub fn main() !void {
    const file = try std.fs.cwd().openFile("day20.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) unreachable;

    var img_data = Image.init(gpa.allocator());
    defer img_data.deinit();

    var img_data_alt = Image.init(gpa.allocator());
    defer img_data_alt.deinit();

    img_data.algo = try file.reader().readBytesNoEof(512);
    img_data_alt.algo = img_data.algo;

    var img = &img_data;
    var img_alt = &img_data_alt;

    var cur_row: i64 = 0;
    var buf: [256]u8 = undefined;
    while (try file.reader().readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        if (line.len == 0) continue;
        for (line) |el, c| {
            if (el == '#') {
                try img.add(Coord{ .row = cur_row, .col = @intCast(i64, c) });
            }
        }
        cur_row += 1;
    }

    var step: u8 = 0;
    while (step < 50) : (step += 1) {
        try img.enhanceInto(img_alt);
        const tmp = img_alt;
        img_alt = img;
        img = tmp;

        if (step + 1 == 2 or step + 1 == 50) {
            std.debug.print("After {d} steps, {d} are lit\n", .{ step + 1, img.data.count() });
        }
        // img.print();
    }
}
