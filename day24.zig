const std = @import("std");

const InputIterator = struct {
    const Self = @This();

    ptr: *anyopaque,
    next_impl: fn (ptr: *anyopaque) ?[]const u8,

    pub fn next(self: *const Self) ?[]const u8 {
        return self.next_impl(self.ptr);
    }
};

const DigitsIn = struct {
    const Self = @This();
    const Alignment = @typeInfo(*Self).Pointer.alignment;

    string: []const u8 = undefined,
    idx: usize = 0,

    pub fn next_impl(ptr: *anyopaque) ?[]const u8 {
        var self = @ptrCast(*Self, @alignCast(Alignment, ptr));
        if (self.idx == self.string.len) {
            return null;
        }
        const result = self.string[self.idx .. self.idx + 1];
        self.idx += 1;
        return result;
    }

    pub fn reader(self: *Self) InputIterator {
        var it = InputIterator{ .ptr = self, .next_impl = next_impl };
        return it;
    }
};

const Op = enum { inp, add, mul, div, mod, eql };

pub fn parseOp(instr: []const u8) Op {
    if (std.mem.eql(u8, instr, "inp")) return Op.inp;
    if (std.mem.eql(u8, instr, "add")) return Op.add;
    if (std.mem.eql(u8, instr, "mul")) return Op.mul;
    if (std.mem.eql(u8, instr, "div")) return Op.div;
    if (std.mem.eql(u8, instr, "mod")) return Op.mod;
    if (std.mem.eql(u8, instr, "eql")) return Op.eql;
    unreachable;
}

// reference implementation for testing purposes
const State = struct {
    const Self = @This();

    w: i64 = 0,
    x: i64 = 0,
    y: i64 = 0,
    z: i64 = 0,

    pub fn get(self: *Self, char: u8) *i64 {
        return switch (char) {
            'x' => &self.x,
            'y' => &self.y,
            'z' => &self.z,
            'w' => &self.w,
            else => unreachable,
        };
    }

    pub fn execute(self: *Self, instr: []const u8, inputs: InputIterator) !void {
        var tokens = std.mem.tokenize(u8, instr, " ");
        const cmd = tokens.next().?;
        const a = tokens.next().?;
        var dest = self.get(a[0]);

        const op = parseOp(cmd);

        // std.debug.print("op{s}\n", .{op});

        if (op == Op.inp) {
            dest.* = try std.fmt.parseInt(i64, inputs.next().?, 10);
            return;
        }

        const b = tokens.next().?;
        var number: i64 = undefined;
        if (std.ascii.isAlpha(b[0])) {
            number = self.get(b[0]).*;
        } else {
            number = try std.fmt.parseInt(i64, b, 10);
        }

        if (op == Op.mul) {
            dest.* = dest.* * number;
        } else if (op == Op.add) {
            dest.* = dest.* + number;
        } else if (op == Op.div) {
            dest.* = @divTrunc(dest.*, number);
        } else if (op == Op.mod) {
            dest.* = @mod(dest.*, number);
        } else if (op == Op.eql) {
            if (dest.* == number) {
                dest.* = 1;
            } else {
                dest.* = 0;
            }
        } else {
            unreachable;
        }
    }
};

const Node = union(enum) {
    expr: Expr,
    variable: u64,
    constant: i64,
};

const Bounds = struct {
    const Self = @This();

    // use +-max i32 / 2 for infinities
    // to give us some buffer for arithmetic
    // calculations
    const NEG_INF = std.math.minInt(i32) / 2;
    const INF = std.math.maxInt(i32) / 2;

    low: i64 = NEG_INF,
    high: i64 = INF,
    max_known_divisor: i64 = 1,

    pub fn setLow(self: *Self, val: i64) void {
        self.low = if (val < NEG_INF) NEG_INF else val;
    }
    pub fn setHigh(self: *Self, val: i64) void {
        self.high = if (val > INF) INF else val;
    }
};

const Expr = struct {
    op: Op = undefined,
    left: usize = undefined,
    right: usize = undefined,
};

pub fn gcd(a: i64, b: i64) i64 {
    if (a == 0) return b;
    if (b == 0) return a;

    if (b < 0) {
        return gcd(a, -b);
    }

    // b is positive
    const rem = @rem(a, b);
    return gcd(b, std.math.absInt(rem) catch unreachable);
}

pub fn divides(num: i64, divisor: i64) bool {
    const abs_divisor = std.math.absInt(divisor) catch unreachable;
    return @mod(num, abs_divisor) == 0;
}

