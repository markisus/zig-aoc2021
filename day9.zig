const std = @import("std");
const print = std.debug.print;
const max_width = 500;
const max_height = 500;

pub fn Grid(comptime T: type) type {
    return struct {
        const Self = @This();
        grid_buf: [max_width * max_height]T = undefined,
        width: usize = 0,
        height: usize = 0,

        pub fn get_ptr(self: *Self, row: usize, col: usize) *T {
            return &self.grid_buf[row * self.width + col];
        }

        pub fn get_safe(self: *Self, row: i16, col: i16) ?T {
            if (0 <= row and row < self.height and 0 <= col and col < self.width) {
                return self.get_ptr(@intCast(usize, row), @intCast(usize, col)).*;
            }
            return null;
        }
    };
}

const NULL_BASIN = 0;
const Basin = struct {
    // ptr to lower basin, if available
    merge: u16 = NULL_BASIN,
    count: u16 = 0,
};

const Top3 = struct {
    const Self = @This();
    top3: [3]u16 = [3]u16{ 0, 0, 0 },
    lowest: u16 = 0,

    pub fn update(self: *Self, val: u16) void {
        if (val > self.lowest) {
            var i: usize = 0;
            while (i < 3) : (i += 1) {
                if (self.top3[i] == self.lowest) {
                    self.top3[i] = val;
                    break;
                }
            }

            self.lowest = self.top3[0];
            i = 1;
            while (i < 3) : (i += 1) {
                self.lowest = @minimum(self.lowest, self.top3[i]);
            }
        }
    }
};

pub fn main() !void {
    var file = try std.fs.cwd().openFile("day9.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader()).reader();
    var buf: [512]u8 = undefined;
    var grid: Grid(u4) = .{};
    while (try reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        if (line.len == 0) {
            continue;
        }
        if (grid.width == 0) {
            grid.width = line.len;
            std.debug.assert(grid.width <= max_width);
        } else {
            std.debug.assert(line.len == grid.width);
        }
        grid.height += 1;
        std.debug.assert(grid.height <= max_height);
        var idx: usize = 0;
        while (idx < grid.width) : (idx += 1) {
            grid.get_ptr(grid.height - 1, idx).* = try std.fmt.parseInt(u4, line[idx .. idx + 1], 10);
        }
    }

    print("grid size {d} x {d}\n", .{ grid.width, grid.height });

    // iterate the top
    // iterate the left
    // iterate the bottom
    // iterate the right

    var low_sum: i16 = 0;
    {
        var row: i16 = 0;
        while (row < grid.height) : (row += 1) {
            var col: i16 = 0;
            while (col < grid.width) : (col += 1) {
                const top_val: u4 = grid.get_safe(row - 1, col) orelse std.math.maxInt(u4);
                const bot_val: u4 = grid.get_safe(row + 1, col) orelse std.math.maxInt(u4);
                const lft_val: u4 = grid.get_safe(row, col - 1) orelse std.math.maxInt(u4);
                const rgt_val: u4 = grid.get_safe(row, col + 1) orelse std.math.maxInt(u4);
                const ctr_val: u4 = grid.get_safe(row, col).?;
                // print("[{d}", .{ctr_val});
                if (ctr_val < top_val and
                    ctr_val < bot_val and
                    ctr_val < lft_val and
                    ctr_val < rgt_val)
                {
                    low_sum += (ctr_val + 1);
                    // print("!]", .{});
                } else {
                    // print(" ]", .{});
                }
            }
            // print("\n", .{});
        }
    }

    print("low sum {d}\n", .{low_sum});

    var basin_map: Grid(u16) = .{ .width = grid.width, .height = grid.height };
    var basins: [max_height * max_width]Basin = undefined;

    var num_basins: usize = 1; // 0 reserved for null basin
    {
        var row: i16 = 0;
        while (row < grid.height) : (row += 1) {
            var col: i16 = 0;
            while (col < grid.width) : (col += 1) {
                const urow = @intCast(usize, row);
                const ucol = @intCast(usize, col);

                const top_val: u4 = grid.get_safe(row - 1, col) orelse 9;
                const lft_val: u4 = grid.get_safe(row, col - 1) orelse 9;
                const ctr_val: u4 = grid.get_ptr(urow, ucol).*;
                if (ctr_val == 9) {
                    basin_map.get_ptr(urow, ucol).* = NULL_BASIN;
                    continue;
                }
                if (top_val == 9 and lft_val == 9) {
                    // this cell does not connect to pre-existing basin
                    // create a new basin
                    basin_map.get_ptr(urow, ucol).* = @intCast(u16, num_basins);
                    basins[num_basins] = .{ .count = 1 };
                    num_basins += 1;
                } else if (top_val == 9) {
                    // this cell connects to a basin on the left
                    const basin_idx = basin_map.get_ptr(urow, ucol - 1).*;
                    basin_map.get_ptr(urow, ucol).* = basin_idx;
                    basins[basin_idx].count += 1;
                } else if (lft_val == 9) {
                    // this cell connects to a basin on the top
                    const basin_idx = basin_map.get_ptr(urow - 1, ucol).*;
                    basin_map.get_ptr(urow, ucol).* = basin_idx;
                    basins[basin_idx].count += 1;
                } else {
                    // this cell connects to a basin on the top and the left
                    const top_basin_idx = basin_map.get_ptr(urow - 1, ucol).*;
                    const left_basin_idx = basin_map.get_ptr(urow, ucol - 1).*;
                    const higher_basin_idx = std.math.max(top_basin_idx, left_basin_idx);
                    const lower_basin_idx = std.math.min(top_basin_idx, left_basin_idx);
                    if (higher_basin_idx != lower_basin_idx) {
                        // generate a flow from the higher basin into the lower basin
                        basins[higher_basin_idx].merge = lower_basin_idx;
                    }
                    basin_map.get_ptr(urow, ucol).* = @intCast(u16, lower_basin_idx);
                    basins[lower_basin_idx].count += 1;
                }
            }
            // print("\n", .{});
        }
    }

    // {
    //     var row: i16 = 0;
    //     while (row < grid.height) : (row += 1) {
    //         var col: i16 = 0;
    //         while (col < grid.width) : (col += 1) {
    //             const basin_idx = basin_map.get_safe(row, col).?;
    //             print("{d: <2} ", .{basin_idx});
    //         }
    //         print("\n", .{});
    //     }
    // }

    // merge basins
    {
        var basin_idx = @intCast(u16, num_basins - 1);
        while (basin_idx != NULL_BASIN) : (basin_idx -= 1) {
            var basin = &basins[basin_idx];
            if (basin.merge != NULL_BASIN) {
                // print("merging {d}=>{d}\n", .{ basin_idx, basin.merge });
                basins[basin.merge].count += basin.count;
                basin.merge = NULL_BASIN;
                basin.count = 0;
                // num_basins -= 1;
            }
        }
    }

    {
        var top3: Top3 = .{};
        var basin_idx: u16 = 1;
        while (basin_idx < num_basins) : (basin_idx += 1) {
            top3.update(basins[basin_idx].count);
        }
        print("top3 {d}, {d}, {d}\n", .{ top3.top3[0], top3.top3[1], top3.top3[2] });
        print("top3 product {d}\n", .{@intCast(u64, top3.top3[0]) * top3.top3[1] * top3.top3[2]});
    }
}
