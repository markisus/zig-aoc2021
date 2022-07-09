const std = @import("std");

const VoxelGrid = std.AutoHashMap([3]i32, void);

pub fn restrictRegion(bounds: [3][2]i32) [3][2]i32 {
    var result = bounds;
    var i: u8 = 0;
    while (i < 3) : (i += 1) {
        result[i][0] = @maximum(result[i][0], -50);
        result[i][1] = @minimum(result[i][1], 50);
    }
    return result;
}

pub fn writeBlock(on: bool, _bounds: [3][2]i32, grid: *VoxelGrid) !void {
    const bounds = restrictRegion(_bounds);
    const xmin = bounds[0][0];
    const xmax = bounds[0][1];
    const ymin = bounds[1][0];
    const ymax = bounds[1][1];
    const zmin = bounds[2][0];
    const zmax = bounds[2][1];

    var x = xmin;
    while (x <= xmax) : (x += 1) {
        var y = ymin;
        while (y <= ymax) : (y += 1) {
            var z = zmin;
            while (z <= zmax) : (z += 1) {
                // check initialization region
                if (on) {
                    try grid.put(.{ x, y, z }, {});
                } else {
                    _ = grid.remove(.{ x, y, z });
                }
            }
        }
    }
}

// block minus sub-block
// one block can split into 26 sub-blocks after removing the middle

// x-splits
// y-splits
// z-splits

const Block = struct {
    const Self = @This();

    bounds: [3][2]i32,

    pub fn intersection(self: *const Self, other: Self) Self {
        var result: Self = undefined;
        var i: u8 = 0;
        while (i < 3) : (i += 1) {
            result.bounds[i][0] = @maximum(self.bounds[i][0], other.bounds[i][0]);
            result.bounds[i][1] = @minimum(self.bounds[i][1], other.bounds[i][1]);
        }
        return result;
    }

    pub fn equals(self: *Self, other: Self) bool {
        // std.debug.print("Checking {d} == {d}\n", .{ self.bounds, other.bounds });
        var i: u8 = 0;
        while (i < 3) : (i += 1) {
            var j: u8 = 0;
            while (j < 2) : (j += 1) {
                if (self.bounds[i][j] != other.bounds[i][j]) {
                    // std.debug.print("\tFalse\n", .{});
                    return false;
                }
            }
        }
        // std.debug.print("\tTrue\n", .{});
        return true;
    }

    pub fn contains(self: *Self, other: Self) bool {
        return self.intersection(other).equals(other);
    }

    pub fn subdivideAxis(bounds: [2]i32) [3][2]i32 {
        var result: [3][2]i32 = undefined;
        result[0] = .{ std.math.minInt(i32), bounds[0] - 1 };
        result[1] = bounds;
        result[2] = .{ bounds[1] + 1, std.math.maxInt(i32) };
        return result;
    }

    pub fn cleave(self: *const Self, other: Self) [27]Block {
        var result: [27]Block = undefined;
        var i: u8 = 0;
        for (subdivideAxis(other.bounds[0])) |xbounds| {
            for (subdivideAxis(other.bounds[1])) |ybounds| {
                for (subdivideAxis(other.bounds[2])) |zbounds| {
                    result[i].bounds[0] = xbounds;
                    result[i].bounds[1] = ybounds;
                    result[i].bounds[2] = zbounds;
                    result[i] = self.intersection(result[i]);
                    i += 1;
                }
            }
        }
        return result;
    }

    pub fn volume(self: *Self) u64 {
        const l = @intCast(u64, self.bounds[0][1] - self.bounds[0][0] + 1);
        const w = @intCast(u64, self.bounds[1][1] - self.bounds[1][0] + 1);
        const h = @intCast(u64, self.bounds[2][1] - self.bounds[2][0] + 1);
        // std.debug.print("Calling volume on {d}, lwh={d},{d},{d}\n", .{ self.bounds, l, w, h });
        return l * w * h;
    }

    pub fn isValid(self: *const Self) bool {
        var i: u8 = 0;
        while (i < 3) : (i += 1) {
            if (self.bounds[i][0] > self.bounds[i][1]) return false;
        }
        return true;
    }
};