const NodeCompiler = struct {
    const Self = @This();

    allocator: std.mem.Allocator = undefined,
    nodes: std.ArrayList(Node) = undefined,
    bounds: std.ArrayList(?Bounds) = undefined,
    unused_variable_id: u64 = 0,

    w: usize = 0,
    x: usize = 0,
    y: usize = 0,
    z: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Self {
        var self: Self = .{};
        self.allocator = allocator;
        self.nodes = std.ArrayList(Node).init(allocator);
        self.bounds = std.ArrayList(?Bounds).init(allocator);
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.nodes.deinit();
        self.bounds.deinit();
    }

    pub fn get(self: *Self, char: u8) *usize {
        return switch (char) {
            'x' => &self.x,
            'y' => &self.y,
            'z' => &self.z,
            'w' => &self.w,
            else => unreachable,
        };
    }

    pub fn optimize(self: *Self) void {
        var progress: usize = 1;
        var iters: usize = 0;
        while (progress != 0 and iters < 100) : (iters += 1) {
            progress = 0;
            const fold_const = self.foldConstants();
            progress += fold_const;
            const norm_comm = self.normalizeCommutative();
            progress += norm_comm;
            const norm_assoc = self.normalizeAssociative();
            progress += norm_assoc;
            const norm_dist = self.normalizeDistributive();
            progress += norm_dist;
            const reduce_noops = self.reduceNoops();
            progress += reduce_noops;
            const removed_count = self.removeDeadNodes() catch unreachable;
            progress += removed_count;
        }
    }

    pub fn printNode(self: *Self, node_idx: usize, max_depth: usize) void {
        if (max_depth == 0) return;

        const node = self.nodes.items[node_idx];
        if (node == .variable) {
            std.debug.print("v{d}", .{node.variable});
            return;
        }
        if (node == .constant) {
            std.debug.print("{d}", .{node.constant});
            return;
        }
        if (node == .expr) {
            std.debug.print("(", .{});
            self.printNode(node.expr.left, max_depth - 1);
            const op_display = switch (node.expr.op) {
                .add => "+",
                .mul => "*",
                .div => "/",
                .eql => "=?",
                .mod => "%",
                else => unreachable,
            };
            std.debug.print("{s}", .{op_display});
            self.printNode(node.expr.right, max_depth - 1);
            std.debug.print(")", .{});
            return;
        }
        unreachable;
    }

    pub fn ingest(self: *Self, instr: []const u8) !void {
        if (self.nodes.items.len == 0) {
            // all variables start off as 0
            try self.nodes.append(Node{ .constant = 0 });
            self.x = 0;
            self.y = 0;
            self.z = 0;
            self.w = 0;
        }

        var tokens = std.mem.tokenize(u8, instr, " ");
        const cmd = tokens.next().?;
        const a = tokens.next().?;
        const a_node: *usize = self.get(a[0]);
        const op = parseOp(cmd);

        // create a new variable and overwrite a_node
        if (op == Op.inp) {
            const var_id = self.unused_variable_id;
            self.unused_variable_id += 1;

            var node = Node{ .variable = var_id };
            try self.nodes.append(node);
            a_node.* = self.nodes.items.len - 1;
            return;
        }

        // create an expression node and overwrite a_node
        const b = tokens.next().?;
        var b_node: usize = undefined;
        if (std.ascii.isAlpha(b[0])) {
            b_node = self.get(b[0]).*;
        } else {
            const b_constant = try std.fmt.parseInt(i64, b, 10);
            try self.nodes.append(Node{ .constant = b_constant });
            b_node = self.nodes.items.len - 1;
        }

        try self.nodes.append(Node{ .expr = .{ .op = op, .left = a_node.*, .right = b_node } });
        a_node.* = self.nodes.items.len - 1;
    }

    pub fn makeBounds(self: *Self) void {
        self.bounds.resize(self.nodes.items.len) catch unreachable;
        for (self.bounds.items) |*bounds| {
            bounds.* = null;
        }
        var node_idx: usize = 0;
        while (node_idx < self.nodes.items.len) : (node_idx += 1) {
            self.makeBoundsImpl(node_idx);
        }
    }

    pub fn makeBoundsImpl(self: *Self, node_idx: usize) void {
        if (self.bounds.items[node_idx] != null) return; // already made this bound

        self.bounds.items[node_idx] = Bounds{};

        var bounds = &(self.bounds.items[node_idx].?);
        const node = self.nodes.items[node_idx];
        if (node == .constant) {
            bounds.low = node.constant;
            bounds.high = node.constant;
            bounds.max_known_divisor = node.constant;
        } else if (node == .variable) {
            bounds.low = 1;
            bounds.high = 9;
        } else if (node == .expr) {
            self.makeBoundsImpl(node.expr.left);
            self.makeBoundsImpl(node.expr.right);
            const left_bounds = self.bounds.items[node.expr.left].?;
            const right_bounds = self.bounds.items[node.expr.right].?;

            if (node.expr.op == .add) {
                bounds.setLow(left_bounds.low + right_bounds.low);
                bounds.setHigh(left_bounds.high + right_bounds.high);
                bounds.max_known_divisor = gcd(left_bounds.max_known_divisor, right_bounds.max_known_divisor);
            }
            if (node.expr.op == .mul) {
                bounds.max_known_divisor = left_bounds.max_known_divisor * right_bounds.max_known_divisor;

                const ll = left_bounds.low * right_bounds.low;
                const lh = left_bounds.low * right_bounds.high;
                const hl = left_bounds.high * right_bounds.low;
                const hh = left_bounds.high * right_bounds.high;

                var min = @minimum(ll, lh);
                min = @minimum(min, hl);
                min = @minimum(min, hh);

                var max = @maximum(ll, lh);
                max = @maximum(max, hl);
                max = @maximum(max, hh);

                bounds.setLow(min);
                bounds.setHigh(max);
            }
            if (node.expr.op == .div) {
                if (right_bounds.low == right_bounds.high) {
                    const divisor = std.math.absInt(right_bounds.low) catch unreachable;
                    if (@mod(left_bounds.max_known_divisor, divisor) == 0) {
                        bounds.max_known_divisor = @divExact(left_bounds.max_known_divisor, divisor);
                    }
                }

                // programmer garauntees that division by 0 is impossible
                // so we can tighten bounds
                var left_low = left_bounds.low;
                if (left_low == 0) left_low += 1;
                var right_low = right_bounds.low;
                if (right_low == 0) right_low += 1;
                var left_high = left_bounds.high;
                if (left_high == 0) left_high -= 1;
                var right_high = right_bounds.high;
                if (right_high == 0) right_high -= 1;

                const ll = @divTrunc(left_low, right_low);
                const lh = @divTrunc(left_low, right_high);
                const hl = @divTrunc(left_high, right_low);
                const hh = @divTrunc(left_high, right_high);

                var min = @minimum(ll, lh);
                min = @minimum(min, hl);
                min = @minimum(min, hh);
                if (right_low <= -1) {
                    // can divide by negative -1
                    min = @minimum(min, -left_high);
                    min = @minimum(min, -left_low);
                }

                var max = @maximum(ll, lh);
                max = @maximum(max, hl);
                max = @maximum(max, hh);
                if (right_low <= -1) {
                    // can divide by negative -1
                    max = @maximum(max, -left_high);
                    max = @maximum(max, -left_low);
                }

                bounds.setLow(min);
                bounds.setHigh(max);
            }
            if (node.expr.op == .mod) {
                bounds.setHigh(left_bounds.high - 1);
                bounds.setLow(0);
            }
            if (node.expr.op == .eql) {
                if (right_bounds.high < left_bounds.low) {
                    bounds.setHigh(0);
                    bounds.setLow(0);
                } else if (left_bounds.high < right_bounds.low) {
                    bounds.setHigh(0);
                    bounds.setLow(0);
                } else {
                    bounds.setHigh(1);
                    bounds.setLow(0);
                }
            }
        }
    }

    pub fn normalizeCommutative(self: *Self) usize {
        var num_fixed: usize = 0;
        for (self.nodes.items) |*node| {
            if (node.* != .expr) continue;
            if (node.expr.op != .add and node.expr.op != .mul) continue;

            const left_child = self.nodes.items[node.expr.left];
            const right_child = self.nodes.items[node.expr.right];

            if (left_child == .constant) continue; // already normalized
            // in the case that both right and left are constants
            // this node will be dealt with during constant folding

            var should_swap: bool = false;

            if (right_child == .constant) {
                // we want constants to be on the left
                should_swap = true;
            } else if (node.expr.left > node.expr.right) {
                // we want the smaller idx to be on the left
                // if neither are constants
                should_swap = true;
            }

            if (should_swap) {
                // std.debug.print("before {s}\n", .{node.*});
                // std.debug.print("\tchildren {s} {s}\n", .{ left_child, right_child });
                const tmp = node.expr.left;
                node.expr.left = node.expr.right;
                node.expr.right = tmp;
                // std.debug.print("after {s}\n", .{node.*});
                num_fixed += 1;
            }
        }
        return num_fixed;
    }

    pub fn normalizeDistributive(self: *Self) usize {
        self.makeBounds();

        var num_fixed: usize = 0;
        var idx: usize = 0;
        const max_node_idx = self.nodes.items.len;
        while (idx < max_node_idx) : (idx += 1) {
            var node = &self.nodes.items[idx];
            if (node.* != .expr) continue;

            if (node.expr.op == .mul) {
                // c1 * (c0 + b) => c0*c1 + c1*b
                const left_child = self.nodes.items[node.expr.left];
                const right_child = self.nodes.items[node.expr.right];

                if (left_child != .constant) continue;
                if (right_child != .expr) continue;
                if (right_child.expr.op != .add) continue;
                const right_left_child = self.nodes.items[right_child.expr.left];
                if (right_left_child != .constant) continue;

                const left_node = Node{ .constant = left_child.constant * right_left_child.constant };
                const right_node = Node{ .expr = Expr{ .op = .mul, .left = node.expr.left, .right = right_child.expr.right } };

                // connect this node to the new node
                // we must do this before appending the new node, because
                // appending invalidates the nodes.items pointer
                const new_node_left_idx = self.nodes.items.len;
                const new_node_right_idx = self.nodes.items.len + 1;
                node.expr.op = .add;
                node.expr.left = new_node_left_idx;
                node.expr.right = new_node_right_idx;

                // add the child nodes
                self.nodes.append(left_node) catch unreachable;
                self.nodes.append(right_node) catch unreachable;
                num_fixed += 1;
            } else if (node.expr.op == .div) {
                // std.debug.print("Can reduce div {s}?\n", .{node});
                const left_child = self.nodes.items[node.expr.left];
                const right_child = self.nodes.items[node.expr.right];
                // std.debug.print("\t left {s} right {s}\n", .{ left_child, right_child });

                if (right_child != .constant) continue;
                if (left_child != .expr) continue;
                if (left_child.expr.op == .add) {
                    // (a + b) / c1 => c0/c1 + b/c1  when (a % c1) == 0 or (b % c1) == 0
                    const left_left_bounds = self.bounds.items[left_child.expr.left].?;
                    const left_right_bounds = self.bounds.items[left_child.expr.right].?;
                    const divides_left_left = divides(left_left_bounds.max_known_divisor, right_child.constant);
                    const divides_left_right = divides(left_right_bounds.max_known_divisor, right_child.constant);
                    if (divides_left_left or divides_left_right) {
                        const left_node = Node{ .expr = Expr{ .op = .div, .left = left_child.expr.left, .right = node.expr.right } };
                        const right_node = Node{ .expr = Expr{ .op = .div, .left = left_child.expr.right, .right = node.expr.right } };

                        // connect this node to the new node
                        // we must do this before appending the new node, because
                        // appending invalidates the nodes.items pointer
                        const new_node_left_idx = self.nodes.items.len;
                        const new_node_right_idx = self.nodes.items.len + 1;
                        node.expr.op = .add;
                        node.expr.left = new_node_left_idx;
                        node.expr.right = new_node_right_idx;

                        self.nodes.append(left_node) catch unreachable;
                        self.nodes.append(right_node) catch unreachable;
                        num_fixed += 1;
                    }
                } else if (left_child.expr.op == .mul) {
                    // (c0*b)/c1 => (c0/c1)*b when (c1 % c2) == 0
                    const left_left_child = self.nodes.items[left_child.expr.left];
                    if (left_left_child != .constant) continue;

                    // std.debug.print("Form ok (c0*b)/c1, checking rem {d}, {d}!\n", .{ left_left_child.constant, right_child.constant });
                    if (@rem(left_left_child.constant, std.math.absInt(right_child.constant) catch unreachable) != 0) continue;
                    // std.debug.print("Reduction proceeding!\n", .{});

                    const left_node = Node{ .constant = @divExact(left_left_child.constant, right_child.constant) };

                    // connect this node to the new node
                    // we must do this before appending the new node, because
                    // appending invalidates the nodes.items pointer
                    const new_node_left_idx = self.nodes.items.len;
                    node.expr.op = .mul;
                    node.expr.left = new_node_left_idx;
                    node.expr.right = left_child.expr.right;

                    self.nodes.append(left_node) catch unreachable;
                    num_fixed += 1;
                }
            } else if (node.expr.op == .mod) {
                const left_child = self.nodes.items[node.expr.left];
                const right_child = self.nodes.items[node.expr.right];

                if (right_child != .constant) continue;
                if (left_child != .expr) continue;
                if (left_child.expr.op == .add) {
                    // (a + b) % c1 => c0%c1 + b%c1  when (a % c1) == 0 or (b % c1) == 0
                    const left_left_bounds = self.bounds.items[left_child.expr.left].?;
                    const left_right_bounds = self.bounds.items[left_child.expr.right].?;
                    const divides_left_left = divides(left_left_bounds.max_known_divisor, right_child.constant);
                    const divides_left_right = divides(left_right_bounds.max_known_divisor, right_child.constant);
                    if (divides_left_left or divides_left_right) {
                        const left_node = Node{ .expr = Expr{ .op = .mod, .left = left_child.expr.left, .right = node.expr.right } };
                        const right_node = Node{ .expr = Expr{ .op = .mod, .left = left_child.expr.right, .right = node.expr.right } };

                        // connect this node to the new node
                        // we must do this before appending the new node, because
                        // appending invalidates the nodes.items pointer
                        const new_node_left_idx = self.nodes.items.len;
                        const new_node_right_idx = self.nodes.items.len + 1;
                        node.expr.op = .add;
                        node.expr.left = new_node_left_idx;
                        node.expr.right = new_node_right_idx;

                        self.nodes.append(left_node) catch unreachable;
                        self.nodes.append(right_node) catch unreachable;
                        num_fixed += 1;
                    }
                }
            }
        }
        return num_fixed;
    }

    pub fn normalizeAssociative(self: *Self) usize {
        // std.debug.print("Normalize assoc with {d}\n", .{self.nodes.items.len});
        // assuming no overflows
        // (c1 + (c2 + expr)) => (c1+c2) + expr
        // (c1 * (c2 * expr)) => (c1*c2) * expr
        // (expr / c1) / c2 => expr / (c1 * c2) <- is this one suss?

        var num_fixed: usize = 0;
        var idx: usize = 0;
        const max_node_idx = self.nodes.items.len;
        while (idx < max_node_idx) : (idx += 1) {
            var node = &self.nodes.items[idx];
            if (node.* != .expr) continue;

            if (node.expr.op == .add or node.expr.op == .mul) {
                const left_child = self.nodes.items[node.expr.left];
                const right_child = self.nodes.items[node.expr.right];
                if (left_child != .constant) continue;
                if (right_child != .expr) continue;
                if (right_child.expr.op != node.expr.op) continue;

                const right_left_child = self.nodes.items[right_child.expr.left];
                if (right_left_child != .constant) continue;

                // connect this node to the new node
                // we must do this before appending the new node, because
                // appending invalidates the nodes.items pointer
                const new_node = Node{ .expr = Expr{ .op = node.expr.op, .left = node.expr.left, .right = right_child.expr.left } };

                const new_node_idx = self.nodes.items.len;
                node.expr.left = new_node_idx;
                node.expr.right = right_child.expr.right;

                // a new node representing (c1 op c2)
                self.nodes.append(new_node) catch unreachable;
                // std.debug.print("\tnodes len is now {d}\n", .{self.nodes.items.len});
                num_fixed += 1;
            }
        }
        return num_fixed;
    }

    // transfer the sub-graph rooted at source_nodes[node_idx] into dst_nodes, deduplicating as subgraphs as necessary
    pub fn removeDeadNodesImpl(source_nodes: []const Node, transferred_source_nodes: *std.AutoHashMap(Node, usize), dest_nodes: *std.ArrayList(Node), node_idx: usize) !usize {
        const debug = false;
        const node = source_nodes[node_idx];

        if (transferred_source_nodes.get(node)) |remapped_idx| {
            // we already found out that we need this node
            // and it was remapped to `remapped_idx`
            if (debug) std.debug.print("Aready remapped {s} to {d}\n", .{ node, remapped_idx });
            return remapped_idx;
        }

        if (node == .constant or node == .variable) {
            const remapped_idx = dest_nodes.items.len;
            try transferred_source_nodes.put(node, remapped_idx);
            try dest_nodes.append(node);
            if (debug) std.debug.print("Remapped {s} to {d}\n", .{ node, remapped_idx });
            return remapped_idx;
        }

        if (node == .expr) {
            var remapped_node = node;
            const remapped_left = removeDeadNodesImpl(source_nodes, transferred_source_nodes, dest_nodes, node.expr.left) catch unreachable;
            const remapped_right = removeDeadNodesImpl(source_nodes, transferred_source_nodes, dest_nodes, node.expr.right) catch unreachable;
            remapped_node.expr.left = remapped_left;
            remapped_node.expr.right = remapped_right;

            const remapped_idx = dest_nodes.items.len;
            try transferred_source_nodes.put(node, remapped_idx);

            try dest_nodes.append(remapped_node);
            if (debug) std.debug.print("Remapped {s} to {d}\n", .{ node, remapped_idx });
            return remapped_idx;
        }

        unreachable;
    }

    pub fn removeDeadNodes(self: *Self) !usize {
        // std.debug.print("Removing dead nodes\n", .{});
        var transferred_source_nodes = std.AutoHashMap(Node, usize).init(self.allocator);
        defer transferred_source_nodes.deinit();

        var dest_nodes = std.ArrayList(Node).init(self.allocator);
        defer dest_nodes.deinit();

        // std.debug.print("Removing dead nodes impl\n", .{});
        const remapped_z = try removeDeadNodesImpl(self.nodes.items, &transferred_source_nodes, &dest_nodes, self.z);

        // std.debug.print("Finishing up\n", .{});
        // swap self.nodes <=> dest_nodes
        const instrs_before = self.nodes.items.len;
        const tmp = dest_nodes;
        dest_nodes = self.nodes;
        self.nodes = tmp;

        const instrs_after = self.nodes.items.len;
        self.z = remapped_z;

        if (instrs_before > instrs_after) return instrs_before - instrs_after;
        return 0;
    }

    pub fn evalNodeImpl(self: *Self, node_idx: usize, variables: []const i64, eval_cache: *std.AutoHashMap(usize, i64)) i64 {
        const debug = false;

        if (debug) std.debug.print("Eval {s}\n", .{self.nodes.items[node_idx]});

        if (eval_cache.get(node_idx)) |value| {
            if (debug) std.debug.print("cached value {d}\n", .{value});
            return value;
        }

        var result: i64 = 0;

        const node = self.nodes.items[node_idx];
        if (node == .variable) {
            const variable_value = variables[node.variable];
            if (debug) std.debug.print("variable {d}={d}\n", .{ node.variable, variable_value });
            result = variable_value;
        }
        if (node == .constant) {
            if (debug) std.debug.print("constant {d}\n", .{node.constant});
            result = node.constant;
        }
        if (node == .expr) {
            if (debug) std.debug.print("binary {s}\n", .{node.expr.op});
            const lval = self.evalNodeImpl(node.expr.left, variables, eval_cache);
            const rval = self.evalNodeImpl(node.expr.right, variables, eval_cache);
            if (node.expr.op == .add) result = rval + lval;
            if (node.expr.op == .mul) result = rval * lval;
            if (node.expr.op == .mod) result = std.math.absInt(@mod(lval, rval)) catch unreachable;
            if (node.expr.op == .div) result = @divTrunc(lval, rval);
            if (node.expr.op == .eql) {
                if (debug) std.debug.print("testing {d} == {d}\n", .{ lval, rval });
                if (rval == lval) {
                    result = 1;
                } else {
                    result = 0;
                }
            }
        }

        eval_cache.put(node_idx, result) catch {}; // ignore error
        if (debug) std.debug.print("{d} evaluated to {d}\n", .{ node_idx, result });
        return result;
    }

    pub fn evalNode(self: *Self, node_idx: usize, variables: []const i64) i64 {
        var eval_cache = std.AutoHashMap(usize, i64).init(self.allocator);
        defer eval_cache.deinit();
        return self.evalNodeImpl(node_idx, variables, &eval_cache);
    }

    pub fn foldConstants(self: *Self) usize {
        // returns number of nodes folded to constants
        self.makeBounds();

        var num_fixed: usize = 0;
        for (self.nodes.items) |*node, node_idx| {
            if (node.* != .expr) continue;

            const bounds = self.bounds.items[node_idx].?;
            if (bounds.low == bounds.high) {
                node.* = Node{ .constant = bounds.low };
                num_fixed += 1;
                continue;
            }

            const left_child = self.nodes.items[node.expr.left];
            const right_child = self.nodes.items[node.expr.right];
            if (left_child != .constant or right_child != .constant) continue;

            // both children are constants
            // replace this node by a constant
            const value = self.evalNode(node_idx, &.{});
            node.* = Node{ .constant = value };
            num_fixed += 1;
        }
        return num_fixed;
    }

    pub fn reduceNoops(self: *Self) usize {
        self.makeBounds();
        // std.debug.print("reduce noops, {d} instrs\n", .{self.nodes.items.len});
        // returns number of nodes changed to noops
        var num_fixed: usize = 0;
        for (self.nodes.items) |*node| {
            if (node.* != .expr) continue;
            // std.debug.print("testings {s}\n", .{node.*});
            const left_child = self.nodes.items[node.expr.left];
            const right_child = self.nodes.items[node.expr.right];

            if (node.expr.op == .add and left_child == .constant and left_child.constant == 0) {
                node.* = right_child;
                num_fixed += 1;
            } else if (node.expr.op == .mul and left_child == .constant and left_child.constant == 1) {
                node.* = right_child;
                num_fixed += 1;
            } else if (node.expr.op == .mul and left_child == .constant and left_child.constant == 0) {
                node.* = Node{ .constant = 0 };
                num_fixed += 1;
            } else if (node.expr.op == .div and right_child == .constant and right_child.constant == 1) {
                node.* = left_child;
                num_fixed += 1;
            } else if (node.expr.op == .mod) {
                const left_bounds = self.bounds.items[node.expr.left].?;
                const right_bounds = self.bounds.items[node.expr.right].?;
                if (left_bounds.low >= 0 and left_bounds.high < right_bounds.low) {
                    // mod does nothing
                    node.* = left_child;
                } else if (right_bounds.low == right_bounds.high and divides(left_bounds.max_known_divisor, right_bounds.low)) {
                    node.* = Node{ .constant = 0 };
                }
            }
        }
        return num_fixed;
    }

    pub fn print(self: *Self) void {
        for (self.nodes.items) |node, node_idx| {
            if (node == .constant) {
                std.debug.print("n{d} := {d}\n", .{ node_idx, node.constant });
            }
            if (node == .variable) {
                std.debug.print("n{d} := v{d}\n", .{ node_idx, node.variable });
            }
            if (node == .expr) {
                std.debug.print("n{d} := {s} n{d} n{d}\n", .{ node_idx, node.expr.op, node.expr.left, node.expr.right });
            }
        }
    }

    pub fn printZ3Program(self: *Self) void {
        // constraints (a, b, c, d, e)
        std.debug.print("from z3 import *\n", .{});

        for (self.nodes.items) |node, node_idx| {
            if (node == .constant) continue;
            if (node == .variable) {
                std.debug.print("v{d} = Int(\"v{d}\")\n", .{ node.variable, node.variable });
            } else {
                // expr node
                std.debug.print("n{d} = Int(\"n{d}\")\n", .{ node_idx, node_idx });
            }
        }

        std.debug.print("constraints = (", .{});
        std.debug.print("n{d} == 0, ", .{self.z});
        for (self.nodes.items) |node| {
            if (node == .variable) {
                std.debug.print("v{d} >= 1, v{d} <= 9,", .{ node.variable, node.variable });
            }
        }
        for (self.nodes.items) |node, node_idx| {
            if (node == .constant) {
                continue;
            }
            if (node == .variable) {
                continue;
            }
            if (node == .expr) {
                const left_child = self.nodes.items[node.expr.left];
                const right_child = self.nodes.items[node.expr.right];

                var left_child_buf: [128]u8 = undefined;
                var left_child_display: []u8 = undefined;
                if (left_child == .constant) {
                    left_child_display = std.fmt.bufPrint(left_child_buf[0..], "{d}", .{left_child.constant}) catch unreachable;
                } else if (left_child == .variable) {
                    left_child_display = std.fmt.bufPrint(left_child_buf[0..], "v{d}", .{left_child.variable}) catch unreachable;
                } else {
                    // expression
                    left_child_display = std.fmt.bufPrint(left_child_buf[0..], "n{d}", .{node.expr.left}) catch unreachable;
                }

                var right_child_buf: [128]u8 = undefined;
                var right_child_display: []u8 = undefined;
                if (right_child == .constant) {
                    right_child_display = std.fmt.bufPrint(right_child_buf[0..], "{d}", .{right_child.constant}) catch unreachable;
                } else if (right_child == .variable) {
                    right_child_display = std.fmt.bufPrint(right_child_buf[0..], "v{d}", .{right_child.variable}) catch unreachable;
                } else {
                    // expression
                    right_child_display = std.fmt.bufPrint(right_child_buf[0..], "n{d}", .{node.expr.right}) catch unreachable;
                }

                const data = .{ left_child_display, right_child_display, node_idx };
                switch (node.expr.op) {
                    .add => std.debug.print("{s} + {s} == n{d}", data),
                    .mul => std.debug.print("{s} * {s} == n{d}", data),
                    .div => std.debug.print("{s} / {s} == n{d}", data),
                    .mod => std.debug.print("{s} % {s} == n{d}", data),
                    .eql => std.debug.print("If({s} == {s}, 1, 0) == n{d}", data),
                    else => unreachable,
                }
                std.debug.print(", ", .{});
            }
        }
        std.debug.print(")\n", .{});
        const opt_prog =
            \\def opt(mode, solver, known_digits, next_low, next_high):
            \\    if len(known_digits) == 14:
            \\        print(f"Solved {''.join(str(s) for s in known_digits)}")
            \\        return known_digits
            \\
            \\    print(f"Current partial solution {mode} = {''.join(str(s) for s in known_digits)}[{next_low}-{next_high}]")
            \\    # print(f"Finding optimal digit {len(known_digits)}, known range [{next_low}, {next_high}]")
            \\    
            \\    if next_low == next_high:
            \\        # print(f"Digit {len(known_digits)} solved = {next_low}")
            \\        next_known_digits = known_digits.copy()
            \\        next_known_digits.append(next_low)
            \\        return opt(mode, solver, next_known_digits, 1, 9)
            \\
            \\    
            \\    additional_constraints = []
            \\    for i, val in enumerate(known_digits):
            \\        additional_constraints.append(Int(f'v{i}') == val)
            \\
            \\    midpoint = (next_low + next_high) // 2
            \\
            \\    search_region = (midpoint+1, next_high)
            \\    other_region = (next_low, midpoint)
            \\    if mode == "min":
            \\        search_region = (next_low, midpoint)
            \\        other_region = (midpoint+1, next_high)
            \\
            \\    additional_constraints.append(Int(f'v{len(known_digits)}') >= search_region[0])
            \\    additional_constraints.append(Int(f'v{len(known_digits)}') <= search_region[1])
            \\
            \\    # print("Searching with constraints", additional_constraints)
            \\
            \\    solver.push()
            \\    solver.add(additional_constraints)
            \\    if solver.check() == CheckSatResult(Z3_L_TRUE):
            \\        # print(f"Digit {len(known_digits)} in = {search_region[0]}, {search_region[1]}")
            \\        # read out the solution found for this digit
            \\        m = solver.model()
            \\        solved_val = m[Int(f"v{len(known_digits)}")].as_long()
            \\        solver.pop()
            \\        return opt(mode, solver, known_digits, search_region[0], search_region[1])
            \\    else:
            \\        # print(f"Digit {len(known_digits)} in = {other_region[0]}, {other_region[1]}")
            \\        solver.pop()
            \\        return opt(mode, solver, known_digits, other_region[0], other_region[1])
            \\
            \\s = Solver()
            \\s.add(constraints)
            \\print("Maximizing")
            \\opt("max", s, [], 1, 9)
            \\print("Minimizing")
            \\opt("min", s, [], 1, 9)
        ;
        std.debug.print("{s}", .{opt_prog});
    }
};

