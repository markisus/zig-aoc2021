const std = @import("std");
const util = @import("util.zig");

const CoordNeighbors = struct {
    const Self = @This();

    rows: u32,
    cols: u32,
    center: Coord,

    idx: u8 = 0,

    pub fn init(center: Coord, rows: u32, cols: u32) Self {
        var self: Self = undefined;
        self.rows = rows;
        self.cols = cols;
        self.center = center;
        self.idx = 0;
    }

    pub fn next(self: *Self) ?Coord {
        self.idx += 1;
        if (self.idx > 4) {
            return null;
        }

        if (self.idx == 1) {
            if (self.top()) |c| return c;
        }

        if (self.idx == 2) {
            if (self.left()) |c| return c;
        }

        if (self.idx == 3) {
            if (self.right()) |c| return c;
        }

        if (self.idx == 4) {
            if (self.bottom()) |c| return c;
        }

        return self.next();
    }

    pub fn top(self: *Self) ?Coord {
        if (self.center.row > 0) {
            return Coord{ .row = self.center.row - 1, .col = self.center.col };
        }
        return null;
    }

    pub fn left(self: *Self) ?Coord {
        if (self.center.col > 0) {
            return Coord{ .row = self.center.row, .col = self.center.col - 1 };
        }
        return null;
    }

    pub fn right(self: *Self) ?Coord {
        if (self.center.col + 1 < self.cols) {
            return Coord{ .row = self.center.row, .col = self.center.col + 1 };
        }
        return null;
    }

    pub fn bottom(self: *Self) ?Coord {
        if (self.center.row + 1 < self.rows) {
            return Coord{ .row = self.center.row + 1, .col = self.center.col };
        }
        return null;
    }
};

const Coord = struct {
    row: u16,
    col: u16,
};

const ExitEdge = struct {
    from: Coord,
    to: Coord,
    cost: u64, // path to traverse start -> .from -> .to
};

pub fn exitEdgeCmp(n: void, e1: ExitEdge, e2: ExitEdge) std.math.Order {
    _ = n;
    if (e1.cost < e2.cost) return std.math.Order.lt; // reverse sort
    if (e1.cost == e2.cost) return std.math.Order.eq;
    return std.math.Order.gt;
}

pub fn queryAugmentedMap(danger_map: *util.Grid(u8, 0), row: u16, col: u16) ?u8 {
    const tile_r = @divTrunc(row, danger_map.rows);
    const tile_c = @divTrunc(col, danger_map.cols);

    const r = @mod(row, danger_map.rows);
    const c = @mod(col, danger_map.cols);

    if (danger_map.getPtr(r, c)) |val| {
        const tile_inc = tile_r + tile_c;
        var val_mod: u8 = val.* + @truncate(u8, tile_inc);
        while (val_mod >= 10) : (val_mod -= 9) {}
        return val_mod;
    }

    return null;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) unreachable;

    var danger_map = try util.Grid(u8, 0).init(gpa.allocator(), 0, 0);
    defer danger_map.deinit();

    const filename = "day15.txt";
    var file = try std.fs.cwd().openFile(filename, .{});
    var buf: [512]u8 = undefined;
    while (try file.reader().readUntcilDelimiterOrEof(buf[0..], '\n')) |line| {
        // map ascii to digit
        for (line) |*c| {
            c.* -= '0';
        }
        try danger_map.addRow(line);
    }

    const NODATA = std.math.maxInt(u64);

    {
        // part 1
        var cost_map = try util.Grid(u64, NODATA).init(gpa.allocator(), danger_map.rows, danger_map.cols);
        defer cost_map.deinit();

        cost_map.getPtr(0, 0).?.* = 0;

        var exit_paths = std.PriorityQueue(ExitEdge, void, exitEdgeCmp).init(gpa.allocator(), {});
        defer exit_paths.deinit();

        const origin: Coord = .{ .row = 0, .col = 0 };
        var origin_neighbors = CoordNeighbors{ .rows = danger_map.rows, .cols = danger_map.cols, .center = origin };
        while (origin_neighbors.next()) |nbr| {
            const edge = ExitEdge{ .from = origin, .to = nbr, .cost = danger_map.getPtr(nbr.row, nbr.col).?.* };
            // std.debug.print("Seeding edge {}\n", .{edge});
            try exit_paths.add(edge);
        }

        while (exit_paths.removeOrNull()) |exit_path| {
            const to = exit_path.to;
            // std.debug.print("Best exit {}\n", .{exit_path});

            var cost = cost_map.getPtr(to.row, to.col).?;
            if (cost.* != NODATA) {
                // std.debug.print("\tDiscarding\n", .{});
                // too late, we already know the shortest path to this node
                continue;
            } else {
                // since this is the min-cost exit path
                // this must be the shorest path to the `to` node
                // std.debug.print("\tRecording\n", .{});
                cost.* = exit_path.cost;
                var nbrs = CoordNeighbors{ .rows = danger_map.rows, .cols = danger_map.cols, .center = to };
                while (nbrs.next()) |nbr| {
                    const edge = ExitEdge{ .from = to, .to = nbr, .cost = danger_map.getPtr(nbr.row, nbr.col).?.* + cost.* };
                    // std.debug.print("\t\tPushing {}\n", .{edge});
                    try exit_paths.add(edge);
                }
            }
        }

        std.debug.print("Cost to end={d}\n", .{cost_map.getPtr(cost_map.rows - 1, cost_map.cols - 1).?.*});
    }

    {
        // part 2
        var cost_map = try util.Grid(u64, NODATA).init(gpa.allocator(), danger_map.rows * 5, danger_map.cols * 5);
        defer cost_map.deinit();

        cost_map.getPtr(0, 0).?.* = 0;

        var exit_paths = std.PriorityQueue(ExitEdge, void, exitEdgeCmp).init(gpa.allocator(), {});
        defer exit_paths.deinit();

        const origin: Coord = .{ .row = 0, .col = 0 };
        var origin_neighbors = CoordNeighbors{ .rows = cost_map.rows, .cols = cost_map.cols, .center = origin };
        while (origin_neighbors.next()) |nbr| {
            const edge = ExitEdge{ .from = origin, .to = nbr, .cost = danger_map.getPtr(nbr.row, nbr.col).?.* };
            // std.debug.print("Seeding edge {}\n", .{edge});
            try exit_paths.add(edge);
        }

        while (exit_paths.removeOrNull()) |exit_path| {
            const to = exit_path.to;
            // std.debug.print("Best exit {}\n", .{exit_path});

            var cost = cost_map.getPtr(to.row, to.col).?;
            if (cost.* != NODATA) {
                // std.debug.print("\tDiscarding\n", .{});
                // too late, we already know the shortest path to this node
                continue;
            } else {
                // since this is the min-cost exit path
                // this must be the shorest path to the `to` node
                // std.debug.print("\tRecording\n", .{});
                cost.* = exit_path.cost;
                var nbrs = CoordNeighbors{ .rows = cost_map.rows, .cols = cost_map.cols, .center = to };
                while (nbrs.next()) |nbr| {
                    const edge_cost = queryAugmentedMap(&danger_map, nbr.row, nbr.col).?;
                    const edge = ExitEdge{ .from = to, .to = nbr, .cost = edge_cost + cost.* };
                    // std.debug.print("\t\tPushing {}\n", .{edge});
                    try exit_paths.add(edge);
                }
            }
        }

        std.debug.print("Cost to end={d}\n", .{cost_map.getPtr(cost_map.rows - 1, cost_map.cols - 1).?.*});
    }
}