const SimpleBlockList = struct {
    const Self = @This();
    const Queue = std.TailQueue(Block);

    allocator: std.mem.Allocator,
    blocks: Queue,
    graveyard: std.ArrayList(*Queue.Node),

    pub fn init(allocator: std.mem.Allocator) Self {
        var self: Self = undefined;
        self.allocator = allocator;
        self.blocks = .{};
        self.graveyard = std.ArrayList(*Queue.Node).init(allocator);
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.emptyGraveyard();
        self.graveyard.deinit();

        var possible_node = self.blocks.first;
        while (possible_node) |node| {
            const next = node.next;
            self.allocator.destroy(node);
            possible_node = next;
        }
    }

    pub fn remove(self: *Self, node: *Queue.Node) !void {
        try self.graveyard.append(node);
        self.blocks.remove(node);
    }

    pub fn emptyGraveyard(self: *Self) void {
        for (self.graveyard.items) |ptr| {
            self.allocator.destroy(ptr);
        }
        self.graveyard.clearRetainingCapacity();
    }

    pub fn append(self: *Self, block: Block) !void {
        // std.debug.print("Appending {d} to list len {d}\n", .{ block.bounds, self.blocks.len });
        var node: *Queue.Node = try self.allocator.create(Queue.Node);
        // std.debug.print("Allocating node at {x}\n", .{@ptrToInt(node)});
        node.data = block;
        self.blocks.append(node);
    }
};