// Direct transpilation to z3 script
// this is too slow in practice
const Z3Transpiler = struct {
    const Self = @This();
    const ConstraintBuf = struct {
        buf: [256]u8,
        len: usize = 0,

        pub fn init(string: []const u8) ConstraintBuf {
            var result: ConstraintBuf = undefined;
            std.mem.copy(u8, result.buf[0..], string);
            result.len = string.len;
            return result;
        }

        pub fn initFmt(comptime fmt: []const u8, data: anytype) !ConstraintBuf {
            var self: ConstraintBuf = undefined;
            self.len = (try std.fmt.bufPrint(self.buf[0..], fmt, data)).len;
            return self;
        }

        pub fn get(self: *const ConstraintBuf) []const u8 {
            return self.buf[0..self.len];
        }
    };

    allocator: std.mem.Allocator = undefined,
    constraints: std.ArrayList(ConstraintBuf) = undefined,
    unused_variable_id: u64 = 0,

    w: usize = 0,
    x: usize = 0,
    y: usize = 0,
    z: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Self {
        var self: Self = .{};
        self.allocator = allocator;
        self.constraints = std.ArrayList(ConstraintBuf).init(allocator);
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.constraints.deinit();
    }

    pub fn get(self: *Self, char: u8) *usize {
        return switch (char) {
            'x' => &self.x,
            'y' => &self.y,
            'z' => &self.z,
            'w' => &self.w,
            else => unreachable,
        };
    }

    pub fn ingest(self: *Self, instr: []const u8) !void {
        const debug = false;
        _ = debug;

        if (self.constraints.items.len == 0) {
            // all variables start off as 0
            try self.constraints.append(ConstraintBuf.init("x0 == 0"));
            try self.constraints.append(ConstraintBuf.init("y0 == 0"));
            try self.constraints.append(ConstraintBuf.init("z0 == 0"));
            try self.constraints.append(ConstraintBuf.init("z0 == 0"));
        }

        var tokens = std.mem.tokenize(u8, instr, " ");
        const cmd = tokens.next().?;
        const a = tokens.next().?;
        const a_node: *usize = self.get(a[0]);
        const op = parseOp(cmd);

        // create a new variable and overwrite a_node
        if (op == Op.inp) {
            const var_id = self.unused_variable_id;
            self.unused_variable_id += 1;

            var lb_constraint = try ConstraintBuf.initFmt("v{d} >= 1", .{var_id});
            var ub_constraint: ConstraintBuf = undefined;
            var eq_constraint: ConstraintBuf = undefined;
            ub_constraint.len = (try std.fmt.bufPrint(ub_constraint.buf[0..], "v{d} <= 9", .{var_id})).len;
            try self.constraints.append(lb_constraint);
            try self.constraints.append(ub_constraint);

            a_node.* += 1;
            eq_constraint.len = (try std.fmt.bufPrint(eq_constraint.buf[0..], "v{d} == {c}{d}", .{ var_id, a[0], a_node.* })).len;
            try self.constraints.append(eq_constraint);

            return;
        }

        var constraint: ConstraintBuf = undefined;
        const b = tokens.next().?;
        if (std.ascii.isAlpha(b[0])) {
            const b_node = self.get(b[0]).*;
            const data = .{ a[0], a_node.*, b[0], b_node, a[0], a_node.* + 1 };
            constraint = switch (op) {
                .add => try ConstraintBuf.initFmt("{c}{d} + {c}{d} == {c}{d}", data),
                .mul => try ConstraintBuf.initFmt("{c}{d} * {c}{d} == {c}{d}", data),
                .div => try ConstraintBuf.initFmt("{c}{d} / {c}{d} == {c}{d}", data),
                .mod => try ConstraintBuf.initFmt("{c}{d} % {c}{d} == {c}{d}", data),
                .eql => try ConstraintBuf.initFmt("If({c}{d} == {c}{d}, 1, 0) == {c}{d}", data),
                else => unreachable,
            };
            a_node.* += 1;
        } else {
            const data = .{ a[0], a_node.*, b, a[0], a_node.* + 1 };
            constraint = switch (op) {
                .add => try ConstraintBuf.initFmt("{c}{d} + {s} == {c}{d}", data),
                .mul => try ConstraintBuf.initFmt("{c}{d} * {s} == {c}{d}", data),
                .div => try ConstraintBuf.initFmt("{c}{d} / {s} == {c}{d}", data),
                .mod => try ConstraintBuf.initFmt("{c}{d} % {s} == {c}{d}", data),
                .eql => try ConstraintBuf.initFmt("If({c}{d} == {s}, 1, 0) == {c}{d}", data),
                else => unreachable,
            };
            a_node.* += 1;
        }
        try self.constraints.append(constraint);
    }

    pub fn print(self: *Self) void {
        const vars: [4]u8 = .{ 'x', 'y', 'z', 'w' };
        for (vars) |v| {
            var version: u64 = 0;
            while (version <= self.get(v).*) : (version += 1) {
                std.debug.print("{c}{d} = Int('{c}{d}')\n", .{ v, version, v, version });
            }
        }
        var vid: usize = 0;
        while (vid < self.unused_variable_id) : (vid += 1) {
            std.debug.print("v{d} = Int('v{d}')\n", .{ vid, vid });
        }
        std.debug.print("constraints = (", .{});
        for (self.constraints.items) |constraint| {
            std.debug.print("{s}, ", .{constraint.get()});
        }
        std.debug.print("z{d} == 0", .{self.z});
        std.debug.print(")", .{});
    }
};

