const std = @import("std");
const util = @import("util.zig");

const Grid = util.Grid(u8, '.');

pub fn eastMoves(grid: *Grid) bool {
    var any_moved: bool = false;
    // east-move
    {
        var row: u32 = 0;
        while (row < grid.rows) : (row += 1) {
            var col: u32 = 0;
            while (col < grid.cols) : (col += 1) {
                const curr = grid.getPtr(row, col).?;
                if (curr.* == '>') {
                    const nbr = grid.getPtr(row, (col + 1) % grid.cols).?;
                    if (nbr.* == '.') {
                        // mark this ready to move l
                        curr.* = 'l';
                        any_moved = true;
                    }
                }
            }
        }
    }
    // do east-moves
    {
        var row: u32 = 0;
        while (row < grid.rows) : (row += 1) {
            var col: u32 = 0;
            while (col < grid.cols) : (col += 1) {
                const curr = grid.getPtr(row, col).?;
                if (curr.* == 'l') {
                    const nbr = grid.getPtr(row, (col + 1) % grid.cols).?;
                    curr.* = '.';
                    nbr.* = '>';
                }
            }
        }
    }

    return any_moved;
}

pub fn southMoves(grid: *Grid) bool {
    var any_moved: bool = false;
    // south-move
    {
        var row: u32 = 0;
        while (row < grid.rows) : (row += 1) {
            var col: u32 = 0;
            while (col < grid.cols) : (col += 1) {
                const curr = grid.getPtr(row, col).?;
                if (curr.* == 'v') {
                    const nbr = grid.getPtr((row + 1) % grid.rows, col).?;
                    if (nbr.* == '.') {
                        // mark this ready to move l
                        curr.* = 'd';
                        any_moved = true;
                    }
                }
            }
        }
    }
    // do south-move
    {
        var row: u32 = 0;
        while (row < grid.rows) : (row += 1) {
            var col: u32 = 0;
            while (col < grid.cols) : (col += 1) {
                const curr = grid.getPtr(row, col).?;
                if (curr.* == 'd') {
                    const nbr = grid.getPtr((row + 1) % grid.rows, col).?;
                    curr.* = '.';
                    nbr.* = 'v';
                }
            }
        }
    }
    return any_moved;
}

pub fn doStep(grid: *Grid) bool {
    var east_moved = eastMoves(grid);
    var south_moved = southMoves(grid);
    return east_moved or south_moved;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) unreachable;

    var grid = try Grid.init(gpa.allocator(), 0, 0);
    defer grid.deinit();

    var file = try std.fs.cwd().openFile("day25.txt", .{});
    var buf: [256]u8 = undefined;
    while (try file.reader().readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        if (line.len == 0) continue;
        try grid.addRow(line);
    }

    var step: usize = 0;
    var any_moved = true;
    while (any_moved) {
        any_moved = doStep(&grid);
        step += 1;
    }

    std.debug.print("Last step {d}!\n", .{step});
}
