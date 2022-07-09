const std = @import("std");
const SmallString = struct {
    const Self = @This();
    data: [10]u8,
    len: u8 = 0,

    pub fn fromString(s: []const u8) Self {
        std.debug.assert(s.len <= std.math.maxInt(u8));
        var id: Self = undefined;
        std.mem.set(u8, id.data[0..], 0);
        std.mem.copy(u8, id.data[0..], s);
        id.len = @truncate(u8, s.len);
        return id;
    }

    pub fn toString(self: *const Self) []const u8 {
        var result: []const u8 = undefined;
        result.len = self.len;
        result.ptr = self.data[0..];
        return result;
    }
};

pub const StringSet = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    set: std.StringHashMap(void),

    pub fn init(allocator: std.mem.Allocator) Self {
        var self: Self = undefined;
        self.allocator = allocator;
        self.set = std.StringHashMap(void).init(allocator);
        return self;
    }

    pub fn add(self: *Self, str: []const u8) !void {
        if (!self.set.contains(str)) {
            var str_copy = try self.allocator.alloc(u8, str.len);
            std.mem.copy(u8, str_copy, str);
            try self.set.put(str_copy, undefined);
        }
    }

    pub fn contains(self: *Self, str: []const u8) bool {
        return self.set.contains(str);
    }

    pub fn get(self: *Self, str: []const u8) ![]const u8 {
        try self.set.getKey(str).?;
    }

    pub fn remove(self: *Self, str: []const u8) bool {
        if (self.set.getKey(str)) |key| {
            _ = self.set.remove(str);
            self.allocator.free(key);
        }
        return false;
    }

    pub fn count(self: *Self) usize {
        return self.set.count();
    }

    pub fn deinit(self: *Self) void {
        var it = self.set.iterator();
        while (it.next()) |kv| {
            self.allocator.free(kv.key_ptr.*);
        }
        self.set.deinit();
    }
};

pub const Graph = struct {
    const Self = @This();

    edges: std.StringHashMap(std.ArrayList(SmallString)),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        var self: Self = undefined;
        self.allocator = allocator;
        self.edges = std.StringHashMap(std.ArrayList(SmallString)).init(allocator);
        return self;
    }

    pub fn getNeighbors(self: *Graph, node: []const u8) !*std.ArrayList(SmallString) {
        if (!self.edges.contains(node)) {
            var node_copy = try self.allocator.alloc(u8, node.len);
            std.mem.copy(u8, node_copy, node);
            try self.edges.put(node_copy, std.ArrayList(SmallString).init(self.allocator));
        }
        return self.edges.getPtr(node).?;
    }

    pub fn addEdge(self: *Graph, node_a: []const u8, node_b: []const u8) !void {
        try (try self.getNeighbors(node_a)).append(SmallString.fromString(node_b));
        try (try self.getNeighbors(node_b)).append(SmallString.fromString(node_a));
    }

    pub fn print(self: *Graph) void {
        var it = self.edges.iterator();
        while (it.next()) |kv| {
            std.debug.print("{s}\n", .{kv.key_ptr.*});
            for (kv.value_ptr.items) |neighbor| {
                std.debug.print("\t{s}\n", .{neighbor.toString()});
            }
        }
    }

    pub fn deinit(self: *Graph) void {
        var it = self.edges.iterator();
        while (it.next()) |kv| {
            kv.value_ptr.deinit();
            self.allocator.free(kv.key_ptr.*);
        }
        self.edges.deinit();
    }
};

pub fn Grid(comptime T: type, default: T) type {
    return struct {
        const Self = @This();

        rows: u32 = 0,
        cols: u32 = 0,
        allocator: std.mem.Allocator,
        data: std.ArrayList(T),

        pub fn init(allocator: std.mem.Allocator, rows_: u32, cols_: u32) !Self {
            var self: Self = .{ .rows = rows_, .cols = cols_, .allocator = allocator, .data = std.ArrayList(T).init(allocator) };
            if (rows_ != 0 and cols_ != 0) {
                try self.data.appendNTimes(default, rows_ * cols_);
            }
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
        }

        pub fn addRow(self: *Self, row: []const T) !void {
            if (self.cols != 0) {
                std.debug.assert(row.len == self.cols);
            } else {
                std.debug.assert(row.len <= std.math.maxInt(u32));
                self.cols = @truncate(u32, row.len);
            }
            for (row) |char| {
                try self.data.append(char);
            }
            self.rows += 1;
        }

        pub fn isInBounds(self: *const Self, row: i64, col: i64) bool {
            if (row < 0) return false;
            if (col < 0) return false;
            if (row >= self.rows) return false;
            if (col >= self.cols) return false;
            return true;
        }

        pub fn getPtr(self: *Self, row: i64, col: i64) ?*T {
            if (!self.isInBounds(row, col)) return null;
            return &self.data.items[@intCast(usize, self.cols * row) + @intCast(usize, col)];
        }

        pub fn print(self: *Self) void {
            var row: i64 = 0;
            while (row < self.rows) : (row += 1) {
                var col: i64 = 0;
                while (col < self.cols) : (col += 1) {
                    if (T == u8) {
                        std.debug.print("{c} ", .{self.getPtr(row, col).?.*});
                    } else {
                        std.debug.print("{} ", .{self.getPtr(row, col).?.*});
                    }
                }
                std.debug.print("\n", .{});
            }
        }
    };
}