// transpilation to C
// intended for
//    clang => llvm ir => optimizer => parse and convert to z3
// solves faster in Z3 than the NodeCompiler.printZ3Program(),
// but takes more manual work to run this pipeline
const CTranspiler = struct {
    const Self = @This();
    const StatementBuf = struct {
        buf: [256]u8,
        len: usize = 0,

        pub fn init(string: []const u8) StatementBuf {
            var result: StatementBuf = undefined;
            std.mem.copy(u8, result.buf[0..], string);
            result.len = string.len;
            return result;
        }

        pub fn initFmt(comptime fmt: []const u8, data: anytype) !StatementBuf {
            var self: StatementBuf = undefined;
            self.len = (try std.fmt.bufPrint(self.buf[0..], fmt, data)).len;
            return self;
        }

        pub fn get(self: *const StatementBuf) []const u8 {
            return self.buf[0..self.len];
        }
    };

    allocator: std.mem.Allocator = undefined,
    statements: std.ArrayList(StatementBuf) = undefined,
    unused_variable_id: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) Self {
        var self: Self = .{};
        self.allocator = allocator;
        self.statements = std.ArrayList(StatementBuf).init(allocator);
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.statements.deinit();
    }

    pub fn ingest(self: *Self, instr: []const u8) !void {
        const debug = false;
        _ = debug;

        if (self.statements.items.len == 0) {
            // all variables start off as 0
            try self.statements.append(StatementBuf.init("long x = 0"));
            try self.statements.append(StatementBuf.init("long y = 0"));
            try self.statements.append(StatementBuf.init("long z = 0"));
            try self.statements.append(StatementBuf.init("long w = 0"));
        }

        var tokens = std.mem.tokenize(u8, instr, " ");
        const cmd = tokens.next().?;
        const a = tokens.next().?;
        const op = parseOp(cmd);

        // create a new variable and overwrite a_node
        if (op == Op.inp) {
            const var_id = self.unused_variable_id;
            self.unused_variable_id += 1;
            var eq_statement: StatementBuf = undefined;
            eq_statement.len = (try std.fmt.bufPrint(eq_statement.buf[0..], "{c} = v{d}", .{ a[0], var_id })).len;
            try self.statements.append(eq_statement);
            return;
        }

        var statement: StatementBuf = undefined;
        const b = tokens.next().?;
        if (std.ascii.isAlpha(b[0])) {
            const data = .{ a[0], a[0], b[0] };
            statement = switch (op) {
                .add => try StatementBuf.initFmt("{c} = {c} + {c}", data),
                .mul => try StatementBuf.initFmt("{c} = {c} * {c}", data),
                .div => try StatementBuf.initFmt("{c} = {c} / {c}", data),
                .mod => try StatementBuf.initFmt("{c} = {c} % {c}", data),
                .eql => try StatementBuf.initFmt("{c} = {c} == {c} ? 1 : 0", data),
                else => unreachable,
            };
        } else {
            const data = .{ a[0], a[0], b };
            statement = switch (op) {
                .add => try StatementBuf.initFmt("{c} = {c} + {s}", data),
                .mul => try StatementBuf.initFmt("{c} = {c} * {s}", data),
                .div => try StatementBuf.initFmt("{c} = {c} / {s}", data),
                .mod => try StatementBuf.initFmt("{c} = {c} % {s}", data),
                .eql => try StatementBuf.initFmt("{c} = {c} == {s} ? 1 : 0", data),
                else => unreachable,
            };
        }
        try self.statements.append(statement);
    }

    pub fn print(self: *Self) void {
        var var_id: usize = 0;
        while (var_id < self.unused_variable_id) : (var_id += 1) {
            std.debug.print("extern const long v{d};\n", .{var_id});
        }

        std.debug.print("long check_inputs() {{\n", .{});
        var_id = 0;
        while (var_id < self.unused_variable_id) : (var_id += 1) {
            std.debug.print("\tif (v{d} < 1) return 1; if (v{d} > 9) return 0;\n", .{ var_id, var_id });
        }
        std.debug.print("\treturn 1; \n}}\n", .{});

        std.debug.print("long go() {{\n\tif (!check_inputs()) return 1;\n", .{});
        for (self.statements.items) |statement| {
            std.debug.print("\t{s};\n", .{statement.get()});
        }
        std.debug.print("\treturn z;\n}}\n", .{});
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) unreachable;

    var z3_transpiler = Z3Transpiler.init(gpa.allocator());
    defer z3_transpiler.deinit();

    var node_compiler = NodeCompiler.init(gpa.allocator());
    defer node_compiler.deinit();

    var file = try std.fs.cwd().openFile("day24.txt", .{});
    var buf: [256]u8 = undefined;
    while (try file.reader().readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        try node_compiler.ingest(line);
    }
    node_compiler.optimize();
    node_compiler.printZ3Program();
}