const BlockList = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    blocks: SimpleBlockList,

    pub fn init(allocator: std.mem.Allocator) Self {
        var self: Self = undefined;
        self.allocator = allocator;
        self.blocks = SimpleBlockList.init(allocator);
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.blocks.deinit();
    }

    pub fn remove(self: *Self, block_to_remove: Block) !void {
        defer self.blocks.emptyGraveyard();

        var sentinel: SimpleBlockList.Queue.Node = undefined;
        sentinel.next = self.blocks.blocks.first;
        var current = &sentinel;
        while (true) {
            // traverse the block list until we get to next intersection
            var intersection: Block = undefined; // valid if intersection_occured
            var intersection_found = false;
            while (current.next) |next| {
                current = next;
                intersection = block_to_remove.intersection(current.data);
                if (intersection.isValid()) {
                    intersection_found = true;
                    break;
                }
            }

            if (intersection_found) {
                if (intersection.equals(current.data)) {
                    // just remove this node
                    // since the block we're trying to remove
                    // completely envelopes it
                    try self.blocks.remove(current);
                } else {
                    // partial intersect -
                    // cleave the intersected node so that whatever
                    // part is intersected can be removed in the next
                    // iteration
                    for (current.data.cleave(intersection)) |cleaved| {
                        if (cleaved.isValid()) {
                            try self.blocks.append(cleaved);
                        }
                    }
                    try self.blocks.remove(current);
                }
            } else {
                // reached the end of the list
                break;
            }
        }
    }

    pub fn volume(self: *Self) u64 {
        var sentinel: SimpleBlockList.Queue.Node = undefined;
        sentinel.next = self.blocks.blocks.first;
        var current = &sentinel;

        var vol: u64 = 0;
        while (current.next) |next| {
            current = next;
            vol += current.data.volume();
        }

        return vol;
    }

    pub fn add(self: *Self, block: Block) !void {
        defer self.blocks.emptyGraveyard();

        const debug = false;
        if (debug) std.debug.print("Original block to add is {d}\n", .{block.bounds});

        var blocks_to_add = SimpleBlockList.init(self.allocator);
        defer blocks_to_add.deinit();
        try blocks_to_add.append(block);

        while (blocks_to_add.blocks.len != 0) {
            var block_to_add = blocks_to_add.blocks.first.?;
            if (debug) std.debug.print("\tAdding {d}\n", .{block_to_add.data});

            var sentinel: SimpleBlockList.Queue.Node = undefined;
            sentinel.next = self.blocks.blocks.first;
            var current = &sentinel;

            while (true) {
                // traverse the block list until we get to the first intersection
                var intersection: Block = undefined;
                var intersection_found = false;
                while (current.next) |next| {
                    current = next;
                    // if (debug) std.debug.print("\tcurrent = {x}, current {d}\n", .{ @ptrToInt(current), current.data.bounds });
                    intersection = block_to_add.data.intersection(current.data);
                    if (intersection.isValid()) {
                        if (debug) std.debug.print("\tFound {d} intersection with {d}\n", .{ block_to_add.data.bounds, current.data.bounds });
                        if (debug) std.debug.print("\tIntersection was {d}\n", .{intersection.bounds});
                        intersection_found = true;
                        break;
                    }
                }

                if (intersection_found) {
                    // we hit an intersection before being able
                    // to get to the end of the list
                    if (intersection.equals(block_to_add.data)) {
                        if (debug) std.debug.print("\tThe block we are adding is subsumed\n", .{});
                        // the block we're adding is completely
                        // inside one that already exists
                        // pop the node from blocks_to_add
                        try blocks_to_add.remove(block_to_add);
                        break; // done processing this block_to_add
                    } else if (intersection.equals(current.data)) {
                        if (debug) std.debug.print("\tThe block we are adding subsumes\n", .{});
                        // just remove this node since the one we're
                        // trying to add completely envelopes it
                        try self.blocks.remove(current);
                    } else {
                        // partial intersect - cleave both nodes
                        if (debug) std.debug.print("\tPartial intersect\n", .{});
                        if (debug) std.debug.print("\tCleaving the existing block\n", .{});
                        for (current.data.cleave(intersection)) |cleaved| {
                            if (cleaved.isValid()) {
                                if (debug) std.debug.print("\t\t{d}\n", .{cleaved.bounds});
                                try self.blocks.append(cleaved);
                            }
                        }
                        if (debug) std.debug.print("\tCleaving the block we are adding\n", .{});
                        for (block_to_add.data.cleave(intersection)) |cleaved| {
                            if (cleaved.isValid()) {
                                if (debug) std.debug.print("\t\t{d}\n", .{cleaved.bounds});
                                try blocks_to_add.append(cleaved);
                            }
                        }
                        try self.blocks.remove(current);
                        try blocks_to_add.remove(block_to_add);
                        break; // done processing this block_to_add
                    }
                } else {
                    if (debug) std.debug.print("\tNo more intersections!\n", .{});
                    // happy path, no intersect with any nodes,
                    // just append it
                    // order important here, need to add to one list
                    // before removing it from another
                    try self.blocks.append(block_to_add.data);
                    if (debug) std.debug.print("\tAdding block to {d}\n", .{block_to_add.data.bounds});
                    try blocks_to_add.remove(block_to_add);
                    break;
                }
            }
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) unreachable;

    var sbl = SimpleBlockList.init(gpa.allocator());
    defer sbl.deinit();

    // var block: Block = undefined;
    // block.bounds[0] = .{ -1, 1 };
    // block.bounds[1] = .{ -1, 1 };
    // block.bounds[2] = .{ -1, 1 };
    // try sbl.append(block);

    var grid = VoxelGrid.init(gpa.allocator());
    defer grid.deinit();

    var blocks = BlockList.init(gpa.allocator());
    defer blocks.deinit();

    var file = try std.fs.cwd().openFile("day22.txt", .{});
    var buf: [256]u8 = undefined;
    while (try file.reader().readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        if (line.len == 0) continue;

        var tokens = std.mem.tokenize(u8, line, " ,");
        const on_off = tokens.next().?;

        var is_on: bool = std.mem.eql(u8, on_off, "on");
        var bounds: [3][2]i32 = undefined;
        var i: u8 = 0;
        while (i < 3) : (i += 1) {
            const bounds_str = tokens.next().?;
            var bounds_tokens = std.mem.tokenize(u8, bounds_str, "=.");
            _ = bounds_tokens.next().?; // x y or z
            const low = bounds_tokens.next().?;
            const high = bounds_tokens.next().?;
            bounds[i][0] = try std.fmt.parseInt(i32, low, 10);
            bounds[i][1] = try std.fmt.parseInt(i32, high, 10);
        }

        std.debug.print("{d} {d}\n", .{ is_on, bounds });

        try writeBlock(is_on, bounds, &grid);
        const block = Block{ .bounds = bounds };
        if (is_on) {
            try blocks.add(block);
        } else {
            try blocks.remove(block);
        }
    }

    std.debug.print("Num on {d}\n", .{grid.count()});
    std.debug.print("Num on blocklist {d}\n", .{blocks.volume()});
}

test "intersection 1" {
    const b2 = Block{ .bounds = .{ .{ -20, 26 }, .{ -21, 17 }, .{ -26, 7 } } };
    const b1 = Block{ .bounds = .{ .{ -20, 26 }, .{ -21, 17 }, .{ 8, 28 } } };
    const x = b1.intersection(b2);
    std.debug.print("{d} {d}\n", .{ x.bounds, x.isValid() });
}
