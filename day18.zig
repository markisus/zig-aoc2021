const std = @import("std");

pub fn print0(comptime str: []const u8) void {
    std.debug.print(str, .{});
}

const Token = union(enum) { left_bracket: void, right_bracket: void, number: u8 };
pub fn printToken(t: Token) void {
    switch (t) {
        .left_bracket => print0("["),
        .right_bracket => print0("]"),
        .number => |val| std.debug.print("{d}", .{val}),
    }
}

const SnailNumber = struct {
    const Self = @This();
    const TokenString = std.TailQueue(Token);

    allocator: std.mem.Allocator,
    data: TokenString,

    pub fn init(allocator: std.mem.Allocator) Self {
        var self: Self = undefined;
        self.allocator = allocator;
        self.data = .{};
        return self;
    }

    pub fn append(self: *Self, t: Token) !void {
        var node = try self.allocator.create(TokenString.Node);
        node.data = t;
        self.data.append(node);
    }

    pub fn prepend(self: *Self, t: Token) !void {
        var node = try self.allocator.create(TokenString.Node);
        node.data = t;
        self.data.prepend(node);
    }

    pub fn print(self: *Self) void {
        if (self.makeSentinel()) |sentinel| {
            var node = &sentinel;
            while (node.next) |next_node| {
                const prev_token = node.data;
                node = next_node;
                if (node.data == Token.number and prev_token == Token.number) {
                    print0(",");
                }
                printToken(node.data);
            }
        }
    }

    pub fn deinit(self: *Self) void {
        while (self.data.popFirst()) |node| {
            self.allocator.destroy(node);
        }
    }

    pub fn makeSentinel(self: *Self) ?TokenString.Node {
        if (self.data.first) |first_node| {
            return TokenString.Node{
                .data = Token{ .left_bracket = {} }, // dummy value
                .next = first_node,
            };
        }
        return null;
    }

    pub fn findExplodee(self: *Self) ?*TokenString.Node {
        // print0("Finding explodee\n");
        var nest_level: u64 = 0;

        if (self.makeSentinel()) |*sentinel| {
            var node: *TokenString.Node = sentinel;
            var idx: u64 = 0;
            while (node.next) |next_node| : (idx += 1) {
                node = next_node;
                switch (node.data) {
                    Token.left_bracket => nest_level += 1,
                    Token.right_bracket => {
                        std.debug.assert(nest_level >= 1);
                        nest_level -= 1;
                    },
                    else => {},
                }
                // printToken(node.data);
                // std.debug.print("nest level {d}\n", .{nest_level});
                if (nest_level == 5) {
                    // the next node is supposed to be a regular number
                    // std.debug.print("nest level within 4 found at idx {d}\n", .{idx});
                    std.debug.assert(node.next.?.data == Token.number);
                    return node;
                }
            }
        }
        return null;
    }

    pub fn getNodeMagnitude(node: *TokenString.Node) u64 {
        if (node.data == .number) {
            return node.data.number;
        }

        std.debug.assert(node.data == Token.left_bracket);

        const left_child = node.next.?;

        var stack_depth: u64 = 0;
        if (left_child.data == Token.left_bracket) stack_depth = 1;

        // search for the right child
        var search_node = left_child;
        while (stack_depth != 0) {
            search_node = search_node.next.?;
            if (search_node.data == Token.left_bracket) stack_depth += 1;
            if (search_node.data == Token.right_bracket) stack_depth -= 1;
        }
        // search_node is now where the left_child ends
        const right_child = search_node.next.?;
        return 3 * getNodeMagnitude(left_child) + 2 * getNodeMagnitude(right_child);
    }

    pub fn getMagnitude(self: *Self) u64 {
        if (self.data.first) |first_node| {
            return getNodeMagnitude(first_node);
        }
        return 0;
    }

    pub fn searchForLeftNumber(node: *TokenString.Node) ?*TokenString.Node {
        var searchee = node;
        while (searchee.prev) |prev| {
            searchee = prev;
            if (searchee.data == Token.number) {
                return searchee;
            }
        }
        return null;
    }

    pub fn searchForRightNumber(node: *TokenString.Node) ?*TokenString.Node {
        var searchee = node;
        while (searchee.next) |next| {
            searchee = next;
            if (searchee.data == Token.number) {
                return searchee;
            }
        }
        return null;
    }

    pub fn explode(self: *Self) bool {
        if (self.findExplodee()) |explodee| {
            // next next is the right number
            const left = explodee.next.?;
            const right = left.next.?;
            std.debug.assert(left.data == Token.number);
            std.debug.assert(right.data == Token.number);

            var leftNumber = searchForLeftNumber(left);
            var rightNumber = searchForRightNumber(right);

            if (leftNumber) |node| {
                node.data.number += left.data.number;
            }
            if (rightNumber) |node| {
                node.data.number += right.data.number;
            }

            // replace the explodee with 0
            // then remove the two numbers and closing paren
            explodee.data = Token{ .number = 0 };
            // remove the explodee
            var i: u8 = 0;
            while (i < 3) : (i += 1) {
                var removee = explodee.next.?;
                self.data.remove(removee);
                self.allocator.destroy(removee);
            }
            // print0("Reduced to ");
            // self.print();
            return true;
        }
        return false;
    }

    pub fn findSplitee(self: *Self) ?*TokenString.Node {
        if (self.makeSentinel()) |*sentinel| {
            var node = sentinel;
            while (node.next) |next| {
                node = next;
                if (node.data == Token.number and node.data.number > 9) {
                    return node;
                }
            }
        }
        return null;
    }

    pub fn split(self: *Self) !bool {
        if (self.findSplitee()) |splitee| {
            // add a node after the splitee
            const number = splitee.data.number;
            const low = number / 2;
            const high = number / 2 + (number % 2);

            splitee.data = Token{ .left_bracket = {} };

            var low_node = try self.allocator.create(TokenString.Node);
            var high_node = try self.allocator.create(TokenString.Node);
            var close_node = try self.allocator.create(TokenString.Node);
            low_node.data = Token{ .number = low };
            high_node.data = Token{ .number = high };
            close_node.data = Token{ .right_bracket = {} };

            self.data.insertAfter(splitee, close_node);
            self.data.insertAfter(splitee, high_node);
            self.data.insertAfter(splitee, low_node);

            return true;
        }
        return false;
    }

    pub fn reduce(self: *Self) !void {
        const debug = false;
        if (debug) {
            print0("Reducing ");
            self.print();
            print0("\n");
        }

        var reduced = true;
        while (reduced) {
            reduced = false;
            if (self.explode()) {
                if (debug) print0("Exploded\n");
                reduced = true;
            } else if (try self.split()) {
                if (debug) print0("Split\n");
                reduced = true;
            }

            if (reduced and debug) {
                print0("Reduced to ");
                self.print();
                print0("\n");
            }
        }
    }

    pub fn copy(self: *Self) !Self {
        var result = Self.init(self.allocator);
        errdefer result.deinit();

        if (self.makeSentinel()) |*sentinel| {
            var node = sentinel;
            while (node.next) |next| {
                node = next;
                try result.append(node.data);
            }
        }

        return result;
    }

    pub fn add(self: *Self, other: *Self) !void {
        // todo: proper errdefer?
        if (other.makeSentinel()) |*sentinel| {
            var node = sentinel;
            while (node.next) |next| {
                node = next;
                try self.append(node.data);
            }
        }
        try self.prepend(Token{ .left_bracket = {} });
        try self.append(Token{ .right_bracket = {} });
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) unreachable;

    var ns: [100]SnailNumber = undefined;
    var num_snails: u8 = 0;
    defer {
        var i: u8 = 0;
        while (i < num_snails) : (i += 1) {
            ns[i].deinit();
        }
    }

    var file = try std.fs.cwd().openFile("day18.txt", .{});
    var newline = true;
    while (true) {
        const byte = file.reader().readByte() catch break;
        if (newline) {
            ns[num_snails] = SnailNumber.init(gpa.allocator());
            num_snails += 1;
        }
        newline = false;
        var curr_snail = &ns[num_snails - 1];
        if (byte == ',') continue; // comma is implicit since all numbers are 1-digit
        // std.debug.print("Read char {c}\n", .{byte});
        var token: Token = undefined;
        switch (byte) {
            '[' => token = Token{ .left_bracket = {} },
            ']' => token = Token{ .right_bracket = {} },
            '\n' => {
                // print0("LINE DONE\n");
                // n.print();
                // print0("\n");
                newline = true;
                continue;
            },
            else => {
                std.debug.assert(byte - '0' <= 9);
                token = Token{ .number = byte - '0' };
            },
        }
        try curr_snail.append(token);
    }

    {
        // part 1
        var acc = try ns[0].copy();
        defer acc.deinit();

        var idx: u8 = 1;
        while (idx < num_snails) : (idx += 1) {
            try acc.add(&ns[idx]);
            try acc.reduce();
        }

        const magnitude_alt = acc.getMagnitude();
        std.debug.print("magnitude {d}\n", .{magnitude_alt});
    }
    {
        // part 2
        var max_magnitude: u64 = 0;
        var idx0: u8 = 0;
        while (idx0 < num_snails) : (idx0 += 1) {
            var idx1 = idx0 + 1;
            while (idx1 < num_snails) : (idx1 += 1) {
                var acc = try ns[idx0].copy();
                defer acc.deinit();

                try acc.add(&ns[idx1]);
                try acc.reduce();
                max_magnitude = @maximum(max_magnitude, acc.getMagnitude());
            }
        }

        std.debug.print("max pair magnitude {d}\n", .{max_magnitude});
    }

    // var max_pair_magnitude: u64 = 0;
    // var idx: u8 = 0;
    // while (idx < num_snails) : (idx += 1) {
    //     ns[idx].print();
    //     print0("\n");
    // }
}
