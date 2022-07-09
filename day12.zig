const std = @import("std");
const util = @import("util.zig");
const Graph = util.Graph;
const StringSet = util.StringSet;

pub fn loadCave(filename: []const u8, graph: *Graph) !void {
    var file = try std.fs.cwd().openFile(filename, .{});
    var buf: [50]u8 = undefined;
    while (try file.reader().readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        var tokens = std.mem.tokenize(u8, line, "-");
        var aname = tokens.next().?;
        var bname = tokens.next().?;
        try graph.addEdge(aname, bname);
    }
}

pub fn exploreCave(cave: *Graph, current: []const u8, small_visited: *StringSet, cur_path: *std.ArrayList(*[]const u8), visited_small_twice_: bool) usize {
    // std.debug.print("Evaluating path\n", .{});
    // for (cur_path.items) |node| {
    //     std.debug.print("{s} ", .{node.*});
    // }
    // std.debug.print("[{s}]\n", .{current});

    // base cases:
    if (std.mem.eql(u8, current, "end")) {
        // for (cur_path.items) |node| {
        //     std.debug.print("{s} ", .{node.*});
        // }
        // std.debug.print("\n", .{});
        // already at the end
        // std.debug.print("OK!\n", .{});
        return 1;
    }

    var visited_small_twice = visited_small_twice_;
    var visiting_current_twice = false;
    if (small_visited.contains(current)) {
        if (visited_small_twice) {
            // already visited this small node
            // and already visited another node twice
            return 0;
        } else if (std.mem.eql(u8, current, "start")) {
            // do not allow double-visiting the start node
            return 0;
        } else {
            // we have now visited a small node twice
            visited_small_twice = true;
            visiting_current_twice = true;
        }
    }

    cur_path.append(&(cave.edges.getKey(current).?)) catch unreachable;
    if (std.ascii.isLower(current[0])) {
        small_visited.add(current) catch unreachable;
    }
    defer {
        if (!visiting_current_twice) {
            _ = small_visited.remove(current);
        }
        _ = cur_path.pop();
    }

    var num_paths: usize = 0;
    var nbrs = cave.getNeighbors(current) catch unreachable;
    for (nbrs.items) |nbr| {
        const neighbor = nbr.toString();
        num_paths += exploreCave(cave, neighbor, small_visited, cur_path, visited_small_twice);
    }

    return num_paths;
}

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer if (gpa.deinit()) {
        std.debug.print("Leaked!\n", .{});
        // unreachable;
    };

    var cave = Graph.init(gpa.allocator());
    defer cave.deinit();

    var small_visited = StringSet.init(gpa.allocator());
    defer small_visited.deinit();

    var cur_path = std.ArrayList(*[]const u8).init(gpa.allocator());
    defer cur_path.deinit();

    try loadCave("day12.txt", &cave);
    // cave.print();

    var num_paths = exploreCave(&cave, "start", &small_visited, &cur_path, true);
    std.debug.print("num_paths={d}\n", .{num_paths});
    var num_paths2 = exploreCave(&cave, "start", &small_visited, &cur_path, false);
    std.debug.print("num_paths2={d}\n", .{num_paths2});
}
