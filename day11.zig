const std = @import("std");

const Simulation = struct {
    const Self = @This();
    rows: u8 = 0,
    cols: u8 = 0,
    num_flashes: u64 = 0,
    data: std.ArrayList(u8) = undefined,

    pub fn init(self: *Self, allocator: std.mem.Allocator) void {
        self.data = std.ArrayList(u8).init(allocator);
    }

    pub fn deinit(self: *Self) void {
        self.data.deinit();
    }

    pub fn addLine(self: *Self, line: []const u8) !void {
        std.debug.assert(line.len <= std.math.maxInt(u8));
        if (self.cols == 0) {
            self.cols = @truncate(u8, line.len);
        } else {
            std.debug.assert(self.cols == @truncate(u8, line.len));
        }
        for (line) |char| {
            try self.data.append(char - '0');
        }
        self.rows += 1;
    }

    pub fn get(self: *Self, row: u8, col: u8) *u8 {
        return &self.data.items[col + row * self.cols];
    }

    pub fn isInBounds(self: *Self, row: i16, col: i16) bool {
        if (row < 0 or row >= self.rows) {
            return false;
        }
        if (col < 0 or col >= self.cols) {
            return false;
        }
        return true;
    }

    pub fn flash(self: *Self, row: u8, col: u8) void {
        var cr: i16 = row;
        var cc: i16 = col;
        var dr: i16 = -1;
        while (dr <= 1) : (dr += 1) {
            var dc: i16 = -1;
            while (dc <= 1) : (dc += 1) {
                var r = cr + dr;
                var c = cc + dc;
                if (!self.isInBounds(r, c)) {
                    continue;
                }
                var nbr = self.get(@intCast(u8, r), @intCast(u8, c));
                if (nbr.* != 0) {
                    nbr.* += 1;
                }
            }
        }
        self.get(row, col).* = 0;
        self.num_flashes += 1;
    }

    pub fn step(self: *Self) void {
        // every octopus increases in energy by 1
        for (self.data.items) |*i| {
            i.* += 1;
        }

        // flashing
        var any_flashes = true; // kick off the iteration
        while (any_flashes) {
            any_flashes = false;
            var r: u8 = 0;
            while (r < self.rows) : (r += 1) {
                var c: u8 = 0;
                while (c < self.cols) : (c += 1) {
                    var energy = self.get(r, c).*;
                    if (energy > 9) {
                        self.flash(r, c);
                        any_flashes = true;
                    }
                }
            }
        }
    }

    pub fn didAllFlash(self: *Self) bool {
        for (self.data.items) |d| {
            if (d != 0) {
                return false;
            }
        }
        return true;
    }

    pub fn print(self: *Self) void {
        var r: u8 = 0;
        while (r < self.rows) : (r += 1) {
            var c: u8 = 0;
            while (c < self.cols) : (c += 1) {
                std.debug.print("{d} ", .{self.get(r, c).*});
            }
            std.debug.print("\n", .{});
        }
    }
};

pub fn readLinesIntoSim(sim: *Simulation, filename: []const u8) !void {
    var file = try std.fs.cwd().openFile(filename, .{});
    var reader = std.io.bufferedReader(file.reader()).reader();
    var buf: [512]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        try sim.addLine(line);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        if (gpa.deinit()) {
            unreachable;
        }
    }

    var sim: Simulation = .{};
    sim.init(allocator);
    defer sim.deinit();

    try readLinesIntoSim(&sim, "day11.txt");
    var step: u32 = 1;
    while (step < 1000) : (step += 1) {
        sim.step();
        if (step == 100) {
            std.debug.print("Step={d}, Flashes={d}\n", .{ step, sim.num_flashes });
        }
        if (sim.didAllFlash()) {
            std.debug.print("Step={d}, All Flashed!\n", .{step});
            break;
        }
    }
}
